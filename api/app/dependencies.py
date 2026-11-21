from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.core.database import get_db
from app.core.security import decode_access_token

bearer_scheme = HTTPBearer(auto_error=False)


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme), connection=Depends(get_db)) -> dict:
    if credentials is None: raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Autenticación requerida", headers={"WWW-Authenticate": "Bearer"})
    claims = decode_access_token(credentials.credentials)
    cursor = connection.cursor(dictionary=True)
    try: cursor.execute("SELECT u.id_usr, u.nom_usr, u.mail, u.tip_usu, u.activo, u.auth_version, r.nombre AS rol FROM usuario u JOIN rol r ON r.id_rol=u.tip_usu WHERE u.id_usr=%s", (int(claims["sub"]),)); user = cursor.fetchone()
    finally: cursor.close()
    if not user or not user["activo"]: raise HTTPException(status_code=401, detail="Cuenta no disponible")
    if int(claims.get('ver', 0)) != int(user.get('auth_version', 0)):
        raise HTTPException(status_code=401, detail="La sesión venció. Inicia sesión de nuevo.")
    return user
