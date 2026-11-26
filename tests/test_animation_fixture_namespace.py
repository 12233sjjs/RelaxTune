#!/usr/bin/env python3
"""Linux/macOS static checks; preprocessing is NOT an Objective-C runtime test.

Optionally pass the Logos-generated .m file to check its lookup/selector tokens.
Empty SDK headers are used only for preprocessing, never for compiling/running.
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HEADER = ROOT / "tests/animation_fixture_namespace.h"
FIXTURE = ROOT / "tests/test_animation_hooks.m"
PREFIX = "RTAnimationFixture_"
header = HEADER.read_text()
fixture = FIXTURE.read_text()
classes = set(re.findall(r"^    X\((\w+)\)", header, re.M))
assert classes and len(classes) == 18
implemented = set(re.findall(r"@implementation\s+(\w+)", fixture))
platform = {name.removeprefix(PREFIX) for name in implemented if name != "RTTestAnimationSettings"}
assert platform == classes, (platform - classes, classes - platform)
aliases = dict(re.findall(r"^#define (\w+) (RTAnimationFixture_\w+)$", header, re.M))
expected = {name: PREFIX + name for name in classes if name != "BSAnimationSettings"}
expected["UITimingCurveProvider"] = PREFIX + "UITimingCurveProvider"
assert aliases == expected
assert "#define BSAnimationSettings " not in header  # also a selector, NOT a type alias
assert '#error "Force-include tests/animation_fixture_namespace.h' in fixture
assert fixture.index("testFixtureClasses();") < fixture.index("RTInstallAnimationHooks(YES);")

compiler = shutil.which("clang") or shutil.which("cc")
assert compiler, "A C preprocessor (clang or cc) is required"
with tempfile.TemporaryDirectory(prefix="rt-animation-namespace-") as directory:
    sdk = Path(directory)
    for name in ("Foundation/Foundation.h", "QuartzCore/QuartzCore.h", "CoreGraphics/CoreGraphics.h",
                 "objc/runtime.h", "objc/message.h"):
        path = sdk / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("")

    def preprocess(path):
        return subprocess.run([
            compiler, "-E", "-P", "-x", "c", "-Wno-deprecated", "-I" + str(sdk),
            "-I" + str(ROOT / "tests/stubs"), "-I" + str(ROOT / "src"),
            "-include", str(HEADER), str(path),
        ], check=True, capture_output=True, text=True).stdout

    expanded = preprocess(FIXTURE)
    actual = set(re.findall(r"@implementation\s+(\w+)", expanded))
    assert actual == {PREFIX + name for name in classes} | {"RTTestAnimationSettings"}
    assert re.search(r"-\s*\(id\)\s*BSAnimationSettings\s*\{", expanded)
    assert not re.search(r"-\s*\(id\)\s*RTAnimationFixture_BSAnimationSettings\s*\{", expanded)
    for name in classes:
        # All 18 identity checks survive preprocessing with literal, raw prefixed names.
        assert re.search(r'@"RTAnimationFixture_"\s*@"' + name + r'"', expanded), name
        assert PREFIX + name + ".class" in expanded
    assert re.search(r"return NSClassFromString\(", expanded)  # wrapper is not recursive
    assert re.search(r"return objc_getClass\(RTAnimationFixtureClassName", expanded)
    assert 'RTAnimationFixtureNSClassFromString(@"BSAnimationSettings")' in expanded

    for argument in sys.argv[1:]:
        path = Path(argument)
        raw = path.read_text()
        expanded = preprocess(path)
        for api in ("NSClassFromString", "objc_getClass"):
            names = set(re.findall(r"\b" + api + r'\(\s*@?"(\w+)"\s*\)', raw))
            assert names and names <= classes, (api, names - classes)
            wrapper = ("RTAnimationFixtureNSClassFromString" if api == "NSClassFromString"
                       else "RTAnimationFixtureObjCGetClass")
            for name in names:
                assert re.search(wrapper + r'\(\s*@?"' + name + r'"\s*\)', expanded)
        selectors = lambda text: re.findall(r"@selector\(([^)]+)\)", text)
        assert selectors(raw) == selectors(expanded), "Logos hook selectors changed"
        method_names = lambda text: re.findall(r'NSSelectorFromString\(\s*@"([^"]+)"', text)
        assert method_names(raw) == method_names(expanded), "Runtime selectors changed"
        assert '@selector(BSAnimationSettings)' in expanded
        assert '[RTAnimationFixture_UIView ' in expanded
        assert '[CASpringAnimation ' in expanded  # real QuartzCore, not a fake
        print("PASS: Logos class lookups isolated; selectors and QuartzCore unchanged:", path)
print("PASS: all 18 fake platform classes isolated; factory selector and identity checks preserved")
