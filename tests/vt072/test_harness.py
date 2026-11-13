"""
Test Harness for VT-072 (Nguyen Quang Anh - 23001825 - SE2026-T19)
Module: SyncRetryService & Transactional Outbox
Validates:
- Transient error retry with exponential backoff & jitter (AC-01)
- Zero side-effect duplication via Idempotency Key (AC-02)
- Consistent state on partial failure (AC-03)
- Faithful persistence status / Kill deliberate mutation (AC-04)
- Deterministic reconciliation (AC-05)
- Concurrency p95 latency <= 5.0s under 200 tasks (NFC-01)
- Memory bounds & FIFO eviction (NFC-02)
"""

import hashlib
import json
import random
import time
from typing import Dict, Any, List, Optional, Tuple


class DiskPersistence:
    def __init__(self, simulate_failure: bool = False, deliberate_bug: bool = False):
        self.storage: Dict[str, str] = {}
        self.simulate_failure = simulate_failure
        self.deliberate_bug = deliberate_bug  # Deliberate mutation: return success even if persistence failed

    def save_with_status(self, key: str, data: Dict[str, Any]) -> Dict[str, Any]:
        if self.simulate_failure:
            if self.deliberate_bug:
                # MUTANT: reports success despite persistence failure!
                return {"success": True, "error": "", "bytes": 0, "status": "COMMITTED"}
            return {"success": False, "error": "PERSISTENCE_ERROR", "bytes": 0, "status": "FAILED_PERSISTENCE"}
        
        serialized = json.dumps(data)
        self.storage[key] = serialized
        return {"success": True, "error": "", "bytes": len(serialized), "status": "COMMITTED"}

    def load(self, key: str) -> Optional[Dict[str, Any]]:
        if key not in self.storage:
            return None
        try:
            return json.loads(self.storage[key])
        except Exception:
            return None


class MockExternalCloudAPI:
    def __init__(self):
        self.processed_keys: Dict[str, Dict[str, Any]] = {}
        self.side_effect_count: Dict[str, int] = {}
        self.total_received_requests: int = 0

    def receive_request(self, idempotency_key: str, payload: Dict[str, Any], simulated_status: int, drop_ack: bool = False) -> Tuple[int, Dict[str, Any]]:
        self.total_received_requests += 1
        
        if simulated_status in (500, 502, 503, 504):
            return simulated_status, {"error": "TRANSIENT_SERVER_ERROR"}
        
        if simulated_status in (400, 401, 422):
            return simulated_status, {"error": "FATAL_CLIENT_ERROR"}
        
        if simulated_status == 200:
            if idempotency_key in self.processed_keys:
                # Deduplication: do not increment side effect
                stored = self.processed_keys[idempotency_key]
                return 200, {"status": "SUCCESS", "deduplicated": True, "data": stored}
            
            # Apply side effect (first time only)
            self.side_effect_count[idempotency_key] = self.side_effect_count.get(idempotency_key, 0) + 1
            self.processed_keys[idempotency_key] = payload
            
            if drop_ack:
                # Partial failure: API committed, but socket resets before client gets response
                raise ConnectionResetError("SOCKET_RESET_BEFORE_ACK")
            
            return 200, {"status": "SUCCESS", "deduplicated": False, "data": payload}
            
        return 500, {"error": "UNKNOWN_ERROR"}


class SyncRetryService:
    MAX_RETRIES = 3
    BASE_DELAY_MS = 5
    MAX_OUTBOX_SIZE = 20

    def __init__(self, persistence: DiskPersistence, api: MockExternalCloudAPI):
        self.persistence = persistence
        self.api = api
        self.outbox: List[Dict[str, Any]] = []
        self.local_run_history: List[Dict[str, Any]] = []

    @staticmethod
    def generate_idempotency_key(seed: str, timestamp: str, hero_idx: int) -> str:
        raw = f"{seed}:{timestamp}:{hero_idx}".encode("utf-8")
        return hashlib.sha256(raw).hexdigest()[:32]

    def record_run(self, seed: str, floor: int, kills: int, hero_idx: int, timestamp: str) -> Dict[str, Any]:
        key = self.generate_idempotency_key(seed, timestamp, hero_idx)
        record = {
            "idempotency_key": key,
            "seed": seed,
            "floor": floor,
            "kills": kills,
            "hero_idx": hero_idx,
            "timestamp": timestamp,
            "sync_status": "PENDING"
        }
        
        # In-memory and local disk persistence
        persist_res = self.persistence.save_with_status(f"outbox_{key}", record)
        if not persist_res.get("success", False) or persist_res.get("status") != "COMMITTED":
            record["sync_status"] = "PERSISTENCE_FAILED"
            return {"success": False, "error": persist_res.get("error", "PERSISTENCE_ERROR"), "record": record}
        
        # Enforce FIFO bound on Outbox
        self.outbox.append(record)
        if len(self.outbox) > self.MAX_OUTBOX_SIZE:
            self.outbox.pop(0)  # Evict oldest entry
            
        self.local_run_history.append(record)
        return {"success": True, "record": record}

    def sync_run(self, record: Dict[str, Any], network_schedule: List[int], simulate_drop_ack_once: bool = False) -> Dict[str, Any]:
        key = record["idempotency_key"]
        attempts = 0
        schedule_idx = 0
        drop_ack = simulate_drop_ack_once

        while attempts < self.MAX_RETRIES:
            attempts += 1
            status_code = network_schedule[schedule_idx] if schedule_idx < len(network_schedule) else 200
            schedule_idx += 1
            
            # Non-blocking backoff with jitter simulation
            if attempts > 1:
                jitter = random.uniform(0.5, 1.5)
                delay = (self.BASE_DELAY_MS * (2 ** (attempts - 1))) * jitter
                time.sleep(delay / 1000.0)

            try:
                code, resp = self.api.receive_request(key, record, status_code, drop_ack=drop_ack)
                drop_ack = False  # Only drop once if scheduled
            except ConnectionResetError:
                drop_ack = False
                # Transient socket reset, retry
                continue

            if code == 200:
                record["sync_status"] = "COMMITTED"
                self.persistence.save_with_status(f"outbox_{key}", record)
                return {"success": True, "attempts": attempts, "response": resp}
            
            if code in (400, 401, 422):
                record["sync_status"] = "FAILED_FATAL"
                return {"success": False, "attempts": attempts, "error": resp.get("error", "FATAL_CLIENT_ERROR")}

        record["sync_status"] = "PENDING_RETRY"
        return {"success": False, "attempts": attempts, "error": "RETRY_EXHAUSTED"}
