# PRANA SETU / GUARDIANEYE — LATEST RUNBOOK

Updated: 01-09-2026
Purpose: Master setup/run sheet for Arduino, Fire, Intruder/JARVIS, Cloudflare, dashboards, ports, and demo testing.

OFFICIAL ESP8266 BOARDS MANAGER URL:

https://arduino.esp8266.com/stable/package_esp8266com_index.json

## STEP 1 — OPEN PREFERENCES

Arduino IDE:

File
-> Preferences

## STEP 2 — ADD BOARD MANAGER URL

Find:

Additional boards manager URLs

Paste:

https://arduino.esp8266.com/stable/package_esp8266com_index.json

Then press:

OK

## STEP 3 — OPEN BOARDS MANAGER

Go to:

Tools
-> Board
-> Boards Manager...

## STEP 4 — SEARCH

Search:

esp8266

## STEP 5 — INSTALL

Select:

esp8266 by ESP8266 Community

Then:

Install

Wait until Arduino IDE finishes downloading/installing the
ESP8266 board package.

STEP 6 — SELECT THE BOARD

Go to:

Tools
-> Board
-> esp8266

For the board shown in the shared screenshot:

Generic ESP8266 Module

If the physical board is actually:

NodeMCU
or
LOLIN D1 mini

select the exact matching board instead of Generic ESP8266 Module.

## STEP 7 — SELECT THE COM PORT

Go to:

Tools
-> Port

The shared screenshot showed:

COM4

BUT:
COM4 is not guaranteed to remain the same after reconnecting.
Always select the COM port currently assigned to the ESP8266.

## STEP 8 — VERIFY INSTALLATION

After installation, the Tools -> Board -> esp8266 list should
contain ESP8266 boards such as:

Generic ESP8266 Module
LOLIN(WEMOS) D1 & mini
NodeMCU 0.9 / NodeMCU 1.0
etc.

The exact visible list depends on the installed ESP8266 package.

ESP8266 QUICK CHECK:

Preferences
↓
Additional boards manager URLs
↓
paste official ESP8266 URL
↓
Boards Manager
↓
search "esp8266"
↓
install "esp8266 by ESP8266 Community"
↓
Tools -> Board -> esp8266
↓
choose correct board
↓
Tools -> Port
↓
choose current COM port



FINAL PORT ARCHITECTURE

FIRE

Fire MasterBridge:
localhost:8000
WebSocket:
ws://localhost:8000/ws

Fire Cloudflare:
MUST point to:
http://localhost:8000

Fire public URL:
stored in:
fire_url.txt

Dashboard connection:
fire_url.txt
-> https://...trycloudflare.com
-> wss://...trycloudflare.com/ws

INTRUDER / JARVIS

GuardianEye realtime server:
localhost:8001

Intruder/JARVIS WebSocket:
ws://localhost:8001/ws
(public version comes from intruder_url.txt)

Intruder Cloudflare:
MUST point to:
http://localhost:8001

Intruder public URL:
stored in:
intruder_url.txt

DO NOT MIX THESE:
FIRE      = 8000
INTRUDER  = 8001

Folder:

C:\Users\DELL\OneDrive\Pictures\IOTPROJECT

Command:

cd "C:\Users\DELL\OneDrive\Pictures\IOTPROJECT"
python masterbridge.py

Current Fire MasterBridge behaviour:

Telegram Fire listener

listens to Fire chat

WebSocket endpoint /ws

sends Fire JSON payloads

zone forced to X2

sensor can be IR1 / FLAME1 / FLAME2

WebSocket client monitor prints every 5 seconds

EXPECTED START:

Fire WebSocket server: http://localhost:8000/ws
Uvicorn running on http://0.0.0.0:8000
Telegram connected: ...
Listening Telegram chat: ...
FIRE TELEGRAM LISTENER ONLINE

EVERY 5 SEC:

🟢 FIRE WEBSOCKET CONNECTED | CLIENTS: 1

or:

🔴 FIRE WEBSOCKET NOT CONNECTED | CLIENTS: 0

CRITICAL TEST:

When IOT2 is open, the Fire terminal MUST change from:

CLIENTS: 0

to:

CLIENTS: 1

Command:

cd "C:\Users\DELL\OneDrive\Pictures\IOTPROJECT"
python start_fire_cloudflare.py

FIRE CLOUDFLARE MUST SHOW:

Settings: ... url:http://localhost:8000

and then:

FIRE CLOUDFLARE URL DETECTED
https://<current>.trycloudflare.com
Local fire_url.txt updated
GitHub fire_url.txt updated

NEVER use localhost:8001 for Fire Cloudflare.

Current file:

guardianeye_realtime_server.py

Command:

