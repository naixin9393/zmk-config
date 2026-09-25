#!/usr/bin/env bash
set -euo pipefail

# Local ZMK build for the Dactyl Manuform 5x6 dongle setup.
#
# Usage:
#   ./build.sh <dongle|dongle-log|left|right|reset|all>
#
#   dongle-log  builds the dongle with the zmk-usb-logging snippet (serial logs
#               over USB; enables peripheral battery reporting over the log).
#
# Environment overrides:
#   ZMK_WORKSPACE  west workspace dir   (default: ~/Projects/zmk-workspace)
#   ZMK_IMAGE      docker image         (default: zmkfirmware/zmk-build-arm:4.1-branch)
#   ZMK_REF        ZMK git ref to clone (default: main)
#   ZMK_BOARD      board target         (default: nice_nano//zmk)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${ZMK_WORKSPACE:-${HOME}/Projects/zmk-workspace}"
IMAGE="${ZMK_IMAGE:-zmkfirmware/zmk-build-arm:4.1-branch}"
ZMK_REF="${ZMK_REF:-main}"
BOARD="${ZMK_BOARD:-nice_nano//zmk}"
PERI_ARGS="-DCONFIG_ZMK_SPLIT=y -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n"

usage() {
  echo "usage: $0 <dongle|dongle-log|left|right|reset|all>"
  exit 1
}

[ $# -ge 1 ] || usage

targets=()
for arg in "$@"; do
  case "$arg" in
    all) targets+=(dongle left right reset) ;;
    dongle|dongle-log|left|right|reset) targets+=("$arg") ;;
    *) echo "unknown target: $arg"; usage ;;
  esac
done

# The ZMK repo must be checked out at the workspace root so that
# app/CMakeLists.txt's `find_package(Zephyr HINTS ../zephyr)` resolves.
if [ ! -d "${WORKSPACE}/.git" ]; then
  echo ">> cloning ZMK (${ZMK_REF}) into ${WORKSPACE}"
  rm -rf "${WORKSPACE}"
  mkdir -p "${WORKSPACE}"
  git clone --depth 1 --branch "${ZMK_REF}" \
    https://github.com/zmkfirmware/zmk "${WORKSPACE}"
fi

script=""
for t in "${targets[@]}"; do
  snippet=""
  case "$t" in
    dongle)     shield="dac_man_5x6_dongle"; extra="" ;;
    dongle-log) shield="dac_man_5x6_dongle"; extra=""; snippet="zmk-usb-logging" ;;
    left)       shield="dac_man_5x6_left";   extra="${PERI_ARGS}" ;;
    right)      shield="dac_man_5x6_right";  extra="${PERI_ARGS}" ;;
    reset)      shield="settings_reset";     extra="" ;;
  esac
  snippet_arg=""
  [ -n "${snippet}" ] && snippet_arg="-S ${snippet}"
  script+="echo '>> build ${t} (${shield})'
"
  script+="west build -p -d /workspace/build/${t} -b '${BOARD}' ${snippet_arg} -- -DSHIELD=${shield} -DZMK_CONFIG=/myconfig/config -DZMK_EXTRA_MODULES=/myconfig ${extra}
"
done

echo ">> image:     ${IMAGE}"
echo ">> workspace: ${WORKSPACE}"
echo ">> config:    ${REPO_ROOT}"
echo ">> targets:   ${targets[*]}"

docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/workspace \
  -v "${WORKSPACE}:/workspace" -v "${REPO_ROOT}:/myconfig:ro" \
  -w /workspace/app "${IMAGE}" \
  bash -c "
set -euo pipefail
if [ ! -d /workspace/.west ]; then
  echo '>> west init -l /workspace/app'
  west init -l /workspace/app
fi
echo '>> west update'
west update
${script}
"

echo
for t in "${targets[@]}"; do
  echo "Firmware: ${WORKSPACE}/build/${t}/zephyr/zmk.uf2"
done
