import os
import subprocess
import tempfile
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from starlette.concurrency import run_in_threadpool

from app.core.database import get_db
from app.core.security import hash_password, verify_password
from app.dependencies import current_user
from app.utils import media_url
from routers.auth import me

router = APIRouter(prefix='/profile', tags=['Perfil y direcciones'])
MAX_AVATAR = 5 * 1024 * 1024


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    alias: str = Field(min_length=1, max_length=50)
    biography: str = Field(default='', max_length=300)

    @field_validator('alias', 'biography', mode='before')
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value


class PasswordUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    current_password: str = Field(min_length=1, max_length=128, repr=False)
    new_password: str = Field(min_length=8, max_length=72, repr=False)
    confirmation: str = Field(min_length=8, max_length=72, repr=False)

    @model_validator(mode='after')
    def validate_password(self):
        if len(self.new_password.encode('utf-8')) > 72:
            raise ValueError('La contraseña es demasiado larga')
        if self.new_password != self.confirmation:
            raise ValueError('Las contraseñas no coinciden')
        if self.new_password == self.current_password:
            raise ValueError('La nueva contraseña debe ser diferente')
        return self


class AddressUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    label: str = Field(min_length=1, max_length=60)
    address: str = Field(min_length=1, max_length=255)
    is_default: bool = False

    @field_validator('label', 'address', mode='before')
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value


