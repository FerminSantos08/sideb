from collections.abc import Generator
import mysql.connector
from fastapi import HTTPException
from app.core.config import settings


def get_db_connection():
    return mysql.connector.connect(host=settings.db_host, port=settings.db_port, user=settings.db_user, password=settings.db_password, database=settings.db_name, charset="utf8mb4", use_unicode=True)


def get_db() -> Generator:
    connection = None
    try:
        connection = get_db_connection()
        yield connection
    except mysql.connector.Error as exc:
        raise HTTPException(status_code=503, detail="Base de datos no disponible") from exc
    finally:
        if connection is not None and connection.is_connected():
            connection.close()
