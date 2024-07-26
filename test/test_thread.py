import asyncio

async def test():
    print("Thread ran")

async def main():
    print("Creating Directive Task")
    asyncio.create_task(test())
    print("Task Created")
    
    # Pause main coroutine to simulate a delay
    await asyncio.sleep(1)
    print("Main coroutine resumed")

# Run the event loop
asyncio.run(main())
