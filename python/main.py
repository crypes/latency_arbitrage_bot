"""Main entry point – continuous KXBTC15M scanner."""
import asyncio, sys, os, time

# Demo by default; change to from venues import KalshiVenue for production
from venues import DemoKalshiVenue

async def main():
    venue = DemoKalshiVenue(rate=9.0)
    await venue.connect()
    print(f"[{venue.name}] Scanning KXBTC15M every 6s...")
    print(f"Started at {time.strftime('%Y-%m-%d %H:%M:%S %Z')} | Press Ctrl+C to stop")
    print("-" * 70)
    try:
        while True:
            markets = await venue.get_markets("KXBTC15M")
            active = [m for m in markets if m.status == "active"]
            print(f"  {len(active)} active markets found")
            for m in active[:3]:
                print(f"  {venue._adapter.format_market(m)}")
            if len(active) > 3:
                print(f"  ... and {len(active) - 3} more")
            await asyncio.sleep(6)
    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        await venue.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
