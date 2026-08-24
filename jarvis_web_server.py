
import os
import time
import asyncio
import threading
from datetime import datetime
from queue import Queue, Empty
from flask import Flask, jsonify, send_from_directory
from dotenv import load_dotenv
from telethon import TelegramClient, events


# ============================================================
# JARVIS WEB BRIDGE
# ============================================================
#
# Web-only JARVIS:
#   Telegram group
#        ↓
#   Telethon user account
#        ↓
#   /api/alerts
#        ↓
#   Browser dashboard
#        ↓
#   Web Speech API + animated face
#
# NO Arduino
# NO physical servo
# NO ElevenLabs secret in the browser
#
# IMPORTANT:
# Keep .env OUT of GitHub.
# Put the secrets only on the machine/server running this file.
# ============================================================


BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)

ENV_FILE = os.getenv(
    "JARVIS_ENV_FILE",
    os.path.join(BASE_DIR, ".env")
)

load_dotenv(
    ENV_FILE
)


# ============================================================
# TELEGRAM CONFIG
# ============================================================

JARVIS_API_ID = int(
    os.getenv(
        "JARVIS_API_ID",
        "0"
    )
)

JARVIS_API_HASH = os.getenv(
    "JARVIS_API_HASH",
    ""
).strip()

GROUP_CHAT_ID = int(
    os.getenv(
        "JARVIS_CHAT_ID",
        "0"
    )
)


# ============================================================
# VALIDATION
# ============================================================

if not JARVIS_API_ID:
    raise SystemExit(
        "ERROR: JARVIS_API_ID missing from .env"
    )

if not JARVIS_API_HASH:
    raise SystemExit(
        "ERROR: JARVIS_API_HASH missing from .env"
    )

if not GROUP_CHAT_ID:
    raise SystemExit(
        "ERROR: JARVIS_CHAT_ID missing from .env"
    )


# ============================================================
# FLASK
# ============================================================

app = Flask(
    __name__,
    static_folder=".",
    static_url_path=""
)


# ============================================================
# ALERT STORE
# ============================================================

alert_lock = threading.Lock()

latest_alert = {
    "id": 0,
    "received_at": "",
    "raw_message": "",
    "speech": "",
    "type": "NONE",
}

next_alert_id = 0


def classify_alert(text: str) -> str:
    upper = text.upper()

    if (
        "DANGEROUS ANIMAL" in upper
        or "DANGEROUS" in upper
    ):
        return "DANGEROUS"

    if (
        "UNKNOWN VEHICLE" in upper
        or "UNAUTHORIZED VEHICLE" in upper
    ):
        return "UNKNOWN_VEHICLE"

    if (
        "KNOWN VEHICLE" in upper
        or "VEHICLE QR DETECTED" in upper
    ):
        return "KNOWN_VEHICLE"

    if (
        "INTRUDER DETECTED" in upper
        or "UNKNOWN PERSON" in upper
    ):
        return "INTRUDER"

    if (
        "KNOWN PERSON" in upper
        or "KNOWN PERSON DETECTED" in upper
    ):
        return "KNOWN_PERSON"

    return "ALERT"


def extract_field(
    text: str,
    field: str,
    stop_fields=None
) -> str:
    upper_text = text.upper()
    field_upper = field.upper()

    if field_upper not in upper_text:
        return ""

    start = (
        upper_text.find(field_upper)
        +
        len(field)
    )

    value = text[start:]

    if stop_fields:
        upper_value = value.upper()
        positions = []

        for stop in stop_fields:
            pos = upper_value.find(
                stop.upper()
            )

            if pos != -1:
                positions.append(pos)

        if positions:
            value = value[
                :min(positions)
            ]

    return value.strip(
        " :-\n\t"
    )


