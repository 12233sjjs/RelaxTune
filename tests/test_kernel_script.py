import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = {
    "kern.wq_max_threads": 512,
    "kern.maxvnodes": 10000,
    "kern.memorystatus_sysprocs_idle_delay_time": 60,
    "kern.memorystatus_apps_idle_delay_time": 60,
    "kern.memorystatus_kill_on_sustained_pressure_delay_ms": 500,
    "kern.vm_max_delayed_work_limit": 32,
}
DESIRED = dict(zip(ORIGINAL, [2048, 20000, 1, 1, 86400000, 64]))
MOCK = r'''
import json, os, pathlib, sys
if pathlib.Path(sys.argv[0]).name == "id":
    print(os.environ.get("FAKE_UID", "0"))
    sys.exit(0)
path = pathlib.Path(os.environ["FAKE_SYSCTL_STATE"])
data = json.loads(path.read_text())
args = sys.argv[1:]
data["calls"].append(args)
path.write_text(json.dumps(data))
if len(args) == 2 and args[0] == "-n":
    if args[1] not in data["values"]:
        sys.exit(1)
    print(data["values"][args[1]])
elif len(args) == 1 and "=" in args[0]:
    if args[0] == os.environ.get("FAKE_FAIL_WRITE"):
        sys.exit(1)
    key, value = args[0].split("=", 1)
    data["values"][key] = int(value)
    path.write_text(json.dumps(data))
else:
    sys.exit(1)
'''


class KernelModuleTests(unittest.TestCase):
    def setUp(self):
        (ROOT / "work").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "work")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.state_dir = self.directory / "saved"
        self.backup = self.state_dir / "kernel-state"
        self.fake_state = self.directory / "fake.json"
        self.fake_state.write_text(json.dumps({"values": ORIGINAL, "calls": []}))
        mock_dir = self.directory / "bin"
        mock_dir.mkdir()
        for name in ["id", "sysctl"]:
            tool = mock_dir / name
            tool.write_text(f"#!{sys.executable}\n" + MOCK)
            tool.chmod(0o755)
        source = (ROOT / "layout/Library/ccSystem/system_tweaks.sh").read_text()
        self.assertEqual(source.count("state_dir=/var/root/Library/Preferences/ccSystem"), 1)
        source = source.replace("state_dir=/var/root/Library/Preferences/ccSystem",
                                f"state_dir='{self.state_dir}'")
        self.script = self.directory / "module.sh"
        self.script.write_text(source)
        self.env = dict(os.environ, PATH=str(mock_dir) + os.pathsep + os.environ["PATH"],
                        FAKE_SYSCTL_STATE=str(self.fake_state))

    def run_module(self, action, **environment):
        return subprocess.run(["sh", str(self.script), action], capture_output=True,
                              text=True, env=dict(self.env, **environment), timeout=20)

    def data(self):
        return json.loads(self.fake_state.read_text())

    def change_value(self, key, value):
        data = self.data()
        data["values"][key] = value
        self.fake_state.write_text(json.dumps(data))

    def test_apply_repeat_and_restore(self):
        self.assertEqual(self.run_module("apply").returncode, 0)
        self.assertEqual(self.data()["values"], DESIRED)
        backup = self.backup.read_text()
        calls = self.data()["calls"]
        self.assertEqual(self.run_module("apply").returncode, 0)
        self.assertEqual(self.backup.read_text(), backup)
        self.assertEqual(self.data()["calls"], calls)
        self.assertEqual(self.run_module("restore").returncode, 0)
        self.assertEqual(self.data()["values"], ORIGINAL)
        self.assertFalse(self.backup.exists())

    def test_unsupported_keys_are_skipped(self):
        subset = {key: ORIGINAL[key] for key in list(ORIGINAL)[:2]}
        self.fake_state.write_text(json.dumps({"values": subset, "calls": []}))
        result = self.run_module("apply")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Skipped unsupported/inaccessible", result.stdout)
        self.assertEqual(self.data()["values"], {key: DESIRED[key] for key in subset})
        self.assertEqual(self.run_module("restore").returncode, 0)
        self.assertEqual(self.data()["values"], subset)

    def test_failed_write_rolls_back_prior_changes(self):
        result = self.run_module("apply", FAKE_FAIL_WRITE="kern.maxvnodes=20000")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.data()["values"], ORIGINAL)
        self.assertFalse(self.backup.exists())

    def test_failed_restore_retains_backup_for_retry(self):
        self.assertEqual(self.run_module("apply").returncode, 0)
        result = self.run_module("restore", FAKE_FAIL_WRITE="kern.wq_max_threads=512")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.backup.read_text().splitlines(), ["kern.wq_max_threads 512 2048"])
        self.assertEqual(self.run_module("restore").returncode, 0)
        self.assertEqual(self.data()["values"], ORIGINAL)

    def test_restore_preserves_external_changes(self):
        self.assertEqual(self.run_module("apply").returncode, 0)
        self.change_value("kern.wq_max_threads", 333)
        self.assertEqual(self.run_module("restore").returncode, 0)
        self.assertEqual(self.data()["values"], dict(ORIGINAL, **{"kern.wq_max_threads": 333}))
        self.assertFalse(self.backup.exists())

    def test_preexisting_target_is_not_owned(self):
        self.change_value("kern.maxvnodes", 20000)
        self.assertEqual(self.run_module("apply").returncode, 0)
        self.assertNotIn("kern.maxvnodes", self.backup.read_text())
        self.assertEqual(self.run_module("restore").returncode, 0)
        self.assertEqual(self.data()["values"]["kern.maxvnodes"], 20000)

    def test_nonroot_cannot_write(self):
        self.assertNotEqual(self.run_module("apply", FAKE_UID="501").returncode, 0)
        self.assertEqual(self.data()["calls"], [])
        self.assertFalse(self.backup.exists())

    def test_invalid_backup_cannot_write_arbitrary_keys(self):
        self.state_dir.mkdir()
        self.backup.write_text("unrelated.key 1 2\n")
        self.assertNotEqual(self.run_module("restore").returncode, 0)
        self.assertEqual(self.data()["calls"], [])


if __name__ == "__main__":
    if not shutil.which("sh"):
        raise SystemExit("A POSIX shell is required; run these tests in the Linux CI job.")
    unittest.main()
