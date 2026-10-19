"""Exercise the real GameNight WebSocket connection without a running daemon.

Uses the GameNight SDK's fake host (addons/gamenight/fake_host.py, Python
standard library only). This is a local fake protocol peer, not a
replacement for hardware/controller certification.

    python tests/wire.py [path/to/godot-or-Ballkickers.exe] [teams 1-3]
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "addons" / "gamenight"))
from fake_host import FakeHost  # noqa: E402

GODOT = sys.argv[1] if len(sys.argv) > 1 else "C:/dev/tools/godot/Godot_v4.5.2-stable_win64_console.exe"
TEAMS = int(sys.argv[2]) if len(sys.argv) > 2 else 1
assert 1 <= TEAMS <= 3
# One catalog entry; the team size follows the party (TEAMS * 2 seats).
GAME_ID = "ballkickers"

engine = GODOT.replace("_console.exe", ".exe")
project_args = [] if Path(GODOT).stem == "Ballkickers" else ["--path", str(ROOT)]
command = [engine, "--headless", "--audio-driver", "Dummy", *project_args, "--", "--mute"]
host = FakeHost(engine, GAME_ID, command=command, cwd=ROOT, timeout=12)
try:
    # FakeHost already checked the hello's game id and launch token.
    host.welcome()
    host.expect("declare_settings")
    players = [{"id": "p1", "name": "Marsh"}]
    seats = [host.local_seat(0, "p1", controller="test-device-9")]
    for index in range(1, TEAMS * 2):
        players.append({"id": f"p{index+1}", "name": f"Guest {index+1}"})
        seats.append(host.local_seat(index, f"p{index+1}", controller=f"other-device-{index}"))
    host.prepare(seats, players, session="wire-a", wait_ready=False)
    assert host.expect("participation")["instant_join"] is False
    assert host.expect("ready")["session"] == "wire-a"
    host.start()
    host.frames({"controller": "test-device-9", "axes": [0, 0, 0, 0, 0, 0], "buttons": 64})
    host.expect("request_overlay")
    host.pause()
    host.resume()
    host.dispose()
    host.prepare(seats, players, session="wire-b", wait_ready=False)
    assert host.expect("ready")["session"] == "wire-b"
    host.start()
    host.disconnect()
    code = host.exit_code(8)
    output = host.output()
    assert code == 0, output
    assert "SCRIPT ERROR" not in output and "ERROR:" not in output, output
    print("PASS: authenticated WebSocket, settings, prepare/ready, start, Back overlay, pause/resume, dispose, reprepare, clean daemon-disconnect exit")
except Exception:
    print(host.output())
    raise
finally:
    host.close()
