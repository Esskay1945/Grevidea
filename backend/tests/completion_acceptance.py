"""Real gateway/PostGIS/WS with LOCAL partner fixtures and disposable identities."""
import asyncio,datetime,json,time,uuid,os,hashlib,hmac,urllib.request,urllib.error
from gateway_acceptance import request,data

def callback(body,valid=True):
    raw=json.dumps(body,separators=(',',':')).encode();stamp=str(int(time.time()));signature=hmac.new(b'local-test-callback',stamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
    if not valid:signature='0'*64
    req=urllib.request.Request('http://127.0.0.1:3000/integrations/delivery/receipt',data=raw,headers={'Content-Type':'application/json','x-grevidea-timestamp':stamp,'x-grevidea-signature':signature})
    try:
        with urllib.request.urlopen(req,timeout=10) as res:return res.status,json.load(res)
    except urllib.error.HTTPError as e:return e.code,json.load(e)

def wait_for(predicate,timeout=45):
    until=time.monotonic()+timeout
    while time.monotonic()<until:
        result=predicate()
        if result:return result
        time.sleep(.2)
    raise AssertionError('Expected state not reached within acceptance deadline')

def run():
    suffix=uuid.uuid4().hex
    def signup(name):return data(request('/api/v1/auth/register',{'email':f'{name}-{suffix}@example.test','display_name':name,'password':'local-fixture-password'}))['token']
    owner=signup('Owner');neighbor=signup('Neighbor')
    baseline={'profile':{'commuteDistances':{'Metro':2.75},'dailyCommuteKm':2.75,'monthlyElectricityKwh':0},'completed':True}
    data(request('/api/v1/baseline',baseline,owner))
    assert data(request('/api/v1/baseline',token=owner))['completed']
    # Completion is monotonic across second-device updates.
    data(request('/api/v1/baseline',{**baseline,'completed':False},owner))
    assert data(request('/api/v1/baseline',token=owner))['completed']
    assert data(request('/api/v1/baseline',token=neighbor)) is None
    event={'client_id':'food-'+suffix,'title':'Plant meal','category':'Food','subtitle':'Self-reported estimate','co2_delta_kg':-.5,'occurred_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    first=data(request('/api/v1/activities',event,owner));second=data(request('/api/v1/activities',event,owner));assert first['id']==second['id']
    history=data(request('/api/v1/activities?days=366',token=owner))['activities'];assert len(history)==1
    assert data(request('/api/v1/activities?days=366',token=neighbor))['activities']==[]
    points_before=data(request('/api/v1/points',token=owner))['total_points']
    assert request('/api/v1/activities',{**event,'co2_delta_kg':float('inf')},owner)[0] in (400,422)
    assert data(request('/api/v1/points',token=owner))['total_points']==points_before
    trip={'mode':'walk','distance_km':10,'client_id':'travel-'+suffix,'occurred_at':event['occurred_at']}
    triprow=data(request('/api/v1/carbon/log',trip,owner));data(request('/api/v1/carbon/log',trip,owner))
    history=data(request('/api/v1/activities?days=366',token=owner))['activities'];assert len(history)==2
    transport=next(r for r in history if r['category']=='Transport');assert transport['co2_delta_kg']==-triprow['co2_saved_kg']
    route=data(request('/api/v1/location/route',{'profile':'foot','origin_lat':19.2183,'origin_lon':72.9781,'destination_lat':19.22,'destination_lon':72.98},owner));assert route['profile']=='foot' and route['routes'][0]['distance']==1234.5
    station_route=data(request('/api/v1/location/route',{'origin_lat':19.2183,'origin_lon':72.9781,'destination_lat':19.22,'destination_lon':72.98},owner));assert station_route['air_quality_scores'][0]['mean_station_pm2_5_ug_m3']==12.
    inference=data(request('/api/v1/transit/infer',{'peak_speed_kmh':40,'points':[{'latitude':lat,'longitude':72.9,'accuracy':10} for lat in (19.2,19.21,19.22)]},owner));assert inference['mode']=='metro'
    hazards=data(request('/api/v1/hazards?lat=19.2&lon=72.9',token=owner));assert hazards['official_status']=='available' and hazards['alerts'][0]['id']=='fixture-flood'
    assert request('/api/v1/trusted-contacts',{'name':'Contact','phone':'+919876543210','consent_attested':False},owner)[0]==400
    contact=data(request('/api/v1/trusted-contacts',{'name':'Contact','phone':'+919876543210','consent_attested':True},owner))
    assert len(data(request('/api/v1/trusted-contacts',token=owner)))==1
    assert data(request('/api/v1/trusted-contacts',token=neighbor))==[]
    sos=data(request('/api/v1/sos',{'latitude':19.2,'longitude':72.9,'disaster_type':'emergency','description':'LOCAL TEST ONLY','needs':['water'],'people_count':1,'battery_percent':67,'street_address':'Fixture street'},owner))
    civic=data(request('/api/v1/reports',{'report_type':'garbage','description':'LOCAL TEST ONLY','latitude':19.2,'longitude':72.9,'severity':3,'photo_url':'data:image/jpeg;base64,test'},owner))
    reward=data(request('/api/v1/rewards/redeem',{'reward_id':'plant_tree'},owner))
    def accepted():
        jobs=data(request('/api/v1/deliveries',token=owner))
        selected=[r for r in jobs if r['entity_id'] in (sos['id'],civic['id'],reward['id'])]
        return selected if len(selected)==3 and all(r['status']=='accepted' for r in selected) else None
    jobs=wait_for(accepted)
    assert next(j for j in jobs if j['kind']=='reward')['attempts']>=2
    assert data(request('/api/v1/deliveries',token=neighbor))==[]
    for job in jobs:
        receipt={'event_id':'test-'+str(uuid.uuid4()),'delivery_id':job['id'],'provider_id':job['provider_id'],'status':'delivered','details':{'authority_reference':'LOCAL-RECEIPT'}}
        assert callback(receipt,False)[0]==401
        assert callback(receipt)[0]==200
        assert callback(receipt)[1]['data']['duplicate']
    assert all(j['status']=='delivered' for j in data(request('/api/v1/deliveries',token=owner)))
    balance=data(request('/api/v1/points',token=owner))['total_points']
    pending=data(request('/api/v1/rewards/redeem',{'reward_id':'plant_tree'},owner))
    wait_for(lambda: next((j for j in data(request('/api/v1/deliveries',token=owner)) if j['entity_id']==pending['id'] and j['status']=='failed'),None))
    assert data(request('/api/v1/rewards/'+pending['id']+'/cancel',{},owner))['refunded_points']==100
    assert data(request('/api/v1/rewards/'+pending['id']+'/cancel',{},owner))['already_cancelled']
    assert data(request('/api/v1/points',token=owner))['total_points']==balance
    assert request('/api/v1/deliveries/'+jobs[0]['id']+'/retry',{},neighbor)[0]==400
    async def websocket_check():
        import websockets
        try:
            async with websockets.connect('ws://127.0.0.1:3000/api/v1/live'):
                raise AssertionError('Unauthenticated websocket accepted')
        except websockets.exceptions.InvalidStatus:pass
        async with websockets.connect('ws://127.0.0.1:3000/api/v1/live',subprotocols=['grevidea','grevidea.jwt.'+neighbor]) as ws:
            await ws.send(json.dumps({'lat':19.2,'lon':72.9,'radius_km':5}))
            initial=json.loads(await asyncio.wait_for(ws.recv(),5));assert initial['type']=='snapshot'
            aid=data(request('/api/v1/mutual-aid',{'category':'water','description':'WS fixture','latitude':19.2,'longitude':72.9},owner))
            changed=json.loads(await asyncio.wait_for(ws.recv(),5));assert any(r['id']==aid['id'] for r in changed['mutual_aid'])
            data(request('/api/v1/mutual-aid/'+aid['id']+'/coordinate',{},neighbor))
            changed=json.loads(await asyncio.wait_for(ws.recv(),5));assert next(r for r in changed['mutual_aid'] if r['id']==aid['id'])['status']=='coordinated'
    asyncio.run(websocket_check())
    print('PASS: cross-device baseline/history isolation, idempotent activity/trip sync, real foot-routing contract, rail inference fixture, fresh geofenced hazard feed, contact consent, leased delivery retry, signed idempotent receipts, authenticated immediate WebSocket updates')
if __name__=='__main__':run()
