"""Real HTTP contract smoke without a production database or external AI keys."""
import base64,hashlib,hmac,json,time,urllib.request,urllib.error,uuid

def call(port,path,body=None,token=None):
    headers={'Content-Type':'application/json'}
    if token:headers['Authorization']='Bearer '+token
    req=urllib.request.Request(f'http://127.0.0.1:{port}{path}',data=None if body is None else json.dumps(body).encode(),headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=15) as res:return res.status,json.load(res)
    except urllib.error.HTTPError as e:
        body=e.read().decode()
        try:return e.code,json.loads(body)
        except ValueError:return e.code,body
for port in (3000,8000):
    for _ in range(30):
        try:
            if call(port,'/health')[0]==200:break
        except OSError:pass
        time.sleep(.2)
    else:raise AssertionError(f'Service {port} did not start')
def b64(value):return base64.urlsafe_b64encode(value).rstrip(b'=')
user=str(uuid.uuid4());now=int(time.time())
head=b64(json.dumps({'alg':'HS256','typ':'JWT'}).encode());payload=b64(json.dumps({'sub':user,'email':'smoke@example.test','role':'user','iat':now,'exp':now+60}).encode());message=head+b'.'+payload
signature=b64(hmac.new(b'ephemeral-audit-key',message,hashlib.sha256).digest());token=(message+b'.'+signature).decode()
for name in json.load(open('backend/tool-handler-map.json')):
    assert call(3000,'/internal/tools/'+name,{} )[0]==401,name
code,body=call(3000,'/api/v1/carbon/calculate',{'mode':'bicycle','distance_km':2.75},token)
assert code==200 and body['data']['co2_emitted_kg']==0,(code,body)
assert call(3000,'/api/v1/carbon/calculate',{'mode':'walk','distance_km':-1},token)[0]==400
assert call(3000,'/api/v1/ai/chat',{'prompt':'legacy incorrect field'},token)[0]==422
assert call(3000,'/api/v1/ai/chat',{'message':'How can I save energy?'},token)[0]==503
assert call(8000,'/brain/chat',{'message':'How can I save energy?','user_id':user})[0]==503
assert call(8000,'/brain/event',{'event_type':'smoke','data':{'verified_test':True},'user_id':user})[0]==200
assert call(3000,'/api/v1/location/route',{'origin_lat':999,'origin_lon':0,'destination_lat':0,'destination_lon':0},token)[0]==400
print('PASS: real HTTP on ports 3000/8000; all 58 internal tools require JWT; decimal zero-emission calculation; invalid distance/GPS rejected; missing AI providers return 503; gateway event ingestion works')
