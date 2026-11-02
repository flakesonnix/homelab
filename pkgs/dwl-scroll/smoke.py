"""Exercise the real compositor on two isolated headless outputs.

Requires foot, wtype, wlr-randr, grim and Pillow (test dependencies only).
No access to the user's Wayland socket, session bus or physical outputs.
"""
import os
import json
from pathlib import Path
import select
import shlex
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time

from PIL import Image


class DiscordStub:
    """Minimal RPC server bound only to the test compositor's private runtime."""
    def __init__(self, root):
        self.activities = []
        self.client_ids = []
        self.errors = []
        self.cleared = threading.Event()
        self.stopped = threading.Event()
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(str(root / "discord-ipc-0"))
        self.listener.listen(4)
        self.listener.settimeout(0.1)
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    @staticmethod
    def send(connection, opcode, payload):
        data = json.dumps(payload).encode()
        connection.sendall(struct.pack("<II", opcode, len(data)) + data)

    def run(self):
        try:
            while not self.stopped.is_set():
                try:
                    connection, _ = self.listener.accept()
                except socket.timeout:
                    continue
                with connection:
                    connection.settimeout(0.1)
                    buffer = bytearray()
                    while not self.stopped.is_set():
                        try:
                            data = connection.recv(4096)
                        except socket.timeout:
                            continue
                        if not data:
                            break
                        buffer.extend(data)
                        while len(buffer) >= 8:
                            opcode, length = struct.unpack_from("<II", buffer)
                            assert length <= 65536, "oversized Discord RPC frame"
                            if len(buffer) < length + 8:
                                break
                            payload = json.loads(buffer[8:length + 8])
                            del buffer[:length + 8]
                            if opcode == 0:
                                assert payload["v"] == 1
                                self.client_ids.append(payload["client_id"])
                                self.send(connection, 1, {"cmd": "DISPATCH", "evt": "READY", "data": {"v": 1}})
                            elif opcode == 1:
                                assert payload["cmd"] == "SET_ACTIVITY"
                                activity = payload["args"]["activity"]
                                self.activities.append(activity)
                                if activity is None:
                                    self.cleared.set()
                                else:
                                    self.cleared.clear()
        except Exception as error:
            if not self.stopped.is_set():
                self.errors.append(str(error))

    def close(self):
        self.stopped.set()
        self.listener.close()
        self.thread.join(timeout=3)
        assert not self.thread.is_alive(), "test Discord server did not stop"


