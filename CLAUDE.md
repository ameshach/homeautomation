# CLAUDE.md — Home Automation Delivery Pipeline (MVP)

You are the build agent for this project. Run on **Sonnet** to conserve Opus quota.

## Mission
Build a safe pipeline so a family WhatsApp group can switch devices on/off via
Hermes Agent + Home Assistant, while all *code/config changes* flow through GitHub
and a utility "deployer" container — without giving you (the agent) admin access
to the Synology NAS and without installing git on the NAS host.

## Hard constraints (never violate)
1. **No admin on the NAS.** You produce files (compose, config, scripts) in THIS repo.
   The human applies them once via Synology Container Manager. After bootstrap, every
   change ships via GitHub → deployer. Do not SSH as admin or run privileged host commands.
2. **git lives only inside the `deployer` container.** Never add git to the NAS host.
3. **No raw Docker socket** in any container. Deploy via shared volume + Home Assistant
   reload API (scoped token). If a container restart is unavoidable, use
   `tecnativa/docker-socket-proxy` limited to restart only.
4. **No LLM-generated code runs against the home in the live path.** WhatsApp → Hermes
   maps natural language to a FIXED allowlist of HA intents (turn_on/turn_off on specific
   entity_ids) for allowlisted senders only. New behaviors become *proposals* in the repo
   for human review (Phase 5) — never auto-executed.

## Two planes (keep separate)
- **Control plane (live):** WhatsApp group → Hermes (Whisper STT + DeepSeek) → allowlisted HA REST intents.
- **Delivery plane (build):** You → GitHub → `deployer` container → target reload. Human-reviewed.

## Resume protocol (IMPORTANT — read on every start)
Claude Code runs on a rolling ~5h window + weekly cap, with no native auto-resume.
So:
1. On start, READ `PROGRESS.md`. Find the FIRST unchecked `[ ]` step.
2. Do only that step. Then RUN its test gate and record PASS/FAIL in PROGRESS.md.
3. Commit a checkpoint: `git add -A && git commit -m "phaseN: <step> (test: PASS)"`.
4. Only then move to the next step. Never skip a test gate.
5. If you are stopped by a usage limit, do nothing special — the next launch reads
   PROGRESS.md and continues. The wrapper `run-claude.sh` relaunches automatically.

## Target topology (NAS containers, via Container Manager)
- `homeassistant` (existing) — exposes REST API.
- `hermes` (existing) — WhatsApp + HA adapters, DeepSeek, Whisper.
- `deployer` (you build) — git + poll loop; pulls this repo, syncs config to a shared
  volume, triggers reload via scoped HA token. No docker socket.
- `target` — Phase 1: dummy nginx serving repo `VERSION`. Phase 2+: Home Assistant config.

## Reference: deployer compose (Phase 1, dummy target) — refine as needed
```yaml
services:
  deployer:
    image: alpine/git:latest
    container_name: deployer
    restart: unless-stopped
    environment:
      REPO_URL: "https://github.com/ameshach/homeautomation.git"
      POLL_SECONDS: "30"
    volumes:
      - shared-config:/out
    entrypoint: ["/bin/sh","-c"]
    command:
      - |
        cd /tmp && git clone "$REPO_URL" repo || (cd repo && git pull)
        while true; do
          cd /tmp/repo && git pull --ff-only
          cp -r deploy/* /out/ 2>/dev/null || true
          sleep "$POLL_SECONDS"
        done
  target:
    image: nginx:alpine
    container_name: target
    restart: unless-stopped
    volumes:
      - shared-config:/usr/share/nginx/html:ro
    ports: ["8088:80"]
volumes:
  shared-config:
```

## Reference: Phase 2 reload (no socket)
Deployer, after `cp` into the shared HA config volume, calls:
```
curl -s -X POST "$HA_URL/api/services/homeassistant/reload_core_config" \
  -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json"
```
Use a dedicated HA user's long-lived token. Note HA tokens are not finely scoped;
mitigate by network-isolating the deployer and limiting what entities exist.

## Caveats to surface to the human (do not silently ignore)
- WhatsApp unofficial gateway = ban risk → use a DEDICATED number, not personal.
- Sender allowlist + intent allowlist are the security boundary — test the refusal paths.
- Confirm the exact DeepSeek model id from Hermes's provider list before relying on a name.
