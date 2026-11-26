#!/usr/bin/env python3
"""Author AU01 locally with Python's standard library and installed FFmpeg.

Run under tools/verify.py exec. No network, accounts, downloaded audio, AI API,
Godot invocation, or runtime integration. All signals are generic designed audio.
"""
from __future__ import annotations

import argparse
from array import array
from dataclasses import asdict, dataclass
import hashlib
import json
import math
from pathlib import Path
import random
import shutil
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
RATE = 48000
TAU = math.tau
AUTHORING_VERSION = "AU01-original-dsp-v1"


@dataclass(frozen=True)
class Spec:
	id: str
	family: str
	state: str
	seconds: float
	channels: int
	loop: bool
	seed: int
	peak_db: float
	recipe: str
	variant: int = 1


SPECS = [
	Spec("fighter_low", "fighter_radial_power", "low", 4, 1, True, 110101, -14,
		"harmonic prop pressure + combustion pulses + band-limited induction; low power"),
	Spec("fighter_cruise", "fighter_radial_power", "cruise", 4, 1, True, 110102, -10,
		"same oscillator architecture; higher pulse rate, induction and loading"),
	Spec("fighter_high", "fighter_radial_power", "high", 4, 1, True, 110103, -8,
		"denser combustion and prop harmonics; high power without fictitious measured RPM"),
	Spec("ship_idle", "ship_propulsion", "idle", 4, 1, True, 110104, -18,
		"low machinery bed, sparse shaft modulation and soft turbine harmonics"),
	Spec("ship_run", "ship_propulsion", "run", 4, 1, True, 110105, -12,
		"loaded machinery bed, prop pressure modulation, restrained turbine whine"),
	Spec("heavy_01", "gun_heavy", "event", 3.5, 1, False, 110106, -6,
		"short pressure crack, falling bass chirp, diffuse low tail and sparse reflections"),
	Spec("heavy_02", "gun_heavy", "event", 3.5, 1, False, 110107, -6,
		"independent excitation, body frequencies and reflection timing", 2),
	Spec("medium", "gun_medium", "event", 1.5, 1, False, 110108, -8,
		"shorter higher artillery body with dry transient and recoil texture"),
	Spec("autocannon", "autocannon", "event", .4, 1, False, 110109, -10,
		"one actual report grain: fast crack, upper body chirp and mechanical reset"),
	Spec("machinegun", "machinegun", "event", .12, 1, False, 110110, -12,
		"one short report: high transient, small body and delayed mechanism tick"),
	Spec("airburst", "airburst", "event", 1, 1, False, 110111, -10,
		"diffuse expanding pressure pop; no metallic ring or water return"),
	Spec("water", "impact_water", "event", 1.8, 1, False, 110112, -10,
		"soft low displacement + delayed spray grains + descending bubble resonances"),
	Spec("land", "impact_land", "event", .9, 1, False, 110113, -10,
		"dry ground thud + short high crack + individually timed debris grains"),
	Spec("metal", "impact_metal", "event", 1, 1, False, 110114, -11,
		"short excitation of six inharmonic damped metal modes"),
	Spec("fire", "burning", "loop", 4, 1, True, 110115, -24,
		"modulated flame turbulence plus sparse deterministic small crackles"),
	Spec("wind", "ambient_wind", "loop", 12, 2, True, 110116, -25,
		"correlated stereo colored air with slow periodic gusts; no combat bed"),
	Spec("coast", "ambient_coast", "loop", 16, 2, True, 110117, -21,
		"three long swell/foam/wash cycles with correlated stereo water texture"),
]


def db_gain(db: float) -> float:
	return 10.0 ** (db / 20.0)


def sha256(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path: Path) -> str:
	return str(path.resolve().relative_to(ROOT))


def rms(samples: array) -> float:
	return math.sqrt(math.fsum(x * x for x in samples) / max(1, len(samples)))


