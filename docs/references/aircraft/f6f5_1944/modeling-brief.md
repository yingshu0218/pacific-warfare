# F6F-5：S04 外形与参数资料卡

2026-11-10。正式ID保持 `us_f6f5_1944`，目标为1944–45的六挺 .50 AN/M2 普通日间型，非-5N、-5K或混合双20mm武装型；不锁定某架个体。10.236m长、13.056m翼展、3.990m地面机体高，R-2800-10W、三叶桨、展开翼、六枪各400发、无外部挂载。高度基准与螺旋桨叶尖包络在旧README已区分。

已实际打开以下完整图片，不以搜索缩略图代替。

| 本地文件 | 原始来源／视角 | 用途与限制 |
| --- | --- | --- |
| `original/EVG_5707.jpg` | [Eric Van Gilder 2013 Camarillo 原页](https://www.vg-photo.com/airshow/2013/Camarillo/hellcat.html)，[原图](https://www.vg-photo.com/airshow/2013/Camarillo/f6f/EVG_5707.jpg)；左侧高位俯看 | 机翼弦长/圆端、六枪、尾翼及宽机身。机体为CAF Minsi III保存/运营机；[CAF自有机档](https://www.commemorativeairforce.org/aircraft/30)明确F6F-5，McCampbell涂装是复涂，不推定1944个体编号。 |
| `original/EVG_5740.jpg` | [原图](https://www.vg-photo.com/airshow/2013/Camarillo/f6f/EVG_5740.jpg)；飞行侧下 | 驼背、座舱高度、机头下颌进气轮廓、主翼上反与尾轮收起；透视照片不作精确翼厚测绘。 |
| `original/EVG_7417.jpg` | [原图](https://www.vg-photo.com/airshow/2013/Camarillo/f6f/EVG_7417.jpg)；高位斜前 | 机身/翼根连接、舱盖、六枪、飞行姿态比例。保存机配件不自动作为战时全部细节。 |
| `original/f6f-pilot-handbook.pdf` | [原始军方 AN01-85FB-1 手册扫描镜像](https://fredhaise.space/docs/career-paths/F6F_Pilot_Handbook.pdf)，AppendixII/F6F-5 | 实际打开PDF第90、91、92、99页。性能图plateIII A/B为不同重量条件的操纵图，condensed power schedule印刷83页给长航程145kts CAS；不能把一个速度当全高度/全功率恒值。保留对应PNG与正向plateIII A。 |

交叉来源：[美海军航空博物馆](https://www.history.navy.mil/content/history/museums/nnam/explore/collections/aircraft/f/f6f-3-hellcat.html)说明1944年-5改进机罩/风挡且存在不同武装版本；[NACA 1945 F6F-3原始报告](https://digital.library.unt.edu/ark:/67531/metadc61068/m1/3/)的共用翼根/翼尖厚度与外翼7.5°仅作家族几何约束，非-5单机测绘。前一轮来源详见 `aircraft/docs/REFERENCES.md`。

本次不新增AI几何图，直接复用已有 Godot 粗模，按已认可SB2C v04目标控制纯色材质和省略程度。实际同一模型侧/前/俯/斜/腹视在 `docs/showcase/evidence/S04/us_f6f5_1944_*.png`；不是AI图。

保留宽机身、机翼根部及外翼折点/上反、圆端、翼尾、下颌进气、舱盖、三叶桨与六枪。飞行适配器收轮、无火箭导轨底座/挂载；省略发动机内部、冷却机构、面板和内舱。按统筹照片复查，增加斜平面前风挡、调整滑动罩/后罩截面与抬高机背过渡；将机身星条移到z=1.95m的座舱后方并沿实际机身曲面贴合。修正导航灯悬空和电台桅杆支点；不改变旧查看器/机场调用接口。涂装是子型识别用概括，不对应某架战术编号；纯色模式取消旧红色标志边框。

旧模型坐标减(0,2.30,0)成为飞行参考；非实测重心。六枪x=±2.35/2.73/3.11，y=-0.155，z分别=-1.9343181818181819/-1.8968939393939392/-1.859861111111111。Marker与正式JSON逐枪对照。照片只支持枪位在翼根外段的大致关系，绝对坐标和简化炮管长度为几何近似。

飞行表将高空极速175.24m/s、7000m最佳高度、升限11370m、初始爬升17.8m/s作为综合近似包络；CAF确认>380mph，军方图表说明功率/高度/重量依赖，并不支持把上述数值宣称为全条件精确复刻。海平面153m/s、任务巡航89.4m/s（200mph，区别于145kts CAS长航程表）、加减速/转率/滚转、爬升衰减和油耗均为明示估值；没有模拟WEP五分钟、增压器档位或热限制。250USgal×0.72kg/L约681kg是内部燃油容量参考；初始余油由场景单独输入。参考质量5650kg不作为逐帧载荷求解。

尚缺-5原厂三维炮站公差与该目标个体多视测绘，翼厚和机身截面保持参数化近似。照片、手册仅用于研究，不成为游戏纹理/模型；Eric Van Gilder与原发布者保留照片版权，程序网格为本项目生成。研究图片不随游戏Web包公开发布，S08统一检查资源过滤。
