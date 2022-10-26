import os
import json
import time
import random
import paho.mqtt.client as mqtt
from datetime import datetime

def connect_mqtt():
    client_id = os.environ["CLIENT_ID"]
    username = os.environ["USERNAME"]
    password = os.environ["PASSWORD"]
    broker_host = os.environ["BROKER_HOST"]
    broker_port = int(os.environ["BROKER_PORT"])

    def on_connect(client, userdata, flags, rc):
        if rc == 0:
            print("Connected to MQTT Broker")

            # topic = f"devices/{client_id}/commands"
            topic = f"commands"

            rc = client.subscribe(topic)
            if rc[0] == 0:
                print(f"Subscribed to topic {topic}")
            else:
                print(f"Failed to subscribe to topic {topic}. Return code {str(rc)}")
        else:
            print(f"Failed to connect. Return code {str(rc)}")

    def on_message(client, userdata, msg):
        print(f"Message received. {msg.topic}: {str(msg.payload)}")

    client = mqtt.Client(client_id)
    client.on_connect = on_connect
    client.on_message = on_message
    client.username_pw_set(username, password)
    client.connect(broker_host, broker_port, 60)

    return client

def publish(client):
    client_id = os.environ["CLIENT_ID"]
    interval_sec = int(os.environ["INTERVAL_SEC"])

    while True:
        payload = {
            'deviceId': client_id,
            'timestamp': str(datetime.utcnow()),
            'temperature': random.uniform(20.0, 35.9),
        }

        # topic = f"devices/{client_id}/telemetry"
        topic = f"telemetry"

        msg = json.dumps(payload)
        result = client.publish(topic, msg)

        status = result[0]
        if status == 0:
            print(f"Message sent to topic {topic}")
        else:
            print(f"Failed to send message to topic {topic}")

        time.sleep(interval_sec)

def run():
    client = connect_mqtt()
    client.loop_start()
    publish(client)

if __name__ == '__main__':
    run()