#!/usr/bin/env python3

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def main() -> int:
    repository = Path(__file__).resolve().parent.parent
    benchmark = repository / "tools" / "measure-startup.py"

    with tempfile.TemporaryDirectory() as temporary_directory:
        fake_shell = Path(temporary_directory) / "fake-shell"
        fake_shell.write_text(
            "#!/bin/sh\n"
            'printf "%s" "$Z4M_BENCHMARK_MARKER"\n'
            "IFS= read -r _z4m_command || :\n",
            encoding="utf-8",
        )
        fake_shell.chmod(0o755)

        completed = subprocess.run(
            [
                sys.executable,
                str(benchmark),
                "--shell",
                str(fake_shell),
                "--no-warmup",
                "--json",
                "3",
            ],
            check=True,
            capture_output=True,
            text=True,
            env=os.environ.copy(),
        )

        result = json.loads(completed.stdout)
        assert result["metric"] == "time_to_first_ready_prompt_ms"
        assert result["iterations"] == 3
        assert result["min"] <= result["p50"] <= result["p95"] <= result["max"]

        # `z4m bench` resolves the framework as $Z4M/zsh4monkey; a link keeps the
        # test independent of the name of the checkout directory.
        cache = Path(temporary_directory) / "cache"
        cache.mkdir()
        (cache / "zsh4monkey").symlink_to(repository)
        wrapper = subprocess.run(
            [
                "zsh",
                "-dfc",
                (
                    'Z4M=$1; _z4m_exe=$2; '
                    'source "$3/fn/-z4m-cmd-bench" --no-warmup --json 2'
                ),
                "_",
                str(cache),
                str(fake_shell),
                str(repository),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        wrapper_result = json.loads(wrapper.stdout)
        assert wrapper_result["iterations"] == 2

        early_exit_shell = Path(temporary_directory) / "early-exit-shell"
        early_exit_shell.write_text("#!/bin/sh\nexit 7\n", encoding="utf-8")
        early_exit_shell.chmod(0o755)
        early_exit = subprocess.run(
            [
                sys.executable,
                str(benchmark),
                "--shell",
                str(early_exit_shell),
                "--no-warmup",
                "--json",
                "1",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        assert early_exit.returncode != 0

        timeout_shell = Path(temporary_directory) / "timeout-shell"
        timeout_shell.write_text("#!/bin/sh\nsleep 5\n", encoding="utf-8")
        timeout_shell.chmod(0o755)
        started_at = time.monotonic()
        timed_out = subprocess.run(
            [
                sys.executable,
                str(benchmark),
                "--shell",
                str(timeout_shell),
                "--no-warmup",
                "--timeout",
                "0.1",
                "--json",
                "1",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        assert timed_out.returncode != 0
        assert time.monotonic() - started_at < 3.0

        stubborn_shell = Path(temporary_directory) / "stubborn-shell"
        child_pid_file = Path(temporary_directory) / "stubborn-child.pid"
        stubborn_shell.write_text(
            "#!/bin/sh\n"
            'sh -c \'trap "" TERM HUP; '
            'printf "%s\\n" "$$" >"$Z4M_TEST_CHILD_PID_FILE"; '
            "exec sleep 30' &\n"
            'while [ ! -s "$Z4M_TEST_CHILD_PID_FILE" ]; do :; done\n'
            'printf "%s" "$Z4M_BENCHMARK_MARKER"\n'
            "IFS= read -r _z4m_command || :\n",
            encoding="utf-8",
        )
        stubborn_shell.chmod(0o755)
        stubborn_environment = os.environ.copy()
        stubborn_environment["Z4M_TEST_CHILD_PID_FILE"] = str(child_pid_file)
        subprocess.run(
            [
                sys.executable,
                str(benchmark),
                "--shell",
                str(stubborn_shell),
                "--no-warmup",
                "--json",
                "1",
            ],
            check=True,
            capture_output=True,
            text=True,
            env=stubborn_environment,
        )
        stubborn_child_pid = int(child_pid_file.read_text(encoding="utf-8"))
        try:
            os.kill(stubborn_child_pid, 0)
        except ProcessLookupError:
            pass
        else:
            os.kill(stubborn_child_pid, 9)
            raise AssertionError("benchmark left a descendant process running")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
