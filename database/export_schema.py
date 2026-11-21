"""Export the current SIDE B MySQL schema without table data."""

import os
from pathlib import Path
import re
import subprocess

from dotenv import dotenv_values


def main() -> None:
    directory = Path(__file__).resolve().parent
    settings = {**dotenv_values(directory.parent / "api" / ".env"), **os.environ}
    if not settings.get("DB_USER"):
        raise SystemExit("Configura DB_USER en api/.env o en el entorno.")

    result = subprocess.run(
        [
            "mysqldump", "--no-defaults", "--protocol=TCP",
            "--host", settings.get("DB_HOST") or "127.0.0.1",
            "--port", settings.get("DB_PORT") or "3306",
            "--user", settings["DB_USER"],
            "--no-data", "--no-tablespaces", "--set-gtid-purged=OFF",
            "--single-transaction", "--skip-add-drop-table",
            "--skip-comments", "--skip-dump-date",
            settings.get("DB_NAME") or "side_b",
        ],
        env={**os.environ, "MYSQL_PWD": settings.get("DB_PASSWORD") or ""},
        stdout=subprocess.PIPE,
    )
    if result.returncode:
        raise SystemExit(result.returncode)

    schema = re.sub(rb"(?<=\)) ENGINE=([^\n;]+?) AUTO_INCREMENT=\d+", rb" ENGINE=\1", result.stdout)
    if re.search(rb"\bDEFINER\s*=", schema, re.IGNORECASE):
        raise SystemExit("El esquema contiene DEFINER. Revisa su portabilidad antes de exportarlo.")
    if not re.search(rb"^CREATE TABLE ", schema, re.MULTILINE):
        raise SystemExit("La exportación no contiene tablas.")
    (directory / "schema.sql").write_bytes(schema)


if __name__ == "__main__":
    main()
