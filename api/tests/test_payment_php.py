"""Exercise the real PHP payment handler with a fake DB and fake PayPal, never funds."""
import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

ROOT=Path('/var/www/html/side-b')

STUB=r'''
$_SERVER['REQUEST_METHOD']='POST';
$_SERVER['HTTP_X_CSRF_TOKEN']='test';
$_SESSION=['csrf_token'=>'test'];
$events=[];
$scenario=getenv('PAYMENT_TEST_SCENARIO');
function mobile_payment_user_id(int $id):int{return 501;}
function mobile_payment_return(int $id):bool{return true;}
class FakeStatement {
    public string $sql;
    function __construct(string $sql){$this->sql=$sql;}
    function execute(array $params=[]):void{
        global $events;
        if(str_starts_with($this->sql,'UPDATE producto'))$events[]='stock_update';
        if(str_starts_with($this->sql,'UPDATE pedido'))$events[]='order_paid';
    }
    function fetch():array{
        global $scenario;
        return ['id_pedido'=>81,'usr_id'=>501,'estado'=>$scenario==='already_paid'?'pagado':'pendiente','total'=>'498.00','paypal_order_id'=>'PAYPAL-81','paypal_capture_id'=>$scenario==='already_paid'?'CAPTURE-81':null];
    }
    function fetchAll():array{
        global $scenario;
        return [['producto_id'=>601,'cantidad'=>1,'stock'=>$scenario==='no_stock'?0:3,'activo'=>true]];
    }
    function rowCount():int{return 1;}
}
class FakeDatabase {
    private bool $transaction=false;
    function prepare(string $sql):FakeStatement{return new FakeStatement($sql);}
    function beginTransaction():void{$this->transaction=true;}
    function inTransaction():bool{return $this->transaction;}
    function commit():void{global $events;$events[]='commit';$this->transaction=false;}
    function rollBack():void{global $events;$events[]='rollback';$this->transaction=false;}
}
$fake=new FakeDatabase();
function db(){global $fake;return $fake;}
function paypal_request(string $method,string $path,?array $payload=null,?string $requestId=null):array{
    global $events,$scenario;
    $events[]='paypal_'.$method;
    if($method==='POST'){
        if($requestId!=='sideb-capture-81')throw new RuntimeException('missing idempotency');
        if($scenario==='capture_timeout')throw new RuntimeException('timeout');
    }
    return ['status'=>'COMPLETED','purchase_units'=>[['payments'=>['captures'=>[['id'=>'CAPTURE-81','status'=>'COMPLETED','amount'=>['currency_code'=>'MXN','value'=>$scenario==='wrong_amount'?'1.00':'498.00']]]]]]];
}
register_shutdown_function(function(){global $events;file_put_contents(getenv('PAYMENT_TEST_EVENTS'),json_encode($events));});
'''


@pytest.mark.skipif(not shutil.which('php'),reason='PHP CLI required')
@pytest.mark.parametrize('scenario',['completed','already_paid','no_stock','wrong_amount','capture_timeout'])
def test_shared_payment_handler(scenario,tmp_path):
    source=(ROOT/'paypal_api.php').read_text()
    source=source.replace("require_once __DIR__ . '/assets/php/bootstrap.php';",STUB)
    source=source.replace("    require_once __DIR__.'/assets/php/mobile_payment.php';",'')
    source=source.replace("(string) file_get_contents('php://input')", "'{\"action\":\"capture\",\"order_id\":81,\"paypal_order_id\":\"PAYPAL-81\"}'")
    path=tmp_path/'capture.php';path.write_text(source)
    events_path=tmp_path/'events.json'
    environment={**os.environ,'PAYMENT_TEST_SCENARIO':scenario,'PAYMENT_TEST_EVENTS':str(events_path)}
    result=subprocess.run(['php',str(path)],capture_output=True,text=True,env=environment,timeout=5,check=True)
    response=json.loads(result.stdout)
    events=json.loads(events_path.read_text())
    if scenario in {'completed','capture_timeout'}:
        assert response['ok'] is True
        assert events.count('stock_update')==1
        assert events.count('order_paid')==1
        assert events[-1]=='commit'
        if scenario=='capture_timeout':assert 'paypal_GET' in events
    elif scenario=='already_paid':
        assert response['ok'] is True
        assert not any(event.startswith('paypal_') for event in events)
        assert 'stock_update' not in events
    else:
        assert 'error' in response
        assert 'stock_update' not in events
        assert 'order_paid' not in events
        if scenario=='no_stock':assert not any(event.startswith('paypal_') for event in events)
        assert events[-1]=='rollback'