cd "C:\Users\DELL\OneDrive\Pictures\IOTPROJECT"
python guardianeye_realtime_server.py

CURRENT CONFIG:

JARVIS_WEB_PORT=8001

EXPECTED:

WEB PORT: 8001
Uvicorn running on http://0.0.0.0:8001
X3: READY
X4: READY
X3 + X4 TELEGRAM LISTENER READY

Command:

cd "C:\Users\DELL\OneDrive\Pictures\IOTPROJECT"
python start_intruder_cloudflare.py

IMPORTANT:

The Python file MUST expose:

http://localhost:8001

The correct section is effectively:

"--url",
"http://localhost:8001",

NOT:

"http://localhost:8000"

EXPECTED CLOUDFLARE LOG:

Settings: ... url:http://localhost:8001

then:

INTRUDER URL DETECTED
https://<current>.trycloudflare.com
intruder_url.txt updated

CHECK FIRE:

netstat -ano | findstr :8000

EXPECTED:
LISTENING

CHECK INTRUDER/JARVIS:

netstat -ano | findstr :8001

EXPECTED:
LISTENING

If 8000 is empty:
Fire MasterBridge is not running.

If 8001 is empty:
guardianeye_realtime_server.py is not running.

FIRE DASHBOARD:

IOT2.html

Latest cleaned/syntax-fixed local version made in chat:
IOT2_Fire_X2_FINAL_SYNTAX_FIXED.html

Latest cleaned version also created:
IOT2_Fire_X2_indented_clean.html

MAIN COMMAND CENTER:

index.html

Latest local final version made in chat:
PranaSetu_Index_FINAL.html

VERY IMPORTANT:

After replacing the GitHub file:

Ctrl + F5

to bypass cached JavaScript.

Hardware / Fire system
|
v
Telegram Fire message
|
v
Fire MasterBridge :8000
|
v
WebSocket /ws
|
v
Fire Cloudflare tunnel
|
v
fire_url.txt
|
v
IOT2.html / index.html

EXPECTED FIRE PAYLOAD:

{
"project": "fire",
"type": "alert",
"zone": "X2",
"sensor": "IR1",
"message": "...",
"raw_message": "...",
"time": "...",
"date": "..."
}

SUPPORTED SENSOR NAMES FROM THE FIRE BRIDGE:

IR1
FLAME1
FLAME2

EXPECTED DASHBOARD TEXT:

FIRE DETECTED
ZONE X2
SENSOR: IR1

or FLAME1 / FLAME2

Current Fire bridge recognizes these patterns:

IR1 FIRE DETECTED
FLAME1 FIRE DETECTED
FLAME2 FIRE DETECTED

IR1 FIRE CONTINUES
FLAME1 FIRE CONTINUES
FLAME2 FIRE CONTINUES

SAFE

Message types:

FIRE DETECTED -> alert
FIRE CONTINUES -> continue
SAFE -> safe

Browser DevTools -> Console

NORMAL CONNECTION:

FIRE URL LOADED:
wss://<current>.trycloudflare.com/ws

Fire Cloudflare connected:
wss://<current>.trycloudflare.com/ws

The initial bridge packet is:

type: "system"

This packet is only a handshake.
It is NOT a fire alert.

WHEN REAL FIRE ARRIVES:

FIRE DATA:
{
project: "fire",
type: "alert",
zone: "X2",
sensor: "IR1",
...
}

DO NOT WORRY ABOUT THESE UNRELATED ERRORS:

Chrome extension coupon errors

favicon 404

Browser extension errors

Those are not the Fire WebSocket payload.

Keep Fire MasterBridge running.

Keep Fire Cloudflare running.

Open IOT2.html.

Press Ctrl + F5.

Check browser Console.

Check Fire MasterBridge.

Expected transition:

🔴 CLIENTS: 0
|
v
browser connects
|
v
🟢 CLIENTS: 1

If still 0:
check that IOT2's fire_url.txt path is accessible
and that it is not using an old cached HTML file.

Current Intruder/JARVIS:

JARVIS_WEB_PORT=8001

Fire is NOT controlled by JARVIS_WEB_PORT.
Fire MasterBridge uses:

port = 8000

Therefore:

FIRE              -> 8000
JARVIS/INTRUDER  -> 8001

LOCAL:

C:\Users\DELL\OneDrive\Pictures\IOTPROJECT\fire_url.txt
C:\Users\DELL\OneDrive\Pictures\IOTPROJECT\intruder_url.txt

GITHUB:

RFID-ACCESS-CONTROL-SYSTEM/fire_url.txt
RFID-ACCESS-CONTROL-SYSTEM/intruder_url.txt

Fire Cloudflare script updates:
fire_url.txt

Intruder Cloudflare script updates:
intruder_url.txt

