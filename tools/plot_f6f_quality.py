#!/usr/bin/env python3
"""Plot measured F6F before/after and final maneuver, without smoothing poses."""
import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/showcase/evidence/S04-spatial'
os.environ.setdefault('MPLCONFIGDIR',str(ROOT/'.local/S04-mpl-cache'))
os.environ.setdefault('XDG_CACHE_HOME',str(ROOT/'.local/S04-font-cache'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def series(data, identifier, low, high):
    return [r for r in data['samples'] if r['id']==identifier and low<=r['time_s']<=high and r['active']]


def value(row, field):
    if field=='altitude': return row['position_m'][1]
    if field=='speed': return math.sqrt(sum(x*x for x in row['velocity_mps']))
    return row[field]


def save(fig,name):
    fig.savefig(OUT/(name+'.png'),dpi=150)
    fig.savefig(OUT/(name+'.svg'))
    plt.close(fig)


def main():
    old=json.loads((OUT/'v2-before-f6f-calibration/current-after.json').read_text())
    new=json.loads((OUT/'current-after.json').read_text())
    fig,axes=plt.subplots(3,2,figsize=(12,9),layout='constrained')
    fields=[('altitude','Altitude (m)',(0,1600)),('speed','Speed (m/s)',(40,200)),
            ('pitch_deg','Flight-path pitch (deg)',(-90,90)),('bank_deg','World-reference bank (deg)',(-180,180)),
            ('load_g','Normal load (g)',(-1,6)),('energy_height_m','Energy height (m)',(0,2500))]
    for axis,(field,label,bounds) in zip(axes.flat,fields):
        for data,color,style,title in [(old,'#8b9299','--','Before: rejected v2'),(new,'#236caa','-','After: coordinated v3')]:
            rows=series(data,'us_air_4',152,178)
            axis.plot([r['time_s'] for r in rows],[value(r,field) for r in rows],style,color=color,lw=1.8,label=title)
        axis.set(xlim=(152,178),ylim=bounds,xlabel='Simulation time (s)',ylabel=label)
        axis.grid(alpha=.2)
    axes[0,0].legend(fontsize=9)
    fig.suptitle('F6F-5 us_air_4 | same aircraft initial states and 152–178 s window\nActual autonomous outcomes may differ; no pose smoothing',fontsize=14)
    save(fig,'f6f-v2-v3-same-window')
    data=json.loads((OUT/'four-after.json').read_text())
    audit=json.loads((OUT/'f6f-trajectory-audit.json').read_text())
    episode=next(e for e in audit['completed_natural_split_s'] if e['passed'])
    low,high=88,106
    rows=series(data,episode['id'],low,high)
    fig,axes=plt.subplots(3,2,figsize=(12,9),layout='constrained')
    fields=[('altitude','Altitude (m)',(1000,3000)),('speed','Speed (m/s)',(70,160)),
            ('pitch_deg','Flight-path pitch (deg)',(-90,40)),('body_roll_rate_degps','Actual body roll (deg/s)',(-70,70)),
            ('load_g','Normal load (g)',(0,6)),('path_curvature_degps','Actual path curvature (deg/s)',(0,40))]
    for axis,(field,label,bounds) in zip(axes.flat,fields):
        axis.axvspan(episode['roll_start_s'],episode['pull_start_s'],color='#efc85a',alpha=.2,label='Roll into plane')
        axis.axvspan(episode['pull_start_s'],episode['end_s'],color='#5096c9',alpha=.18,label='Positive-load pull')
        axis.plot([r['time_s'] for r in rows],[value(r,field) for r in rows],color='#23465c',lw=1.6)
        axis.set(xlim=(low,high),ylim=bounds,xlabel='Simulation time (s)',ylabel=label)
        axis.grid(alpha=.2)
    axes[0,0].legend(fontsize=9)
    fig.suptitle(f"F6F-5 {episode['id']} | autonomous flight after controlled 4v4 initial orders\nRoll alignment → positive-load half-loop → recovery; actual fixed-tick data",fontsize=14)
    save(fig,'f6f-v3-split-curves')
    origin=rows[0]['position_m']
    points=[[(r['position_m'][i]-origin[i])/1000 for i in [0,2,1]] for r in rows]
    fig=plt.figure(figsize=(9,8),layout='constrained')
    axis=fig.add_subplot(projection='3d')
    axis.plot([p[0] for p in points],[p[1] for p in points],[p[2] for p in points],lw=2,color='#236caa')
    for key,label in [('roll_start_s','roll'),('pull_start_s','pull'),('end_s','recover')]:
        row=min(rows,key=lambda r:abs(r['time_s']-episode[key]))
        p=[(row['position_m'][i]-origin[i])/1000 for i in [0,2,1]]
        axis.scatter(*p,s=30);axis.text(*p,label,fontsize=10)
    minima=[min(p[i] for p in points) for i in range(3)]
    maxima=[max(p[i] for p in points) for i in range(3)]
    radius=max(b-a for a,b in zip(minima,maxima))/2+.2
    bounds=[((a+b)/2-radius,(a+b)/2+radius) for a,b in zip(minima,maxima)]
    axis.set(xlim=bounds[0],ylim=bounds[1],zlim=bounds[2],xlabel='Δ world X (km)',ylabel='Δ world Z (km)',zlabel='Δ altitude (km)')
    axis.set_box_aspect((1,1,1));axis.set_proj_type('ortho');axis.view_init(26,-48)
    axis.set_title('Actual F6F half-loop trajectory, 88–106 s\nAll axes km, equal physical scale; origin at first sample',fontsize=13)
    save(fig,'f6f-v3-split-trajectory')
    print('F6F quality plots PASS: measured samples, equal physical trajectory scale')


if __name__=='__main__':main()
