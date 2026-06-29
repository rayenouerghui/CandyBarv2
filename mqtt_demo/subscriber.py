"""
Simple MQTT Subscriber
Listens for messages on topic "test/mqtt" from localhost:1883
Run this alongside publisher.py
"""

import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883
TOPIC = "test/mqtt"


def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"[Subscriber] Connected to {BROKER}:{PORT}")
        client.subscribe(TOPIC)
        print(f"[Subscriber] Listening on topic: {TOPIC}\n")
    else:
        print(f"[Subscriber] Connection failed (rc={rc})")


def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8", errors="replace")
    print(f"[Subscriber] Received on '{msg.topic}': {payload}")


client = mqtt.Client(client_id="subscriber")
client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, PORT, keepalive=60)

print("[Subscriber] Waiting for messages... Ctrl+C to quit.\n")
try:
    client.loop_forever()
except KeyboardInterrupt:
    print("\n[Subscriber] Exiting.")
finally:
    client.disconnect()
