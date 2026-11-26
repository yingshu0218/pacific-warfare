#!/usr/bin/env python3
"""Plot real S04 fixed-tick trace JSON; no fabricated poses or trajectory smoothing."""
import argparse
import json
from pathlib import Path
import os
ROOT=Path(__file__).resolve().parents[1]
os.environ.setdefault('MPLCONFIGDIR',str(ROOT/'.local/S04-mpl-cache'))
os.environ.setdefault('XDG_CACHE_HOME',str(ROOT/'.local/S04-font-cache'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('trace',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--time-limit',type=float,default=240)
    args=parser.parse_args()
    data=json.loads(args.trace.read_text())
    rows={}
    for row in data['samples']:
        if row['active']:
            rows.setdefault(row['id'],[]).append(row)
    fig=plt.figure(figsize=(15,9),layout='constrained')
    grid=fig.add_gridspec(3,3,width_ratios=[1.3,1,1])
    axis=fig.add_subplot(grid[:,0],projection='3d')
    plots=[fig.add_subplot(grid[0,1]),fig.add_subplot(grid[0,2]),fig.add_subplot(grid[1,1]),fig.add_subplot(grid[1,2]),fig.add_subplot(grid[2,1:])]
    fields=[('altitude','Altitude (m)'),('speed','Speed (m/s)'),('pitch_deg','Flight-path pitch (deg)'),('bank_deg','Bank (deg)'),('energy_height_m','Energy height: h + V²/(2g) (m)')]
    palette=plt.get_cmap('tab10')
    for i,(identifier,series) in enumerate(rows.items()):
        color=palette(i%10)
        xyz=[s['position_m'] for s in series]
        axis.plot([p[0]/1000 for p in xyz],[p[2]/1000 for p in xyz],[p[1]/1000 for p in xyz],color=color,lw=1.2,label=identifier)
        for plot,(field,title) in zip(plots,fields):
            if field=='altitude':values=[r['position_m'][1] for r in series]
            elif field=='speed':values=[sum(x*x for x in r['velocity_mps'])**.5 for r in series]
            else:values=[r[field] for r in series]
            plot.plot([r['time_s'] for r in series],values,color=color,lw=1.1)
            plot.set_ylabel(title)
            plot.set_xlabel('Simulation time (s)')
            plot.grid(alpha=.2)
    axis.set_xlabel('World X (km)');axis.set_ylabel('World Z (km)');axis.set_zlabel('')
    axis.set_title('Actual controlled flight tracks; inactive wrecks excluded')
    axis.set_xlim(-12,12);axis.set_ylim(-12,12);axis.set_zlim(0,4)
    axis.set_zticks([0,2,4]);axis.tick_params(axis='z',labelsize=8,pad=0)
    axis.set_box_aspect((24,24,4))
    axis.set_proj_type('ortho')
    axis.view_init(elev=26,azim=-48)
    axis.set_title('Actual tracks, km; equal physical axis scale\nX/Z: [-12,12], altitude: [0,4]; no vertical exaggeration')
    for plot,bounds in zip(plots,[(0,4000),(0,200),(-90,90),(-90,90),(0,6000)]):
        plot.set_xlim(0,args.time_limit);plot.set_ylim(*bounds)
    axis.legend(fontsize=7,loc='upper left')
    fig.suptitle(f"{data['case']} | {'Before: frozen S04 v1' if data['baseline'] else 'After: spatial flight'} | {data['time_s']:.0f} s | Actual fixed-tick samples",fontsize=15)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    fig.savefig(args.output,dpi=150)
    fig.savefig(args.output.with_suffix('.svg'))
    plt.close(fig)
    print(args.output)

if __name__=='__main__':main()
