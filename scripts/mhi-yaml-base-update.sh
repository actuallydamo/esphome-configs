#!/usr/bin/env bash
# shellcheck disable=SC2016

# Simple script to fetch releases MHI-AC-Ctrl-ESPHome
# Combines the full and energy YAML example files
# Customises the merged file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"
TEMP_DIR="$(mktemp -d)"
BASE_AC="$CONFIG_DIR/base.ac.yaml"
FETCH_FULL="$TEMP_DIR/full.yaml"
FETCH_ENERGY="$TEMP_DIR/energy.yaml"
PREVIOUS_FULL="$TEMP_DIR/previous_full.yaml"
PREVIOUS_ENERGY="$TEMP_DIR/previous_energy.yaml"
MHI_VERSION_FILE="$CONFIG_DIR/mhi-version.txt"
MERGED="$TEMP_DIR/merged.yaml"

if ! command -v yq &>/dev/null || ! yq --version 2>&1 | grep -q 'mikefarah/yq'; then
  echo "Go yq is not installed."
  exit 1
fi

if ! command -v difft &>/dev/null; then
  echo "difftastic is not installed."
  exit 1
fi

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

touch "$BASE_AC"

echo "=== Checking latest release on GitHub ==="

tag="$(curl -s https://api.github.com/repos/ginkage/MHI-AC-Ctrl-ESPHome/releases/latest | jq -r '.tag_name')"

if [[ -f "$MHI_VERSION_FILE" ]]; then
  local_version="$(cat "$MHI_VERSION_FILE")"
  if [[ "$local_version" == "$tag" ]]; then
    echo "No new version available. Current version: $local_version"
    exit 0
  fi
  echo "New version available: $tag"
  echo ""
else
  echo "No previous version found, fetching latest: $tag"
  local_version=""
fi

echo "=== Fetching YAML files from GitHub ==="

echo "Fetching full.yaml..."
curl -s "https://raw.githubusercontent.com/ginkage/MHI-AC-Ctrl-ESPHome/$tag/examples/full.yaml" >"$FETCH_FULL"

echo "Fetching simple-energy-measurement.yaml..."
curl -s "https://raw.githubusercontent.com/ginkage/MHI-AC-Ctrl-ESPHome/$tag/examples/simple-energy-measurement.yaml" >"$FETCH_ENERGY"

if [[ -f "$MHI_VERSION_FILE" ]]; then
  echo "Fetching previous tag full.yaml..."
  curl -s "https://raw.githubusercontent.com/ginkage/MHI-AC-Ctrl-ESPHome/$local_version/examples/full.yaml" >"$PREVIOUS_FULL"

  echo "Fetching previous tag simple-energy-measurement.yaml..."
  curl -s "https://raw.githubusercontent.com/ginkage/MHI-AC-Ctrl-ESPHome/$local_version/examples/simple-energy-measurement.yaml" >"$PREVIOUS_ENERGY"

  echo ""
  echo "=== Checking diff between versions ==="
  if ! cmp -s "$PREVIOUS_FULL" "$FETCH_FULL"; then
    difft "$PREVIOUS_FULL" "$FETCH_FULL"
  fi
  if ! cmp -s "$PREVIOUS_ENERGY" "$FETCH_ENERGY"; then
    difft "$PREVIOUS_ENERGY" "$FETCH_ENERGY"
  fi
fi

# Prevent yq stripping out empty lines
sed -e 's/^$/# __NEWLINE__#/' -i "$FETCH_FULL"

echo ""
echo "=== Merging energy example file ==="
# Ideally we could merge everything in one go e.g. '. += load("energy.yaml")'
# yq doesn't have a simple way to merge sequences by key
cp "$FETCH_FULL" "$MERGED"
echo "Merging MHI platform sensors"
yq -i eval-all "(.sensor[] | select(.platform == \"MhiAcCtrl\")) *= (load(\"${FETCH_ENERGY}\").sensor[] | select(.platform == \"MhiAcCtrl\"))" "$MERGED"
echo "Merging other sensors"
yq -i eval-all '.sensor += [load("'"${FETCH_ENERGY}"'").sensor[] | select(.platform != "MhiAcCtrl")]' "$MERGED"
echo "Merging globals"
yq -i eval-all '.globals += load("'"${FETCH_ENERGY}"'").globals' "$MERGED"

echo ""
echo "=== Customising YAML ==="
echo ""
echo "Removing sections defined in base.yaml"
# Ideally we could use yq to strip values that are defined in base.yaml
# I can't find a simple way to do this automatically, so do it manually
# ESPHome will merge the base.yaml values in anyway but I want a minimal ac base file
yq -i 'del(.api)' "$MERGED"
yq -i 'del(.button[] | select(.name == "Restart"))' "$MERGED"
yq -i 'del(.captive_portal)' "$MERGED"
yq -i 'del(.esphome.friendly_name)' "$MERGED"
yq -i 'del(.esphome.name)' "$MERGED"
yq -i 'del(.ota)' "$MERGED"
yq -i 'del(.sensor[] | select(.name == "Uptime"))' "$MERGED"
yq -i 'del(.wifi)' "$MERGED"

echo ""
echo "Locking git repo to same version as YAML: $tag"
yq -i ".external_components[].source= \"github://ginkage/MHI-AC-Ctrl-ESPHome@$tag\"" "$MERGED"

echo ""
echo "Disabling warnings for components"
# https://github.com/ginkage/MHI-AC-Ctrl-ESPHome#i-am-getting-the-following-logline-in-the-console-of-my-device
yq -i '.logger.logs.component = "ERROR"' "$MERGED"

echo ""
echo "Setting local voltage"
yq -i '(.globals[] | select(.id == "grid_voltage")).initial_value = "247"' "$MERGED"

echo ""
echo "Setting name to use substitution"
yq -i '(.climate[] | select(.platform == "MhiAcCtrl")) |= .name = "$friendly_name"' "$MERGED"

echo ""
echo "=== Sorting file ==="
echo "Deep sort mappings by key"
yq -i 'sort_keys(..)' "$MERGED"
echo "Sorting sequences by platform"
yq -i '.[] |= sort_by(.platform)' "$MERGED"
echo "Prepending platform key to mapping"
yq -i '(.[][] | select(. | has("platform"))) |= (.platform as $platform | del(.platform) | {"platform": $platform} + .)' "$MERGED"

echo ""
echo "=== Styling file ==="
yq -i -P "$MERGED"
# Add back empty lines
sed -e 's/.*# __NEWLINE__#.*//' -i "$MERGED"

echo ""
echo "=== Validating config ==="
mkdir -p "$TEMP_DIR/configs"
cp "$MERGED" "$TEMP_DIR/configs/base.ac.yaml"
cp "$CONFIG_DIR/base.yaml" "$TEMP_DIR/configs/"
cp {secrets.yaml,office-ac.yaml} "$TEMP_DIR"
docker pull ghcr.io/esphome/esphome
docker run --rm --user "$(id -u):$(id -g)" -v "$TEMP_DIR":/config -v "/dev/shm/cache:/cache" -it ghcr.io/esphome/esphome config "office-ac.yaml"

echo ""
echo "=== Updating base.ac.yaml ==="
difft "$BASE_AC" "$MERGED"
cp "$MERGED" "$BASE_AC"

echo ""
echo "=== Updating version file ==="
echo "$tag" >"$MHI_VERSION_FILE"
echo "Updated version to: $tag"

echo ""
echo "=== Done! ==="
