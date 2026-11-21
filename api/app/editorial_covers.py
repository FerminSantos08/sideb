import hashlib
import json
import os
import subprocess
import tempfile
import uuid
from pathlib import Path
from fastapi import HTTPException
from app.utils import publication_image_url

MAX_IMAGE=5*1024*1024

def request_hash(body):
    data=body.model_dump(mode='json',exclude={'cover_token'})
    return hashlib.sha256(json.dumps(data,sort_keys=True,ensure_ascii=False).encode()).hexdigest()

def claim_cover(cursor,token,user):
    if token is None:return None
    cursor.execute('SELECT *,expires_at>NOW() AS valid FROM editorial_cover_upload WHERE token=%s AND usr_id=%s FOR UPDATE',(str(token),user['id_usr']))
    row=cursor.fetchone()
    if not row:raise HTTPException(404,'Portada no encontrada')
    if row['blog_id'] is None and row['request_hash'] is not None:raise HTTPException(409,'Esta portada ya fue utilizada.')
    if row['blog_id'] is None and not row['valid']:raise HTTPException(410,'La selección de portada venció. Vuelve a subir la imagen.')
    return row

def consumed_cover(row,body,post_id=None):
    if not row or row['blog_id'] is None:return False
    if row['request_hash']!=request_hash(body) or (post_id is not None and row['blog_id']!=post_id):
        raise HTTPException(409,'La portada ya se utilizó. Vuelve a abrir la publicación para continuar.')
    return True

def consume_cover(cursor,row,body,id,revision=None):
    if row:
        cursor.execute('UPDATE editorial_cover_upload SET blog_id=%s,request_hash=%s,result_revision=%s WHERE token=%s',(id,request_hash(body),revision,row['token']))

def store_cover(data,user,connection):
    root=Path(os.getenv('UPLOADS_DIR','/var/www/html/side-b/uploads'))
    token=uuid.uuid4().hex
    path=root/'publicaciones'/(uuid.uuid4().hex+'.webp')
    source=None;committed=False
    try:
        path.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.NamedTemporaryFile(delete=False) as file:
            source=Path(file.name);file.write(data)
        helper=os.getenv('WEB_IMAGE_HELPER','/var/www/html/side-b/assets/php/images.php')
        result=subprocess.run(['php','-r','require $argv[1];try{convert_image_to_webp($argv[2],$argv[3],1920);}catch(Throwable $e){exit(2);}',helper,str(source),str(path)],capture_output=True,timeout=20)
        if result.returncode!=0 or not path.is_file():raise HTTPException(422,'Usa una imagen JPG, PNG o WebP válida de hasta 5 MB y 16 megapíxeles.')
        path.chmod(0o644)
        cursor=connection.cursor()
        try:
            cursor.execute('INSERT INTO editorial_cover_upload(token,usr_id,filename,expires_at) VALUES (%s,%s,%s,DATE_ADD(NOW(),INTERVAL 1 HOUR))',(token,user['id_usr'],path.name))
            connection.commit();committed=True
        finally:cursor.close()
        return {'token':token,'url':publication_image_url(path.name)}
    except HTTPException:
        connection.rollback()
        if not committed:path.unlink(missing_ok=True)
        raise
    except (OSError,subprocess.TimeoutExpired):
        connection.rollback()
        if not committed:path.unlink(missing_ok=True)
        raise HTTPException(503,'No pudimos preparar la portada. Intenta de nuevo.')
    except Exception:
        connection.rollback()
        if not committed:path.unlink(missing_ok=True)
        raise
    finally:
        if source:source.unlink(missing_ok=True)
