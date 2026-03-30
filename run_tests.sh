#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  EndoSync — one-command test runner
#  Run this from the project root:  ./run_tests.sh
#  No device, no BLE hardware, no simulator required.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║     EndoSync Automated Test Suite    ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Pre-flight: verify Flutter is on PATH ────────────────────
if ! command -v flutter &>/dev/null; then
  echo -e "${RED}✗  Flutter not found.${RESET}"
  echo "   Install Flutter from https://flutter.dev/docs/get-started/install"
  echo "   then reopen this terminal and try again."
  exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>&1 | head -1)
echo -e "   Flutter  : ${FLUTTER_VERSION}"
echo -e "   Test file: test/timing_test.dart"
echo ""

# ── Run the tests ─────────────────────────────────────────────
echo -e "${BOLD}Running tests...${RESET}"
echo "────────────────────────────────────────"
echo ""

# Capture output; also stream it live
TMPFILE=$(mktemp)
if flutter test test/timing_test.dart --reporter expanded 2>&1 | tee "$TMPFILE"; then
  EXIT_CODE=0
else
  EXIT_CODE=1
fi

echo ""
echo "────────────────────────────────────────"

# ── Pretty summary ────────────────────────────────────────────
PASS_COUNT=$(grep -c "✓\|[+] [0-9]" "$TMPFILE" 2>/dev/null || true)
FAIL_COUNT=$(grep -c "✗\|FAILED\|[-] [0-9]" "$TMPFILE" 2>/dev/null || true)

if [ "$EXIT_CODE" -eq 0 ]; then
  echo ""
  echo -e "${GREEN}${BOLD}  ✅  ALL TESTS PASSED${RESET}"
  echo ""
  echo -e "   No hardware needed. No BLE required."
  echo -e "   These tests verify:"
  echo -e "     • Session timer counts down and ends the session"
  echo -e "     • 'End Session Early' button works immediately"
  echo -e "     • Short sessions (< 5 s) don't count toward the session limit"
  echo -e "     • Two full sessions trigger the cooldown"
  echo -e "     • Cooldown expires and the app returns to the scanner"
else
  echo ""
  echo -e "${RED}${BOLD}  ❌  SOME TESTS FAILED${RESET}"
  echo ""
  echo -e "${YELLOW}Troubleshooting checklist:${RESET}"
  echo -e "  1. Open  lib/bluetooth/ble_constants.dart"
  echo -e "     Make sure these two lines read exactly:${RESET}"
  echo -e "       ${CYAN}static const bool kDebugShortTimers = true;${RESET}"
  echo -e "       ${CYAN}const bool kDebugSkipBle = true;${RESET}"
  echo -e ""
  echo -e "  2. Run  ${CYAN}flutter pub get${RESET}  and then try again."
  echo -e ""
  echo -e "  3. Look at the FAILED test name above and check the"
  echo -e "     matching section in  docs/bug_fix_strategy.md"
  echo -e "     for a ready-made fix prompt."
fi

rm -f "$TMPFILE"
echo ""
exit $EXIT_CODE
