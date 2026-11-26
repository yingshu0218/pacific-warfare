#!/usr/bin/env python3
"""A metre-scale chart from the same map/scenario sources (not a game screenshot)."""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/'data/maps/island_harbor.json').read_text())
scenario=json.loads((ROOT/'data/scenarios/island_harbor.json').read_text())
def font(size):return ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansCJKsc-Regular.otf'),size)
im=Image.new('RGB',(1440,1260),'#eef0e7');d=ImageDraw.Draw(im)
left,top,width=75,120,1050
scale=width/24000

def xy(x,z):return (left+(x+12000)*scale,top+(z+12000)*scale)
def p3(p):return xy(p[0],p[2])
d.text((75,24),'青岬群岛 · 原创24×24 km地图',font=font(31),fill='#203a46')
d.text((75,70),'北 = -Z；舰机采用米制真实尺寸。此图由地图与场景数据生成，不是运行截图。',font=font(18),fill='#526974')
d.rectangle((left,top,left+width,top+width),fill='#284e60')
for km in range(-12,13,3):
 x,y=xy(km*1000,km*1000)
 d.line((x,top,x,top+width),fill='#3c6070');d.line((left,y,left+width,y),fill='#3c6070')
 d.text((x-18,top+width+12),str(km),font=font(15),fill='#36545d')
 d.text((left-38,y-10),str(km),font=font(15),fill='#36545d')
for island in source['islands']:
 points=[p3(v) for v in island['outline_m']]
 d.polygon(points,fill='#7c9071');d.line(points+[points[0]],fill='#d3ccb0',width=2)
 x,y=p3(island['center_m']);d.text((x,y),island['label'],font=font(17),fill='#edf0d7',anchor='mm')
# Main 12x12km test square; the chart deliberately includes land interactions.
x1,y1=xy(-6000,-6000);x2,y2=xy(6000,6000)
for i in range(0,int(x2-x1),16):
 d.line((x1+i,y1,min(x1+i+8,x2),y1),fill='#94b8bd');d.line((x1+i,y2,min(x1+i+8,x2),y2),fill='#94b8bd')
for i in range(0,int(y2-y1),16):
 d.line((x1,y1+i,x1,min(y1+i+8,y2)),fill='#94b8bd');d.line((x2,y1+i,x2,min(y1+i+8,y2)),fill='#94b8bd')
for spawn in scenario['spawns']:
 x,y=p3(spawn['position_m']);ship=spawn['id'].endswith(('bb','dd'));color='#f1b48f' if spawn['faction_id']=='jp' else '#a7dcf2'
 if ship:d.rectangle((x-4,y-6,x+4,y+6),fill=color)
 else:d.polygon([(x+5,y),(x-4,y-4),(x-4,y+4)],fill=color)
 if ship:
  offset=-70 if spawn['faction_id']=='jp' else 12
  d.text((x+offset,y-10),scenario['presentation']['names'][spawn['id']],font=font(15),fill='white')
for site in source['deployment_sites']:
 x,y=p3(site['position_m']);d.polygon([(x,y-6),(x-5,y+5),(x+5,y+5)],fill='#f2d08c')
for name,origin,end in [('港湾 / 小镇',[-4400,0,-3250],[-8200,0,-2000]),('入口岸炮空阵地',[-3010,0,-3200],[0,0,-3000]),('590m高地防空空阵地',[-5200,0,-4630],[-10000,0,-8200])]:
 x,y=p3(origin);ex,ey=p3(end);d.line((x,y,ex,ey),fill='#e6d3a4',width=2);d.text((ex,ey-23),name,font=font(17),fill='#f5e6bd')
for x,name in [(-10000,'日方'),(10000,'美方')]:
 c=xy(x,6500);r=700*scale;d.ellipse((c[0]-r,c[1]-r,c[0]+r,c[1]+r),outline='#e8ccb7',width=2);d.text((c[0],c[1]+r+12),name+'撤离区',anchor='mt',font=font(15),fill='#e8ccb7')
x,y=xy(0,2600);d.text((x,y),'中央炮战 / 空中机动水域',anchor='mm',font=font(20),fill='#d3e5e6')
x,y=xy(-10000,10300);xx,_=xy(-8000,10300);d.line((x,y,xx,y),fill='white',width=4);d.text(((x+xx)/2,y+12),'2 km',anchor='mt',font=font(15),fill='white')
d.text((1170,150),'N / 北',font=font(26),fill='#294a57');d.line((1225,250,1225,200),fill='#294a57',width=4);d.polygon([(1225,190),(1217,205),(1233,205)],fill='#294a57')
legend=['简化地图，可复验','7座高低岛屿','山脊最高约640米','港湾、码头、防波堤','沿岸道路与30座房屋','4处空阵地（未装炮）','','方块：军舰初态','三角：在空战斗机','浅黄：陆基安装点','虚线：主要测试区','','舰艇沿实际岸线绕行','地形 / 建筑遮挡与弹着','所有单位比例保持不变']
for i,line in enumerate(legend):d.text((1160,320+i*35),line,font=font(17),fill='#3f5b65')
d.text((75,1210),'坐标：X向东 / Z向南（km）。初态与旧开阔海相同；新图仅覆盖舰队巡航区域。',font=font(18),fill='#526974')
output=ROOT/'docs/maps/island_harbor_layout.png';im.save(output);print(output)
