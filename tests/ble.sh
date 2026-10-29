#!/usr/bin/env bash
# Invoked by tests/sup.sh under an interactive PTY with an isolated HOME.
set -o emacs
source "$SKILLMOD_TEST_BLE_PATH" --attach=attach
source "$SKILLMOD_TEST_MODULE"

# Model command execution in ble.sh's user space, with visible terminal FDs.
_ble_edit_exec_inside_userspace=1
exec 1>/dev/tty 2>/dev/tty

# Deliberately do not put sup in an if/||: that masks errexit/EOF interactions.
sup
skillmod_test_status=$?
builtin printf '\nBLE_SUP_STATUS=%s\n' "$skillmod_test_status"
builtin exit "$skillmod_test_status"
