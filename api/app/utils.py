from contextvars import ContextVar
from urllib.parse import quote, urlsplit, urlunsplit

from app.core.config import settings


_media_base_url: ContextVar[str | None] = ContextVar("media_base_url", default=None)


def select_media_base_url(host: str | None):
    """Select a configured media host for the lifetime of one request."""
    return _media_base_url.set(settings.media_base_url_for_host(host))


def reset_media_base_url(token) -> None:
    _media_base_url.reset(token)


def media_url(path: str | None) -> str | None:
    if not path:
        return None
    value = path.replace("\\", "/").lstrip("/")
    base_url = _media_base_url.get() or settings.media_base_url
    if value.startswith(("http://", "https://")):
        parsed = urlsplit(value)
        known_hosts = {
            urlsplit(url).hostname for url in settings.media_base_urls
        }
        if base_url and parsed.hostname in known_hosts:
            target = urlsplit(base_url)
            return urlunsplit(
                (target.scheme, target.netloc, parsed.path, parsed.query, parsed.fragment)
            )
        return value
    return f"{base_url}/{quote(value, safe='/')}" if base_url else value


def publication_image_url(path: str | None) -> str | None:
    """Resolve legacy blog filenames to Apache's public uploads directory."""
    if not path:
        return None
    value = path.replace("\\", "/").lstrip("/")
    if not value.startswith(("http://", "https://", "uploads/")):
        value = f"uploads/publicaciones/{value}"
    return media_url(value)



def serialize_media(record: dict, *fields: str) -> dict:
    for field in fields:
        record[field] = media_url(record.get(field))
    return record
