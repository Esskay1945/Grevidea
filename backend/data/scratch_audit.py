import sys
import re

sys.stdout.reconfigure(encoding='utf-8')

with open('C:/Users/Sid/.gemini/antigravity-ide/brain/4329e3f1-76c1-4f6e-ae61-66445789f9be/scratch/docs_summary.txt', encoding='utf-8') as f:
    text = f.read()

# Search for GreenPulse_NetNew_Features and Grevidea_Project_Document sections
files = re.split(r'=== FILE: (.*?) ===', text)

summary_out = []

for i in range(1, len(files), 2):
    fname = files[i]
    fcontent = files[i+1]
    summary_out.append(f"\n==========================================")
    summary_out.append(f"DOC: {fname}")
    summary_out.append(f"Content length: {len(fcontent)}")
    summary_out.append(f"==========================================")
    
    # Extract headings, tables, or feature lists
    lines = fcontent.split('\n')
    for line in lines:
        if any(w in line.lower() for w in ['dataset', 'database', 'cpcb', 'openaq', 'emission', 'module', 'feature', 'table', 'gap', 'api', 'architecture']):
            summary_out.append(line[:160])

with open('C:/Users/Sid/.gemini/antigravity-ide/brain/4329e3f1-76c1-4f6e-ae61-66445789f9be/scratch/extracted_features_datasets.txt', 'w', encoding='utf-8') as out:
    out.write('\n'.join(summary_out))

print("Extracted", len(summary_out), "lines of dataset/feature mentions")
