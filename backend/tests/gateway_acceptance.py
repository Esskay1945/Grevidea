"""Acceptance checks against a DISPOSABLE PostGIS database; never production.
Run the gateway with CI-created database, then execute this script.
"""
import concurrent.futures
import datetime
import json
import time
import urllib.error
import urllib.request
import uuid

BASE='http://127.0.0.1:3000'
def request(path, body=None, token=None):
    headers={'Content-Type':'application/json'}
    if token:headers['Authorization']='Bearer '+token
    data=None if body is None else json.dumps(body).encode()
    req=urllib.request.Request(BASE+path,data=data,headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=10) as response:return response.status,json.load(response)
    except urllib.error.HTTPError as error:
        raw=error.read().decode()
        try:return error.code,json.loads(raw)
        except ValueError:return error.code,raw

def data(result):
    code,body=result
    assert code==200,(code,body)
    return body.get('data',body)

def run():
    for _ in range(30):
        try:
            if request('/health')[0]==200:break
        except OSError:pass
        time.sleep(.5)
    suffix=uuid.uuid4().hex[:8]
    def signup(name):return data(request('/api/v1/auth/register',{'email':f'{name}-{suffix}@example.test','password':'disposable-password-2026','display_name':name}))['token']
    driver=signup('Driver'); rider=signup('Rider'); other=signup('Other')
    assert request('/internal/tools/carbon_calculator',{'mode':'walk','distance_km':2})[0]==401
    calc=data(request('/api/v1/carbon/calculate',{'mode':'bicycle','distance_km':2.75},rider))
    assert calc['co2_emitted_kg']==0 and calc['co2_saved_kg']>0
    assert request('/api/v1/carbon/calculate',{'mode':'walk','distance_km':-1},rider)[0]==400
    before=data(request('/api/v1/points',token=rider))
    for distance in [1.25,2.5]:data(request('/api/v1/carbon/log',{'mode':'walk','distance_km':distance},rider))
    trip_body={'mode':'walk','distance_km':1.25,'client_id':'retry-test'}
    first=data(request('/api/v1/carbon/log',trip_body,rider))
    retry=data(request('/api/v1/carbon/log',trip_body,rider))
    assert first['id']==retry['id']
    with concurrent.futures.ThreadPoolExecutor() as pool:
        claims=list(pool.map(lambda _:data(request('/api/v1/habits/claim',{'habit_id':'green_plate'},rider)),range(2)))
    assert sum(r['points_earned'] for r in claims)==50,claims
    balance=data(request('/api/v1/points',token=rider))
    ranks=data(request('/api/v1/leaderboard',token=rider))
    user=data(request('/api/v1/user/profile',token=rider))
    row=next(r for r in ranks if r['user_id']==user['id'])
    assert row['total_points']==balance['total_points'],(row,balance)
    aid=data(request('/api/v1/mutual-aid',{'category':'water','description':'Test water request','latitude':19.2183,'longitude':72.9781},rider))
    nearby=data(request('/api/v1/mutual-aid?lat=19.2183&lon=72.9781&radius_km=5',token=other))
    assert any(r['id']==aid['id'] for r in nearby)
    statuses=[]
    with concurrent.futures.ThreadPoolExecutor() as pool:
        statuses=list(pool.map(lambda token:request(f"/api/v1/mutual-aid/{aid['id']}/coordinate",{},token)[0],[other,driver]))
    assert sorted(statuses)==[200,400],statuses
    departure=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(hours=1)).isoformat()
    listing=data(request('/api/v1/carpool',{'origin':'Test pickup','destination':'Test destination','departure_at':departure,'seats_available':1,'price_points':0,'pickup_lat':19.2183,'pickup_lon':72.9781,'route_geometry':{'type':'LineString','coordinates':[[72.9781,19.2183],[72.99,19.23]]}},driver))
    matches=data(request('/api/v1/carpool/nearby?lat=19.2183&lon=72.9781&radius_km=5',token=rider))
    assert any(r['id']==listing['id'] for r in matches)
    with concurrent.futures.ThreadPoolExecutor() as pool:
        statuses=list(pool.map(lambda token:request(f"/api/v1/carpool/{listing['id']}/book",{},token)[0],[rider,other]))
    assert sorted(statuses)==[200,400],statuses
    report=data(request('/api/v1/reports',{'report_type':'garbage','description':'Disposable test report','latitude':19.2183,'longitude':72.9781,'severity':3,'photo_url':'data:image/jpeg;base64,test'},rider))
    assert report['photo_url']=='data:image/jpeg;base64,test' and report['latitude']==19.2183
    cards=data(request('/api/v1/learn/cards',token=rider))
    if cards:
        with concurrent.futures.ThreadPoolExecutor() as pool:
            results=list(pool.map(lambda _:data(request(f"/api/v1/learn/cards/{cards[0]['id']}/complete",{},rider)),range(2)))
        assert sum(r['points_earned'] for r in results)==cards[0]['points_reward'],results
    assert request('/api/v1/rewards/redeem',{'reward_id':'unknown'},rider)[0]==400
    receipt=data(request('/api/v1/rewards/redeem',{'reward_id':'plant_tree'},rider))
    assert receipt['status']=='pending_fulfillment'
    assert data(request('/api/v1/points',token=rider))['total_points']==receipt['balance']
    print('PASS: auth, carbon decimals, ledger/ranks, civic attachments, aid coordination, carpool concurrency, idempotent learning claims')
if __name__=='__main__':run()
