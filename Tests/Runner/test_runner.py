"""Real process/PTY tests. Never invokes Claude or the network."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

RUNNER = str(Path(sys.argv.pop(1)).resolve())
FIXTURE = r'''
import os, signal, subprocess, sys, time
from pathlib import Path
assert sys.argv[1] == "remote-control"
assert os.isatty(0) and os.isatty(1)
mode = os.environ["BEAMLET_TEST_MODE"]
child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
Path("pids").write_text(str(os.getpid()) + " " + str(child.pid))
def stop(sig, frame):
    print("INTERRUPTED", flush=True)
    child.wait(timeout=3)
    sys.exit(0)
signal.signal(signal.SIGINT, signal.SIG_IGN if mode == "stubborn" else stop)
if mode == "stubborn": signal.signal(signal.SIGTERM, signal.SIG_IGN)
print("https://claude.ai/code/session_fixture", flush=True)
if mode == "exit":
    print("FINAL_ERROR", flush=True)
    sys.exit(7)
while True: time.sleep(0.05)
'''


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="beamlet runner spaces ")
        self.folder = Path(self.temp.name)
        self.fixture = self.folder / "fake claude"
        self.fixture.write_text("#!" + sys.executable + "\n" + FIXTURE)
        self.fixture.chmod(0o700)
        self.processes = []

    def tearDown(self):
        for process in self.processes:
            if process.poll() is None:
                process.stdin.close()
                process.wait(timeout=15)
            for stream in (process.stdin, process.stdout, process.stderr):
                if stream and not stream.closed: stream.close()
        self.temp.cleanup()

    def launch(self, mode="normal"):
        env = dict(os.environ, BEAMLET_TEST_MODE=mode)
        process = subprocess.Popen([RUNNER, str(self.fixture), str(self.folder),
                                    str(self.folder / "lock"), "remote-control"],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        self.processes.append(process)
        return process

    def ready(self):
        until = time.monotonic() + 5
        while time.monotonic() < until:
            if (self.folder / "pids").exists():
                text = (self.folder / "pids").read_text()
                if len(text.split()) == 2:
                    return [int(pid) for pid in text.split()]
            time.sleep(0.03)
        self.fail("Fixture never started")

    def assert_gone(self, pids):
        for pid in pids:
            for _ in range(100):
                try: os.kill(pid, 0)
                except ProcessLookupError: break
                time.sleep(0.03)
            else: self.fail(f"Owned process {pid} survived runner exit")

    def test_interrupt_closes_child_group_and_flushes_output(self):
        process = self.launch()
        pids = self.ready()
        output, _ = process.communicate(b"I", timeout=6)
        self.assertEqual(process.returncode, 0)
        self.assertIn(b"INTERRUPTED", output)
        self.assert_gone(pids)

    def test_parent_pipe_eof_cleans_up_after_app_crash(self):
        process = self.launch()
        pids = self.ready()
        process.stdin.close()
        process.stdin = None
        process.communicate(timeout=6)
        self.assertEqual(process.returncode, 0)
        self.assert_gone(pids)

    def test_exit_preserves_status_and_final_output(self):
        process = self.launch("exit")
        pids = self.ready()
        process.wait(timeout=6)
        output = process.stdout.read()
        self.assertEqual(process.returncode, 7)
        self.assertIn(b"FINAL_ERROR", output)
        self.assert_gone(pids)

    def test_duplicate_owner_is_rejected_without_touching_first(self):
        first = self.launch()
        pids = self.ready()
        second = self.launch()
        second.wait(timeout=3)
        self.assertEqual(second.returncode, 73)
        self.assertIsNone(first.poll())
        for pid in pids: os.kill(pid, 0)
        first.communicate(b"I", timeout=6)
        self.assert_gone(pids)

    def test_stubborn_child_is_bounded(self):
        process = self.launch("stubborn")
        pids = self.ready()
        process.communicate(b"I", timeout=15)
        self.assert_gone(pids)


if __name__ == "__main__": unittest.main(verbosity=2)
