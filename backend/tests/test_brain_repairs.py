import json
import httpx
import pytest
from app.config import Settings
from app.brain.llm import LLMChain
from app.brain.mythos import OpenMythos
from app.brain.tools.registry import ToolRegistry
from app.brain.tools.base import BaseTool
from app.brain.tools.builtin.tavily_search import TavilySearch
from app.brain.tools.builtin.openalex_search import OpenAlexSearch
from app.brain.amygdala import Amygdala
from app.brain.seal import SEALLoop
from app.brain.models.schemas import SystemState

@pytest.fixture
def settings(tmp_path):
    return Settings(_env_file=None, sqlite_db_path=str(tmp_path/'brain.db'), ollama_enabled=False, gemini_api_key='test-gemini', groq_api_key='test-groq', mistral_enabled=False)

@pytest.mark.asyncio
async def test_gemini_falls_back_after_rate_limit(settings):
    calls=[]
    def handler(request):
        calls.append(request.url.host)
        if 'googleapis' in request.url.host: return httpx.Response(429)
        assert request.headers['Authorization']=='Bearer test-groq'
        return httpx.Response(200,json={'choices':[{'message':{'content':'Use public transit.'}}]})
    chain=LLMChain(settings,httpx.MockTransport(handler))
    assert await chain.chat([{'role':'user','content':'Help me reduce emissions'}])=='Use public transit.'
    assert chain.active=='groq'
    assert calls==['generativelanguage.googleapis.com','api.groq.com']

@pytest.mark.asyncio
async def test_gemini_system_and_history_contract(settings):
    def handler(request):
        body=json.loads(request.content)
        assert request.headers['x-goog-api-key']=='test-gemini'
        assert body['systemInstruction']['parts'][0]['text']=='Speak plainly'
        assert body['contents'][0]['role']=='model'
        return httpx.Response(200,json={'candidates':[{'content':{'parts':[{'text':'Plant '},{'text':'trees.'}]}}]})
    chain=LLMChain(settings,httpx.MockTransport(handler))
    assert await chain.chat([{'role':'system','content':'Speak plainly'},{'role':'assistant','content':'Hi'},{'role':'user','content':'Help'}])=='Plant trees.'
    assert chain.active=='gemini'

@pytest.mark.asyncio
async def test_no_provider_never_fakes_answer(settings):
    settings.gemini_enabled=False; settings.groq_enabled=False
    with pytest.raises(RuntimeError,match='unavailable'): await LLMChain(settings).chat([{'role':'user','content':'Help'}])

@pytest.mark.asyncio
async def test_empty_provider_response_falls_back(settings):
    def handler(r):
        if 'googleapis' in r.url.host:return httpx.Response(200,json={'candidates':[]})
        return httpx.Response(200,json={'choices':[{'message':{'content':'Valid'}}]})
    assert await LLMChain(settings,httpx.MockTransport(handler)).chat([{'role':'user','content':'Help'}])=='Valid'

@pytest.mark.asyncio
async def test_tavily_bound_and_sources(settings):
    settings.tavily_api_key='test-tavily'
    def handler(r):
        assert json.loads(r.content)['max_results']==5
        assert r.headers['Authorization']=='Bearer test-tavily'
        return httpx.Response(200,json={'results':[{'title':'Evidence','url':'https://example.org/paper','content':'x'*2000}]})
    result=await TavilySearch(settings,httpx.MockTransport(handler)).execute('verify climate claim')
    assert len(result['sources'][0]['excerpt'])==1500
    assert result['sources'][0]['url']=='https://example.org/paper'

@pytest.mark.asyncio
async def test_missing_tavily_key_fails(settings):
    settings.tavily_api_key=None
    record=await TavilySearch(settings).safe_execute(query='claim')
    assert record.error_message=='Tavily is not configured'

