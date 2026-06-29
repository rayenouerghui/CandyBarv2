"""
Simple MQTT Publisher
Publishes messages to topic "test/mqtt" on localhost:1883
Run this alongside subscriber.py
"""

import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883
TOPIC = "test/mqtt"


def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"[Publisher] Connected to {BROKER}:{PORT}")
    else:
        print(f"[Publisher] Connection failed (rc={rc})")


client = mqtt.Client(client_id="publisher")
client.on_connect = on_connect
client.connect(BROKER, PORT, keepalive=60)
client.loop_start()

print("[Publisher] Type a message and press Enter to send. Ctrl+C to quit.\n")
try:
    while True:
        msg = input("Message: ")
        if msg:
            client.publish(TOPIC, msg)
            print(f"[Publisher] Sent: {msg}")
except KeyboardInterrupt:
    print("\n[Publisher] Exiting.")
finally:
    client.loop_stop()
    client.disconnect()
