import mysql.connector
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.dependencies import current_user
from app.utils import serialize_media
from app.schemas import LoginRequest, RegisterRequest, TokenResponse

router=APIRouter(prefix="/auth",tags=["Autenticación"])
@router.post("/login",response_model=TokenResponse)
def login(body:LoginRequest,connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id_usr,pass,tip_usu,auth_version FROM usuario WHERE mail=%s AND activo=TRUE LIMIT 1",(str(body.email),)); user=cursor.fetchone()
        if not user or not verify_password(body.password,user["pass"]): raise HTTPException(status_code=401,detail="Correo o contraseña incorrectos",headers={"WWW-Authenticate":"Bearer"})
        return TokenResponse(access_token=create_access_token(user["id_usr"],user["tip_usu"],user["auth_version"]),expires_in=settings.access_token_minutes*60)
    finally: cursor.close()
@router.post("/register",status_code=status.HTTP_201_CREATED)
def register(body:RegisterRequest,connection=Depends(get_db)):
    cursor=connection.cursor()
    try:
        cursor.execute("INSERT INTO usuario (nom_usr,mail,pass,tip_usu) VALUES (%s,%s,%s,1)",(body.username.strip(),str(body.email),hash_password(body.password)))
        user_id=cursor.lastrowid; cursor.execute("INSERT INTO perfil_usuario (usr_id,alias) VALUES (%s,%s)",(user_id,body.username.strip())); connection.commit()
        return {"id":user_id,"message":"Cuenta creada"}
    except mysql.connector.IntegrityError as exc:
        connection.rollback(); raise HTTPException(status_code=409,detail="Ese correo ya está registrado") from exc
    except Exception:
        connection.rollback(); raise
    finally: cursor.close()
@router.get("/me")
def me(user=Depends(current_user),connection=Depends(get_db)):
    cursor=connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT p.alias,p.biografia,p.avatar_url FROM perfil_usuario p WHERE p.usr_id=%s",(user["id_usr"],)); profile=serialize_media(cursor.fetchone() or {}, "avatar_url")
        return {"id":user["id_usr"],"name":user["nom_usr"],"email":user["mail"],"role":{"id":user["tip_usu"],"name":user["rol"]},"profile":profile}
    finally: cursor.close()