def band_noise(count: int, low: float, high: float, seed: int, periodic: bool = False) -> array:
	"""Independent deterministic excitation; circular warmup for periodic beds."""
	rng = random.Random(seed)
	white = array("f", (rng.random() * 2 - 1 for _ in range(count)))
	a_hi = math.exp(-TAU * high / RATE)
	a_lo = math.exp(-TAU * low / RATE) if low > 0 else 1.0
	hi_state = 0.0
	lo_state = 0.0
	output = array("f")
	for turn in range(2 if periodic else 1):
		output = array("f")
		for value in white:
			hi_state = a_hi * hi_state + (1 - a_hi) * value
			lo_state = a_lo * lo_state + (1 - a_lo) * value
			output.append(hi_state - lo_state)
	scale = .32 / max(rms(output), .000001)
	return array("f", (x * scale for x in output))


def chirp_phase(t: float, start: float, end: float, decay: float) -> float:
	return TAU * (end * t - (start - end) * math.expm1(-decay * t) / decay)


def bridge_cycle(samples: array, window: int = 144) -> None:
	"""Short periodic C1 bridge, without fading a loop to silence at its ends."""
	n = len(samples)
	width = min(window, n // 8)
	first = float(samples[-width])
	last = float(samples[width])
	tangent_limit = max(abs(first), abs(last), .03) * 2
	m0 = max(-tangent_limit, min(tangent_limit, (samples[-width + 1] - samples[-width - 1]) * width))
	m1 = max(-tangent_limit, min(tangent_limit, (samples[width + 1] - samples[width - 1]) * width))
	for index in range(2 * width):
		u = index / (2 * width)
		u2, u3 = u * u, u * u * u
		value = (2*u3 - 3*u2 + 1)*first + (u3 - 2*u2 + u)*m0 + (-2*u3 + 3*u2)*last + (u3 - u2)*m1
		samples[(n - width + index) % n] = value


def prepare(samples: array, loop: bool, peak_db: float) -> array:
	output = array("f", samples)
	if loop:
		bridge_cycle(output)
		mean = math.fsum(output) / len(output)
		output = array("f", (x - mean for x in output))
	else:
		# Weighted DC removal retains zero endpoints and the report's short attack.
		fade = max(16, int(.001 * RATE))
		end_fade = min(int(.04 * RATE), len(output) // 8)
		weights = array("f", (min(1., i/fade, (len(output)-1-i)/max(1, end_fade)) for i in range(len(output))))
		weighted_mean = math.fsum(x*w for x, w in zip(output, weights)) / math.fsum(weights)
		output = array("f", ((x - weighted_mean) * w for x, w in zip(output, weights)))
	peak = max(abs(min(output)), abs(max(output)))
	if peak < 1e-9:
		raise ValueError("silent generated signal")
	scale = db_gain(peak_db) / peak
	return array("f", (x * scale for x in output))


def fighter(spec: Spec) -> list[array]:
	n = round(spec.seconds * RATE)
	shaft, combustion, air = {"low":(16,84,.15), "cruise":(22,132,.23), "high":(29,174,.34)}[spec.state]
	induction = band_noise(n, 150, 3000, spec.seed, True)
	rumble = band_noise(n, 30, 320, spec.seed + 1000, True)
	values = array("f")
	for i in range(n):
		t = i / RATE
		prop = TAU * shaft * 3 * t
		fire_phase = TAU * combustion * t + .09 * math.sin(TAU * .5 * t)
		load = .94 + .04 * math.sin(TAU * .25 * t + .4)
		pressure = .26*math.sin(prop) + .12*math.sin(2*prop+.32) + .045*math.sin(3*prop+.7)
		comb = .22*math.sin(fire_phase) + .095*math.sin(2*fire_phase+.9) + .04*math.sin(4*fire_phase+.5)
		pulse = .62 + .24 * math.sin(prop + .5) ** 2
		values.append(load * (pressure + comb + .26*rumble[i] + air*induction[i]*pulse))
	return [values]


def ship(spec: Spec) -> list[array]:
	n = round(spec.seconds * RATE)
	run = spec.state == "run"
	low = band_noise(n, 25, 360 if run else 240, spec.seed, True)
	gear = band_noise(n, 250, 1500, spec.seed + 1000, True)
	prop = 16 if run else 7
	turbine = 426 if run else 266
	values = array("f")
	for i in range(n):
		t = i / RATE
		load = .78 + .16*math.sin(TAU*.25*t+.7)
		rotation = .8 + .2*math.sin(TAU*prop*t)
		body = .13*math.sin(TAU*43*t) + .085*math.sin(TAU*86*t+.2) + .07*math.sin(TAU*prop*4*t)
		whine = .035*math.sin(TAU*turbine*t) + .012*math.sin(TAU*turbine*2*t+.8)
		values.append(load*(.6*low[i]*rotation + .09*gear[i] + body + whine))
	return [values]


def report(spec: Spec) -> list[array]:
	n = round(spec.seconds * RATE)
	crack = band_noise(n, 700, 10000, spec.seed)
	body = band_noise(n, 35, 800, spec.seed + 1000)
	tail = band_noise(n, 70, 1800, spec.seed + 2000)
	values = array("f")
	if spec.family == "gun_heavy":
		start, end = (156., 44.) if spec.variant == 1 else (139., 51.)
		for i in range(n):
			t = i/RATE
			attack = 1 - math.exp(-t/.0008)
			pressure = .82*math.sin(chirp_phase(t,start,end,19))*math.exp(-t/.23)
			low = .31*body[i]*math.exp(-t/.36)
			bang = 1.7*crack[i]*math.exp(-t/.013)
			diffuse = .13*tail[i]*(1-math.exp(-t/.025))*math.exp(-t/.72)
			values.append(attack*(pressure+low+bang+diffuse))
		# Reflections remain designed layers, not extra firing events.
		base = array("f", values)
		for delay, gain in ([(.047,.16),(.121,.10),(.263,.065)] if spec.variant==1 else [(.059,.14),(.143,.11),(.311,.06)]):
			offset = round(delay*RATE)
			for i in range(offset,n):
				values[i] += base[i-offset]*gain*math.exp(-(i-offset)/RATE/.42)
	elif spec.family == "gun_medium":
		for i in range(n):
			t=i/RATE
			values.append((1-math.exp(-t/.0007))*(1.4*crack[i]*math.exp(-t/.009)+.64*math.sin(chirp_phase(t,255,85,25))*math.exp(-t/.10)+.30*body[i]*math.exp(-t/.17)+.09*tail[i]*math.exp(-t/.28)))
	elif spec.family == "autocannon":
		for i in range(n):
			t=i/RATE
			reset=max(0.,t-.026)
			mechanism=.15*math.sin(TAU*1320*reset)*math.exp(-reset/.011) if t>=.026 else 0.
			values.append((1-math.exp(-t/.00035))*(1.1*crack[i]*math.exp(-t/.0045)+.52*math.sin(chirp_phase(t,510,165,75))*math.exp(-t/.023)+.16*tail[i]*math.exp(-t/.052))+mechanism)
	else:
		for i in range(n):
			t=i/RATE
			reset=max(0.,t-.017)
			mechanism=.12*math.sin(TAU*2800*reset)*math.exp(-reset/.0035) if t>=.017 else 0.
			values.append((1-math.exp(-t/.0002))*(1.2*crack[i]*math.exp(-t/.0025)+.34*math.sin(TAU*860*t)*math.exp(-t/.009)+.09*tail[i]*math.exp(-t/.017))+mechanism)
	return [values]


def add_grain(values: array, start_s: float, life_s: float, gain: float, seed: int, frequency: float, mode: str) -> None:
	rng=random.Random(seed)
	offset=round(start_s*RATE)
	for j in range(round(life_s*RATE)):
		i=offset+j
		if i>=len(values): break
		t=j/RATE
		env=(1-math.exp(-t/.0015))*math.exp(-t/(life_s*.22))
		if mode=="bubble":
			value=math.sin(chirp_phase(t,frequency,frequency*.36,30))
		else:
			value=.7*(rng.random()*2-1)+.3*math.sin(TAU*frequency*t)
		values[i]+=gain*env*value


def impact(spec: Spec) -> list[array]:
	n=round(spec.seconds*RATE)
	rng=random.Random(spec.seed)
	values=array("f")
	if spec.family=="airburst":
		air=band_noise(n,250,4800,spec.seed)
		for i in range(n):
			t=i/RATE
			values.append((1-math.exp(-t/.002))*(.73*air[i]*math.exp(-t/.085)+.3*math.sin(chirp_phase(t,310,98,23))*math.exp(-t/.115)+.08*air[i]*math.exp(-t/.3)))
	elif spec.family=="impact_water":
		foam=band_noise(n,350,6200,spec.seed)
		wash=band_noise(n,70,1100,spec.seed+1000)
		for i in range(n):
			t=i/RATE
			arrival=(1-math.exp(-t/.006))
			spray=(1-math.exp(-t/.028))*math.exp(-t/.29)
			values.append(.32*math.sin(chirp_phase(t,125,51,18))*arrival*math.exp(-t/.09)+.48*foam[i]*spray+.18*wash[i]*arrival*math.exp(-t/.45))
		for k in range(22):
			start=rng.uniform(.09,1.25)
			add_grain(values,start,rng.uniform(.035,.12),.13*math.exp(-start),spec.seed+k, rng.uniform(550,1850),"bubble")
	elif spec.family=="impact_land":
		grit=band_noise(n,650,7500,spec.seed)
		low=band_noise(n,70,650,spec.seed+1000)
		for i in range(n):
			t=i/RATE
			values.append((1-math.exp(-t/.001))*(.65*grit[i]*math.exp(-t/.025)+.43*low[i]*math.exp(-t/.08)+.24*math.sin(chirp_phase(t,195,105,35))*math.exp(-t/.065)))
		for k in range(35):
			start=rng.uniform(.015,.72)
			add_grain(values,start,rng.uniform(.006,.033),.14*math.exp(-start*3),spec.seed+k,rng.uniform(1200,6100),"debris")
	else:
		excite=band_noise(n,900,11000,spec.seed)
		modes=[(371,.31,.23),(587,.24,.18),(1039,.18,.14),(1627,.13,.105),(2431,.085,.07),(3623,.045,.042)]
		for i in range(n):
			t=i/RATE
			ring=sum(amplitude*math.sin(TAU*freq*t+.15)*math.exp(-t/decay) for freq,amplitude,decay in modes)
			values.append((1-math.exp(-t/.0003))*(ring+.75*excite[i]*math.exp(-t/.002)))
	return [values]


def environment(spec: Spec) -> list[array]:
	n=round(spec.seconds*RATE)
	if spec.family=="burning":
		flame=band_noise(n,240,4400,spec.seed,True)
		low=band_noise(n,45,330,spec.seed+1000,True)
		values=array("f", ((.65+.18*math.sin(TAU*.5*i/RATE)+.10*math.sin(TAU*1.75*i/RATE))*(.45*flame[i]+.13*low[i]) for i in range(n)))
		rng=random.Random(spec.seed)
		for k in range(16):
			add_grain(values,rng.uniform(.04,3.90),rng.uniform(.006,.022),rng.uniform(.04,.11),spec.seed+k,rng.uniform(2000,7000),"crackle")
		return [values]
	low=band_noise(n,45 if spec.family=="ambient_wind" else 70,650,spec.seed,True)
	foam=band_noise(n,500,4200 if spec.family=="ambient_wind" else 6500,spec.seed+1000,True)
	side=band_noise(n,150,3600,spec.seed+2000,True)
	left,right=array("f"),array("f")
	for i in range(n):
		t=i/RATE
		if spec.family=="ambient_wind":
			gust=.55+.20*math.sin(TAU*t/spec.seconds+.8)+.11*math.sin(TAU*3*t/spec.seconds+.2)
			mid=gust*(.45*low[i]+.12*foam[i])
			width=.11*gust*side[i]
		else:
			phase=TAU*3*t/spec.seconds
			crest=max(0.,math.sin(phase+.3))**2
			return_wash=max(0.,math.sin(phase-.6))**2
			mid=(.12+.4*crest)*low[i]+(.03+.31*crest+.11*return_wash)*foam[i]
			width=(.02+.09*crest+.04*return_wash)*side[i]
		left.append(mid+width)
		right.append(mid-width)
	return [left,right]


def synthesize(spec: Spec) -> list[array]:
	if spec.family=="fighter_radial_power": return fighter(spec)
	if spec.family=="ship_propulsion": return ship(spec)
	if spec.family in ["gun_heavy","gun_medium","autocannon","machinegun"]: return report(spec)
	if spec.family in ["airburst","impact_water","impact_land","impact_metal"]: return impact(spec)
	return environment(spec)


def wav_write(path: Path, channels: list[array], width: int) -> None:
	path.parent.mkdir(parents=True,exist_ok=True)
	frames=len(channels[0])
	assert all(len(c)==frames for c in channels)
	limit=(1 << (width*8-1))-1
	data=bytearray(frames*len(channels)*width)
	offset=0
	for i in range(frames):
		for channel in channels:
			value=round(channel[i]*limit)
			if abs(value)>limit: raise ValueError("unclipped PCM expected")
			data[offset:offset+width]=int(value).to_bytes(width,"little",signed=True)
			offset+=width
	with wave.open(str(path),"wb") as output:
		output.setnchannels(len(channels));output.setsampwidth(width);output.setframerate(RATE)
		output.writeframes(data)


def encode_ogg(ffmpeg: str, source: Path, output: Path, encoder: str) -> None:
	command=[ffmpeg,"-nostdin","-hide_banner","-loglevel","error","-y","-i",str(source),"-map_metadata","-1","-c:a",encoder,"-q:a","6"]
	if encoder=="vorbis": command.extend(["-strict","experimental"])
	command.extend(["-fflags","+bitexact","-flags:a","+bitexact",str(output)])
	result=subprocess.run(command,capture_output=True,text=True,timeout=45)
	if result.returncode:
		raise RuntimeError(f"FFmpeg encoding failed: {result.stderr[-1500:]}")


def lowpass(samples: array, cutoff: float) -> array:
	coefficient=math.exp(-TAU*cutoff/RATE)
	state=0.
	output=array("f")
	for x in samples:
		state=coefficient*state+(1-coefficient)*x
		output.append(state)
	return output


def lerp_keys(keys: list[list[float]], t: float) -> float:
	if t<=keys[0][0]: return keys[0][1]
	for index in range(1,len(keys)):
		a,b=keys[index-1],keys[index]
		if t<=b[0]:
			weight=(t-a[0])/max(.000001,b[0]-a[0])
			return a[1]+(b[1]-a[1])*weight
	return keys[-1][1]


def cue(asset: str, at: float, gain_db: float, pan: float = 0., cutoff_hz: float = 16000., label: str = "") -> dict:
	return dict(asset=asset,at_s=at,gain_db=gain_db,pan=pan,cutoff_hz=cutoff_hz,label=label)


def bed(asset: str, gain_db: float, start: float = 0., end: float = 32., pan_keys: list = None, gain_keys: list = None, label: str = "") -> dict:
	return dict(asset=asset,gain_db=gain_db,start_s=start,end_s=end,pan_keys=pan_keys or [[start,0.],[end,0.]],gain_keys=gain_keys or [[start,1.],[end,1.]],label=label)


def mix_timelines() -> list[dict]:
	naval=[cue("heavy_01",4,-4,-.42,label="near_design_salvo_1"),cue("heavy_02",4.07,-6,-.24),cue("heavy_01",4.14,-8,-.1),cue("water",8.1,-8,.35),cue("water",8.35,-10,.48),cue("medium",12.2,-10,.1),cue("metal",14.7,-7,-.3),cue("heavy_02",18,-13,.4,2800,"mid_range_design_salvo"),cue("heavy_01",18.08,-15,.53,2800),cue("water",22.3,-13,-.2,2600),cue("heavy_01",26.1,-22,-.5,1100,"far_design_salvo"),cue("water",29.1,-20,.18,1500)]
	aa=[cue("medium",t,-10,(-1)**i*.3,5000) for i,t in enumerate([3.,7.2,12.,18.5,25.])]
	for start,duration,pan in [(4.,1.1,-.5),(8.8,1.4,.4),(13.5,1.2,-.2),(20.,1.3,.2),(26.,.9,-.4)]:
		for k in range(round(duration/.13)): aa.append(cue("autocannon",start+k*.13,-15,pan,6500))
	for k,t in enumerate([4.5,5.1,7.8,9.6,11.1,13.8,15.0,19.2,20.8,21.4,25.8,27.4]):
		aa.append(cue("airburst",t,-11 if k%3==0 else -17,math.sin(k*1.7)*.7,4200))
	for k in range(12): aa.append(cue("machinegun",16.+k*.075,-20,.5,5500))
	dog=[]
	for start,asset,spacing,count,pan in [(7.8,"machinegun",.075,9,-.25),(12.3,"autocannon",.13,6,.2),(17.5,"machinegun",.075,12,.3),(22.,"autocannon",.13,7,-.1)]:
		for k in range(count): dog.append(cue(asset,start+k*spacing,-15 if asset=="machinegun" else -13,pan))
	dog.extend([cue("metal",23.7,-16,-.2,5000),cue("airburst",28,-22,.6,2200)])
	shore=[cue("medium",3.4,-6,-.35,label="shore_gun_design_only"),cue("water",6.5,-10,.4),cue("medium",10.,-12,.4,4000),cue("land",12.8,-7,-.2),cue("medium",17.2,-9,-.25),cue("metal",20.1,-9,.25),cue("heavy_02",22,-22,.55,1500),cue("water",25.3,-16,-.4,2600),cue("medium",26.2,-15,.15,3200),cue("land",29,-15,-.3,3500)]
	for k in range(9): shore.append(cue("autocannon",7.5+k*.15,-21,.4,4200))
	for k,t in enumerate([8.1,15.4,18.9]): shore.append(cue("airburst",t,-23,(-1)**k*.5,2800))
	return [
		{"id":"01_naval_salvo","title":"舰炮齐射与海面／舰体命中","seconds":32,"events":naval,"beds":[bed("wind",-15),bed("ship_run",-13),bed("fire",-6,15.2,24,gain_keys=[[15.2,0],[16,1],[22,1],[24,0]],label="staged_damage_fire_after_metal_impact")],"intent":"near_mid_far_design_layers_not_actual_weapon_ranges"},
		{"id":"02_aa_screen","title":"防空火网","seconds":32,"events":sorted(aa,key=lambda e:e['at_s']),"beds":[bed("wind",-15),bed("ship_idle",-17)],"intent":"short_bursts_and_gaps_instead_of_flat_prerecorded_combat"},
		{"id":"03_dogfight","title":"近距空战与动力变化","seconds":32,"events":sorted(dog,key=lambda e:e['at_s']),"beds":[bed("wind",-17),bed("fighter_low",-9,0,8,gain_keys=[[0,1],[5,1],[8,0]]),bed("fighter_cruise",-10,4,27,pan_keys=[[4,-.6],[12,0],[22,.3],[27,.6]],gain_keys=[[4,0],[8,1],[12,.3],[17,.3],[21,1],[24,1],[27,0]]),bed("fighter_high",-11,10,22,pan_keys=[[10,-.2],[17,.15],[22,.4]],gain_keys=[[10,0],[13,1],[17,1],[22,0]]),bed("fighter_cruise",-23,13,31,pan_keys=[[13,.8],[23,-.5],[31,-.9]],gain_keys=[[13,0],[18,1],[24,1],[31,0]],label="second_aircraft_staged_flypast")],"intent":"power_weights_and_stereo_pass_no_historical_RPM_or_live_flight_claim"},
		{"id":"04_harbor_shore","title":"港湾岸炮与海陆弹着","seconds":32,"events":sorted(shore,key=lambda e:e['at_s']),"beds":[bed("coast",-7),bed("wind",-19),bed("ship_idle",-19)],"intent":"staged_shore_scene_not_S10_gameplay_evidence"},
	]


def render_mix(timeline: dict, masters: dict[str,list[array]]) -> tuple[list[array],dict]:
	n=round(timeline['seconds']*RATE)
	left,right=array("f",[0.])*n,array("f",[0.])*n
	for layer in timeline['beds']:
		signals=masters[layer['asset']]
		begin=round(layer['start_s']*RATE);end=min(n,round(layer['end_s']*RATE))
		gain=db_gain(layer['gain_db'])
		count=len(signals[0])
		for i in range(begin,end):
			t=i/RATE
			fade=min(1.,(i-begin)/(.2*RATE),(end-1-i)/(.3*RATE))
			weight=max(0.,fade)*lerp_keys(layer['gain_keys'],t)*gain
			idx=(i-begin)%count
			if len(signals)==2:
				left[i]+=signals[0][idx]*weight;right[i]+=signals[1][idx]*weight
			else:
				pan=max(-1.,min(1.,lerp_keys(layer['pan_keys'],t)))
				angle=(pan+1)*math.pi/4
				left[i]+=signals[0][idx]*weight*math.cos(angle);right[i]+=signals[0][idx]*weight*math.sin(angle)
	filtered={}
	for event in timeline['events']:
		key=(event['asset'],event['cutoff_hz'])
		if key not in filtered:
			source=masters[event['asset']][0]
			filtered[key]=lowpass(source,event['cutoff_hz']) if event['cutoff_hz']<15000 else source
		source=filtered[key]
		angle=(event['pan']+1)*math.pi/4
		gain=db_gain(event['gain_db']);gl=gain*math.cos(angle);gr=gain*math.sin(angle)
		start=round(event['at_s']*RATE)
		for j in range(min(len(source),n-start)):
			left[start+j]+=source[j]*gl;right[start+j]+=source[j]*gr
	# One constant trim, never a per-shot loudness pump or hard clipper.
	peak=max(max(abs(min(c)),abs(max(c))) for c in [left,right])
	energy=math.sqrt((rms(left)**2+rms(right)**2)/2)
	trim=min(db_gain(-22)/max(energy,1e-12),db_gain(-3)/max(peak,1e-12))
	for channel in [left,right]:
		for i in range(n):
			fade=min(1.,i/(.15*RATE),(n-1-i)/(.25*RATE))
			channel[i]*=trim*max(0.,fade)
	return [left,right],{"constant_gain":trim,"peak_ceiling_dbfs":-3,"RMS_target_dbfs":-22,"compression":"none_constant_trim_only"}


def main() -> int:
	parser=argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--asset-root',type=Path,default=ROOT/'assets/audio/au01')
	parser.add_argument('--doc-root',type=Path,default=ROOT/'docs/audio')
	args=parser.parse_args()
	asset_root=args.asset_root.resolve();doc_root=args.doc_root.resolve()
	for path in [asset_root,doc_root]:
		if ROOT not in path.parents: parser.error('output roots must remain inside this project')
	ffmpeg=shutil.which('ffmpeg')
	if not ffmpeg: raise RuntimeError('installed FFmpeg required; no installation or service fallback')
	encoder_list=subprocess.run([ffmpeg,'-hide_banner','-encoders'],capture_output=True,text=True,timeout=10,check=True).stdout
	available={line.split()[1] for line in encoder_list.splitlines() if len(line.split())>1 and line.lstrip().startswith('A')}
	encoder='libvorbis' if 'libvorbis' in available else 'vorbis' if 'vorbis' in available else None
	if encoder is None: raise RuntimeError('no installed Vorbis encoder; retain lossless sources, do not install or use a service')
	print('Using installed Vorbis encoder: '+encoder,flush=True)
	source_root=asset_root/'source';master_root=asset_root/'masters';runtime_root=asset_root/'runtime';preview_root=doc_root/'au01/preview'
	for path in [source_root,master_root,runtime_root,preview_root]: path.mkdir(parents=True,exist_ok=True)
	for path in [source_root,master_root]: (path/'.gdignore').write_text('')
	generator_hash=sha256(Path(__file__))
	recipe={"version":AUTHORING_VERSION,"rate_hz":RATE,"origin":"local_original_DSP_no_recordings","network":False,"accounts":0,"cost_usd":0,"paid_services":0,"public_license_added":False,"historical_equipment_recording":False,"generator":"tools/audio/build_au01.py","generator_sha256":generator_hash,"specs":[asdict(s) for s in SPECS],"loop_boundary":"144_sample_each_side_periodic_C1_bridge_no_silent_padding","mastering":"DC_removal_and_peak_trim_no_clipping_no_loudness_pumping"}
	recipe_path=source_root/'recipe.json';recipe_path.write_text(json.dumps(recipe,ensure_ascii=False,indent=2)+'\n')
	assets=[];masters={}
	for spec in SPECS:
		print('Rendering '+spec.id,flush=True)
		signals=synthesize(spec)
		raw=[prepare(s,spec.loop,-3) for s in signals]
		final=[prepare(s,spec.loop,spec.peak_db) for s in raw]
		masters[spec.id]=final
		stem=f'{spec.family}_{spec.state}_shared_v{spec.variant:02d}'
		source_path=source_root/(stem+'.wav');master_path=master_root/(stem+'.wav')
		wav_write(source_path,raw,3);wav_write(master_path,final,3)
		runtime_path=runtime_root/(stem+('.ogg' if spec.channels==2 else '.wav'))
		if spec.channels==2: encode_ogg(ffmpeg,master_path,runtime_path,encoder)
		else: wav_write(runtime_path,final,2)
		assets.append({**asdict(spec),"status":"generated_hearing_and_integration_pending","origin":"original_generic_design_no_external_recording","source_path":relative(source_path),"master_path":relative(master_path),"runtime_path":relative(runtime_path),"source_sha256":sha256(source_path),"master_sha256":sha256(master_path),"runtime_sha256":sha256(runtime_path),"loop_begin_sample":0 if spec.loop else None,"loop_end_sample":round(spec.seconds*RATE) if spec.loop else None,"runtime_bytes":runtime_path.stat().st_size,"seed_scope":"asset_local_not_SimulationWorld_RNG","auditioned":False,"integrated":False})
	timelines=mix_timelines();mixes=[]
	for timeline in timelines:
		print('Mixing '+timeline['id'],flush=True)
		audio,trim=render_mix(timeline,masters)
		wav_path=preview_root/(timeline['id']+'.wav');ogg_path=preview_root/(timeline['id']+'.ogg')
		wav_write(wav_path,audio,2);encode_ogg(ffmpeg,wav_path,ogg_path,encoder)
		mixes.append({"id":timeline['id'],"title":timeline['title'],"duration_s":timeline['seconds'],"wav_path":relative(wav_path),"ogg_path":relative(ogg_path),"wav_sha256":sha256(wav_path),"ogg_sha256":sha256(ogg_path),"normalization":trim,"origin":"offline_authored_audition_timeline_not_simulation","listening_status":"pending_not_heard_by_agent","gameplay_evidence":False})
	(preview_root/'timelines.json').write_text(json.dumps({"scope":"offline_material_audition_only_not_real_battle_events","auditioned":False,"mixes":timelines},ensure_ascii=False,indent=2)+'\n')
	ffmpeg_version=subprocess.run([ffmpeg,'-version'],capture_output=True,text=True,timeout=10).stdout.splitlines()[0]
	manifest={"schema_version":1,"task":"AU01","authoring_version":AUTHORING_VERSION,"status":"generated_technical_report_separate_hearing_pending","engine_integration":False,"cost_usd":0,"accounts":0,"paid_services":0,"network_requests":0,"external_recordings":0,"historical_recordings":0,"public_license_added":False,"recipe_path":relative(recipe_path),"recipe_sha256":sha256(recipe_path),"generator_path":"tools/audio/build_au01.py","generator_sha256":generator_hash,"toolchain":{"python":sys.version.split()[0],"ffmpeg":ffmpeg_version,"vorbis_encoder":encoder,"vorbis_quality":6,"native_vorbis_is_experimental":encoder=='vorbis',"dependencies":"Python_standard_library_and_existing_FFmpeg_only"},"assets":assets,"mixes":mixes,"automated_report":relative(doc_root/'au01-checks.json'),"listening":{"performed":False,"status":"pending_human_or_equipped_reviewer","note":"signal_checks_do_not_constitute_hearing_acceptance"},"future_integration":{"task":"AU02","authorized_here":False,"web_playback_required":"PLAYBACK_TYPE_STREAM","loop_metadata_must_be_applied_on_import":True}}
	manifest['timelines_path']=relative(preview_root/'timelines.json')
	manifest['timelines_sha256']=sha256(preview_root/'timelines.json')
	manifest_path=doc_root/'au01-asset-manifest.json';manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
	print(json.dumps({"assets":len(assets),"mixes":len(mixes),"runtime_bytes":sum(a['runtime_bytes'] for a in assets),"manifest":relative(manifest_path),"hearing":"pending"},ensure_ascii=False),flush=True)
	return 0


if __name__=='__main__':
	raise SystemExit(main())
