#!/usr/bin/env python3

from __future__ import annotations

import argparse
import errno
import json
import math
import os
import pty
import secrets
import select
import signal
import statistics
import sys
import time
from dataclasses import dataclass


@dataclass(frozen=True)
class Measurement:
    milliseconds: float


def terminate_child(pid: int) -> None:
    leader_reaped = False

    def process_group_exists() -> bool:
        try:
            os.killpg(pid, 0)
        except (ProcessLookupError, PermissionError):
            return False
        return True

    try:
        os.killpg(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except PermissionError:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    deadline = time.monotonic() + 1.0
    while time.monotonic() < deadline:
        if not leader_reaped:
            try:
                waited, _ = os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                leader_reaped = True
            else:
                leader_reaped = waited == pid
        if leader_reaped and not process_group_exists():
            return
        time.sleep(0.01)

    if process_group_exists():
        try:
            os.killpg(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    if not leader_reaped:
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass


def measure_once(shell: str, login: bool, timeout: float) -> Measurement:
    marker = f"__Z4M_READY_{secrets.token_hex(16)}__"
    marker_bytes = marker.encode()
    environment = os.environ.copy()
    environment["Z4M_BENCHMARK_MARKER"] = marker

    started_at = time.monotonic_ns()
    pid, master_fd = pty.fork()
    if pid == 0:
        argument = "-il" if login else "-i"
        os.execvpe(shell, [shell, argument], environment)

    deadline = time.monotonic() + timeout
    output = bytearray()
    measured: Measurement | None = None

    try:
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            readable, _, _ = select.select(
                [master_fd], [], [], min(0.1, remaining)
            )
            if not readable:
                waited, status = os.waitpid(pid, os.WNOHANG)
                if waited == pid:
                    raise RuntimeError(
                        f"shell exited before readiness marker (status={status})"
                    )
                continue

            try:
                chunk = os.read(master_fd, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    chunk = b""
                else:
                    raise

            if not chunk:
                raise RuntimeError("shell closed the PTY before readiness marker")

            output.extend(chunk)
            if marker_bytes in output:
                elapsed = (time.monotonic_ns() - started_at) / 1_000_000
                measured = Measurement(milliseconds=elapsed)
                os.write(master_fd, b"exit\n")
                break

            if len(output) > 1_048_576:
                del output[:-len(marker_bytes)]

        if measured is None:
            tail = bytes(output[-512:]).decode(errors="replace")
            raise TimeoutError(
                f"timed out after {timeout:.1f}s waiting for readiness marker; "
                f"output tail={tail!r}"
            )
        return measured
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        terminate_child(pid)


def percentile_nearest_rank(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    index = max(0, math.ceil(percentile * len(ordered)) - 1)
    return ordered[index]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure time to zsh4monkey's first fully initialized prompt."
    )
    parser.add_argument("count", nargs="?", type=int, default=10)
    parser.add_argument("--shell", required=True)
    parser.add_argument("--login", action="store_true")
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--no-warmup", action="store_true")
    arguments = parser.parse_args()
    if arguments.count < 1:
        parser.error("count must be greater than zero")
    if arguments.timeout <= 0:
        parser.error("timeout must be greater than zero")
    return arguments


def main() -> int:
    arguments = parse_args()

    if not arguments.no_warmup:
        measure_once(arguments.shell, arguments.login, arguments.timeout)

    measurements: list[float] = []
    for index in range(arguments.count):
        measurement = measure_once(
            arguments.shell, arguments.login, arguments.timeout
        )
        measurements.append(measurement.milliseconds)
        if not arguments.json:
            print(
                f"\riteration {index + 1}/{arguments.count}: "
                f"{measurement.milliseconds:.1f}ms",
                end="",
                flush=True,
            )

    summary = {
        "metric": "time_to_first_ready_prompt_ms",
        "iterations": arguments.count,
        "min": min(measurements),
        "p50": statistics.median(measurements),
        "p95": percentile_nearest_rank(measurements, 0.95),
        "max": max(measurements),
        "mean": statistics.fmean(measurements),
    }

    if arguments.json:
        print(json.dumps(summary, separators=(",", ":"), sort_keys=True))
    else:
        print()
        print("z4m: time to first fully initialized prompt")
        print(f"  min:  {summary['min']:7.1f}ms")
        print(f"  p50:  {summary['p50']:7.1f}ms")
        print(f"  p95:  {summary['p95']:7.1f}ms")
        print(f"  max:  {summary['max']:7.1f}ms")
        print(f"  mean: {summary['mean']:7.1f}ms")

    return 0


if __name__ == "__main__":
    sys.exit(main())
