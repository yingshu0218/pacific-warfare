from pathlib import Path
import fitz,re,json,hashlib
root=Path(__file__).resolve().parents[2]
source=root/'docs/references/bomb01/OP-1667-V1.pdf'
out=root/'docs/references/bomb01/pages';out.mkdir(parents=True,exist_ok=True)
doc=fitz.open(source);matches=[]
for i,page in enumerate(doc):
 text=page.get_text()
 clean=re.sub('[^a-z0-9]','',text.lower())
 if ('type97no6land' in clean or ('no25landbomb' in clean and 'totalweight' in clean) or ('type97mk2' in clean and 'operation' in clean)):
  matches.append({'pdf_index':i,'text':text})
  page.get_pixmap(matrix=fitz.Matrix(1.5,1.5)).save(out/f'OP1667-p{i+1:03d}.png')
  (out/f'OP1667-p{i+1:03d}.txt').write_text(text)
record={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'url':'https://stephentaylorhistorian.com/wp-content/uploads/2020/09/op-1667-japanese-explosive-ordnance-volume-1.pdf','pages':len(doc),'matches':matches}
(out/'extraction.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'pages':len(doc),'matching_indices':[x['pdf_index'] for x in matches]}))
