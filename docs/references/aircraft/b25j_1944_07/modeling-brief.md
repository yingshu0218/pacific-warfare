# AV04 B-25J 透明投弹机鼻参考锁定

2026-11-11。目标：**B-25J-1-NC早期标准轰炸构型，1944-07**；不是某尾号逐件复原。Wright R-2600-13双发，三叶桨，双垂尾，三轮起落架；早期12×.50枪（AN/M2族，具体枪架站位/批次细节未测绘）。使用AN 01-60GE-1 1944-07-10原始手册的后续修订汇编，晚期增枪、加装设备和修复实机不倒推为本机装备。

已实际打开下列原图/原页，所有资料仅私人建模参考；原创游戏几何不复制原照片为纹理。原图、手册扫描、成品比例模型和Godot渲染分别留存。不新增AI结构图，执行既定simplified-historical-v0.2简化风格。

| ID | 原始文件（originals或manual-pages） | 视角/用途与实际检查 | 限制 |
| --- | --- | --- | --- |
| H01 | p004.png（手册PDF页4，印刷ii，Figure1） | 历史照片三联：近前、后、完整右侧；机身长高、双尾、停放轮杆和短舱关系 | 扫描879×1136；上/中图远翼裁切，不算完整正前；地面轻微姿态，不是厂图 |
| H02 | p005.png（PDF页5，印刷1） | 近斜前透明鼻、阶梯风挡、两侧上下排列枪包；文字核对12枪/双发/轮组 | 插画裁掉翼尾，不能替代全机照；汇编页修订1944-10-10 |
| H03 | p009.png/p010.png（Figures5/6） | 装甲与机身配置图；炮塔前置、腰/尾防御枪位、双尾与翼平面辅助 | 手册示意透视，不可当精确投影；图5晚期附加底板不采用 |
| H04 | p013.png/p014.png（Figures8/9） | 轮组收放宿主、前轮/主轮、襟翼和弹舱双门运动辅助 | 非完整精密传动测绘，模型只有限转轴/显隐 |
| M01 | alistairfgauld_240419_66224436e7cdb.jpg | Alistair Gauld HKM1/48成品，完整左斜前、停放；全机与透明鼻/座舱/短舱交叉检查 | 成品模型；三鼻枪/涂装/条纹不用于早期12枪历史证明；保持简化，不复制铆钉 |
| M02 | alistairfgauld_240419_66224431d9e15.jpg | 同机完整高位斜前；机翼平面收束、低上反外翼、尾翼/鳍位置、舱盖 | 有透视，不称严格顶视；尾号和红罩圈不采用 |
| M03 | alistairfgauld_240419_6622443488c69.jpg | 同机完整高位斜后；长短舱后锥、尾翼与双联尾枪、防御枪位 | 地面全下襟翼，不能据此改变飞行翼型 |
| M04 | alistairfgauld_240419_6622443329ae2.jpg | 同机另一侧高位；座舱阶梯、整机体量、腰枪和主要连接 | 右翼尖虽近边仍完整，透视明显 |
| M05 | alistairfgauld_240419_6622443641114.jpg | 同机高位近侧/近顶；翼尾轮廓、襟/副翼分区 | 非正顶，机翼状态不同于巡航；条纹不作史实 |
| M06 | alistairfgauld_240419_6622443a25344.jpg | 同机完整低位后斜；垂尾上下延伸、尾枪罩、短舱后段与机翼连接 | 近侧主轮可见，远轮遮挡；无底部装填视图 |
| R01 | B25Chino08.jpg | Richard Seaman，2008 Chino，保存B-25J“Photo Fanny”；完整腹面，近俯视式平面检查、关闭轮舱/弹舱 | 修复/表演机无背塔炮罩、缺部分枪包；不据此删战时武器或复制涂装 |
| R02 | HeavenlyBodyFlying.jpg | Richard Seaman，2004 March Field，B-25“Heavenly Body”；完整斜腹面、双舱门向下开、巡航轮收状态 | 原作者页只称B-25，具体生产子型未核；限共通舱门/机腹，不作早期J鼻枪证据 |
| R03 | B-25-Wild-Cargo-from-the-MAM-Photo-Archives-1102x720.jpg | MAM 44-30129修复J；近正前放轮、三轮长短和中翼/双尾/机鼻体量 | 两翼尖裁切，不计完整正前；1944-12交付、复制枪械，非本机1944-07配置 |
| P01 | b-25j-ned-3.jpg | Cees Hendriks2013，修复J 44-31258；双联尾枪枪口承载局部 | 600×337，晚期/修复，只看外承载，不能测射界 |
| L01 | loading-record-p082.png | 战时11th Bombardment Squadron《The Record》印刷81/PDF82，表列6×500 GP，D/H/J挂架相同；M64使用条目 | 数量类别有据；逐站坐标仍需装载厂图，模型保守安排并标近似 |

