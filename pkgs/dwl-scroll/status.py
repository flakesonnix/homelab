"""Plain-text dwlb metrics; no shell evaluation or compositor IPC required."""
import argparse
import os
from pathlib import Path
import subprocess
import time

ICONS = {
    "battery": ("\uf244", "\uf243", "\uf242", "\uf241", "\uf240"),
    "charging": "\uf0e7",
    "cpu": "\uf2db",
    "temperature": "\uf2c9",
    "ram": "\U000f035b",
    "gpu": "\uf108",
}


def read_text(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ""


def read_int(path):
    try:
        return int(read_text(path))
    except ValueError:
        return None


def run_text(args):
    try:
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=2, check=False,
            env={**os.environ, "LC_ALL": "C"},
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, UnicodeError, subprocess.TimeoutExpired):
        return ""


class Metrics:
    def __init__(self, sys_root=Path("/sys"), proc_root=Path("/proc"),
                 nvidia_smi=None, runner=run_text):
        self.sys = Path(sys_root)
        self.proc = Path(proc_root)
        self.nvidia_smi = nvidia_smi
        self.runner = runner
        self.previous_cpu = self.cpu_sample()

    def cpu_sample(self):
        for line in read_text(self.proc / "stat").splitlines():
            if line.startswith("cpu "):
                try:
                    # Guest time is already included in user/nice; count it once.
                    fields = [int(value) for value in line.split()[1:9]]
                    if len(fields) >= 5:
                        return sum(fields), fields[3] + fields[4]
                except ValueError:
                    pass
        return None

    def cpu_usage(self):
        current, previous = self.cpu_sample(), self.previous_cpu
        self.previous_cpu = current
        if current is None or previous is None:
            return "n/a"
        total, idle = current[0] - previous[0], current[1] - previous[1]
        if total <= 0:
            return "0%"
        used = max(0.0, min(100.0, 100 * (total - idle) / total))
        return f"{used:.0f}%"

    def memory(self):
        values = {}
        for line in read_text(self.proc / "meminfo").splitlines():
            fields = line.split()
            if len(fields) > 1:
                try:
                    values[fields[0].rstrip(":")] = int(fields[1])
                except ValueError:
                    pass
        total = values.get("MemTotal", 0)
        available = values.get("MemAvailable")
        if not total or available is None:
            return f"{ICONS['ram']} n/a"
        used = max(0, min(total, total - available))
        return f"{ICONS['ram']} {used * 1024 / 1000000000:.1f} GB"

    def battery(self):
        batteries = []
        for supply in sorted((self.sys / "class/power_supply").glob("*")):
            if read_text(supply / "type") != "Battery":
                continue
            capacity = read_int(supply / "capacity")
            if capacity is not None and 0 <= capacity <= 100:
                batteries.append((capacity, read_text(supply / "status")))
        if not batteries:
            return f"{ICONS['battery'][0]} n/a"
        capacity = sum(value for value, _ in batteries) / len(batteries)
        states = {state for _, state in batteries}
        icon = ICONS["battery"][min(4, int((capacity + 10) / 25))]
        suffix = " " + ICONS["charging"] if "Charging" in states else ""
        return f"{icon} {capacity:.0f}%{suffix}"

    def temperatures(self, kind):
        names = {
            "cpu": {"coretemp", "k10temp", "zenpower", "cpu_thermal"},
            "gpu": {"amdgpu", "nouveau", "nvidia", "i915", "xe"},
        }
        values = []
        for hwmon in (self.sys / "class/hwmon").glob("hwmon*"):
            chip = read_text(hwmon / "name").lower()
            for sensor in hwmon.glob("temp*_input"):
                label = read_text(sensor.with_name(sensor.name.replace("_input", "_label"))).lower()
                if chip not in names[kind] and not label.startswith(kind):
                    continue
                value = read_int(sensor)
                if value is not None and 0 < value < 150000:
                    values.append(value / 1000)
        if not values and kind == "cpu":
            for zone in (self.sys / "class/thermal").glob("thermal_zone*"):
                if read_text(zone / "type").lower() in {"x86_pkg_temp", "cpu-thermal", "cpu_thermal"}:
                    value = read_int(zone / "temp")
                    if value is not None and 0 < value < 150000:
                        values.append(value / 1000)
        return values

    def cpu_temperature(self):
        values = self.temperatures("cpu")
        return f"{max(values):.0f}°C" if values else "n/a"

    def gpu_temperature(self):
        values = self.temperatures("gpu")
        if values:
            return f"{ICONS['gpu']} {max(values):.0f}°C"
        devices = list((self.sys / "bus/pci/drivers/nvidia").glob("*:*"))
        active = [p.name for p in devices if read_text(p / "power/runtime_status") == "active"]
        if devices and not active:
            return f"{ICONS['gpu']} off"
        # nvidia-smi can wake a suspended dGPU. Only query already-active devices.
        if active and self.nvidia_smi:
            output = self.runner([
                self.nvidia_smi, "--id=" + ",".join(active),
                "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits",
            ])
            values = []
            for line in output.splitlines():
                try:
                    value = float(line)
                    if 0 < value < 150:
                        values.append(value)
                except ValueError:
                    pass
            if values:
                return f"{ICONS['gpu']} {max(values):.0f}°C"
        return f"{ICONS['gpu']} n/a"

    def status(self):
        return " | ".join([
            self.battery(),
            f"{ICONS['cpu']} {self.cpu_usage()} {ICONS['temperature']} {self.cpu_temperature()}",
            self.memory(), self.gpu_temperature(),
        ])


def right_padding(busctl, runner=run_text):
    """Leave room for the clock/tray overlaid at the right edge of dwlb."""
    output = runner([
        busctl, "--user", "get-property", "org.kde.StatusNotifierWatcher",
        "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
        "RegisteredStatusNotifierItems",
    ])
    try:
        fields = output.split()
        count = int(fields[1]) if fields[0] == "as" else 1
        count = max(0, min(16, count))
    except (IndexError, ValueError):
        count = 1
    # Iosevka is monospaced. Four cells per icon cover icon + spacing/padding;
    # twelve more cells cover HH:MM and its padding. Grow with registered icons.
    return " " * (12 + 4 * count)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dwlb", required=True)
    parser.add_argument("--nvidia-smi")
    parser.add_argument("--busctl", default="busctl")
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("--interval must be positive")
    metrics = Metrics(nvidia_smi=args.nvidia_smi)
    while True:
        status = metrics.status()
        if args.once:
            print(status)
            return
        # The target starts before the bar; wait for its socket without failing.
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/nonexistent")) / "dwlb"
        if any(p.is_socket() for p in runtime.glob("dwlb-*")):
            run_text([args.dwlb, "-status", "all", status + right_padding(args.busctl)])
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
