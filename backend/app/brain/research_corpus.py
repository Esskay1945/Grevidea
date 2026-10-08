"""Import supplied local research PDFs into durable Mythos memory.
Configure RESEARCH_PDF_DIR; the checkout contains no research PDFs by default.
"""
import hashlib
from pathlib import Path

def ingest_papers(mythos, directory):
    from pypdf import PdfReader
    folder=Path(directory)
    if not folder.is_dir():raise ValueError('Research PDF directory not found')
    imported=0
    for path in sorted(folder.glob('*.pdf')):
        if path.stat().st_size>50_000_000:continue
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        existing=mythos._conn.execute('SELECT 1 FROM semantic_memories WHERE metadata LIKE ?',('%'+digest+'%',)).fetchone()
        if existing:continue
        try:
            pages=PdfReader(path).pages
            for number,page in enumerate(pages,1):
                text=page.extract_text() or ''
                for start in range(0,len(text),1800):
                    chunk=text[start:start+1800].strip()
                    if chunk:mythos.remember(chunk,source='local_research_pdf',memory_type='research',metadata={'paper':path.name,'page':number,'sha256':digest,'peer_review_status':'not independently verified'})
            imported+=1
        except Exception:
            # A corrupt/encrypted paper cannot silently become verified evidence.
            continue
    return imported
