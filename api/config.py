"""Compatibility module; configuration lives in app.core.config."""
from app.core.database import get_db_connection

__all__ = ["get_db_connection"]
