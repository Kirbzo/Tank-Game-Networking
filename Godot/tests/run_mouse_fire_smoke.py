"""Windows graphical pair: send OS mouse messages only to the two test processes."""
import concurrent.futures
import ctypes
from ctypes import wintypes
from pathlib import Path
import subprocess
import sys
import threading


def click(pid, x, y):
    user = ctypes.WinDLL("user32", use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.IsWindowVisible.argtypes = [wintypes.HWND]
    user.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    windows = []

    @callback_type
    def visit(handle, _):
        owner = wintypes.DWORD()
        user.GetWindowThreadProcessId(handle, ctypes.byref(owner))
        if owner.value == pid and user.IsWindowVisible(handle):
            windows.append(handle)
        return True

    user.EnumWindows(visit, 0)
    if len(windows) != 1:
        raise RuntimeError(f"Expected one visible test window for PID {pid}, got {len(windows)}")
    point = (y << 16) | x
    for message, buttons in [(0x200, 0), (0x201, 1), (0x202, 0)]:
        if not user.PostMessageW(windows[0], message, buttons, point):
            raise ctypes.WinError(ctypes.get_last_error())


def main():
    root = Path(__file__).resolve().parents[2]
    engine = sys.argv[1]
    # The console launcher starts another process; target the graphical executable
    # directly so the window PID must match the process we own.
    if engine.endswith("_console.exe"):
        engine = engine.removesuffix("_console.exe") + ".exe"
    processes = [(role, subprocess.Popen(
        [engine, "--path", str(root / "Godot"), "--script", "res://tests/mouse_fire_smoke.gd",
         "--", role, "native"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, creationflags=subprocess.CREATE_NO_WINDOW)) for role in ["host", "guest"]]

    def collect(item):
        role, process = item
        timer = threading.Timer(30, process.kill)
        timer.start()
        output = []
        try:
            for line in process.stdout:
                output.append(line)
                if line.startswith("NATIVE_CLICK "):
                    _, pid, x, y = line.split()
                    if int(pid) != process.pid:
                        raise RuntimeError("Unexpected test process ID")
                    click(int(pid), int(x), int(y))
            code = process.wait()
            print(role, code, "".join(output), flush=True)
            return code == 0 and "PASS real mouse fire" in "".join(output)
        finally:
            timer.cancel()
            if process.poll() is None:
                process.kill()

    with concurrent.futures.ThreadPoolExecutor() as pool:
        results = list(pool.map(collect, processes))
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
