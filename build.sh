#!/bin/sh
# Build an APK with the same apk-tools mkpkg format used by AREDN/OpenWrt.
set -eu
umask 022

src=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
apk_tool=${APK_TOOL:-apk}
out=${OUTPUT_DIR:-"$src/dist"}
name=aredn-nand-validator-hotfix
version=1.0.0-r0
build_epoch=${SOURCE_DATE_EPOCH:-1793923200}

case "$build_epoch" in
    ''|*[!0-9]*) echo 'SOURCE_DATE_EPOCH must be a nonnegative integer.' >&2; exit 1 ;;
esac

command -v "$apk_tool" >/dev/null 2>&1 || {
    echo 'apk-tools 3.x with mkpkg is required (set APK_TOOL to its path).' >&2
    exit 1
}
command -v fakeroot >/dev/null 2>&1 || {
    echo 'fakeroot is required so the package records root ownership.' >&2
    exit 1
}
case "$("$apk_tool" --version)" in
    'apk-tools 3.'*) ;;
    *) echo 'apk-tools 3.x is required.' >&2; exit 1 ;;
esac

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
trap 'exit 1' HUP INT TERM
chmod 755 "$stage"
mkdir -p "$stage/usr/libexec/$name" "$stage/lib/apk/packages" "$out"
cp "$src/patch-aredn-nand-validator.sh" "$stage/usr/libexec/$name/patch-aredn-nand-validator.sh"
chmod 755 "$stage/usr/libexec/$name/patch-aredn-nand-validator.sh"
printf '/usr/libexec/%s/patch-aredn-nand-validator.sh\n' "$name" > "$stage/lib/apk/packages/$name.list"
find "$stage" -exec touch -d "@$build_epoch" {} +

fakeroot "$apk_tool" mkpkg \
    --info "name:$name" \
    --info "version:$version" \
    --info 'description:One-time guarded AREDN MikroTik NAND validator fix' \
    --info 'arch:noarch' \
    --info 'license:GPL-3.0-or-later' \
    --info "origin:https://github.com/mathisono/$name" \
    --info "url:https://github.com/mathisono/$name" \
    --info 'maintainer:Mathison (KJ6DZB)' \
    --script "post-install:$src/post-install" \
    --files "$stage" \
    --output "$out/$name-$version.apk"

sha256sum "$out/$name-$version.apk"
