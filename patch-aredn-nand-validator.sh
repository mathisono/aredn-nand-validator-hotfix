#!/bin/sh
# One-time running-firmware fix for AREDN #2993 / merged PR #2979.
# Run as root on the node. Does NOT flash, reboot, or bypass image checks.
set -eu
fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail "Run as root on the AREDN node."
board=$(cat /tmp/sysinfo/board_name) || fail "Cannot identify node."
case "$board" in
    mikrotik,routerboard-912uag-5hpnd|mikrotik,routerboard-911g-5hpnd|mikrotik,routerboard-911g-5hpnd-qrt) ;;
    *) fail "Unsupported board: $board (nothing changed)." ;;
esac
file=/lib/upgrade/platform.sh
[ -f "$file" ] && [ ! -L "$file" ] || fail "Expected a regular $file."
hash() { sha256sum "$1" | awk '{print $1}'; }
before=$(hash "$file")
fixed=023897131f603e6c062c29ff902bc1ee21b3874f534f54efb558c8c0797860cc
case "$before" in
    "$fixed") echo "Already fixed; retry the normal AREDN web UI upgrade."; exit 0 ;;
    2e89020c0d3c6b715b7e801a02571d0c17e279362f9f480d9820debbc57e1724|96ede1f3e0778bcd7d898660739360cec52a68ae342b725f0e8b683fe9197315) ;;
    *) fail "Unrecognized platform.sh ($before); nothing changed. Needs review." ;;
esac

temp=$(mktemp "${file}.hotfix.XXXXXX")
trap 'rm -f "$temp"' EXIT
trap 'exit 1' HUP INT TERM
cp -p "$file" "$temp"
awk '
    /^platform_check_image\(\) \{$/ { inside=1 }
    inside && /^\}$/ { inside=0 }
    inside && /mikrotik,routerboard-912uag-5hpnd/ { next }
    { print }
    inside && /mikrotik,routerboard-911g-5hpacd/ {
        print " \tmikrotik,routerboard-911g-5hpnd*|\\"
    }
    inside && /mikrotik,routerboard-912uag-2hpnd/ {
        print " \tmikrotik,routerboard-912uag-5hpnd|\\"
    }
' "$file" > "$temp"
/bin/sh -n "$temp"
[ "$(hash "$temp")" = "$fixed" ] || fail "Candidate differs from verified fixed script."
[ "$(hash "$file")" = "$before" ] || fail "Original changed during patch."
backup=$(mktemp -d /root/aredn-validator-backup.XXXXXX)
cp -p "$file" "$backup/platform.sh"
[ "$(hash "$backup/platform.sh")" = "$before" ] || fail "Backup verification failed."
mv "$temp" "$file"
if [ "$(hash "$file")" != "$fixed" ]; then
    cp -p "$backup/platform.sh" "$file"
    fail "Installed checksum mismatch; restored backup: $backup/platform.sh"
fi
echo "Patched NAND validation for $board. Backup: $backup/platform.sh"
echo "No reboot needed. Retry the normal AREDN web UI firmware upgrade."
echo "To undo BEFORE upgrading: cp -p '$backup/platform.sh' '$file'"
