from dataclasses import dataclass
import os
from dotenv import load_dotenv
from urllib.parse import urlsplit

load_dotenv()


def _csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


@dataclass(frozen=True)
class Settings:
    db_host: str = os.getenv("DB_HOST", "127.0.0.1")
    db_port: int = int(os.getenv("DB_PORT", "3306"))
    db_name: str = os.getenv("DB_NAME", "side_b")
    db_user: str = os.getenv("DB_USER", "")
    db_password: str = os.getenv("DB_PASSWORD", "")
    jwt_secret: str = os.getenv("JWT_SECRET", "")
    access_token_minutes: int = int(os.getenv("ACCESS_TOKEN_MINUTES", "480"))
    cors_origins: tuple[str, ...] = tuple(_csv(os.getenv("CORS_ORIGINS", "")))
    media_base_url: str = os.getenv("MEDIA_BASE_URL", "").rstrip("/")
    media_base_urls: tuple[str, ...] = tuple(
        url.rstrip("/")
        for url in _csv(
            os.getenv(
                "MEDIA_BASE_URLS",
                "http://10.223.22.245/SIDE_B,http://192.168.3.15/SIDE_B",
            )
        )
    )

    def media_base_url_for_host(self, host: str | None) -> str:
        """Return the media host that matches the API host used by the client."""
        if host:
            for base_url in self.media_base_urls:
                if urlsplit(base_url).hostname == host:
                    return base_url
        return self.media_base_url


settings = Settings()
