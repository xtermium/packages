#!/bin/bash
# Sets each PKGBUILD to the latest release / nightly build and rewrites its .SRCINFO. Changes
# nothing while GitHub has not finished publishing (no .deb yet, or no digest for it). Run as a
# user other than root (makepkg refuses root); GH_TOKEN is optional (raises the API rate limit).
set -euo pipefail
cd "$(dirname "$0")"
api() { curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} "https://api.github.com/repos/xtermium/xtermium/releases/$1"; }
# digest <release json> <asset name>: the asset's sha256 as GitHub computed it on upload.
digest() { jq -r --arg n "$2" '.assets[] | select(.name == $n) | .digest // empty' <<<"$1" | sed -n 's/^sha256://p'; }

set_pkg() { # <dir> <pkgver> <sha256>
  [ -n "$3" ] || { echo "$1: $2 has no .deb digest yet, later"; return; }
  grep -qx "pkgver=$2" "$1/PKGBUILD" && return
  sed -i -e "s/^pkgver=.*/pkgver=$2/" -e 's/^pkgrel=.*/pkgrel=1/' -e "s/^sha256sums=.*/sha256sums=('$3')/" "$1/PKGBUILD"
  (cd "$1" && makepkg --printsrcinfo > .SRCINFO)
  echo "$1: $2"
}

rel=$(api latest)
v=$(jq -r .tag_name <<<"$rel"); v=${v#v}
set_pkg xtermium-bin "$v" "$(digest "$rel" "xtermium_${v}_amd64.deb")"

# The nightly's name takes its build time last, once its files are uploaded (nightly.yml).
rel=$(api tags/nightly)
v=$(jq -r .name <<<"$rel" | sed -n 's/.*\([0-9]\{4\}\)-\([0-9][0-9]\)-\([0-9][0-9]\) \([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\).*/\1\2\3.\4\5\6/p')
[ -n "$v" ] && set_pkg xtermium-nightly-bin "$v" "$(digest "$rel" xtermium_nightly_amd64.deb)"
