from uuid import uuid4
import pytest
from fastapi.testclient import TestClient
from main import app
from app.core.database import get_db,get_db_connection
from app.dependencies import current_user

@pytest.fixture
def isolated_editorial():
    c=get_db_connection();q=c.cursor(dictionary=True);previous=app.dependency_overrides.copy()
    try:
        for table in ('blog','blog_detalle','blog_artista','blog_album','guardado_publicacion'):
            q.execute('SHOW CREATE TABLE '+table);ddl=q.fetchone()['Create Table']
            ddl='\n'.join(line for line in ddl.splitlines() if not line.lstrip().startswith('CONSTRAINT'))
            q.execute(ddl.replace('CREATE TABLE','CREATE TEMPORARY TABLE',1).replace(',\n)','\n)'))
        q.execute('SELECT id_usr,tip_usu FROM usuario WHERE activo=TRUE AND tip_usu IN (2,3,4) ORDER BY id_usr LIMIT 1');author=q.fetchone()
        assert author,'An editorial account is required for read-only author joins'
        user={'id_usr':author['id_usr'],'tip_usu':2}
        q.execute("INSERT INTO blog (titulo,`desc`,tags,slug) VALUES ('Artículo de prueba','Descripción','música','articulo-prueba')");post_id=q.lastrowid
        q.execute("INSERT INTO blog_detalle (blog_id,contenido,autor_id,estado,fecha_publicacion) VALUES (%s,'<p>Contenido original.</p>',%s,'publicado',NOW())",(post_id,user['id_usr']))
        c.commit()
        app.dependency_overrides[get_db]=lambda:c
        app.dependency_overrides[current_user]=lambda:user
        yield TestClient(app),c,q,user,post_id
    finally:
        app.dependency_overrides.clear();app.dependency_overrides.update(previous);q.close();c.close()

def edit_body(snapshot,**changes):
    return {'title':'Título actualizado','description':'Descripción','content':'<h2>Subtítulo</h2><p>Texto seguro.</p><script>bad()</script>',
            'tags':'rock','state':'borrador','artist_ids':[],'album_ids':[],'revision':snapshot['revision'],**changes}

def test_saved_articles_are_idempotent_private_and_shared_with_web_table(isolated_editorial):
    client,c,q,user,id=isolated_editorial
    assert client.put(f'/library/posts/{id}').status_code==204
    assert client.put(f'/library/posts/{id}').status_code==204
    q.execute('SELECT COUNT(*) n FROM guardado_publicacion');assert q.fetchone()['n']==1;c.rollback()
    library=client.get('/library/posts').json();assert library['saved_ids']==[id] and library['posts'][0]['id']==id
    original=user['id_usr'];user['id_usr']=original+99999
    assert client.get('/library/posts').json()=={'posts':[],'saved_ids':[]}
    assert client.delete(f'/library/posts/{id}').status_code==204
    user['id_usr']=original
    assert client.get('/library/posts').json()['saved_ids']==[id]
    assert client.delete(f'/library/posts/{id}').status_code==204
    assert client.delete(f'/library/posts/{id}').status_code==204
    assert client.get('/library/posts').json()['saved_ids']==[]

def test_hidden_articles_cannot_be_saved_or_read_from_library(isolated_editorial):
    client,c,q,_,id=isolated_editorial
    assert client.put(f'/library/posts/{id}').status_code==204
    q.execute("UPDATE blog_detalle SET estado='borrador',fecha_publicacion=NULL WHERE blog_id=%s",(id,));c.commit()
    assert client.put(f'/library/posts/{id}').status_code==404
    assert client.get('/library/posts').json()['posts']==[]
    assert client.delete(f'/library/posts/{id}').status_code==204

def test_edit_preserves_slug_owner_and_sanitizes_content(isolated_editorial):
    client,c,q,user,id=isolated_editorial
    snapshot=client.get(f'/editorial/posts/{id}');assert snapshot.status_code==200,snapshot.text
    response=client.put(f'/editorial/posts/{id}',json=edit_body(snapshot.json()))
    assert response.status_code==200,response.text
    saved=response.json();assert saved['post']['slug']=='articulo-prueba'
    assert saved['post']['owner_id']==user['id_usr']
    assert saved['post']['estado']=='borrador' and saved['post']['fecha_publicacion'] is None
    assert '<script' not in saved['post']['contenido']
    assert client.get(f'/posts/{id}').status_code==404
    again=client.put(f'/editorial/posts/{id}',json=edit_body(saved,state='publicado'))
    assert again.status_code==200 and again.json()['post']['fecha_publicacion'] is not None
    assert client.get(f'/posts/{id}').status_code==200
    assert client.put(f'/editorial/posts/{id}',json=edit_body(again.json(),state='archivado')).status_code==200
    assert client.get(f'/posts/{id}').status_code==404

def test_stale_revision_does_not_overwrite_another_session(isolated_editorial):
    client,c,q,_,id=isolated_editorial
    snapshot=client.get(f'/editorial/posts/{id}').json()
    q.execute("UPDATE blog SET titulo='Cambio de la web' WHERE id_blog=%s",(id,));c.commit()
    assert client.put(f'/editorial/posts/{id}',json=edit_body(snapshot)).status_code==409
    q.execute('SELECT titulo FROM blog WHERE id_blog=%s',(id,));assert q.fetchone()['titulo']=='Cambio de la web'

def test_editorial_roles_and_ownership_are_enforced(isolated_editorial):
    client,c,q,user,id=isolated_editorial
    own=client.get(f'/editorial/posts/{id}').json()
    user['id_usr']+=99999
    assert client.get('/editorial/posts').json()['posts']==[]
    assert client.get(f'/editorial/posts/{id}').status_code==404
    assert client.put(f'/editorial/posts/{id}',json=edit_body(own)).status_code==404
    user['tip_usu']=3
    assert client.get(f'/editorial/posts/{id}').status_code==200
    assert len(client.get('/editorial/posts').json()['posts'])==1
    user['tip_usu']=1
    assert client.get('/editorial/posts').status_code==403
    assert client.get(f'/editorial/posts/{id}').status_code==403
    assert client.put(f'/editorial/posts/{id}',json=edit_body(own)).status_code==403

def test_library_and_editorial_require_login(isolated_editorial):
    client,_,_,_,id=isolated_editorial
    del app.dependency_overrides[current_user]
    assert client.get('/library/posts').status_code==401
    assert client.put(f'/library/posts/{id}').status_code==401
    assert client.get('/editorial/posts').status_code==401
