"""Local-only HTTP partner fixture. Never sends emergency messages or orders."""
import json,threading
from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from datetime import datetime,timedelta,timezone
from urllib.parse import urlparse
class Handler(BaseHTTPRequestHandler):
    counts={}; lock=threading.Lock()
    def log_message(self,*args):pass
    def send(self,status,body):
        raw=json.dumps(body).encode();self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
    def do_GET(self):
        path=urlparse(self.path).path
        if path=='/health':return self.send(200,{'healthy':True})
        if path=='/flood':return self.send(200,{'daily':{'time':['2026-10-09'],'river_discharge':[12.5]}})
        if path.startswith('/route'):
            return self.send(200,{'code':'Ok','routes':[{'distance':1234.5,'duration':900,'geometry':{'type':'LineString','coordinates':[[72.9781,19.2183],[72.979,19.219],[72.98,19.22]]}}]})
        if path=='/stations':return self.send(200,[{'latitude':19.2183,'longitude':72.9781,'pm2_5_ug_m3':12.,'measured_at':datetime.now(timezone.utc).isoformat()}])
        if path=='/hazards':
            now=datetime.now(timezone.utc)
            return self.send(200,[{'id':'fixture-flood','kind':'flash_flood','title':'Disposable test warning','description':'Local fixture only','severity':'Warning','bounds':[72.,19.,74.,20.],'issued_at':(now-timedelta(minutes=1)).isoformat(),'expires_at':(now+timedelta(minutes=5)).isoformat(),'source_url':'https://example.test/warning'}])
        if path=='/shelters':return self.send(200,[{'name':'Fixture shelter','lat':19.2183,'lng':72.9781,'isOpen':True,'capacity':50}])
        return self.send(404,{'error':'unknown fixture path'})
    def do_POST(self):
        raw=self.rfile.read(int(self.headers.get('Content-Length',0)))
        if urlparse(self.path).path=='/overpass':
            return self.send(200,{'elements':[{'tags':{'railway':'subway'},'geometry':[{'lat':19.1,'lon':72.9},{'lat':19.3,'lon':72.9}]}]})
        if urlparse(self.path).path!='/relay':return self.send(404,{'error':'unknown'})
        if self.headers.get('Authorization')!='Bearer local-test-provider':return self.send(401,{'error':'fixture auth'})
        body=json.loads(raw)
        assert body['schema_version']==1 and self.headers.get('Idempotency-Key')==body['delivery_id']
        with self.lock:
            count=self.counts.get(body['delivery_id'],0)+1;self.counts[body['delivery_id']]=count
        # Verify recovery from a transient failure without producing a fake delivery.
        if body['kind']=='reward' and count==1:return self.send(503,{'error':'disposable transient failure'})
        return self.send(202,{'provider_id':'fixture-'+body['delivery_id'],'status':'accepted'})
if __name__=='__main__':ThreadingHTTPServer(('127.0.0.1',8999),Handler).serve_forever()
