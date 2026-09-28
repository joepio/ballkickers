"""Exercise the real GameNight WebSocket connection without a running daemon.

Uses only Python's standard library. This is a local fake protocol peer, not
a replacement for hardware/controller certification.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GODOT = sys.argv[1] if len(sys.argv) > 1 else "C:/dev/tools/godot/Godot_v4.5.2-stable_win64_console.exe"
TEAMS = int(sys.argv[2]) if len(sys.argv) > 2 else 1
assert 1 <= TEAMS <= 3
GAME_ID = "ballkickers" if TEAMS == 1 else f"ballkickers-{TEAMS}v{TEAMS}"

def exact(sock, count):
    result = b""
    while len(result) < count:
        chunk = sock.recv(count-len(result))
        if not chunk:
            raise EOFError("WebSocket disconnected")
        result += chunk
    return result

def receive(sock):
    first, second = exact(sock, 2)
    count = second & 127
    if count == 126: count = struct.unpack("!H", exact(sock,2))[0]
    if count == 127: count = struct.unpack("!Q", exact(sock,8))[0]
    mask = exact(sock,4) if second & 128 else b""
    payload = exact(sock,count)
    if mask: payload = bytes(b ^ mask[i%4] for i,b in enumerate(payload))
    assert first & 15 == 1, f"Expected text frame, got {first}"
    return json.loads(payload)

def send(sock, message):
    data = json.dumps(message).encode()
    header = bytes([129,len(data)]) if len(data) < 126 else bytes([129,126])+struct.pack("!H",len(data))
    sock.sendall(header+data)

def expect(sock, kind):
    for _ in range(15):
        msg = receive(sock)
        if msg["type"] == kind: return msg
    raise AssertionError(f"Did not receive {kind}")

with socket.socket() as server:
    server.bind(("127.0.0.1",0))
    server.listen(1)
    server.settimeout(12)
    env = dict(os.environ, GAMENIGHT="1", GAMENIGHT_ADDR=f"127.0.0.1:{server.getsockname()[1]}", GAMENIGHT_GAME_ID=GAME_ID, GAMENIGHT_TOKEN="local-test-token")
    log_path = ROOT / "captures" / "wire.log"
    log = log_path.open("w", encoding="utf-8")
    project_args = [] if Path(GODOT).stem == "Ballkickers" else ["--path",str(ROOT)]
    process = subprocess.Popen([GODOT.replace("_console.exe", ".exe"),"--headless","--audio-driver","Dummy",*project_args,"--","--mute",f"--teams={TEAMS}"], env=env, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, text=True)
    try:
        with server.accept()[0] as peer:
            peer.settimeout(8)
            request = b""
            while b"\r\n\r\n" not in request: request += peer.recv(4096)
            headers = dict(line.split(":",1) for line in request.decode().split("\r\n")[1:] if ":" in line)
            key = next(value.strip() for name,value in headers.items() if name.lower()=="sec-websocket-key")
            accept = base64.b64encode(hashlib.sha1((key+"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
            peer.sendall(f"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n".encode())
            hello = expect(peer,"hello")
            assert hello["game"]==GAME_ID and hello["token"]=="local-test-token"
            send(peer,{"type":"welcome","protocol_version":1,"party":{}})
            expect(peer,"declare_settings")
            players = [{"id":"p1","name":"Marsh"}]
            seats = [{"index":0,"controller":"test-device-9","occupant":{"kind":"local","player_id":"p1"}}]
            for index in range(1, TEAMS * 2):
                players.append({"id":f"p{index+1}","name":f"Guest {index+1}"})
                seats.append({"index":index,"controller":f"other-device-{index}","occupant":{"kind":"local","player_id":f"p{index+1}"}})
            send(peer,{"type":"prepare","session":"wire-a","players":players,"seats":seats})
            assert expect(peer,"participation")["instant_join"] is False
            assert expect(peer,"ready")["session"]=="wire-a"
            send(peer,{"type":"start","session":"wire-a"})
            send(peer,{"type":"controller_frame","controllers":[{"controller":"test-device-9","axes":[0,0,0,0,0,0],"buttons":64}]})
            expect(peer,"request_overlay")
            send(peer,{"type":"pause","session":"wire-a"})
            send(peer,{"type":"resume","session":"wire-a"})
            send(peer,{"type":"dispose","session":"wire-a"})
            send(peer,{"type":"prepare","session":"wire-b","players":players,"seats":seats})
            assert expect(peer,"ready")["session"]=="wire-b"
            send(peer,{"type":"start","session":"wire-b"})
        process.wait(timeout=8)
        log.flush()
        output = log_path.read_text(encoding="utf-8")
        assert process.returncode==0, output
        assert "SCRIPT ERROR" not in output and "ERROR:" not in output, output
        print("PASS: authenticated WebSocket, settings, prepare/ready, start, Back overlay, pause/resume, dispose, reprepare, clean daemon-disconnect exit")
    except Exception:
        if process.poll() is None: process.kill()
        process.wait(timeout=4)
        log.flush()
        output = log_path.read_text(encoding="utf-8")
        print(output)
        raise
    finally:
        if process.poll() is None: process.kill(); process.wait()
        log.close()