BOARD MANAGER URL (CONFIRMED):

https://arduino.esp8266.com/stable/package_esp8266com_index.json

ARDUINO IDE STEPS:

File
-> Preferences
-> Additional Boards Manager URLs
-> paste the URL above

Then:

Tools
-> Board
-> Boards Manager
-> search: esp8266
-> install:
esp8266 by ESP8266 Community

BOARD SELECTION SEEN IN SCREENSHOT:

Generic ESP8266 Module

PORT SEEN IN SCREENSHOT:

COM4

CHECK THE PORT BEFORE UPLOAD:

Tools -> Port -> current ESP port

NOTE:

If the physical board is actually NodeMCU / LOLIN D1 mini,
selecting the exact board is preferable to Generic ESP8266 Module.



CONFIRMED FROM SHARED ARDUINO CODE / CHAT HISTORY:

BOARD PACKAGE:

ESP8266 by ESP8266 Community

STANDARD / BOARD-INCLUDED:

Wire
Servo

EXPLICITLY SEEN IN AN OLDER SHARED OLED/SMART-DUSTBIN SKETCH:

Adafruit GFX Library
Adafruit SSD1306

FIRE HARDWARE CODE SEEN IN CHAT:

#include <Servo.h>

Therefore Servo is required for that Fire sketch.

IMPORTANT:

I do NOT have a reliable record of every library ever installed
on the PC. The list above contains libraries/packages explicitly
visible in the shared code/history, not a claim about the complete
current Arduino installation.

OTHER LIBRARIES FROM OLDER PROJECTS SHOULD ONLY BE INSTALLED
WHEN THE CURRENT SKETCH ACTUALLY INCLUDES THEM.

Connect ESP8266 by USB.

Check Tools -> Port.

Select the correct ESP8266 board.

Select correct COM port.

Verify sketch.

Upload.

Open Serial Monitor if the sketch uses Serial.

Confirm baud rate from the sketch.

Launcher file:

<project>/ ... /dual camera launcher
(the shared code uses:)

intruder_system/combined_test1.py
intruder_system2/combined_CAMERA_test.py

The launcher starts:

X3 -> Camera Index 0
X4 -> Camera Index 1

Use the launcher instead of manually starting both scripts.

The launcher DOES NOT itself create the 8001 web server.
The 8001 server is:

guardianeye_realtime_server.py

TERMINAL 1:

python masterbridge.py

TERMINAL 2:

python start_fire_cloudflare.py

TERMINAL 3:

python guardianeye_realtime_server.py

TERMINAL 4:

python start_intruder_cloudflare.py

OPTIONAL / SEPARATE:

run the dual-camera intruder launcher if X3/X4 camera
processes are not already being started by the current
intruder architecture.

THEN:

open GitHub Pages dashboard / IOT2 page
Ctrl + F5

FIRE:

netstat -ano | findstr :8000
-> LISTENING

INTRUDER:

netstat -ano | findstr :8001
-> LISTENING

FIRE MASTERBRIDGE:

CLIENTS: 1
when IOT2 is open

IOT2:

Fire Bridge: CONNECTED

BROWSER:

FIRE URL LOADED
FIRE WEBSOCKET CONNECTED

FIRE EVENT:

Telegram:
IR1 FIRE DETECTED

MasterBridge:
WEBSOCKET CLIENTS: 1
FIRE DATA SENT TO WEBSOCKET

IOT2:

FIRE DETECTED
ZONE X2
IR1

FIXED:

Fire and Intruder were accidentally mixed across ports.
Correct split is:
Fire  = 8000
Intruder/JARVIS = 8001

FIXED:

IOT2 markdown-paste damaged JavaScript regex.

FIXED:

IOT2 markdown-paste damaged escapeHTML().

FIXED:

Fire Cloudflare connector must point to 8000,
not 8001.

FIXED:

Intruder Cloudflare connector must point to 8001,
not 8000.

FIXED:

Fire dashboard reads the current URL from fire_url.txt.

CURRENT BACKEND CONTRACT:

Fire WebSocket:
/ws

Fire JSON:
project = "fire"
zone = "X2"

FIRE:

masterbridge.py
start_fire_cloudflare.py
fire_url.txt
IOT2.html

INTRUDER / JARVIS:
guardianeye_realtime_server.py
start_intruder_cloudflare.py
intruder_url.txt
IOT4.html

MAIN:
index.html

Fire:
python masterbridge.py
+
python start_fire_cloudflare.py

Intruder/JARVIS:
python guardianeye_realtime_server.py
+
python start_intruder_cloudflare.py

Ports:
Fire = 8000
Intruder = 8001

Fire URL:
fire_url.txt

Intruder URL:
intruder_url.txt
