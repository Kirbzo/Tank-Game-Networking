"""Run bounded Godot checks, including real host/guest loopback sessions."""
import argparse
from pathlib import Path
import queue
import subprocess
import threading


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--pair", action="store_true")
    parser.add_argument("--timeout", type=float, default=75)
    parser.add_argument("script")
    parser.add_argument("args", nargs="*")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    base = [args.godot, "--headless", "--path", str(project), "--log-file", "NUL",
            "--script", "res://tests/" + args.script + ".gd", "--"]
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    if not args.pair:
        result = subprocess.run(base + args.args, capture_output=True, text=True,
                                timeout=args.timeout, creationflags=flags)
        output = result.stdout + result.stderr
        print(output)
        return result.returncode or int("SCRIPT ERROR" in output or "FAIL:" in output)
    processes = []
    output = []
    endpoint = queue.Queue()
    def collect(process):
        for line in process.stdout:
            output.append(line)
            if "FAIL:" in line or "SCRIPT ERROR" in line:
                print("HOST:", line, end="", flush=True)
            if line.startswith("ENDPOINT "):
                endpoint.put(line.split()[1:])
    try:
        host = subprocess.Popen(base + ["host", "loopback"] + args.args,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, creationflags=flags)
        processes.append(host)
        reader = threading.Thread(target=collect, args=(host,), daemon=True)
        reader.start()
        game, port = endpoint.get(timeout=15)
        print("READY", game, port, flush=True)
        guest = subprocess.Popen(base + ["loopback", game, port] + args.args,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, creationflags=flags)
        processes.append(guest)
        guest_output = guest.communicate(timeout=args.timeout)[0]
        host.wait(timeout=args.timeout)
        reader.join(timeout=2)
        host_output = "".join(output)
        print("HOST", host.returncode, host_output)
        print("GUEST", guest.returncode, guest_output)
        return host.returncode or guest.returncode or int(any(
            marker in host_output + guest_output for marker in ["SCRIPT ERROR", "FAIL:"]))
    except (subprocess.TimeoutExpired, queue.Empty) as error:
        print("HOST OUTPUT", "".join(output))
        if isinstance(error, subprocess.TimeoutExpired):
            print("GUEST OUTPUT", error.output)
        return 1
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    raise SystemExit(run())
