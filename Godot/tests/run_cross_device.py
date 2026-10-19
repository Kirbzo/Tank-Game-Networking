"""Run the actual Godot lobby on Windows and an SSH-accessible Linux VM."""
import argparse
import json
from pathlib import Path
import queue
import shlex
import subprocess
import threading
import time
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--guest-ip", required=True)
    parser.add_argument("--host-ip", required=True)
    parser.add_argument("--ssh-key", required=True)
    parser.add_argument("--known-hosts", required=True)
    parser.add_argument("--host-engine", required=True)
    parser.add_argument("--guest-engine", required=True)
    parser.add_argument("--guest-project", default="/home/comp214/COMP214/Godot")
    parser.add_argument("--output", required=True)
    parser.add_argument("--mode", choices=["automatic", "session-id", "direct"], action="append")
    parser.add_argument("--direction", choices=["windows-host", "linux-host"], action="append")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    ssh = ["ssh.exe", "-i", args.ssh_key, "-o", "BatchMode=yes", "-o", "ConnectTimeout=45",
           "-o", "StrictHostKeyChecking=yes", "-o", "UserKnownHostsFile=" + args.known_hosts,
           "comp214@" + args.guest_ip]
    results = []
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    def command(remote, user_args):
        engine = args.guest_engine if remote else args.host_engine
        path = args.guest_project if remote else str(project)
        cmd = [engine, "--headless", "--path", path, "--script", "res://tests/cross_device_smoke.gd", "--"] + user_args
        return ssh + [shlex.join(cmd)] if remote else cmd

    def start(cmd):
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, encoding="utf-8", errors="replace")
        collected = []
        messages = queue.Queue()

        def read():
            for line in process.stdout:
                collected.append(line)
                messages.put(line)

        threading.Thread(target=read, daemon=True).start()
        return process, collected, messages

    for direction in args.direction or ["windows-host", "linux-host"]:
        remote_host = direction == "linux-host"
        host_ip = args.guest_ip if remote_host else args.host_ip
        for mode in args.mode or ["automatic", "session-id", "direct"]:
            name = direction + "/" + mode
            print("RUN " + name, flush=True)
            stop_name = "comp214-test-stop-" + uuid.uuid4().hex + ".flag"
            stop_file = "/tmp/" + stop_name if remote_host else str(Path(tempfile.gettempdir()) / stop_name)
            host, host_lines, lines = start(command(remote_host, ["host", "stop-file=" + stop_file] + ([] if mode == "automatic" else ["query-only"])))
            observer = None
            observer_lines = []
            shutdown_requested = False

            def request_shutdown():
                nonlocal shutdown_requested
                if shutdown_requested:
                    return
                if remote_host:
                    subprocess.run(ssh + ["touch -- " + shlex.quote(stop_file)], capture_output=True,
                                   text=True, timeout=60, check=True)
                else:
                    Path(stop_file).touch()
                shutdown_requested = True

            error = None
            try:
                deadline = time.monotonic() + 90
                session = None
                while time.monotonic() < deadline:
                    try:
                        line = lines.get(timeout=0.25)
                    except queue.Empty:
                        if host.poll() is not None:
                            break
                        continue
                    if line.startswith("HOST_READY "):
                        session = json.loads(line.removeprefix("HOST_READY "))
                        break
                if session is None:
                    raise RuntimeError("Host did not create a session: " + "".join(host_lines))
                observer, observer_lines, observer_messages = start(command(not remote_host,
                    ["observer", "address=" + host_ip, "id=" + session["id"], "mode=" + mode]))
                deadline = time.monotonic() + 150
                while time.monotonic() < deadline:
                    try:
                        line = observer_messages.get(timeout=0.25)
                    except queue.Empty:
                        if observer.poll() is not None:
                            break
                        continue
                    if line.startswith("REMOTE_LISTING "):
                        print("DISCOVERED " + name + " " + line.removeprefix("REMOTE_LISTING ").strip(), flush=True)
                        request_shutdown()
                if observer.poll() is None:
                    raise RuntimeError("Observer timed out")
                request_shutdown()
                host_code = host.wait(timeout=60)
                if host_code or observer.returncode:
                    raise RuntimeError("Host or observer failed")
                if "PASS cross-device observer" not in "".join(observer_lines):
                    raise RuntimeError("Observer did not report acceptance")
            except Exception as exc:
                error = str(exc)
                try:
                    request_shutdown()
                    host.wait(timeout=60)
                except (subprocess.SubprocessError, OSError):
                    host.terminate()
                    host.wait(timeout=10)
                if observer is not None and observer.poll() is None:
                    observer.terminate()
                    observer.wait(timeout=10)
            finally:
                if not remote_host:
                    Path(stop_file).unlink(missing_ok=True)
            result = {"case": name, "passed": error is None, "host_ip": host_ip,
                      "observer_ip": args.host_ip if remote_host else args.guest_ip,
                      "host_log": "".join(host_lines), "error": error,
                      "shutdown_requested_after_listing": shutdown_requested,
                      "observer_log": "".join(observer_lines)}
            results.append(result)
            output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
            print(("PASS " if error is None else "FAIL ") + name, flush=True)
            print(result["observer_log"], flush=True)
    raise SystemExit(0 if all(result["passed"] for result in results) else 1)


if __name__ == "__main__":
    main()
