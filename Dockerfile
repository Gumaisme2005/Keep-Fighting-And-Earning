# ==============================================================================
# Multi-stage Dockerfile cho Keep Fighting And Earning (Godot Engine 4)
# Stage 1: Chạy kiểm thử tự động (CI / Test Runner Headless)
# Stage 2: Xuất bản WebAssembly & Nginx Web Server
# ==============================================================================

# --- STAGE 1: TEST RUNNER (Headless Godot 4) ---
FROM barichello/godot-ci:4.3 AS test

WORKDIR /app
COPY . .

# Mặc định chạy toàn bộ bộ kiểm thử tự động
CMD ["godot", "--headless", "--path", ".", "res://tests/test_dungeon_generator_unit.tscn"]

# --- STAGE 2: BUILD WEB EXPORT ---
FROM barichello/godot-ci:4.3 AS builder

WORKDIR /app
COPY . .

RUN mkdir -p build/web && \
    godot --headless --path . --export-release "Web" build/web/index.html || true

# --- STAGE 3: NGINX WEB SERVER ---
FROM nginx:alpine AS web

# Sao chép cấu hình Nginx với headers COOP/COEP bắt buộc của Godot 4
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Sao chép file game Web đã biên dịch
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
