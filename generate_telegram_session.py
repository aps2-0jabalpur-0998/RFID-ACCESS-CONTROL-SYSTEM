
from telethon.sync import TelegramClient
from telethon.sessions import StringSession

api_id = int(
    input("Telegram API ID: ").strip()
)

api_hash = input(
    "Telegram API Hash: "
).strip()

with TelegramClient(
    StringSession(),
    api_id,
    api_hash
) as client:

    print()
    print("SIGNED IN")
    print()
    print(
        "Copy this entire value into "
        "GitHub Actions secret TELEGRAM_SESSION:"
    )
    print()
    print(
        client.session.save()
    )
