#!/usr/bin/env python3
"""Original top-down layout from MAP02 data; no alternative world-height implementation."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
m=json.loads((ROOT/'data/maps/island_harbor_expanded.json').read_text())
r=json.loads((ROOT/'data/map02/regions.json').read_text())
im=Image.new('RGB',(1800,1330),'#e9ece3');d=ImageDraw.Draw(im)
def font(n):return ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansCJKsc-Regular.otf'),n)
def text(p,t,n=18,c='#253f4b',anchor=None):d.text(p,t,font=font(n),fill=c,anchor=anchor)
text((45,20),'MAP02 · 青岬群岛港湾扩展',32)
text((45,65),'独立扩展版本 / 港区、机场与空阵地；承载与通航由同一 TerrainQueries 实测',19)
colors={'civil_town':'#d4a177','civil_port':'#cfc19b','naval_base':'#83a8a4','fuel_yard':'#cab36e','airfield':'#9fb1b8'}
def chart(rect,bounds,label):
 x,y,w,h=rect;ox,oz,bw,bh=bounds;scale=min(w/bw,h/bh)
 tile=Image.new('RGB',(w,h),'#294e61');td=ImageDraw.Draw(tile)
 def local(p):return ((p[0]-ox)*scale,(p[2]-oz)*scale)
 def xy(p):return (x+local(p)[0],y+local(p)[1])
 td.rectangle((0,0,w,h),fill='#294e61')
 for island in m['islands']:
  points=[local(p) for p in island['outline_m']]
  td.polygon(points,fill='#6f8669');td.line(points+[points[0]],fill='#b9c0a4',width=2)
 for o in m['objects']:
  p=o['position_m'];s=o['size_m'];a=local([p[0]-s[0]*.5,0,p[2]-s[2]*.5]);b=local([p[0]+s[0]*.5,0,p[2]+s[2]*.5])
  if b[0]<0 or a[0]>w or b[1]<0 or a[1]>h:continue
  a=(max(0,a[0]),max(0,a[1]));b=(min(w,b[0]),min(h,b[1]))
  c=colors.get(o.get('map02_region_id'),'#bcc7ad')
  if o.get('map02_shape') in ['cylinder','cone']:td.ellipse((*a,*b),fill=c)
  else:td.rectangle((*a,*b),fill=c)
 for channel in r['shipping_channels']:
  p=[local(v) for v in channel['waypoints_m']];td.line(p,fill='#a9d7e1',width=4)
 for site in m['deployment_sites']:
  p=local(site['position_m'])
  if 0<p[0]<w and 0<p[1]<h:td.polygon([(p[0],p[1]-7),(p[0]-6,p[1]+5),(p[0]+6,p[1]+5)],fill='#f0d685')
 td.rectangle((0,0,w-1,h-1),outline='#92a4a6',width=2)
 td.text((12,10),label,font=font(21),fill='#e4ebdf')
 im.paste(tile,(x,y))
 return xy
xy=chart((45,115,1120,1120),[-12000,-12000,24000,24000],'24×24 km / 北 = -Z')
for area in r['carrier_operation_areas']:
 x,z,w,h=area['bounds_xz_m'];a=xy([x,0,z]);b=xy([x+w,0,z+h]);d.rectangle((*a,*b),outline='#e8c593',width=3)
 p=[xy(q) for q in area['launch_lane_m']];d.line(p,fill='#e8c593',width=3)
 text(((a[0]+b[0])/2,(a[1]+b[1])/2+12),'航母操作水域',16,'#f2d6a7','mm')
for title,p,off in [('民用港 / 小镇',[-4950,0,-3500],(-235,55)),('军港 / 油库',[3250,0,-4700],(-55,-105)),('陆基机场',[6800,0,-2400],(60,40))]:
 p=xy(p);q=(p[0]+off[0],p[1]+off[1]);d.line((*p,*q),fill='#dce4c4',width=2);text(q,title,19,'#f3ead0')
text((1100,140),'N',22,'white');d.line((1110,210,1110,175),fill='white',width=3);d.polygon([(1110,162),(1103,177),(1117,177)],fill='white')
d.line((80,1190,80+2000/24000*1120,1190),fill='white',width=4);text((82,1197),'2 km',15,'white')
chart((1200,115,555,490),[-5850,-4050,2350,2075],'民港 / 街区 / 钟楼 / T形栈桥')
chart((1200,645,555,490),[1700,-6100,3700,3267],'军港 / 双泊位 / 维修棚 / 油罐组')
text((1200,1160),'浅黄三角：空阵地（未装炮）',19)
text((1200,1194),'蓝线：进出航道 / 杏框：航母操作区',17)
text((45,1260),'原创泛用1944–45太平洋设施；不复刻具体港口。旧S09、S14与共享运行源码保持冻结。',20)
out=ROOT/'docs/maps/MAP02/layout.png';im.save(out);print(out)
