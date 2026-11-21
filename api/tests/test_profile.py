import subprocess
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from main import app
from app.core.database import get_db,get_db_connection
from app.core.security import hash_password,verify_password
from app.dependencies import current_user


@pytest.fixture
def isolated_profile(monkeypatch,tmp_path):
    c=get_db_connection();q=c.cursor(dictionary=True)
    previous=app.dependency_overrides.copy()
    try:
        for table in ('usuario','perfil_usuario','direccion_usuario'):
            q.execute('SHOW CREATE TABLE '+table)
            ddl=q.fetchone()['Create Table']
            ddl='\n'.join(line for line in ddl.splitlines() if not line.lstrip().startswith('CONSTRAINT'))
            q.execute(ddl.replace('CREATE TABLE','CREATE TEMPORARY TABLE',1).replace(',\n)','\n)'))
        password=hash_password('current-test-123')
        for id in (501,502):
            q.execute('INSERT INTO usuario (id_usr,nom_usr,mail,pass,tip_usu) VALUES (%s,%s,%s,%s,1)',(id,'test'+str(id),'test'+str(id)+'@example.com',password))
        q.execute("INSERT INTO perfil_usuario (usr_id,alias,biografia) VALUES (501,'Ana','Música')")
        c.commit()
        user={'id_usr':501,'nom_usr':'test501','mail':'test501@example.com','rol':'Listener','tip_usu':1}
        app.dependency_overrides[get_db]=lambda:c
        app.dependency_overrides[current_user]=lambda:user
        monkeypatch.setenv('UPLOADS_DIR',str(tmp_path))
        yield TestClient(app),c,q,user,tmp_path
    finally:
        app.dependency_overrides.clear();app.dependency_overrides.update(previous)
        q.close();c.close()


def test_profile_limits_trimming_and_immutable_account_fields(isolated_profile):
    client,c,q,_,_=isolated_profile
    response=client.put('/profile',json={'alias':'  Ana música  ','biography':'  Vinilos y café  '})
    assert response.status_code==200,response.text
    assert response.json()['profile']['alias']=='Ana música'
    assert response.json()['profile']['biografia']=='Vinilos y café'
    assert response.json()['email']=='test501@example.com'
    assert client.put('/profile',json={'alias':'  '}).status_code==422
    assert client.put('/profile',json={'alias':'a'*51}).status_code==422
    assert client.put('/profile',json={'alias':'Ana','biography':'a'*301}).status_code==422
    assert client.put('/profile',json={'alias':'Ana','role':'Admin'}).status_code==422
    q.execute('SELECT alias FROM perfil_usuario WHERE usr_id=502');assert q.fetchone() is None


def test_password_verification_and_session_revocation(isolated_profile):
    client,c,q,_,_=isolated_profile
    del app.dependency_overrides[current_user]
    login=client.post('/auth/login',json={'email':'test501@example.com','password':'current-test-123'})
    assert login.status_code==200,login.text
    old={'Authorization':'Bearer '+login.json()['access_token']}
    assert client.get('/auth/me',headers=old).status_code==200
    body={'current_password':'wrong','new_password':'new-test-123','confirmation':'new-test-123'}
    assert client.put('/profile/password',json=body,headers=old).status_code==403
    body['current_password']='current-test-123'
    body['confirmation']='different'
    assert client.put('/profile/password',json=body,headers=old).status_code==422
    body['confirmation']='new-test-123'
    assert client.put('/profile/password',json=body,headers=old).status_code==204
    assert client.get('/auth/me',headers=old).status_code==401
    assert client.post('/auth/login',json={'email':'test501@example.com','password':'current-test-123'}).status_code==401
    new=client.post('/auth/login',json={'email':'test501@example.com','password':'new-test-123'})
    assert new.status_code==200
    assert client.get('/auth/me',headers={'Authorization':'Bearer '+new.json()['access_token']}).status_code==200
    q.execute('SELECT pass,auth_version FROM usuario WHERE id_usr=501');row=q.fetchone()
    assert row['auth_version']==1 and verify_password('new-test-123',row['pass'])
    result=subprocess.run(['php','-r','echo password_verify($argv[1],$argv[2])?"ok":"fail";','new-test-123',row['pass']],capture_output=True,text=True,check=True)
    assert result.stdout=='ok'


