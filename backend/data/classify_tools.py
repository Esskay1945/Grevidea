import os
import re

tools_dir = r"c:\Users\Sid\Pictures\Siddharth data\Projects\Grevidea\backend\axum_gateway\src\tools"

tool_map = {}

# Parse tools
for fname in os.listdir(tools_dir):
    if not fname.endswith('.rs') or fname == 'mod.rs':
        continue
    fpath = os.path.join(tools_dir, fname)
    with open(fpath, encoding='utf-8') as f:
        text = f.read()
    
    # split by tool headers
    parts = re.split(r'(//\s*──\s*T\d{2}[a-z]?\b.*?──+)', text)
    for i in range(1, len(parts), 2):
        header = parts[i].strip()
        body = parts[i+1] if i+1 < len(parts) else ""
        
        m_id = re.search(r'(T\d{2}[a-z]?)', header)
        tool_id = m_id.group(1) if m_id else "UNKNOWN"
        
        # Check DB queries
        db_tables = re.findall(r'(?:FROM|INTO|UPDATE|JOIN)\s+([a-zA_Z_0-9]+)', body, re.IGNORECASE)
        # Check external APIs
        apis = re.findall(r'https?://[^\s"\'\)]+', body)
        # Check GCI Brain calls
        brain = 'state.brain' in body
        # Check mock / hardcoded / fallback
        has_mock = any(w in body.lower() for w in ['mock', 'todo', 'fallback', 'simulat', 'dummy', 'hardcoded'])
        
        tool_map[tool_id] = {
            'file': fname,
            'header': header,
            'tables': list(set(db_tables)),
            'apis': list(set(apis)),
            'brain': brain,
            'has_mock': has_mock,
            'body_len': len(body)
        }

print(f"Total tools mapped: {len(tool_map)}")
for tid in sorted(tool_map.keys()):
    t = tool_map[tid]
    print(f"{tid:6} | {t['file']:15} | DB: {len(t['tables'])} tbls {t['tables']} | APIs: {len(t['apis'])} {t['apis']} | Brain: {t['brain']} | Mock: {t['has_mock']}")
