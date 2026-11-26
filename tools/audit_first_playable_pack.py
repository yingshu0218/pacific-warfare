#!/usr/bin/env python3
"""Audit the actual ordinary PCK against the admitted build manifest."""
import argparse,hashlib,json,re,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def audit(pack):
    data=pack.read_bytes();magic,version,major,minor,patch,flags,base,directory=struct.unpack_from('<6I2Q',data)
    assert magic==0x43504447 and version==4 and (major,minor,patch)==(4,7,2)
    count=struct.unpack_from('<I',data,directory)[0];cursor=directory+4;entries=[];payloads={}
    for _ in range(count):
        length=struct.unpack_from('<I',data,cursor)[0];cursor+=4
        name=data[cursor:cursor+length].rstrip(b'\0').decode();cursor+=length
        offset,size,digest,entry_flags=struct.unpack_from('<QQ16sI',data,cursor);cursor+=36
        payload=data[base+offset:base+offset+size]
        assert len(payload)==size and hashlib.md5(payload).digest()==digest,name
        payloads[name]=payload;entries.append({'path':name,'bytes':size,'md5':digest.hex()})
    manifest=json.loads((pack.parent/'build_manifest.json').read_text());remaps={}
    output_hashes={}
    for name,expected in manifest['outputs'].items():
        path=pack.parent/name
        actual={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        assert actual==expected,('Output changed after build',name)
        output_hashes[name]=actual
    for name,expected in manifest['root_sources'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected,('Runtime source changed after build',name)
    assert hashlib.sha256((ROOT/'tools/showcase_runtime.json').read_bytes()).hexdigest()==manifest['admission_manifest_sha256']
    for name,payload in payloads.items():
        if name.endswith('.remap'):
            for target in re.findall(r'path="res://([^"]+)"',payload.decode()):
                assert target in payloads,(name,target)
                remaps[name[:-6]]=target
    def exists(name):return name in payloads or name in remaps or name+'.import' in payloads
    checked_json=[]
    for name,digest in manifest['sources'].items():
        if name in ['shell.html','export_presets.cfg','project.godot'] or name.endswith('.uid'):continue
        assert exists(name),name
        if name.endswith('.json'):
            assert hashlib.sha256(payloads[name]).hexdigest()==digest,name
            checked_json.append(name)
        if name.endswith('.import'):
            for target in re.findall(rb'"res://(\.godot/imported/[^\"]+)"',payloads[name]):assert target.decode() in payloads,(name,target)
    forbidden=[name for name in payloads if re.search(r'(^|/)(docs|tests|tools|research|references|screenshots|evidence|au01|essex_cv9_1944_04_15|expanded)(/|$)|\.(pdf|md|zip|gz|bak)$',name,re.I)]
    assert not forbidden,forbidden
    assert manifest['entry'].encode() in payloads['project.binary']
    models=[]
    for name in checked_json:
        if name.startswith('data/units/') and '/' not in name[len('data/units/'):]:
            definition=json.loads(payloads[name]);model=definition.get('model_scene','').removeprefix('res://')
            assert model and exists(model),model
            models.append({'id':definition['id'],'scene':model})
    assert len(models)==9,models
    for name in ['scripts/presentation/environment/cloud_noise.png','scripts/presentation/environment/wave_slopes.png','assets/fonts/NotoSansCJKsc-Regular.otf','assets/fonts/LICENSE.txt']:assert exists(name),name
    assert 'run/main_scene="res://scenes/main.tscn"' in (ROOT/'project.godot').read_text()
    return {'pck_sha256':hashlib.sha256(data).hexdigest(),'pck_bytes':len(data),'entry':manifest['entry'],'engine':[major,minor,patch],'entry_count':count,'payload_md5_all_match':True,'output_sha256_all_match':True,'root_sources_all_match':True,'output_hashes':output_hashes,'json_files':checked_json,'models':models,'forbidden':forbidden,'remaps_checked':len(remaps),'entries':entries}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=ROOT/'docs/showcase/evidence/S08/final-20261111/pack_audit.json');args=parser.parse_args()
    result=audit(ROOT/'build/first-playable/index.pck');args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['entries','json_files']},ensure_ascii=False))
