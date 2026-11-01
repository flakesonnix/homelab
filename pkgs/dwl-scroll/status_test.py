"""Deterministic metrics fixtures; never contact the real user/system D-Bus."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("dwl_status", sys.argv.pop(1))
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class MetricsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.runner = Mock(return_value="")
        self.put("proc/stat", "cpu 100 0 100 800 0 0 0 0 0 0\n")
        self.metrics = status.Metrics(
            self.root / "sys", self.root / "proc", nvidia_smi="/nvidia-smi", runner=self.runner,
        )

    def put(self, path, value):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value)

    def test_cpu_usage_delta_and_guest_accounting(self):
        self.put("proc/stat", "cpu 150 0 100 850 0 0 0 0 20 0\n")
        self.assertEqual(self.metrics.cpu_usage(), "50%")
        self.assertEqual(self.metrics.cpu_usage(), "0%")

    def test_memory_uses_memavailable_not_memfree(self):
        self.put("proc/meminfo", "MemTotal: 8388608 kB\nMemAvailable: 2097152 kB\nMemFree: 1024 kB\n")
        self.assertEqual(self.metrics.memory(), "\U000f035b 6.4 GB")

    def test_battery_and_charging(self):
        self.put("sys/class/power_supply/BAT0/type", "Battery")
        self.put("sys/class/power_supply/BAT0/capacity", "82")
        self.put("sys/class/power_supply/BAT0/status", "Charging")
        self.assertEqual(self.metrics.battery(), "\uf241 82% \uf0e7")
        self.put("sys/class/power_supply/BAT0/status", "Discharging")
        self.assertEqual(self.metrics.battery(), "\uf241 82%")

    def test_status_does_not_poll_network_names(self):
        self.metrics.status()
        self.runner.assert_not_called()

    def test_cpu_package_sensor(self):
        self.put("sys/class/hwmon/hwmon7/name", "coretemp")
        self.put("sys/class/hwmon/hwmon7/temp1_input", "61000")
        self.put("sys/class/hwmon/hwmon7/temp2_input", "57000")
        self.assertEqual(self.metrics.cpu_temperature(), "61°C")

    def test_thinkpad_gpu_sensor_needs_no_nvidia_smi(self):
        self.put("sys/class/hwmon/hwmon6/name", "thinkpad")
        self.put("sys/class/hwmon/hwmon6/temp2_label", "GPU")
        self.put("sys/class/hwmon/hwmon6/temp2_input", "48000")
        self.assertEqual(self.metrics.gpu_temperature(), "\uf108 48°C")
        self.runner.assert_not_called()

    def test_suspended_gpu_is_not_woken(self):
        self.put("sys/bus/pci/drivers/nvidia/0000:01:00.0/power/runtime_status", "suspended")
        self.assertEqual(self.metrics.gpu_temperature(), "\uf108 off")
        self.runner.assert_not_called()

    def test_active_gpu_fallback(self):
        self.put("sys/bus/pci/drivers/nvidia/0000:01:00.0/power/runtime_status", "active")
        self.runner.return_value = "53\n"
        self.assertEqual(self.metrics.gpu_temperature(), "\uf108 53°C")
        self.assertIn("--id=0000:01:00.0", self.runner.call_args.args[0])

    def test_missing_metrics_without_clock_or_date(self):
        self.assertEqual(self.metrics.status(), "\uf244 n/a | \uf2db 0% \uf2c9 n/a | \U000f035b n/a | \uf108 n/a")

    def test_invalid_sensors_are_ignored(self):
        self.put("sys/class/hwmon/hwmon0/name", "nouveau")
        self.put("sys/class/hwmon/hwmon0/temp1_input", "-128000")
        self.assertEqual(self.metrics.gpu_temperature(), "\uf108 n/a")

    def test_right_padding_tracks_tray_icons(self):
        runner = Mock(return_value='as 3 ":1.1/one" ":1.2/two" ":1.3/three"')
        self.assertEqual(status.right_padding("/busctl", runner), " " * 24)
        runner.return_value = "as 0"
        self.assertEqual(status.right_padding("/busctl", runner), " " * 12)
        runner.return_value = ""
        self.assertEqual(status.right_padding("/busctl", runner), " " * 16)


if __name__ == "__main__":
    unittest.main()
