#!/usr/bin/env python3
"""Independently inspect authored files; these checks do not constitute hearing.

Run via tools/verify.py exec so FFmpeg decoding/oversampling shares its bounded
process group and project render lock. Does not import the synthesis code.
"""
from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import wave

ROOT=Path(__file__).resolve().parents[2]
RATE=48000


def digest(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def local_path(value: str) -> Path:
	path=(ROOT/value).resolve()
	if ROOT not in path.parents: raise ValueError('manifest path outside project')
	return path


def level(value: float) -> float:
	return 20*math.log10(max(abs(value),1e-12))


def decode(path: Path, ffmpeg: str, ffprobe: str) -> tuple[list[array],dict]:
	if path.suffix=='.wav':
		with wave.open(str(path),'rb') as source:
			channels,rate,width,frames=source.getnchannels(),source.getframerate(),source.getsampwidth(),source.getnframes()
			payload=source.readframes(frames)
		if width==2:
			values=array('h');values.frombytes(payload)
			if sys.byteorder!='little': values.byteswap()
			x=array('f',(v/32768 for v in values))
		elif width==3:
			x=array('f',(int.from_bytes(payload[i:i+3],'little',signed=True)/8388608 for i in range(0,len(payload),3)))
		else:
			raise ValueError(f'unsupported PCM width {width}')
		return [x[c::channels] for c in range(channels)],dict(codec='pcm_s'+str(width*8)+'le',rate_hz=rate,channels=channels,bit_depth=width*8,frames=frames,duration_s=frames/rate)
	probe=subprocess.run([ffprobe,'-v','error','-show_entries','stream=codec_name,sample_rate,channels:format=duration','-of','json',str(path)],capture_output=True,text=True,timeout=15,check=True)
	metadata=json.loads(probe.stdout);stream=metadata['streams'][0]
	result=subprocess.run([ffmpeg,'-nostdin','-hide_banner','-loglevel','error','-i',str(path),'-f','f32le','-c:a','pcm_f32le','-'],capture_output=True,timeout=30,check=True)
	x=array('f');x.frombytes(result.stdout)
	if sys.byteorder!='little': x.byteswap()
	channels=int(stream['channels']);rate=int(stream['sample_rate'])
	return [x[c::channels] for c in range(channels)],dict(codec=stream['codec_name'],rate_hz=rate,channels=channels,bit_depth=None,frames=len(x)//channels,duration_s=len(x)/channels/rate,container_duration_s=float(metadata['format']['duration']))


def measurements(channels: list[array], rate: int, loop: bool) -> dict:
	count=len(channels[0]);summaries=[]
	for channel in channels:
		peak=max(abs(min(channel)),abs(max(channel)))
		mean=math.fsum(channel)/count
		energy=math.sqrt(math.fsum(x*x for x in channel)/count)
		start=next((i for i,x in enumerate(channel) if abs(x)>=peak*.1),count)/rate
		trailing=0
		for x in reversed(channel):
			if abs(x)>=.0001: break
			trailing+=1
		last_count=min(round(.1*rate),count)
		tail=math.sqrt(math.fsum(x*x for x in channel[-last_count:])/last_count)
		# Coarse independent texture measurements; not a historical sound classifier.
		a150=math.exp(-math.tau*150/rate);a1500=math.exp(-math.tau*1500/rate)
		l150=l1500=low_energy=high_energy=0.
		for x in channel:
			l150=a150*l150+(1-a150)*x;l1500=a1500*l1500+(1-a1500)*x
			low_energy+=l150*l150;high_energy+=(x-l1500)**2
		row=dict(peak_dbfs=level(peak),rms_dbfs=level(energy),dc_offset=mean,dc_dbfs=level(mean),clipped_samples=sum(abs(x)>=.999969 for x in channel),onset_10percent_peak_s=start,trailing_below_minus80db_s=trailing/rate,last_100ms_rms_dbfs=level(tail),lowpass150_energy_fraction=low_energy/max(energy*energy*count,1e-15),highpass1500_energy_fraction=high_energy/max(energy*energy*count,1e-15))
		if loop:
			step=max(1,count//20000)
			differences=sorted(abs(channel[i]-channel[i-1]) for i in range(1,count,step))
			p99=differences[min(len(differences)-1,round(len(differences)*.99))]
			window=min(round(.02*rate),count//4)
			seam_energy=math.sqrt((math.fsum(x*x for x in channel[:window])+math.fsum(x*x for x in channel[-window:]))/(window*2))
			jump=abs(channel[0]-channel[-1])
			row['loop_boundary']={'jump_linear':jump,'jump_dbfs':level(jump),'neighbor_step_p99':p99,'jump_over_neighbor_p99':jump/max(p99,1e-12),'seam_40ms_rms_ratio':seam_energy/max(energy,1e-12),'first_last_slope_change':max(abs((channel[0]-channel[-1])-(channel[-1]-channel[-2])),abs((channel[1]-channel[0])-(channel[0]-channel[-1])))}
		summaries.append(row)
	correlation=None
	if len(channels)==2:
		left,right=channels
		correlation=math.fsum(a*b for a,b in zip(left,right))/max(1e-15,math.sqrt(math.fsum(x*x for x in left)*math.fsum(x*x for x in right)))
	return {'channels':summaries,'stereo_correlation':correlation}


def true_peak(path: Path, ffmpeg: str) -> float:
	result=subprocess.run([ffmpeg,'-nostdin','-hide_banner','-nostats','-i',str(path),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True,timeout=30,check=True)
	matches=re.findall(r'Peak:\s+([-+\d.]+)\s+dBFS',result.stderr)
	if not matches: raise ValueError('FFmpeg true-peak summary missing for '+str(path))
	return float(matches[-1])


def codec_error(decoded: list[array], reference: Path, ffmpeg: str, ffprobe: str) -> dict:
	baseline,metadata=decode(reference,ffmpeg,ffprobe)
	results=[]
	for actual,original in zip(decoded,baseline):
		count=min(len(actual),len(original))
		error=math.sqrt(math.fsum((actual[i]-original[i])**2 for i in range(count))/count)
		energy=math.sqrt(math.fsum(original[i]*original[i] for i in range(count))/count)
		results.append({'error_rms_dbfs':level(error),'signal_to_error_db':level(energy/max(error,1e-12)),'reference_frames':len(original),'decoded_frames':len(actual)})
	return {'reference_path':str(reference.relative_to(ROOT)),'channels':results,'interpretation':'lossy_codec_difference_only_not_hearing_acceptance'}


def main() -> int:
	parser=argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--manifest',type=Path,default=ROOT/'docs/audio/au01-asset-manifest.json')
	parser.add_argument('--report',type=Path,default=ROOT/'docs/audio/au01-checks.json')
	parser.add_argument('--compare-manifest',type=Path)
	args=parser.parse_args()
	ffmpeg,ffprobe=shutil.which('ffmpeg'),shutil.which('ffprobe')
	if not ffmpeg or not ffprobe: raise RuntimeError('existing FFmpeg/ffprobe required')
	m=json.loads(args.manifest.read_text());issues=[];files=[];check_count=0
	def check(ok: bool, name: str) -> None:
		nonlocal check_count
		check_count+=1
		if not ok: issues.append(name)
	check(len(m['assets'])==17,'17 asset records')
	check(len(m['mixes'])==4,'4 preview records')
	check(m['cost_usd']==m['accounts']==m['paid_services']==m['network_requests']==m['external_recordings']==0,'no spending accounts services external files')
	check(not m['engine_integration'] and not m['listening']['performed'] and not m['public_license_added'],'hearing integration licensing scope honest')
	planned=json.loads((ROOT/'docs/audio/asset-manifest-plan.json').read_text())
	actual_counts={}
	for asset in m['assets']: actual_counts[asset['family']]=actual_counts.get(asset['family'],0)+1
	check(actual_counts==planned['pilot']['selected_family_file_counts'],'exact planned representative family counts')
	check(digest(local_path(m['recipe_path']))==m['recipe_sha256'],'recipe hash')
	check(digest(local_path(m['generator_path']))==m['generator_sha256'],'generator hash')
	timeline_path=local_path(m['timelines_path']);timeline=json.loads(timeline_path.read_text())
	check(digest(timeline_path)==m['timelines_sha256'],'offline timeline hash')
	used={x['asset'] for mix in timeline['mixes'] for kind in ['events','beds'] for x in mix[kind]}
	check(used=={x['id'] for x in m['assets']},'all 17 representative assets occur in audition contexts')
	for asset in m['assets']:
		for kind in ['source','master','runtime']:
			path=local_path(asset[kind+'_path'])
			print('Inspecting '+asset['id']+' '+kind,flush=True)
			check(path.is_file(),str(path)+' exists')
			check(digest(path)==asset[kind+'_sha256'],str(path)+' hash')
			channels,fmt=decode(path,ffmpeg,ffprobe)
			stats=measurements(channels,fmt['rate_hz'],asset['loop'])
			check(fmt['rate_hz']==RATE and fmt['channels']==asset['channels'],str(path)+' rate/channels')
			check(fmt['frames']==round(asset['seconds']*RATE),str(path)+' exact decoded sample count')
			if kind!='runtime': check(fmt['bit_depth']==24,str(path)+' 24-bit authoring')
			elif asset['channels']==1: check(fmt['bit_depth']==16,str(path)+' 16-bit positioning sound')
			else: check(fmt['codec']=='vorbis',str(path)+' environment Vorbis')
			for index,channel in enumerate(stats['channels']):
				prefix=str(path)+f' channel {index}'
				check(channel['clipped_samples']==0,prefix+' unclipped')
				check(channel['peak_dbfs']<=-2.99,prefix+' source/master/runtime peak headroom')
				check(abs(channel['dc_offset'])<.001,prefix+' DC offset')
				check(channel['rms_dbfs']>-75,prefix+' nonempty signal')
				if asset['loop']:
					seam=channel['loop_boundary']
					check(seam['jump_linear']<=max(.0002,2*seam['neighbor_step_p99']),prefix+' seam step within local slope scale')
					check(seam['seam_40ms_rms_ratio']>.05,prefix+' no silent boundary gap')
				else:
					check(channel['onset_10percent_peak_s']<.02,prefix+' prompt onset')
					check(channel['trailing_below_minus80db_s']<min(.5,asset['seconds']*.7),prefix+' no excessive empty tail')
			row={'asset_id':asset['id'],'layer':kind,'path':str(path.relative_to(ROOT)),'sha256':digest(path),'bytes':path.stat().st_size,'format':fmt,**stats}
			if kind=='runtime':
				row['estimated_true_peak_db']=true_peak(path,ffmpeg)
				check(row['estimated_true_peak_db']<=-2.9,str(path)+' oversampled headroom')
				if path.suffix=='.ogg': row['codec_difference']=codec_error(channels,local_path(asset['master_path']),ffmpeg,ffprobe)
			files.append(row)
	for preview in m['mixes']:
		for kind in ['wav','ogg']:
			path=local_path(preview[kind+'_path']);print('Inspecting preview '+preview['id']+' '+kind,flush=True)
			check(digest(path)==preview[kind+'_sha256'],str(path)+' hash')
			channels,fmt=decode(path,ffmpeg,ffprobe);stats=measurements(channels,RATE,False)
			check(fmt['rate_hz']==RATE and fmt['channels']==2 and fmt['frames']==32*RATE,str(path)+' stereo 32-second preview')
			peak=true_peak(path,ffmpeg)
			check(peak<=-1,str(path)+' preview true peak ceiling')
			check(all(x['clipped_samples']==0 for x in stats['channels']),str(path)+' preview unclipped')
			check(all(-45<x['rms_dbfs']<-10 for x in stats['channels']),str(path)+' preview energy present')
			check(not preview['gameplay_evidence'],str(path)+' no fake runtime evidence')
			row={'preview_id':preview['id'],'layer':kind,'path':str(path.relative_to(ROOT)),'sha256':digest(path),'bytes':path.stat().st_size,'format':fmt,'estimated_true_peak_db':peak,**stats}
			if kind=='ogg': row['codec_difference']=codec_error(channels,local_path(preview['wav_path']),ffmpeg,ffprobe)
			files.append(row)
	ids={a['id']:a for a in m['assets']}
	check(ids['heavy_01']['master_sha256']!=ids['heavy_02']['master_sha256'],'heavy variants distinct payload')
	check(len({ids[x]['master_sha256'] for x in ['fighter_low','fighter_cruise','fighter_high']})==3,'three distinct power states')
	comparison={'performed':False}
	if args.compare_manifest:
		other=json.loads(args.compare_manifest.read_text());other_assets={x['id']:x for x in other['assets']};other_mixes={x['id']:x for x in other['mixes']}
		count=0;mismatches=[]
		for asset in m['assets']:
			for layer in ['source','master','runtime']:
				count+=1
				if digest(local_path(asset[layer+'_path']))!=digest(local_path(other_assets[asset['id']][layer+'_path'])): mismatches.append(asset['id']+':'+layer)
		for preview in m['mixes']:
			for layer in ['wav','ogg']:
				count+=1
				if digest(local_path(preview[layer+'_path']))!=digest(local_path(other_mixes[preview['id']][layer+'_path'])): mismatches.append(preview['id']+':'+layer)
		for field in ['recipe_path','timelines_path']:
			count+=1
			if digest(local_path(m[field]))!=digest(local_path(other[field])): mismatches.append(field)
		check(not mismatches,'isolated rebuild byte-identical audio payloads')
		comparison={'performed':True,'audio_payloads_compared':count-2,'recipe_and_timeline_files_compared':2,'mismatches':mismatches,'scope':'same_host_and_recorded_toolchain_not_cross_platform_libm_guarantee'}
	report={'schema_version':1,'task':'AU01','status':'passed' if not issues else 'failed','checks':check_count,'failures':issues,'checker_path':'tools/audio/check_au01.py','checker_sha256':digest(Path(__file__)),'method':'independent_actual_file_read_WAV_and_FFmpeg_decode_ebur128_oversampled_peak','hearing_performed':False,'hearing_status':'pending_not_substituted_by_waveform_checks','game_runtime_tested':False,'files':files,'rebuild':comparison,'totals':{'runtime_files':17,'preview_clips':4,'source_bytes':sum(x['bytes'] for x in files if x['layer']=='source'),'master_bytes':sum(x['bytes'] for x in files if x['layer']=='master'),'runtime_bytes':sum(x['bytes'] for x in files if x['layer']=='runtime'),'preview_wav_bytes':sum(x['bytes'] for x in files if x.get('preview_id') and x['layer']=='wav'),'preview_ogg_bytes':sum(x['bytes'] for x in files if x.get('preview_id') and x['layer']=='ogg')}}
	args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
	print(json.dumps({k:report[k] for k in ['status','checks','failures','rebuild','totals']},ensure_ascii=False),flush=True)
	return 0 if not issues else 1


if __name__=='__main__':
	raise SystemExit(main())
