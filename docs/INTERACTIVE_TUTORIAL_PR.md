# Suggested title

feat(tutorial): add interactive gameplay tutorial for Guild Hall

# Prepared PR description

## Behavior

New players can accept optional Adventurer Training after selecting a hero in Guild Hall. A private copy of the selected hero teaches movement, basic attack, a representative skill, pickup, equipment, armor/HP recovery and potion use. The final lesson returns the player's original hero to the hall and directs them to Rune Portal. Completion is saved only after the original hero reaches an initialized, playable floor 1.

Not Now and Skip preserve normal play. Restart creates a fresh practice generation. Returning players can replay training manually. Practice grants no production items, rewards, progression, Wallet changes, replay frames or perk/RNG changes.

## Implementation and safety

- Keep the existing heroes, inventory transactions and collision/damage behavior; use an isolated world, session-owned event sources, action facts and guarded input routing.
- Suspend the original hall/hero, restore their processing/visibility/input ownership, and retain a release guard while controls remain held. Defer acquisition while external timed effects still exist.
- Stage the real dungeon while retaining the hall. Commit floor/seed/recording changes only after entity initialization; bound pending requests, reject stale callbacks and recover portal control after failure.
- Preserve valid item ownership after a wrong-order pickup and allow real survival damage again after full healing.
- Add a persistent final-entry hint and gold Rune Portal marker, event-driven practice inventory refresh, and step-driven static arena redraw.
- Keep completion in a separate versioned save with atomic replacement and memory fallback on I/O failure.

## Verification

The final-source evidence inventory, assertion counts, 30/144 FPS comparisons, source fingerprint, cold-process PIDs and GUI capture paths are recorded in [the design report](INTERACTIVE_TUTORIAL_DESIGN.md). Coverage retains all 14 previous Tutorial suites, all 43 existing suites at 144 FPS, the 14 existing CI groups at 30 FPS and their 12 required trace pairs. New coverage includes five rounds of transition faults/retry, 20 lifecycle rounds across eight heroes, wrong-order/healing recovery, a real 31-second soak, historical/current Pyrois measurements and two independent cold application processes.

All local gates passed with zero runtime/script errors: 15 required Tutorial trace pairs and 12 existing pairs MATCH; transition safety has 290 assertions per rate, lifecycle regression 399 per rate, and Pyrois measurement 60 per rate. The GUI has 129 UI assertions and 354 eight-hero full-flow assertions. Cold GUI processes pass 32/13 assertions with independent PIDs 11976/20344; cold 30 FPS processes pass 23/11 with PIDs 17612/7696. Python runner contracts pass all 24 checks. Ninety final GUI captures remain in disposable evidence folders.

The final 608-file functional manifest is `8869b5885c3579c49505aed7d0295edf4076c5dbddfd278eb259d23b177a66a8`. Three earlier regression invocations differ only in the unused dungeon-entry test fixture; every executed source/helper and the other 607 entries match final source. The changed fixture was rerun at both rates and in the GUI. The design report records that exception explicitly rather than claiming identical complete manifests. Actual OS Alt-Tab/lost-key-up and per-hero human playtesting remain NOT VERIFIED.

The new CI safety job runs alongside the existing full job; it does not remove or shorten old assertions. Both jobs upload bounded logs/results/source manifests. The previous Task 4 full workflow succeeded at commit `b378175e9d1ed7f0a3c7842008d5a7bcc643215e`: https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/46131900973. The new commit's workflow must be checked independently.

## Review steps

1. Read the transition findings and staging/commit boundary in the design report; inspect failure tests before reviewing successful completion.
2. Review input lease/adapter/release-guard ownership, hero-specific async effects and production isolation.
3. Run the committed runners with Godot 4.7.2, including `--cross-fps` and the separate cold-relaunch runner. Inspect errors, completion markers, hero/round evidence and raw Pyrois metrics.
4. Complete the per-hero [human acceptance checklist](INTERACTIVE_TUTORIAL_ACCEPTANCE.md), particularly Alt-Tab/lost release, charge feel, instruction clarity, tooltip/layout and production combat after completion.
5. Recheck development ancestry and open branch overlaps before merging. Resolve FPS/UI branch conflicts only when that branch is intentionally integrated, preserving both settings behavior and Tutorial input/safety gates.

## Reviewers and readiness

Suggested reviewers: the gameplay/hero owner, a Godot UI/input reviewer, and Bravee9 for the Issue 62 control guidance context. These are suggestions; no review requests have been sent.

- [x] Tasks 1–4 retained as separate ancestor commits.
- [x] Optional training and eight-step architecture implemented.
- [x] Targeted safety tests and fail-closed runners prepared.
- [x] Full local regression, required cross-FPS comparisons, GUI and independent cold relaunch gates passed.
- [ ] Verify the new commit's full CI, including both jobs.
- [ ] Complete human acceptance for all eight heroes.
- [ ] Review compatibility conflicts if FPS/UI changes are integrated.

Human acceptance and the new CI result remain explicit merge gates. No PR has been created or merged by this task. No BT3, balance redesign, new hero/enemy, settings system or lore expansion is included.

Refs #62
