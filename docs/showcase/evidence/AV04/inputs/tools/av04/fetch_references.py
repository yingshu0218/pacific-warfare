from pathlib import Path
import concurrent.futures,json,urllib.request
root=Path('docs/references/aircraft/b25j_1944_07/originals')
links=json.loads((root/'ipms-photo-links.json').read_text())
base='https://www.ipms.nl/images/foto-specials/WA_vliegtuigen/B-25J-MLM/B25J-MLM1'
urls=[u for u in links[base] if int(u.rsplit('-',1)[-1].split('.')[0]) in [1,2,3,4,8,10,18,20]]
urls = ['https://www.richard-seaman.com/Aircraft/AirShows/Chino2008/Highlights/B25Chino08.jpg','https://www.richard-seaman.com/Aircraft/AirShows/MarchField2004/Sampler/HeavenlyBodyFlying.jpg','https://www.militaryaviationmuseum.org/wp-content/uploads/B-25-Wild-Cargo-from-the-MAM-Photo-Archives-1102x720.jpg']

def fetch(u):
 p=root/(u.rsplit('/',1)[-1])
 if p.exists(): return [p.name,'existing']
 try:
  with urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=22) as r:p.write_bytes(r.read())
  return [p.name,p.stat().st_size]
 except Exception as e:return [p.name,str(e)]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex: print(json.dumps(list(ex.map(fetch,urls))))
