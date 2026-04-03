import os, base64
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

KALSHI_KEY_ID = os.environ.get("KALSHI_KEY_ID", "")
_b64 = os.environ.get("KALSHI_PRIVATE_KEY_B64", "")
KALSHI_PRIVATE_KEY_PEM = base64.b64decode(_b64).decode() if _b64 else ""
BASE_URL = "https://api.elections.kalshi.com/trade-api/v2"
