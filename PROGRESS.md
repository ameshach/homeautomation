# PROGRESS.md — single source of truth

> Agent: continue from the FIRST unchecked box. Run the test, record result, commit, then proceed.
> Format: `[ ]` todo, `[x]` done. Put `(test: PASS|FAIL — note)` after each completed step.

## Phase 0 — Bootstrap + resume harness
- [x] Create private GitHub repo and push CLAUDE.md, PROGRESS.md, run-claude.sh
      (test: PASS — https://github.com/ameshach/homeautomation; all 3 files verified via GitHub API)
- [x] Confirm `claude --continue` reads this file and reports the next step
      (test: PASS — agent reads PROGRESS.md on start and identifies next unchecked step)

## Phase 1 — Deployer + dummy target
- [ ] Write `compose/phase1.yml` (deployer + nginx target, shared volume, no socket)
- [ ] Add `deploy/VERSION` with value `v1`
- [ ] Human applies compose in Container Manager (record done here)
      Test gate: `curl http://<nas>:8088/VERSION` returns `v1`
- [ ] Bump `deploy/VERSION` to `v2`, commit, push
      Test gate: within POLL_SECONDS, curl returns `v2`  ← proves Git→deploy loop

## Phase 2 — Home Assistant as target
- [ ] Create dedicated HA user + long-lived token; store as deployer env (not in repo)
- [ ] Add `ha_config/packages/mvp.yaml` with a script that fires persistent_notification
- [ ] Update deployer to sync ha_config into HA volume + call reload API
      Test gate: push → notification script appears in HA → calling it shows the notice

## Phase 3 — Hermes → HA control (text, allowlisted)
- [ ] Configure Hermes HA adapter + DeepSeek model
- [ ] Define sender allowlist + intent allowlist (turn_on/turn_off, specific entity_ids)
      Test gate (1:1 DM): "turn on living room light" works
      Test gate: "delete all automations" is refused
      Test gate: message from non-allowlisted number is ignored

## Phase 4 — Family group + voice
- [ ] Provision DEDICATED WhatsApp number; add Hermes to the family group
- [ ] Scope Hermes to that group + allowlisted members; enable Whisper STT
      Test gate: group TEXT "switch off the fan" → off
      Test gate: group VOICE NOTE saying the same → transcribed → off
      Test gate: off-list request → asks to clarify, takes no action

## Phase 5 — "Create a script" loop (reviewed)
- [ ] Configure Hermes: unknown intent → write candidate script to `proposals/` branch, do NOT execute
- [ ] Review path: agent/human reviews proposal, merges to main, deployer ships
      Test gate: ask for non-existent "movie mode" → proposal file appears →
      after merge + deploy → "movie mode" works; before merge it does nothing
