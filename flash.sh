#!/usr/bin/env bash
set -euo pipefail

# Flash a built nice!nano ZMK firmware.
#
# Usage:
#   ./flash.sh <dongle|dongle-log|left|right|reset> [timeout_seconds]
#
# Double-tap the nice!nano reset button while this waits; the NICENANO USB
# drive will appear and the firmware will be copied to it.
#
# Environment overrides:
#   ZMK_WORKSPACE  west workspace dir  (default: ~/Projects/zmk-workspace)

WORKSPACE="${ZMK_WORKSPACE:-${HOME}/Projects/zmk-workspace}"

case "${1:-}" in
  dongle|dongle-log|left|right|reset) TARGET="$1" ;;
  *) echo "usage: $0 <dongle|dongle-log|left|right|reset> [timeout_seconds]"; exit 1 ;;
esac

UF2="${WORKSPACE}/build/${TARGET}/zephyr/zmk.uf2"
[ -f "${UF2}" ] || { echo "Missing firmware: ${UF2}"; exit 1; }

find_mount() {
  local m
  m="$(lsblk -rno LABEL,MOUNTPOINT | awk '$1=="NICENANO" && $2!="" {print $2; exit}')"
  if [ -z "${m}" ]; then
    for c in "/run/media/${USER}/NICENANO" "/media/${USER}/NICENANO"; do
      [ -d "${c}" ] && { echo "${c}"; return; }
    done
  fi
  echo "${m}"
}

TIMEOUT="${2:-180}"
echo "Waiting up to ${TIMEOUT}s for the NICENANO bootloader drive (double-tap reset)..."
for _ in $(seq 1 "${TIMEOUT}"); do
  MOUNT="$(find_mount)"
  if [ -n "${MOUNT}" ]; then
    echo "Copying ${TARGET} firmware to ${MOUNT}..."
    cp "${UF2}" "${MOUNT}/${TARGET}.uf2"
    sync
    echo "Flashed ${TARGET}. The board will reboot automatically."
    exit 0
  fi
  sleep 1
done

echo "Timed out waiting for the NICENANO bootloader drive."
exit 1