@router.put('')
def update_profile(body: ProfileUpdate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor()
    try:
        cursor.execute('''INSERT INTO perfil_usuario (usr_id,alias,biografia) VALUES (%s,%s,%s)
            ON DUPLICATE KEY UPDATE alias=%s,biografia=%s''',
            (user['id_usr'], body.alias, body.biography or None, body.alias, body.biography or None))
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
    return me(user, connection)


def save_avatar(data, user, connection):
    root = Path(os.getenv('UPLOADS_DIR', '/var/www/html/side-b/uploads'))
    destination = root / 'perfiles' / (uuid.uuid4().hex + '.webp')
    source = None
    committed = False
    try:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(delete=False) as file:
            source = Path(file.name)
            file.write(data)
        converter = os.getenv('WEB_IMAGE_HELPER', '/var/www/html/side-b/assets/php/images.php')
        result = subprocess.run([
            'php', '-r', 'require $argv[1]; try { convert_image_to_webp($argv[2],$argv[3],512); } catch(Throwable $e) { fwrite(STDERR,"invalid image"); exit(2); }',
            converter, str(source), str(destination),
        ], capture_output=True, timeout=15)
        if result.returncode != 0 or not destination.is_file():
            raise HTTPException(422, 'Usa una imagen JPG, PNG o WebP válida de hasta 5 MB y 16 megapíxeles.')
        destination.chmod(0o644)
        cursor = connection.cursor()
        try:
            cursor.execute('''INSERT INTO perfil_usuario (usr_id,alias,avatar_url) VALUES (%s,%s,%s)
                ON DUPLICATE KEY UPDATE avatar_url=%s''',
                (user['id_usr'], user['nom_usr'], 'uploads/perfiles/' + destination.name, 'uploads/perfiles/' + destination.name))
            connection.commit()
            committed = True
        finally:
            cursor.close()
        return me(user, connection)
    except HTTPException:
        connection.rollback()
        if not committed: destination.unlink(missing_ok=True)
        raise
    except (OSError, subprocess.TimeoutExpired):
        connection.rollback()
        if not committed: destination.unlink(missing_ok=True)
        raise HTTPException(503, 'No pudimos guardar la foto. Intenta de nuevo.')
    except Exception:
        connection.rollback()
        if not committed: destination.unlink(missing_ok=True)
        raise
    finally:
        if source: source.unlink(missing_ok=True)


@router.put('/avatar')
async def upload_avatar(request: Request, user=Depends(current_user), connection=Depends(get_db)):
    data = bytearray()
    async for chunk in request.stream():
        if len(data) + len(chunk) > MAX_AVATAR:
            raise HTTPException(413, 'La foto debe pesar como máximo 5 MB.')
        data.extend(chunk)
    if not data:
        raise HTTPException(422, 'Selecciona una foto.')
    return await run_in_threadpool(save_avatar, bytes(data), user, connection)


@router.put('/password', status_code=204)
def change_password(body: PasswordUpdate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute('SELECT pass FROM usuario WHERE id_usr=%s FOR UPDATE', (user['id_usr'],))
        row = cursor.fetchone()
        if not row or not verify_password(body.current_password, row['pass']):
            raise HTTPException(403, 'La contraseña actual no es correcta.')
        cursor.execute('UPDATE usuario SET pass=%s,auth_version=auth_version+1 WHERE id_usr=%s', (hash_password(body.new_password), user['id_usr']))
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


def address_rows(cursor, uid, lock=False):
    cursor.execute('''SELECT id_direccion AS id,etiqueta AS label,direccion AS address,es_principal AS is_default
        FROM direccion_usuario WHERE usr_id=%s ORDER BY id_direccion''' + (' FOR UPDATE' if lock else ''), (uid,))
    return cursor.fetchall()


def lock_addresses(cursor, uid):
    cursor.execute('SELECT id_usr FROM usuario WHERE id_usr=%s FOR UPDATE', (uid,))
    cursor.fetchone()
    return address_rows(cursor, uid, True)


def primary(cursor, uid, id):
    if id is None:
        cursor.execute('UPDATE usuario SET dir_usr=NULL WHERE id_usr=%s', (uid,))
        return
    cursor.execute('SELECT direccion FROM direccion_usuario WHERE id_direccion=%s AND usr_id=%s', (id, uid))
    row = cursor.fetchone()
    if not row: raise HTTPException(404, 'Dirección no encontrada.')
    cursor.execute('UPDATE direccion_usuario SET es_principal=(id_direccion=%s) WHERE usr_id=%s', (id, uid))
    cursor.execute('UPDATE usuario SET dir_usr=%s WHERE id_usr=%s', (row['direccion'], uid))


@router.get('/addresses')
def list_addresses(user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        return {'addresses': sorted(address_rows(cursor, user['id_usr']), key=lambda row: not row['is_default'])}
    finally:
        cursor.close()


@router.post('/addresses', status_code=201)
def create_address(body: AddressUpdate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        rows = lock_addresses(cursor, user['id_usr'])
        cursor.execute('INSERT INTO direccion_usuario (usr_id,etiqueta,direccion,es_principal) VALUES (%s,%s,%s,FALSE)', (user['id_usr'], body.label, body.address))
        id = cursor.lastrowid
        old = next((row['id'] for row in rows if row['is_default']), rows[0]['id'] if rows else None)
        primary(cursor, user['id_usr'], id if body.is_default or not rows else old)
        connection.commit()
        return {'id': id}
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


@router.put('/addresses/{id}')
def update_address(id: int, body: AddressUpdate, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        rows = lock_addresses(cursor, user['id_usr'])
        current = next((row for row in rows if row['id'] == id), None)
        if not current: raise HTTPException(404, 'Dirección no encontrada.')
        cursor.execute('UPDATE direccion_usuario SET etiqueta=%s,direccion=%s WHERE id_direccion=%s AND usr_id=%s', (body.label, body.address, id, user['id_usr']))
        other = next((row['id'] for row in rows if row['id'] != id and row['is_default']), next((row['id'] for row in rows if row['id'] != id), id))
        primary(cursor, user['id_usr'], id if body.is_default else other)
        connection.commit()
        return {'id': id}
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


@router.put('/addresses/{id}/default', status_code=204)
def set_default(id: int, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        lock_addresses(cursor, user['id_usr'])
        primary(cursor, user['id_usr'], id)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


@router.delete('/addresses/{id}', status_code=204)
def delete_address(id: int, user=Depends(current_user), connection=Depends(get_db)):
    cursor = connection.cursor(dictionary=True)
    try:
        rows = lock_addresses(cursor, user['id_usr'])
        if not any(row['id'] == id for row in rows): raise HTTPException(404, 'Dirección no encontrada.')
        cursor.execute('DELETE FROM direccion_usuario WHERE id_direccion=%s AND usr_id=%s', (id, user['id_usr']))
        remaining = [row for row in rows if row['id'] != id]
        next_id = next((row['id'] for row in remaining if row['is_default']), remaining[0]['id'] if remaining else None)
        primary(cursor, user['id_usr'], next_id)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
