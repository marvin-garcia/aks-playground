import os
import json
import time
import asyncio
from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient

async def run():
    # Create a producer client to send messages to the event hub.
    # Specify a connection string to your event hubs namespace and
    # the event hub name.

    connection_string = os.environ['EH_CONN_STR']
    event_hub_name = os.environ['EH_NAME']
    interval_sec = int(os.environ["INTERVAL_SEC"])

    producer = EventHubProducerClient.from_connection_string(conn_str=connection_string, eventhub_name=event_hub_name)
    while True:
        payload = {
            'clientId': 'client001',
            'command': 'restart',
        }
        await producer.send_event(EventData(json.dumps(payload)))

        time.sleep(interval_sec)

if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run())