def build_speech_message(
    text: str
) -> str:
    """
    Same basic alert-to-speech idea as the supplied JARVIS
    listener, but optimized for browser speech.
    """

    clean = " ".join(
        text.split()
    )

    upper = clean.upper()

    # --------------------------------------------------------
    # KNOWN PERSON
    # --------------------------------------------------------

    if (
        "KNOWN PERSON" in upper
        or
        "KNOWN PERSON DETECTED" in upper
        or
        "KNOWN: " in upper
    ):

        name = extract_field(
            clean,
            "NAME:",
            [
                "DATE:",
                "TIME:",
                "GPS:",
                "VEHICLE:"
            ]
        )

        if not name:
            name = extract_field(
                clean,
                "KNOWN PERSON:",
                [
                    "DATE:",
                    "TIME:",
                    "GPS:",
                    "VEHICLE:"
                ]
            )

        if not name:
            name = "Known person"

        date = extract_field(
            clean,
            "DATE:",
            [
                "TIME:",
                "GPS:",
                "VEHICLE:"
            ]
        )

        tm = extract_field(
            clean,
            "TIME:",
            [
                "GPS:",
                "VEHICLE:"
            ]
        )

        result = (
            "Security check. "
            "Known person detected. "
            f"Name {name}. "
        )

        if date:
            result += (
                f"Date {date}. "
            )

        if tm:
            result += (
                f"Time {tm}. "
            )

        result += "System is safe."

        return result

    # --------------------------------------------------------
    # DANGEROUS ANIMAL
    # --------------------------------------------------------

    if (
        "DANGEROUS ANIMAL" in upper
        or
        "⚠️ DANGEROUS" in upper
    ):

        date = extract_field(
            clean,
            "DATE:",
            [
                "TIME:",
                "GPS:"
            ]
        )

        tm = extract_field(
            clean,
            "TIME:",
            [
                "GPS:"
            ]
        )

        result = (
            "Alert. Dangerous animal detected. "
        )

        if date:
            result += (
                f"Date {date}. "
            )

        if tm:
            result += (
                f"Time {tm}. "
            )

        return result

    # --------------------------------------------------------
    # INTRUDER
    # --------------------------------------------------------

    if (
        "INTRUDER DETECTED" in upper
        or
        "INTRUDER EVIDENCE" in upper
        or
        "UNKNOWN PERSON DETECTED" in upper
        or
        "UNKNOWN PERSON" in upper
    ):

        date = extract_field(
            clean,
            "DATE:",
            [
                "TIME:",
                "GPS:",
                "VEHICLE:"
            ]
        )

        tm = extract_field(
            clean,
            "TIME:",
            [
                "GPS:",
                "VEHICLE:"
            ]
        )

        result = (
            "Alert. Intruder detected. "
        )

        if date:
            result += (
                f"Date {date}. "
            )

        if tm:
            result += (
                f"Time {tm}. "
            )

        result += (
            "Please check the security alert."
        )

        return result

    # --------------------------------------------------------
    # UNKNOWN VEHICLE
    # --------------------------------------------------------

    if (
        "UNKNOWN VEHICLE" in upper
        or
        "UNAUTHORIZED VEHICLE" in upper
        or
        "VEHICLE ID:" in upper
    ):

        vehicle_id = extract_field(
            clean,
            "VEHICLE ID:",
            [
                "VEHICLE NAME:",
                "VEHICLE:",
                "STATUS:",
                "DATE:",
                "TIME:"
            ]
        )

        vehicle_name = extract_field(
            clean,
            "VEHICLE NAME:",
            [
                "STATUS:",
                "DATE:",
                "TIME:"
            ]
        )

        vehicle_status = extract_field(
            clean,
            "STATUS:",
            [
                "DATE:",
                "TIME:"
            ]
        )

        date = extract_field(
            clean,
            "DATE:",
            [
                "TIME:",
                "GPS:"
            ]
        )

        tm = extract_field(
            clean,
            "TIME:",
            [
                "GPS:"
            ]
        )

        if "UNKNOWN VEHICLE" in upper:
            result = (
                "Alert. Unknown vehicle detected. "
            )
        else:
            result = (
                "Vehicle alert received. "
            )

        if vehicle_id:
            result += (
                f"Vehicle ID {vehicle_id}. "
            )

        if vehicle_name:
            result += (
                f"{vehicle_name}. "
            )

        if vehicle_status:
            result += (
                f"Status {vehicle_status}. "
            )

        if date:
            result += (
                f"Date {date}. "
            )

        if tm:
            result += (
                f"Time {tm}."
            )

        return result

    # --------------------------------------------------------
    # DEFAULT
    # --------------------------------------------------------

    return clean


def publish_alert(
    text: str,
    speech: str
) -> None:

    global next_alert_id
    global latest_alert

    next_alert_id += 1

    payload = {
        "id": next_alert_id,
        "received_at": datetime.now().isoformat(
            timespec="seconds"
        ),
        "raw_message": text,
        "speech": speech,
        "type": classify_alert(
            text
        ),
    }

    with alert_lock:
        latest_alert = payload

    print()
    print("=" * 65)
    print("WEB JARVIS ALERT")
    print("=" * 65)
    print("TYPE:", payload["type"])
    print("MESSAGE:", text)
    print("SPEECH:", speech)


# ============================================================
# API
# ============================================================

@app.get("/")
def index():
    return send_from_directory(
        BASE_DIR,
        "jarvis_dashboard.html"
    )


@app.get("/api/health")
def health():
    return jsonify(
        {
            "ok": True,
            "telegram_group": GROUP_CHAT_ID,
        }
    )


@app.get("/api/alert")
def api_alert():
    with alert_lock:
        payload = dict(
            latest_alert
        )

    return jsonify(payload)


# ============================================================
# TELEGRAM CLIENT
# ============================================================

SESSION_FILE = os.path.join(
    BASE_DIR,
    "jarvis_telegram_web"
)

telegram_client = TelegramClient(
    SESSION_FILE,
    JARVIS_API_ID,
    JARVIS_API_HASH
)


@telegram_client.on(
    events.NewMessage(
        chats=GROUP_CHAT_ID
    )
)
async def telegram_alert(
    event
):
    try:
        text = (
            event.raw_text
            or ""
        ).strip()

        if not text:
            return

        speech = (
            build_speech_message(
                text
            )
        )

        publish_alert(
            text,
            speech
        )

    except Exception as e:
        print(
            "Telegram handler error:",
            e
        )


async def telegram_main():
    print(
        "Connecting to Telegram..."
    )

    await telegram_client.start()

    me = await telegram_client.get_me()

    print(
        "Telegram connected:",
        me.first_name,
        me.id
    )

    entity = await telegram_client.get_entity(
        GROUP_CHAT_ID
    )

    print(
        "Group:",
        getattr(
            entity,
            "title",
            "Unknown"
        )
    )

    print(
        "🟢 Telegram listener online"
    )

    await telegram_client.run_until_disconnected()


def run_telegram_thread():

    asyncio.run(
        telegram_main()
    )


# ============================================================
# SERVER
# ============================================================

if __name__ == "__main__":

    telegram_thread = threading.Thread(
        target=run_telegram_thread,
        daemon=True
    )

    telegram_thread.start()

    print()
    print(
        "=================================================="
    )
    print(
        "JARVIS WEB DASHBOARD ONLINE"
    )
    print(
        "Open: http://127.0.0.1:5000"
    )
    print(
        "=================================================="
    )
    print()

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
        threaded=True
    )
