# S06 航行参数依据与近似

2026-11-10。本板块不改模型、炮位、史实尺寸或服役年；这些仍由正式单位定义与S02/S03交付维护。`data/fleet/showcase.json`的历史最大航速仅作型号性能上界，不根据阵营胜率调整。

| 正式ID | 历史上界采用值 | 来源与限制 |
| --- | --- | --- |
| jp_yamato_1944_04 | 27 kn = 13.890 m/s | [NHHC H-044-3](https://www.history.navy.mil/content/history/nhhc/about-us/leadership/director/directors-corner/h-grams/h-gram-044/h-044-3.html)记载1945年最终作战时全速27节。用作1944配置的量级上界，不声称是选定日期的实测载荷曲线 |
| us_iowa_bb61_1944_12_28 | 33 kn = 16.977 m/s | [NHHC DANFS Iowa III](https://www.history.navy.mil/research/histories/ship-histories/danfs/i/iowa-iii.html)规格33节；未采用轻载超负荷传闻 |
| us_fletcher_dd445_1942_07_18 | 36 kn = 18.520 m/s | [NHHC DANFS Fletcher I](https://www.history.navy.mil/research/histories/ship-histories/danfs/f/fletcher.html)规格36节；其他网页38节与试航载荷有差异，本轮按DANFS，不择高速值平衡 |
| jp_yukikaze_1942_06 | 35 kn = 18.006 m/s | [田宫阳炎说明书](https://cdn.simba-dickie-group.de/downloads/300078032/300078032_Kagero_w._PE-Parts.pdf)记载级设计最高35节。是厂商模型资料而非海军试航原始档案，属provisional；不声称雪风该日实测35.5节 |

NHHC规格已核对其搜索索引正文摘要，原页本轮直接打开返回502，不能声称通读原页；田宫PDF可访问，索引提取了35节的英文说明。历史上界仍保留provisional，尚无对应日期的载荷/试航原表。技术公式为明确的游戏近似：

- 最大可达速度乘S05动力因子；加速0.055–0.12m/s²、制动0.12–0.22m/s²，损伤变更也逐tick减速。
- 回转率上限为实际航速/近似回转半径×S05操纵因子，转舵有角加速度；零速不能原地转向。半径250–520m未查到所选日期/载荷的完整操纵试验，未冒称史实战术回转直径。
- disabled直线阻力0.065–0.10m/s²，停距有界v²/(2a)，不计时沉没。sinking/wreck位移仍由S05处理。
- 巡航10–12m/s、炮战期望距离5.5–10km、620m站位间隔、右转让行/海图盒绕行均是首段规模的可读近似。炮位、射界、火控射程与实际能否射击仍由S05决定。
- 舰艇fuel_fraction是场景余油比例，172800秒巡航参考续航配三次方速度消耗，仅提供可复验低油决策；没有声称吨位、锅炉效率或历史续航。飞机余油/消耗/储备使用S04原参数。
- 海岸AABB海面投影扩大舰长安全区与转弯余量，静态可见性图绕行；邻舰按同tick起始位姿计算预测最近距离，稳定右转/让行。尚未回收的下沉舰保守保留为障碍直至removed；不模拟浅滩吃水、潮汐、海流、船体实体碰撞反力、复杂港口调度。

模型比例与主副炮布局不会因以上游戏近似而放宽；没有鱼雷、驱逐舰雷击或航母作业链。
