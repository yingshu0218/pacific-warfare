#!/usr/bin/env python3
"""Restore selected original references from sources.json, without erasing inspection history."""
import argparse,hashlib,json,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/references/ships/essex_cv9_1944_04_15'

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--id',action='append',default=[]);parser.add_argument('--retry-failed',action='store_true');args=parser.parse_args()
 rows=json.loads((OUT/'sources.json').read_text());changed=False
 for row in rows:
  if args.id and row['id'] not in args.id:continue
  path=ROOT/row.get('local_path',str((OUT/'images'/(row['id']+'.jpg')).relative_to(ROOT)))
  if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==row.get('sha256'):
   print(row['id'],'existing original hash matches; inspection history retained');continue
  url=row.get('original_url')
  if not url:
   print(row['id'],'no validated original URL; previously failed/not inspected');continue
  if row.get('error') and not args.retry_failed:
   print(row['id'],'previous retrieval failure retained; use --retry-failed explicitly');continue
  try:
   data=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=40).read()
   path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
   digest=hashlib.sha256(data).hexdigest()
   if digest!=row.get('sha256'):
    row.update(sha256=digest,status='downloaded new bytes; pending original-image visual inspection',bytes=len(data));changed=True
   row.pop('error',None);print(row['id'],len(data),'bytes')
  except Exception as exc:
   row['retrieval_error']=str(exc);changed=True;print(row['id'],str(exc))
 if changed:(OUT/'sources.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
