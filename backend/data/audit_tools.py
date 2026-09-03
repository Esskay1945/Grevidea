import os
import re

tools_dir = r"c:\Users\Sid\Pictures\Siddharth data\Projects\Grevidea\backend\axum_gateway\src\tools"

tools_audit = []

for fname in os.listdir(tools_dir):
    if not fname.endswith('.rs') or fname == 'mod.rs':
        continue
    fpath = os.path.join(tools_dir, fname)
    with open(fpath, encoding='utf-8') as f:
        content = f.read()
    
    # Find tool markers like T01, T02, etc.
    lines = content.split('\n')
    current_tool = None
    for i, line in enumerate(lines):
        # Look for comments like "// ── T01" or "/// T01" or "pub async fn"
        m = re.search(r'T\d{1,2}[a-z]?', line)
        if m and ('──' in line or '///' in line or 'EPIC' in line or 'Tool' in line):
            current_tool = line.strip()
            tools_audit.append({
                'file': fname,
                'line': i + 1,
                'header': current_tool,
                'snippet': '\n'.join(lines[i:min(len(lines), i+25)])
            })

print(f"Found {len(tools_audit)} tool sections in Axum gateway")

with open('C:/Users/Sid/.gemini/antigravity-ide/brain/4329e3f1-76c1-4f6e-ae61-66445789f9be/scratch/axum_tools_audit.txt', 'w', encoding='utf-8') as out:
    for t in tools_audit:
        out.write(f"\n[{t['file']}:L{t['line']}] {t['header']}\n")
        # Check characteristics in snippet
        s = t['snippet']
        db_call = 'sqlx::query' in s
        api_call = 'http.get' in s or 'http.post' in s or 'reqwest' in s or 'api.openaq' in s or 'api.openweathermap' in s
        brain_call = 'state.brain' in s or 'brain_client' in s
        mock = 'mock' in s.lower() or 'todo' in s.lower() or 'fallback' in s.lower() or 'simulat' in s.lower()
        out.write(f"  DB: {db_call} | External API: {api_call} | Brain Call: {brain_call} | Has Mock/Sim: {mock}\n")
