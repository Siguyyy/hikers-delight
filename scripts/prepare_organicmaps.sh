#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checkout="${RUNNER_TEMP}/organicmaps"
commit="$(tr -d '[:space:]' < "${repo_root}/ORGANIC_MAPS_COMMIT")"

rm -rf "${checkout}"
git clone --depth 1 --branch master --recurse-submodules --shallow-submodules \
  https://github.com/organicmaps/organicmaps.git "${checkout}"
git -C "${checkout}" fetch --depth 1 origin "${commit}"
git -C "${checkout}" checkout --detach "${commit}"
git -C "${checkout}" submodule update --init --recursive --depth 1

python3 "${repo_root}/scripts/customize_organicmaps.py" "${checkout}"
printf '%s\n' "${checkout}"

