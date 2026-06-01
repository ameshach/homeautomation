#!/usr/bin/env bash
# Relaunch loop for unattended building across usage windows.
# Usage: ./run-claude.sh        (resumes from PROGRESS.md each time)
# Run inside the repo. First ever run: it will start fresh; later runs continue.
set -uo pipefail

DRIVER='Read CLAUDE.md and PROGRESS.md. Continue from the first unchecked step,
run its test gate, record PASS/FAIL in PROGRESS.md, commit a checkpoint, then stop.'

FLAG=""   # becomes --continue after the first launch
SLEEP_SECONDS="${SLEEP_SECONDS:-1800}"   # 30 min; tune to your reset

while true; do
  echo "=== launching claude (sonnet) $(date) ==="
  claude --model sonnet $FLAG -p "$DRIVER"
  code=$?
  FLAG="--continue"

  if [ $code -eq 0 ]; then
    # Stop when every box is checked.
    if ! grep -q '^- \[ \]' PROGRESS.md; then
      echo "All steps complete. Done."
      break
    fi
    echo "Step finished; immediately continuing to next."
    continue
  fi

  # Non-zero usually means a usage-limit stop (exit codes aren't fully documented,
  # so tune this). Wait past the reset, then resume.
  echo "Stopped (exit $code) — likely usage limit. Sleeping ${SLEEP_SECONDS}s, then resuming."
  echo "Tip: run 'claude' and '/usage' to see the exact reset time."
  sleep "$SLEEP_SECONDS"
done
