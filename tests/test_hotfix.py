#!/usr/bin/env python3
"""Isolated test against an operator-supplied affected platform.sh fixture.

No node is contacted. All absolute node paths are redirected into a temp tree.
Usage: python3 tests/test_hotfix.py /path/to/affected/platform.sh [one-line-workaround.sh]
"""

import hashlib
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile


SOURCE = pathlib.Path(__file__).resolve().parents[1] / "patch-aredn-nand-validator.sh"
OLD = "2e89020c0d3c6b715b7e801a02571d0c17e279362f9f480d9820debbc57e1724"
FIXED = "023897131f603e6c062c29ff902bc1ee21b3874f534f54efb558c8c0797860cc"
WORKAROUND = "96ede1f3e0778bcd7d898660739360cec52a68ae342b725f0e8b683fe9197315"
BOARDS = (
    "mikrotik,routerboard-912uag-5hpnd",
    "mikrotik,routerboard-911g-5hpnd",
    "mikrotik,routerboard-911g-5hpnd-qrt",
)


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_case(fixture, board, *, run_twice=False, unknown=False, nonroot=False, bad_expected=False):
    with tempfile.TemporaryDirectory(prefix="aredn-validator-test-") as tmp:
        root = pathlib.Path(tmp)
        (root / "tmp/sysinfo").mkdir(parents=True)
        (root / "lib/upgrade").mkdir(parents=True)
        (root / "root").mkdir()
        (root / "tmp/sysinfo/board_name").write_text(board + "\n")
        target = root / "lib/upgrade/platform.sh"
        shutil.copyfile(fixture, target)
        if unknown:
            with target.open("a") as fh:
                fh.write("\n# unknown local edit\n")
        before = checksum(target)

        script = SOURCE.read_text()
        script = script.replace("/tmp/sysinfo/board_name", str(root / "tmp/sysinfo/board_name"))
        script = script.replace("file=/lib/upgrade/platform.sh", f"file={target}")
        script = script.replace("/root/aredn-validator-backup.", str(root / "root/aredn-validator-backup."))
        script = script.replace("$(id -u)", "1" if nonroot else "0")
        if bad_expected:
            script = script.replace(f"fixed={FIXED}", "fixed=" + "0" * 64)
        test_script = root / "test-patcher.sh"
        test_script.write_text(script)

        busybox = shutil.which("busybox")
        if not busybox:
            raise RuntimeError("BusyBox is required for this test")
        bindir = root / "bin"
        bindir.mkdir()
        for applet in ("cat", "sha256sum", "awk", "mktemp", "cp", "mv", "rm"):
            (bindir / applet).symlink_to(busybox)
        env = os.environ.copy()
        env["PATH"] = f"{bindir}:/usr/bin:/bin"

        def invoke():
            return subprocess.run([busybox, "ash", str(test_script)],
                                  env=env, text=True, capture_output=True)

        result = invoke()
        should_patch = board in BOARDS and not (unknown or nonroot or bad_expected)
        backups = list((root / "root").glob("aredn-validator-backup.*/platform.sh"))
        if should_patch:
            assert result.returncode == 0, result.stderr
            assert checksum(target) == FIXED
            assert len(backups) == 1 and checksum(backups[0]) == before
            if run_twice:
                again = invoke()
                assert again.returncode == 0 and "Already fixed" in again.stdout
                assert checksum(target) == FIXED
                assert len(list((root / "root").glob("aredn-validator-backup.*/platform.sh"))) == 1
        else:
            assert result.returncode != 0
            assert checksum(target) == before
            assert not backups


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    fixture = pathlib.Path(sys.argv[1]).resolve()
    assert checksum(fixture) == OLD, "Fixture is not the known affected platform.sh"
    passed = 0
    for board in BOARDS:
        run_case(fixture, board, run_twice=True)
        passed += 1
    if len(sys.argv) == 3:
        workaround = pathlib.Path(sys.argv[2]).resolve()
        assert checksum(workaround) == WORKAROUND, "Fixture is not the known one-line workaround"
        for board in BOARDS:
            run_case(workaround, board, run_twice=True)
            passed += 1
    for kwargs in (
        {"board": "mikrotik,routerboard-951g-2hnd"},
        {"board": BOARDS[0], "unknown": True},
        {"board": BOARDS[0], "nonroot": True},
        {"board": BOARDS[0], "bad_expected": True},
    ):
        run_case(fixture, **kwargs)
        passed += 1
    print(f"{passed} isolated BusyBox cases passed; no node was modified")


if __name__ == "__main__":
    main()