来源页面：
- 手册：https://stephentaylorhistorian.com/wp-content/uploads/2020/04/b25jpfoi.pdf （USAAF/NAA原始资料，修订汇编，扫描私人参考）
- 成品：https://imodeler.com/2024/04/hong-kong-models-1-48-mitchell-b-25j-glazed-nose/ （2024-04-19，原作者保留版权）
- 修复局部：https://www.ipms.nl/walkarounds/walkaround-vliegtuigen-props/walkaround-b25 （Cees Hendriks，IPMS NL版权）
- 腹面：https://www.richard-seaman.com/Aircraft/AirShows/Chino2008/Highlights/ 与 https://www.richard-seaman.com/Aircraft/AirShows/MarchField2004/Sampler/index.html （Richard Seaman版权）
- MAM：https://www.militaryaviationmuseum.org/aircraft/north-american-b-25-mitchell/ （馆藏页，档案图版权保留）
- 载荷：https://worldwartwoveterans.org/wp-content/uploads/2022/01/The-record_-the-eleventh-Bombardment-Squadron-M.pdf （战时部队记录影印）

覆盖结论：侧面/完整斜前/高位近顶/完整后斜/完整腹面均已实际查看；完整严格正前、严格厂图正顶与精确站位尚缺，近正前由H01与R03互补，仅做观战距离几何，不宣称测绘精度。现有资料足以进入大形建模。

武装：活动鼻枪1+固定鼻枪1（右侧）、机身左右各2固定、背塔2、左右腰各1、尾部2，共12挺.50。照片中的晚期额外固定鼻枪不制作。首批内部6枚AN-M64级，双侧梯式挂架每侧三层，坐标为可装配估值；BOMB持有库存，先放下层再上层以免通过仍挂载弹体。

外观：橄榄褐上表面/中性灰下表面与蓝白星徽，通用早期USAAF识别，不声称复原成品模型的“Cactus Kitten”或任何特定尾号。发动机内部/细密框架/地勤不在范围。

淘汰：旧docs/references/bombers/b25/05.jpg为实心八枪鼻，不能用于透明鼻；本次初选b-25j-ned-1/2/4/8/10/18/20及b-25j-mitchell-1…6实际打开前四张后确认为局部/内部，全部不计整机角度。下载成功不等于采用，未实际查看的其余候选不承担几何证明。

补核弹药：已实际打开TM9-1980/AFM136-7 **1950版**原始表XXVII（印刷296/PDF299，`manual-pages/tm9-p299.png`），AN-M64 TNT完整弹511.8lb=232.148575kg、TNT261.7lb=118.705123kg，表列总长59.2in、弹身直径14.2in。6枚实际质量1392.89145kg，与名义6×500lb分开；后期M64A1条目不混入。该1950表不能独立证明1944具体批次或引信，本机为TNT型明确选择的未注册提案。BOMB01现有240kg占位不能自动视为同一装填；由统筹协调。来源：https://hangarthirteen.org/wp-content/uploads/2023/04/9-1980-Bombs-for-Aircraft.pdf 。

模型修正记录：首轮襟翼旋转符号已改成实际向下；双尾中立轮廓收顺，消除接缝V缺口；翼面星徽修正法线/层次/前向。可选两侧机身星徽整块省略，避免曲面裁切，不继续细化贴花。玻璃保持不透明色块，不做内舱。
