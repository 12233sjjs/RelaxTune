#!/bin/sh
# Run from any directory on a macOS CI worker with Xcode Command Line Tools.
set -eu
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then
    echo 'macOS Foundation/CoreFoundation/CoreGraphics SDK required; fixture not run' >&2
    exit 1
fi
CC=${CC:-clang}
build=$(mktemp -d "${TMPDIR:-/tmp}/rt-time-capsule.XXXXXX")
trap 'rm -rf "$build"' EXIT HUP INT TERM
# Compile the unmocked production branches too (syntax only; never load DateInfo).
"$CC" -x objective-c -std=c11 -fobjc-arc -fblocks -DOBJC_OLD_DISPATCH_PROTOTYPES=0 -Wall -Wextra -Werror \
    -Itests/stubs/time_capsule -Isrc -fsyntax-only src/TimeCapsuleBattery.x
for opt in 0 2; do
    "$CC" -std=c11 -Wall -Wextra -Werror -O"$opt" -Isrc \
        tests/test_time_capsule_policy.c -lm -o "$build/policy-$opt"
    "$build/policy-$opt"
    "$CC" -std=c11 -fobjc-arc -fblocks -DOBJC_OLD_DISPATCH_PROTOTYPES=0 -Wall -Wextra -Werror -O"$opt" \
        -Itests/stubs/time_capsule -Isrc tests/test_time_capsule.m \
        -framework Foundation -framework CoreFoundation -framework CoreGraphics \
        -o "$build/companion-$opt"
    "$build/companion-$opt"
done
