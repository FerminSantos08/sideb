import base64
import hashlib
import hmac
import json
import time
import bcrypt
from fastapi import HTTPException, status
from app.core.config import settings


def verify_password(password: str, password_hash: str) -> bool:
    try: return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError): return False


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _b64encode(value: bytes) -> str: return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")
def _b64decode(value: str) -> bytes: return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def create_access_token(user_id: int, role_id: int, version: int = 0) -> str:
    if len(settings.jwt_secret) < 32: raise RuntimeError("JWT_SECRET debe tener al menos 32 caracteres")
    now = int(time.time())
    header = _b64encode(b'{"alg":"HS256","typ":"JWT"}')
    payload = _b64encode(json.dumps({"sub": str(user_id), "role": role_id, "ver": version, "iat": now, "exp": now + settings.access_token_minutes * 60}, separators=(",", ":")).encode())
    signature = _b64encode(hmac.new(settings.jwt_secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest())
    return f"{header}.{payload}.{signature}"


def decode_access_token(token: str) -> dict:
    try:
        header, payload, signature = token.split(".")
        expected = _b64encode(hmac.new(settings.jwt_secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected): raise ValueError
        claims = json.loads(_b64decode(payload))
        if int(claims["exp"]) <= int(time.time()): raise ValueError
        return claims
    except (ValueError, KeyError, json.JSONDecodeError, UnicodeDecodeError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o vencido", headers={"WWW-Authenticate": "Bearer"})