def run(package, keymap="default", bar=None, tray=None):
    # Drive the same layout operations through the actual p53/Niri shortcuts.
    # Unlisted combinations are shared by the two configurations.
    niri_keys = {
        ("comma", ()): ("Left", ("shift",)),
        ("l", ("ctrl",)): ("l", ("alt",)),
        ("space", ("shift",)): ("v", ()),
        ("i", ()): ("i", ("alt",)),
        ("k", ("shift",)): ("k", ("ctrl",)),
        ("Return", ("shift",)): ("period", ()),
        ("Return", ("ctrl", "shift")): ("Return", ("alt", "shift")),
        ("l", ("ctrl", "shift")): ("bracketright", ("alt",)),
        ("h", ("shift",)): ("h", ("ctrl",)),
        ("bracketright", ()): ("equal", ()),
        ("f", ()): ("f", ("shift",)),
        ("period", ("shift",)): ("Right", ("ctrl", "shift")),
        ("q", ()): ("w", ()),
        **{(key, ()): (key, ("alt",)) for key in ("s", "t", "v", "m")},
    }
    with tempfile.TemporaryDirectory(prefix="dwl-scroll-") as directory:
        root = Path(directory)
        env = os.environ.copy()
        for key in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "XDG_ACTIVATION_TOKEN", "DBUS_SESSION_BUS_ADDRESS"):
            env.pop(key, None)
        env.update(
            XDG_RUNTIME_DIR=str(root),
            XDG_CONFIG_HOME=str(root / "config"),
            XDG_CACHE_HOME=str(root / "cache"),
            XDG_DATA_HOME=str(root / "data"),
            XDG_DATA_DIRS=str(root / "empty-data"),
            XDG_CURRENT_DESKTOP="dwl-scroll",
            WLR_BACKENDS="headless",
            WLR_HEADLESS_OUTPUTS="2",
            WLR_RENDERER="pixman",
        )
        clients = []
        tray_process = None
        locker_process = None
        rpc_server = DiscordStub(root) if env.get("DWL_TEST_DISCORD_RPC") else None
        apps = root / "data/applications"
        apps.mkdir(parents=True)
        icon_theme = root / "data/icons/DwlTestIcons"
        (icon_theme / "24x24/apps").mkdir(parents=True)
        (icon_theme / "index.theme").write_text(
            "[Icon Theme]\nName=DwlTestIcons\nInherits=hicolor\nDirectories=24x24/apps\n"
            "[24x24/apps]\nSize=24\nType=Fixed\nContext=Applications\n"
        )
        Image.new("RGBA", (24, 12), (240, 78, 152, 255)).save(
            icon_theme / "24x24/apps/dwl-test-alpha.png"
        )
        svg_icon = root / "file icon.svg"
        svg_icon.write_text(
            '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
            '<rect width="24" height="24" fill="#23cf8b"/></svg>'
        )
        gtk_config = root / "config/gtk-3.0"
        gtk_config.mkdir(parents=True)
        (gtk_config / "settings.ini").write_text("[Settings]\ngtk-icon-theme-name=DwlTestIcons\n")
        for identifier, name, title, icon in (
            ("alpha", "Launcher Alpha", "LauncherAlpha", "dwl-test-alpha"),
            ("beta", "Launcher Beta", "LauncherBeta", str(svg_icon)),
            ("unicode", "Ärger Editor", "LauncherUnicode", "dwl-missing-icon"),
        ):
            (apps / f"test-{identifier}.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=" + name
                + "\nExec=foot --config=/dev/null --app-id=dwl-scroll-launcher-test "
                + "--title=" + title + " sleep 120\nIcon=" + icon + "\n"
            )
        (apps / "test-hidden.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=Launcher Hidden\n"
            "Exec=foot\nNoDisplay=true\n"
        )
        input_log = root / "input.log"
        input_ready = root / "input.ready"
        input_log.write_bytes(b"")
        status_file = root / "status"
        error_file = root / "compositor.log"
        status = status_file.open("w")
        errors = error_file.open("w")
        compositor_args = [str(Path(package) / "bin/dwl-scroll")]
        if bar:
            bar_binary = bar
            compositor_args += [
                "-s", f"tee {shlex.quote(str(status_file))} | {shlex.quote(bar_binary)}",
            ]
        compositor = subprocess.Popen(
            compositor_args,
            env=env, stdout=status, stderr=errors,
        )

        def until(predicate, description, timeout=15):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                if rpc_server:
                    assert not rpc_server.errors, rpc_server.errors
                if compositor.poll() is not None:
                    raise AssertionError("compositor exited: " + error_file.read_text())
                value = predicate()
                if value:
                    return value
                time.sleep(0.05)
            raise AssertionError("timed out: " + description)

        def command(*args):
            return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT)

        def field(output, name):
            prefix = f"{output} {name} "
            matches = [line[len(prefix):] for line in status_file.read_text().splitlines()
                       if line.startswith(prefix)]
            return matches[-1] if matches else None

        def key(symbol, *modifiers, translate=True):
            if keymap == "niri" and translate:
                symbol, modifiers = niri_keys.get((symbol, modifiers), (symbol, modifiers))
            args = ["wtype", "-M", "logo"]
            for modifier in modifiers:
                args += ["-M", modifier]
            args += ["-k", symbol]
            for modifier in reversed(modifiers):
                args += ["-m", modifier]
            command(*args, "-m", "logo")
            time.sleep(0.12)

        colors = {"A": "aa0000", "B": "00aa00", "C": "0000aa", "D": "aaaa00"}

        def bounds(name, output="HEADLESS-1"):
            shot = root / "shot.png"
            command("grim", "-o", output, str(shot))
            with Image.open(shot) as image:
                rgb = image.convert("RGB")
                color = tuple(bytes.fromhex(colors[name]))
                mask = Image.new("1", rgb.size)
                mask.putdata([pixel == color for pixel in rgb.getdata()])
                return mask.getbbox()

        def open_window(name, observe_input=False):
            log = (root / f"foot-{name}.log").open("w")
            child = ["sleep", "120"]
            if observe_input:
                child = [sys.executable, "-c", (
                    "import os, pathlib, tty; tty.setraw(0); "
                    f"out=open({str(input_log)!r}, 'ab', buffering=0); "
                    f"pathlib.Path({str(input_ready)!r}).touch(); "
                    "\nwhile True: out.write(os.read(0, 1024))"
                )]
            clients.append(subprocess.Popen(
                ["foot", "--config=/dev/null", "--title=" + name,
                 "--app-id=dwl-scroll-test", "--override=font=Iosevka:size=10",
                 "--override=colors-dark.background=" + colors[name],
                 "--override=colors-light.background=" + colors[name],
                  *child], env=env, stdout=log, stderr=log,
            ))
            until(lambda: field("HEADLESS-1", "title") == name, "map " + name)
            return until(lambda: bounds(name), "render " + name)

        try:
            socket = until(lambda: next((p for p in root.glob("wayland-*") if p.is_socket()), None),
                           "Wayland socket")
            env["WAYLAND_DISPLAY"] = socket.name
            if tray:
                # The sandbox has no /etc/dbus-1/session.conf. Keep this bus
                # self-contained, with no real session's service activation.
                bus_config = root / "session.conf"
                bus_config.write_text(f"""<busconfig>
  <type>session</type>
  <listen>unix:tmpdir={root}</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
    <allow own="*"/>
  </policy>
</busconfig>
""")
                tray_process = subprocess.Popen(
                    ["dbus-run-session", "--config-file=" + str(bus_config), "--", tray],
                    env=env, stdout=errors, stderr=errors,
                )
            until(lambda: "HEADLESS-2" in command("wlr-randr"), "two outputs")
            command("wlr-randr", "--output", "HEADLESS-1", "--pos", "0,0",
                    "--output", "HEADLESS-2", "--pos", "1280,0")
            if field("HEADLESS-1", "selmon") != "1":
                key("comma")
            if bar:
                until(lambda: any(p.is_socket() for p in (root / "dwlb").glob("dwlb-*")),
                      "dwlb command socket")
            initial = open_window("A", observe_input=True)
            until(input_ready.exists, "focused client input observer")
            if rpc_server:
                until(lambda: any(activity and activity["state"] == "Application: dwl-scroll-test"
                                  for activity in rpc_server.activities),
                      "Discord presence publishes the focused app ID, not the window title", timeout=25)
                assert rpc_server.client_ids == [env["DWL_TEST_DISCORD_RPC"]]
            if bar:
                def below_bar():
                    box = bounds("A")
                    return box if box and box[1] > 20 else None

                initial = until(below_bar, "dwlb exclusive zone above tiled window")
                command(bar_binary, "-status", "all", "dwl-scroll headless test")
                command(bar_binary, "-hide", "all")
                until(lambda: (box := bounds("A")) and box[1] < initial[1],
                      "hide dwlb and reclaim bar space")
                command(bar_binary, "-show", "all")
                until(lambda: (box := bounds("A")) and box[1] == initial[1],
                      "show dwlb and reserve bar space")
                palette = json.loads(env["DWL_BAR_COLORS"])

                def bar_has_palette():
                    shot = root / "bar-style.png"
                    command("grim", "-o", "HEADLESS-1", str(shot))
                    with Image.open(shot) as image:
                        # The window body begins after bar + 12px padding + 2px border.
                        pixels = set(image.convert("RGB").crop(
                            (0, 0, image.width, initial[1] - 14)).getdata())
                    return all(tuple(bytes.fromhex(palette[name][:6])) in pixels
                               for name in ("root", "focus"))

                until(bar_has_palette, "dwlb background and active tag match dwl palette")
                if tray:
                    def tray_at_output_edge():
                        assert tray_process.poll() is None, "tray/clock process exited: " + error_file.read_text()
                        shot = root / "tray-position.png"
                        command("grim", "-o", "HEADLESS-1", str(shot))
                        with Image.open(shot) as image:
                            rgb = image.convert("RGB")
                            color = tuple(bytes.fromhex(env["DWL_TRAY_TEST_BACKGROUND"]))
                            mask = Image.new("1", rgb.size)
                            mask.putdata([pixel == color for pixel in rgb.getdata()])
                            box = mask.getbbox()
                            foreground = tuple(bytes.fromhex(palette["focus"][:6]))
                            clock_visible = box and foreground in set(rgb.crop(box).getdata())
                        return (clock_visible and box[1] == 0 and box[2] == rgb.width
                                and box[3] <= initial[1] - 12)

                    until(tray_at_output_edge, "tray/clock shares dwlb's first row, not a second bar")
            launcher_top = initial[1] - 2  # usable output top + 12px, inside dwl's padding

            def launcher_visible(output="HEADLESS-1"):
                shot = root / "launcher.png"
                command("grim", "-o", output, str(shot))
                with Image.open(shot) as image:
                    rgb = image.convert("RGB")
                    panel_width = min(720, image.width - 24)
                    x = (image.width - panel_width) // 2
                    focus = tuple(bytes.fromhex(json.loads(env.get(
                        "DWL_BAR_COLORS", '{"focus":"c69bff"}'))["focus"][:6]))
                    return all(rgb.getpixel(point) == focus for point in (
                        (x, launcher_top), (x + panel_width - 1, launcher_top),
                        (x, launcher_top + 100),
                    ))

            def launcher_icon(expected=None, row=0):
                shot = root / "launcher-icons.png"
                command("grim", "-o", "HEADLESS-1", str(shot))
                with Image.open(shot) as image:
                    rgb = image.convert("RGB")
                    left = (image.width - 720) // 2 + 12
                    top = launcher_top + 36 + row * 28 + 4
                    if expected is not None:
                        return rgb.getpixel((left + 10, top + 10)) == expected
                    # The icon cell contains no text/border. A missing application
                    # icon must still render something against the selected row.
                    background = tuple(bytes.fromhex(json.loads(env.get(
                        "DWL_BAR_COLORS", '{"focus":"c69bff"}'))["focus"][:6]))
                    return sum(pixel != background for pixel in rgb.crop(
                        (left, top, left + 20, top + 20)).getdata()) > 20

            baseline = input_log.read_bytes()
            # Holding the opening shortcut must not toggle the launcher on repeat.
            command("wtype", "-M", "logo", "-P", "d", "-s", "750", "-p", "d", "-m", "logo")
            until(launcher_visible, "built-in launcher rendered above clients")
            command("wtype", "Launcher Alpha")
            until(lambda: launcher_icon((240, 78, 152)), "themed PNG application icon rendered beside its result")
            command("wtype", "-k", "Down", "-k", "Up", "-k", "Tab")
            key("h")  # must not run a compositor focus binding while searching
            assert field("HEADLESS-1", "title") == "A"
            command("wtype", "-k", "Escape")
            until(lambda: not launcher_visible(), "Escape dismisses launcher")
            assert input_log.read_bytes() == baseline, "launcher input leaked into focused client"
            command("wtype", "after-launcher")
            until(lambda: b"after-launcher" in input_log.read_bytes(), "keyboard focus restored")

            key("d")
            until(launcher_visible, "reopen built-in launcher")
            command("wtype", "no-such-launcher-app")
            command("wtype", "-k", "Return")
            assert launcher_visible(), "Enter on an empty result closed the launcher"
            command("wtype", "-M", "ctrl", "-k", "u", "-m", "ctrl")
            command("wtype", "Launcher Alpha")
            command("wtype", "-k", "Return")
            until(lambda: field("HEADLESS-1", "title") == "LauncherAlpha", "launch .desktop application")
            key("q")
            until(lambda: field("HEADLESS-1", "title") == "A", "close launched application")
            key("d")
            until(launcher_visible, "search next application")
            command("wtype", "Launcher")
            command("wtype", "-k", "Down")
            until(lambda: launcher_icon((35, 207, 139), row=1), "absolute SVG application icon rendered beside its result")
            command("wtype", "-k", "Return")
            until(lambda: field("HEADLESS-1", "title") == "LauncherBeta", "navigate to second result")
            key("q")
            until(lambda: field("HEADLESS-1", "title") == "A", "return from second application")
            key("d")
            until(launcher_visible, "Unicode search")
            command("wtype", "Ärger")
            until(launcher_icon, "missing application icon has a visible fallback")
            command("wtype", "-k", "Return")
            until(lambda: field("HEADLESS-1", "title") == "LauncherUnicode", "launch Unicode application name")
            key("q")
            until(lambda: field("HEADLESS-1", "title") == "A", "return from Unicode application")

            if env.get("DWL_TEST_LOCKER"):
                key("d")
                until(launcher_visible, "launcher before session lock")
                baseline = input_log.read_bytes()
                locker_process = subprocess.Popen(
                    [env["DWL_TEST_LOCKER"]], env=env, stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, stderr=errors,
                )
                assert select.select([locker_process.stdout], [], [], 10)[0], "locker did not acquire session lock"
                assert locker_process.stdout.readline() == b"locked\n"
                until(lambda: not launcher_visible(), "session lock dismisses launcher")
                if rpc_server:
                    until(lambda: rpc_server.activities and rpc_server.activities[-1] is None,
                          "session lock immediately clears Discord presence")
                key("d")
                assert not launcher_visible(), "launcher opened over session lock"
                command("wtype", "locked-search")
                assert input_log.read_bytes() == baseline, "locked input leaked into client"
                if rpc_server:
                    assert rpc_server.activities[-1] is None, "Discord activity reappeared while locked"
                locker_process.stdin.write(b"u")
                locker_process.stdin.flush()
                assert locker_process.wait(timeout=10) == 0
                if rpc_server:
                    until(lambda: rpc_server.activities[-1] is not None,
                          "Discord reconnects after unlock", timeout=25)
                key("d")
                until(launcher_visible, "launcher available after unlock")
                command("wtype", "-k", "Escape")
                until(lambda: not launcher_visible(), "dismiss after unlock")

            width = initial[2] - initial[0]
            open_window("B")
            open_window("C")
            key("h")
            assert field("HEADLESS-1", "title") == "B"
            key("h")
            assert field("HEADLESS-1", "title") == "A"
            if keymap == "niri":
                key("Right")
                assert field("HEADLESS-1", "title") == "B"
                key("Left")
                assert field("HEADLESS-1", "title") == "A"
                key("f", translate=False)  # physical Super+F, not fullscreen
                maximized = bounds("A")
                assert maximized[2] - maximized[0] > width + 100, "Super+F did not maximize column"
                assert field("HEADLESS-1", "fullscreen") == "0", "maximize entered fullscreen"
                key("f", translate=False)
                restored = bounds("A")
                assert restored[2] - restored[0] == width, "Super+F did not restore column width"
            revealed = bounds("A")
            assert revealed[2] - revealed[0] == width, "opening windows resized A"
            key("l", "ctrl")  # viewport only
            assert field("HEADLESS-1", "title") == "A"
            panned = bounds("A")
            assert panned[0] < revealed[0] or panned[2] - panned[0] < width
            assert bounds("A", "HEADLESS-2") is None, "off-screen column leaked onto output 2"
            for _ in range(6):
                key("l", "ctrl")
            assert bounds("A") is None
            key("space", "shift")  # restore a completely clipped body/borders
            assert bounds("A"), "floating a clipped window left it invisible"
            key("space", "shift")
            assert bounds("A"), "returning to tiling did not reveal A"

            key("i")  # insert into focused column
            open_window("D")
            top, bottom = bounds("A"), bounds("D")
            assert top and bottom and top[3] < bottom[1], "not vertically stacked"
            if keymap == "niri":
                key("f", translate=False)
                max_top, max_bottom = bounds("A"), bounds("D")
                assert max_top[2] - max_top[0] > top[2] - top[0], "stacked column did not maximize"
                assert max_bottom[2] - max_bottom[0] == max_top[2] - max_top[0]
                assert max_top[3] < max_bottom[1], "maximize destroyed vertical stacking"
                assert field("HEADLESS-1", "fullscreen") == "0"
                key("f", translate=False)
                assert bounds("D")[2] - bounds("D")[0] == bottom[2] - bottom[0]
            key("k")
            assert field("HEADLESS-1", "title") == "A"
            key("j")
            assert field("HEADLESS-1", "title") == "D"
            key("k", "shift")  # move row above A
            assert bounds("D")[3] < bounds("A")[1]
            key("Return", "shift")  # split D into new column
            assert bounds("D")[3] - bounds("D")[1] > 600
            key("Return", "ctrl", "shift")  # merge left
            assert bounds("D")[3] - bounds("D")[1] < 400
            key("l", "ctrl", "shift")  # move D into adjacent column
            assert bounds("D") and bounds("B")
            key("h", "shift")  # move the whole B/D column left
            key("bracketright")
            key("r")
            key("space", "shift")
            assert field("HEADLESS-1", "floating") == "1"
            key("space", "shift")
            assert field("HEADLESS-1", "floating") == "0"
            key("f")
            assert field("HEADLESS-1", "fullscreen") == "1"
            key("f")
            assert field("HEADLESS-1", "fullscreen") == "0"
            assert bounds("D"), "fullscreen exit did not reveal D"
            for layout in ("t", "m", "v", "s"):
                key(layout)
                assert bounds("D"), "layout transition left D clipped: " + layout

            key("2", "shift")  # tag focused window
            key("2")
            assert field("HEADLESS-1", "title") == "D"
            key("period", "shift")  # move to second output
            assert field("HEADLESS-2", "title") == "D"
            assert bounds("D", "HEADLESS-2")
            # Sending a window does not focus its destination output in dwl.
            if keymap == "niri":
                key("Right", "shift", translate=False)
            else:
                key("period")
            key("d")
            until(lambda: launcher_visible("HEADLESS-2"), "launcher on selected output")
            command("wlr-randr", "--output", "HEADLESS-2", "--custom-mode", "1024x768")
            time.sleep(0.2)
            assert launcher_visible("HEADLESS-2"), "launcher lost position after output resize"
            command("wtype", "-k", "Escape")
            assert bounds("D", "HEADLESS-2")
            key("d")
            until(lambda: launcher_visible("HEADLESS-2"), "launcher before output disable")
            command("wlr-randr", "--output", "HEADLESS-2", "--off")
            key("1")  # evacuation preserves dwl tags; output 2 had tag 1
            until(lambda: field("HEADLESS-1", "title") == "D", "output evacuation")
            assert bounds("D"), "evacuated window inaccessible"
            if keymap == "niri":
                command("wtype", "-M", "alt", "-k", "w", "-m", "alt")
                time.sleep(0.12)
                assert clients[-1].poll() is None, "Alt unexpectedly acts as the primary modifier"
            key("q")
            until(lambda: clients[-1].poll() is not None, "close focused window")
            key("1")
            assert field("HEADLESS-1", "title") in ("A", "B", "C")
            key("d")
            until(launcher_visible, "launcher before disabling all outputs")
            command("wlr-randr", "--output", "HEADLESS-1", "--off")
            command("wlr-randr", "--output", "HEADLESS-1", "--on")
            recovered = until(lambda: field("HEADLESS-1", "title") in ("A", "B", "C"),
                              "recovery after all outputs disabled")
            assert recovered and bounds(field("HEADLESS-1", "title"))
            if rpc_server:
                rpc_server.cleared.clear()
            key("e", "shift")
            assert compositor.wait(timeout=10) == 0, error_file.read_text()
            if rpc_server:
                assert rpc_server.cleared.wait(3), "compositor exit did not clear Discord presence"
                assert not rpc_server.errors, rpc_server.errors
                assert all(activity["assets"] == {
                    "large_image": "https://codeberg.org/avatars/dc21c9ec8f16c95100d96692df5f00c1f19e5a1ab2248bacacf122ba23635f28",
                    "large_text": "dwl-scroll",
                } for activity in rpc_server.activities if activity), "Discord presence lost its dwl logo"
            # Restart with the same isolated runtime directory.
            compositor = subprocess.Popen(
                compositor_args,
                env=env, stdout=status, stderr=errors,
            )
            time.sleep(0.3)
            assert compositor.poll() is None, "restart failed"
            compositor.terminate()
            assert compositor.wait(timeout=10) == 0
            print(f"PASS: real headless dwl ({keymap} keys): map, columns, focus, pan, clipping, "
                  "stacking, movement, merge, widths, tags, floating, fullscreen, "
                  "output resize/disable, close, restart")
            if bar:
                print("PASS: dwlb stdin status pipe, command socket, show/hide, exclusive zone, dwl palette")
            if tray:
                print("PASS: tray/clock overlays the output edge beside dwlb, without a second row")
            print("PASS: built-in launcher rendering, repeat guard, input isolation, search, navigation, "
                  "Unicode launch, cancellation, output resize/disable and session-lock safety")
            print("PASS: menu application icons: themed PNG, absolute SVG and missing-icon fallback pixels")
            if rpc_server:
                print("PASS: built-in Discord RPC: local handshake, dwl logo, focused app, lock clearing, unlock reconnect and shutdown clearing")
        except Exception:
            print(status_file.read_text()[-4000:], file=sys.stderr)
            print(error_file.read_text(), file=sys.stderr)
            for log in root.glob("foot-*.log"):
                print(log.name + ": " + log.read_text(), file=sys.stderr)
            raise
        finally:
            if locker_process is not None and locker_process.poll() is None:
                locker_process.terminate()
                locker_process.wait(timeout=10)
            for client in clients:
                if client.poll() is None:
                    client.terminate()
                client.wait(timeout=10)
            if compositor.poll() is None:
                compositor.terminate()
                compositor.wait(timeout=10)
            if tray_process is not None:
                if tray_process.poll() is None:
                    tray_process.terminate()
                tray_process.wait(timeout=10)
            if rpc_server:
                rpc_server.close()
            status.close()
            errors.close()


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "default",
        sys.argv[3] if len(sys.argv) > 3 else None,
        sys.argv[4] if len(sys.argv) > 4 else None)
