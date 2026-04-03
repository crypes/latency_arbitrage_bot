import asyncio, time, random

class RateLimiter:
    def __init__(self, calls_per_second: float = 9.0):
        self.interval = 1.0 / calls_per_second
        self._lock = asyncio.Lock()
        self._next = 0.0

    async def acquire(self):
        async with self._lock:
            now = time.monotonic()
            wait = self._next - now
            if wait > 0:
                await asyncio.sleep(wait + random.uniform(0.01, 0.05))
            self._next = time.monotonic() + self.interval

def rate_limited(func):
    async def wrapper(self, *args, **kwargs):
        await self.limiter.acquire()
        return await func(self, *args, **kwargs)
    return wrapper