@pytest.mark.asyncio
async def test_openalex_returns_doi_not_peer_review_claim(settings):
    def handler(r):
        assert r.url.params['filter']=='type:article,primary_location.source.type:journal'
        return httpx.Response(200,json={'results':[{'display_name':'Climate study','doi':'https://doi.org/test','publication_year':2025}]})
    result=await OpenAlexSearch(settings,httpx.MockTransport(handler)).execute('climate')
    assert result['papers'][0]['url']=='https://doi.org/test'
    assert result['papers'][0]['peer_review_status']=='not independently verified'

@pytest.mark.asyncio
@pytest.mark.parametrize('query',['','x'*1001])
async def test_research_rejects_invalid_queries(settings,query):
    with pytest.raises(ValueError): await OpenAlexSearch(settings).execute(query)

def test_mythos_survives_relaunch_and_filters(settings):
    memory=OpenMythos(settings)
    id=memory.remember('Solar panels avoid coal emissions',memory_type='research')
    memory.close()
    restored=OpenMythos(settings)
    assert restored.get_memory_count()==1
    assert restored.recall('solar',memory_type='research')[0].id==id
    assert restored.recall('solar',memory_type='other')==[]
    restored.close()

class Tool(BaseTool):
    name='test_tool'; description='Noncritical test tool'
    async def execute(self,**kwargs):return {}
class Critical(Tool):
    name='critical'
    is_critical=True

@pytest.mark.asyncio
async def test_amygdala_sheds_then_restores_tools(settings):
    memory=OpenMythos(settings); registry=ToolRegistry();registry.register(Tool());registry.register(Critical())
    amygdala=Amygdala(settings,memory,registry)
    await amygdala.enter_survival_mode('High load')
    assert not registry.is_tool_active('test_tool')
    assert registry.is_tool_active('critical')
    await amygdala.exit_survival_mode()
    assert registry.is_tool_active('test_tool')
    memory.close()

@pytest.mark.asyncio
async def test_seal_cycle_records_all_phases(settings,monkeypatch):
    memory=OpenMythos(settings); registry=ToolRegistry()
    seal=SEALLoop(settings,memory,registry)
    async def sense():return {'cpu_percent':10,'memory_percent':20,'disk_percent':20,'errors_last_hour':0}
    monkeypatch.setattr(seal,'_sense',sense)
    result=await seal.run_once()
    assert result.anomalies==[]
    assert seal.cycle_count==1
    phases={e.event_type.value for e in memory.get_recent_events()}
    assert {'SENSE','EVALUATE','LEARN'}<=phases
    assert memory.get_memory_count()>0
    memory.close()

def test_pdf_corpus_ingestion_is_durable_and_idempotent(settings,tmp_path):
    from pypdf import PdfWriter
    from pypdf.generic import DecodedStreamObject,NameObject,DictionaryObject
    from app.brain.research_corpus import ingest_papers
    writer=PdfWriter(); page=writer.add_blank_page(width=300,height=300)
    font=DictionaryObject({NameObject('/Type'):NameObject('/Font'),NameObject('/Subtype'):NameObject('/Type1'),NameObject('/BaseFont'):NameObject('/Helvetica')})
    page[NameObject('/Resources')]=DictionaryObject({NameObject('/Font'):DictionaryObject({NameObject('/F1'):writer._add_object(font)})})
    stream=DecodedStreamObject();stream.set_data(b'BT /F1 12 Tf 10 100 Td (Solar energy avoids coal emissions.) Tj ET')
    page[NameObject('/Contents')]=writer._add_object(stream)
    folder=tmp_path/'papers';folder.mkdir()
    with open(folder/'study.pdf','wb') as file:writer.write(file)
    (folder/'corrupt.pdf').write_bytes(b'not a PDF')
    memory=OpenMythos(settings)
    assert ingest_papers(memory,folder)==1
    assert ingest_papers(memory,folder)==0
    record=memory.recall('solar',memory_type='research')[0]
    assert record.metadata['page']==1
    assert record.metadata['peer_review_status']=='not independently verified'
    memory.close()
