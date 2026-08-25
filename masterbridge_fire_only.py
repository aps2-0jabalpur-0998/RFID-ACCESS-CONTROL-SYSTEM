import asyncio
import websockets
import serial
import json
import csv
import os
from datetime import datetime

# ============================================================
#                 FIRE-ONLY MASTER BRIDGE
# ============================================================
# Fire sensor:
#   Arduino -> COM3
#
# Intruder:
#   NOT READ HERE.
#   combined_test1.py sends its live event packets to this
#   WebSocket server, and we forward those packets to the
#   intruder dashboard (IOT4.html).
# ============================================================

FIRE_PORT = "COM3"
BAUD = 9600
WS_PORT = 8767

CSV_FILE = r"C:\Users\Pcc\Pictures\IOTPROJECT-20260703T021207Z-3-001\IOTPROJECT\users.csv"

clients = set()
fire_history = []
last_modified = 0


async def broadcast(data):
    if not clients:
        return

    message = json.dumps(data, ensure_ascii=False)
    dead = set()

    for client in list(clients):
        try:
            await client.send(message)
        except Exception:
            dead.add(client)

    clients.difference_update(dead)


def read_csv():
    users = []

    if not os.path.exists(CSV_FILE):
        print("[CSV] File not found:", CSV_FILE)
        return users

    try:
        with open(CSV_FILE, "r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)

            for row in reader:
                try:
                    points = int(row.get("points", 0) or 0)
                except Exception:
                    points = 0

                users.append({
                    "uid": row.get("uid", ""),
                    "name": row.get("name", ""),
                    "email": row.get("email", ""),
                    "phone": row.get("phone", ""),
                    "points": points,
                    "last_scan": row.get("last_scan", ""),
                    "reward_claimed": row.get("reward_claimed", "NO"),
                })

    except Exception as exc:
        print("[CSV ERROR]", exc)

    return users


async def ws_handler(websocket):
    clients.add(websocket)
    print("[+] Dashboard / upstream client connected:", len(clients))

    try:
        await websocket.send(
            json.dumps({
                "type": "users",
                "data": read_csv(),
            })
        )

        async for raw_message in websocket:
            try:
                data = json.loads(raw_message)
            except json.JSONDecodeError:
                continue

            # combined_test1.py -> Fire-only master bridge -> IOT4.html
            if data.get("source") == "combined_test1":
                await broadcast(data)
                print(
                    "[INTRUDER FORWARDED]",
                    data.get("type", "unknown"),
                )
                continue

            # Old combined_test source is intentionally ignored.
            if data.get("source") == "combined_test":
                continue

    except websockets.ConnectionClosed:
        pass
    except Exception as exc:
        print("[WS HANDLER ERROR]", exc)
    finally:
        clients.discard(websocket)
        print("[-] Dashboard / upstream client disconnected:", len(clients))


async def watch_csv():
    global last_modified

    while True:
        try:
            if os.path.exists(CSV_FILE):
                modified = os.path.getmtime(CSV_FILE)

                if modified != last_modified:
                    last_modified = modified
                    await broadcast({
                        "type": "users",
                        "data": read_csv(),
                    })
                    print("[CSV] Updated and broadcast")

        except Exception as exc:
            print("[CSV WATCH ERROR]", exc)

        await asyncio.sleep(1)


async def read_fire():
    ser = None

    sensor_map = {
        "IR1 FIRE DETECTED": ("A", "IR Sensor 1"),
        "FLAME1 FIRE DETECTED": ("B", "Flame Sensor 1"),
        "FLAME2 FIRE DETECTED": ("C", "Flame Sensor 2"),
    }

    while True:
        try:
            if ser is None or not ser.is_open:
                ser = serial.Serial(FIRE_PORT, BAUD, timeout=0.1)
                print(f"[FIRE] Connected on {FIRE_PORT}")

            if ser.in_waiting:
                line = (
                    ser.readline()
                    .decode(errors="ignore")
                    .strip()
                )

                if not line:
                    continue

                print("[FIRE RAW]", line)

                if line in ("NO FIRE", "SAFE"):
                    await broadcast({
                        "project": "fire",
                        "type": "safe",
                    })
                    continue

                if line in sensor_map:
                    zone, sensor = sensor_map[line]
                    now = datetime.now()

                    packet = {
                        "project": "fire",
                        "type": "alert",
                        "zone": zone,
                        "sensor": sensor,
                        "message": f"Fire detected by {sensor}",
                        "time": now.strftime("%H:%M:%S"),
                        "date": now.strftime("%d %b %Y"),
                    }

                    fire_history.insert(0, packet)
                    if len(fire_history) > 100:
                        fire_history.pop()

                    print("[FIRE ALERT]", packet)
                    await broadcast(packet)

        except serial.SerialException as exc:
            print("[FIRE SERIAL ERROR]", exc)
            try:
                if ser:
                    ser.close()
            except Exception:
                pass
            ser = None
            await asyncio.sleep(1)

        except Exception as exc:
            print("[FIRE ERROR]", exc)
            ser = None
            await asyncio.sleep(1)

        await asyncio.sleep(0.01)


async def main():
    print("=" * 60)
    print("      GUARDIANEYE FIRE-ONLY MASTER BRIDGE")
    print("=" * 60)
    print(f"[*] WebSocket: ws://localhost:{WS_PORT}")
    print(f"[*] Fire Arduino: {FIRE_PORT}")
    print("[*] Intruder Arduino reader: DISABLED")
    print("[*] Intruder source: combined_test1.py")

    server = await websockets.serve(
        ws_handler,
        "0.0.0.0",
        WS_PORT,
        ping_interval=20,
        ping_timeout=20,
    )

    print("[+] Server ready")

    await asyncio.gather(
        server.serve_forever(),
        read_fire(),
        watch_csv(),
    )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[+] Fire-only bridge stopped.")
