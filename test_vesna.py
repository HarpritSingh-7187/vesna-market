import asyncio
import websockets
import json

async def test_vesna():
    uri = "ws://localhost:9080"
    print(f"Connecting to {uri}...")
    try:
        async with websockets.connect(uri) as websocket:
            print("Connected!")
            
            # Test message: Try to grab a non-existent object just to test communication
            msg = {
                "sender": "python_tester",
                "receiver": "body",
                "type": "interact",
                "data": {
                    "type": "grab",
                    "art_name": "non_existent_object"
                }
            }
            
            print(f"Sending: {json.dumps(msg)}")
            await websocket.send(json.dumps(msg))
            print("Message sent.")
            
            # Wait a bit to see if we get any response (though vesna.gd might only print to console)
            # In a real scenario we might expect a response, but vesna.gd seems to mostly print.
            # We can check Godot console output.
            
            # Let's try a walk command too, maybe it triggers a response?
            # vesna.gd sends "signal" back when movement ends.
            
            await asyncio.sleep(1)
            print("Test finished. Check Godot console for 'Received msg' and 'Object not found!'.")

    except ConnectionRefusedError:
        print("Connection refused. Is the Godot project running?")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    asyncio.run(test_vesna())
