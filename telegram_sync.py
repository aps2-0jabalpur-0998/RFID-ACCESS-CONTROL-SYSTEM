
import json
import os
from pathlib import Path

from telethon.sync import TelegramClient
from telethon.sessions import StringSession


ROOT = Path.cwd()

api_id = int(
    os.environ["TELEGRAM_API_ID"]
)

api_hash = os.environ[
    "TELEGRAM_API_HASH"
].strip()

session_string = os.environ[
    "TELEGRAM_SESSION"
].strip()

target_chat_id = int(
    os.environ["TELEGRAM_CHAT_ID"]
)

offset_file = (
    ROOT /
    "telegram_offset.txt"
)

alerts_file = (
    ROOT /
    "alerts.json"
)


def load_offset():
    if not offset_file.exists():
        return 0

    try:
        return int(
            offset_file.read_text(
                encoding="utf-8"
            ).strip()
        )
    except Exception:
        return 0


def build_speech(text, alert_type):
    clean = " ".join(
        text.split()
    )

    if alert_type == "INTRUDER":
        return (
            "Alert. Intruder detected. "
            + clean
        )

    if alert_type == "DANGEROUS":
        return (
            "Alert. Dangerous detected. "
            + clean
        )

    if alert_type == "UNKNOWN_VEHICLE":
        return (
            "Alert. Unknown vehicle detected. "
            + clean
        )

    return clean


def classify(text):
    upper = text.upper()

    if (
        "INTRUDER DETECTED" in upper
        or
        "INTRUDER EVIDENCE" in upper
        or
        "UNKNOWN PERSON" in upper
    ):
        return "INTRUDER"

    if "DANGEROUS ANIMAL" in upper:
        return "DANGEROUS"

    if (
        "UNKNOWN VEHICLE" in upper
        or
        "UNAUTHORIZED VEHICLE" in upper
    ):
        return "UNKNOWN_VEHICLE"

    return "ALERT"


def save_alert(message_id, text):

    alert_type = classify(
        text
    )

    payload = {
        "id":
            int(message_id),

        "received_at":
            "",

        "raw_message":
            text,

        "speech":
            build_speech(
                text,
                alert_type
            ),

        "type":
            alert_type
    }

    alerts_file.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2
        ),
        encoding="utf-8"
    )


offset = load_offset()

with TelegramClient(
    StringSession(
        session_string
    ),
    api_id,
    api_hash
) as client:

    messages = list(
        client.iter_messages(
            target_chat_id,
            min_id=max(
                0,
                offset
            ),
            limit=100,
            reverse=True
        )
    )

    newest_id = offset

    for message in messages:

        if not message.id:
            continue

        if message.id <= offset:
            continue

        text = (
            message.message
            or
            ""
        ).strip()

        if text:

            upper = text.upper()

            relevant = (
                "GUARDIANEYE" in upper
                or
                "INTRUDER" in upper
                or
                "DANGEROUS ANIMAL" in upper
                or
                "UNKNOWN VEHICLE" in upper
            )

            if relevant:

                save_alert(
                    message.id,
                    text
                )

        newest_id = max(
            newest_id,
            message.id
        )

    offset_file.write_text(
        str(newest_id),
        encoding="utf-8"
    )

print(
    "GuardianEye Telegram sync complete.",
    "OFFSET =",
    newest_id
)