def test_address_lifecycle_keeps_one_default_and_legacy_delivery_in_sync(isolated_profile):
    client,c,q,_,_=isolated_profile
    a=client.post('/profile/addresses',json={'label':'Casa','address':'Primera calle'}).json()['id']
    b=client.post('/profile/addresses',json={'label':'Trabajo','address':'Segunda calle'}).json()['id']
    def primary(expected,text):
        rows=client.get('/profile/addresses').json()['addresses']
        assert [r['id'] for r in rows if r['is_default']]==expected
        q.execute('SELECT dir_usr FROM usuario WHERE id_usr=501');assert q.fetchone()['dir_usr']==text
        c.rollback()
    primary([a],'Primera calle')
    assert client.put(f'/profile/addresses/{b}/default').status_code==204
    primary([b],'Segunda calle')
    assert client.put(f'/profile/addresses/{b}',json={'label':'Oficina','address':'Nueva oficina','is_default':True}).status_code==200
    primary([b],'Nueva oficina')
    assert client.delete(f'/profile/addresses/{b}').status_code==204
    primary([a],'Primera calle')
    assert client.delete(f'/profile/addresses/{a}').status_code==204
    primary([],None)


def test_foreign_address_ids_are_never_editable(isolated_profile):
    client,c,q,user,_=isolated_profile
    a=client.post('/profile/addresses',json={'label':'Casa','address':'Privada'}).json()['id']
    user['id_usr']=502
    assert client.get('/profile/addresses').json()['addresses']==[]
    assert client.put(f'/profile/addresses/{a}',json={'label':'Otra','address':'Otra'}).status_code==404
    assert client.put(f'/profile/addresses/{a}/default').status_code==404
    assert client.delete(f'/profile/addresses/{a}').status_code==404
    user['id_usr']=501
    assert client.get('/profile/addresses').json()['addresses'][0]['address']=='Privada'


def test_avatar_is_validated_and_reencoded_to_shared_webp(isolated_profile):
    client,c,q,user,root=isolated_profile
    assert client.put('/profile/avatar',content=b'').status_code==422
    assert client.put('/profile/avatar',content=b'<?php echo "no"; ?>').status_code==422
    assert client.put('/profile/avatar',content=b'a'*(5*1024*1024+1)).status_code==413
    png=subprocess.run(['php','-r','$im=imagecreatetruecolor(800,600);imagepng($im);'],capture_output=True,check=True).stdout
    response=client.put('/profile/avatar',content=png,headers={'Content-Type':'application/octet-stream'})
    assert response.status_code==200,response.text
    url=response.json()['profile']['avatar_url']
    assert '/uploads/perfiles/' in url and url.endswith('.webp')
    files=list((root/'perfiles').glob('*.webp'));assert len(files)==1
    result=subprocess.run(['php','-r','$s=getimagesize($argv[1]);echo $s[0].",".$s[1].",".$s["mime"];',str(files[0])],capture_output=True,text=True,check=True)
    assert result.stdout=='512,384,image/webp'
    q.execute('SELECT avatar_url FROM perfil_usuario WHERE usr_id=501');assert q.fetchone()['avatar_url']=='uploads/perfiles/'+files[0].name


def test_profile_and_address_routes_require_login(isolated_profile):
    client,_,_,_,_=isolated_profile
    del app.dependency_overrides[current_user]
    assert client.put('/profile',json={'alias':'Ana'}).status_code==401
    assert client.put('/profile/avatar',content=b'picture').status_code==401
    assert client.get('/profile/addresses').status_code==401
    assert client.post('/profile/addresses',json={'label':'Casa','address':'Calle'}).status_code==401
