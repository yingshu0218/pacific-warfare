# 历史依据、尺寸与实现边界

## 机场设定

场景参照沃莱艾环礁法拉拉普岛（Woleai / Falalap），时间设为 1944 年。沃莱艾机场由日军修建；资料记载其跑道约 3,290 × 330 英尺（约 1,003 × 101 米），另有约 2,050 × 165 英尺（约 625 × 50 米）的滑行道。1944 年 2 月 25 日的美军空中地图用于核对机场在岛上的位置与 NE—SW 大致方位。机场资料亦记载其在 1944 年 4 月至 1945 年 4 月遭到空袭。

模型把这两个宽度理解为清障/压实范围：跑道中央表现为 58 米宽硬化珊瑚面，外侧总净空带约 100 米；滑行道是 16 米宽通行面，置于约 50 米净空带内。长度采用资料尺寸并按 1:1 米制建模。小岛外围尺寸、海岸曲线、林带、机坪、机库位置和设施间距是根据单岛地形及航路需要制作的视觉重构，不宣称是测绘复原。岛面起伏保持低缓，模拟珊瑚岛；跑道两端均在海上留有进近和离场空间。

## 飞机

使用仓库已有的程序化三菱 A6M5a Model 52 Ko 模型，不复制或修改飞机任务资产。模型标注服役年代为 1944 年，尺寸为长 9.121 米、翼展 11 米、高 3.57 米；配置说明为中岛荣 21 型发动机、两挺九七式 7.7 毫米机枪和两门九九式二号四型 20 毫米机炮。尺寸与系列配置对照日文 A6M5 资料表和 Smithsonian 的 A6M5 Model 52 收藏记录。这里展示的是可用于 1944 年设定的机型，不断言该具体甲型当时部署在法拉拉普岛。

飞机保持现有资产的 1:1 几何；螺旋桨和轮子随阶段转动。滑行、起飞、航线、进近、接地与滑回由可复现的三维航点驱动。演示路线、姿态和速度是观赏模拟，不包含升力/阻力求解、天气、跑道摩擦、轮胎载荷或碰撞损伤。

## 地面装备与建筑

- **九六式 25 毫米双联高射炮**：场景设置两处固定阵地，并在南侧增设一座与机枪并排的尺度对照位。程序模型表现约 1.49 米双炮管、每管独立的 15 发箱式弹匣、炮闩、液压弹簧复进筒、炮耳架、俯仰/方向手轮、简化计算瞄具和双炮手座椅；炮台采用开放式炮架与三层沙袋掩体，没有大型炮盾。美军 1944 年手册记录该炮用于机场周边的双联/三联固定阵地、手轮控制和计算式瞄具；1945 年 CINCPAC-CINCPOA 公报记录 58.5 英寸炮管、15 发箱式弹匣及液压弹簧复进。具体炮架、座椅和炮位外形仍是场景重构，炮管不模拟俯仰/转向或射击。近景图为 `screenshots/type96_aa_closeup.png`。
- **九二式 7.7 毫米重机枪**：外围放置三处三脚架阵地，并在南侧尺度对照位与九六式双联炮同地面并排摆放。模型按 1945 年 CINCPAC-CINCPOA Bulletin SS-45 的 46 英寸（约 1.17 米）全长和 28.4 英寸（约 0.72 米）枪管长度控制比例，表现霍奇基斯式风冷散热环、枪口消焰器、左侧 30 发金属弹板、右侧拉机柄、照门、下垂木质握把和三脚架高低机手轮。弹药只作静态展示，不模拟供弹、转向或射击。并排对照位用于比例查看，不代表已确认的历史炮位。近景图为 `screenshots/type92_hmg_closeup.png`；并排图为 `screenshots/type92_vs_type96_scale.png`。注意：原引用的美军手册中 56 英寸尺寸属于另一种 Lewis 型 Model 92 航空机枪，不能用于九二式重机枪。
- **机库、观察塔、工棚**：以热带岛屿机场所需的木构架、波纹金属屋面、开门维修空间和高架观察室制作。当前没有把可查到的某座法拉拉普机库平面或防空炮位图当作确证；设施布局属于场景重构。

## 资产来源与许可

- 岛屿、机场设施、沙袋、地面装备和动态海水均为本项目 GDScript 程序几何/材质，不引入第三方模型、照片或 AI 纹理。
- A6M5a 飞机几何复用仓库 `aircraft/` 内项目自有资产；未修改其文件。
- HUD 字体复用 `assets/fonts/NotoSansCJKsc-Regular.otf`，仓库附带 SIL Open Font License 1.1。
- 历史来源只用于尺寸、时间与装备识别。未获得的机场布置图与详细构造按推定处理。

## 资料

1. [Pacific Wrecks：Woleai Airfield](https://pacificwrecks.com/airfield/fed_states/woleai/index.html) — 跑道/滑行道尺寸、建造与战时使用摘要。
2. [Pacific Wrecks：1944-02-25 美军沃莱艾机场地图](https://pacificwrecks.com/airfield/fed_states/woleai/maps/map-woleai-2-25-44.html) — 岛上机场位置与方位核对。
3. [FSM 民航局：Woleai Civil Airfield](https://tci.gov.fm/civilaviation/woleai.html) — 法拉拉普岛与现址信息。
4. [U.S. Naval Technical Mission to Japan, O-47(N)-2 (PDF)](https://www.fischer-tropsch.org/primary_documents/gvt_reports/USNAVY/USNTMJ%20Reports/USNTMJ-200F-0524-0618%20Report%20O-47%20N-2.pdf) — 九六式 25 毫米炮架型号、双联装与结构资料。
5. [U.S. War Department, TM-E 30-480 (1944)：Japanese Machine Guns](https://www.lonesentry.com/manuals/handbook-japanese-military/japanese-machine-guns.html) — 九二式重机枪为霍奇基斯式改型、导气式、风冷、金属弹板供弹及其瞄具说明；手册内 56 英寸尺寸对应 Lewis 型 Model 92。
6. [CINCPAC-CINCPOA Bulletin SS-45 (1945)：Japanese Infantry Weapons](https://www.bulletpicker.com/pdf/Japanese-Infantry-Weapons.pdf) — 九二式重机枪 46 英寸全长、28.4 英寸枪管、30 发金属弹板、三脚架和重量数据。
7. [Australian War Memorial：Type 92 Heavy Machine Gun](https://www.awm.gov.au/collection/C150147) — 实物细节：枪管散热环、枪口锥形消焰器、右侧拉机柄及润滑金属弹板。
8. [A6M5 系列尺寸与配置表（日文）](https://japanese-warship.com/aircraft/zero-a6m5/) — A6M5/A6M5a 系列数据与型号区分。
9. [Smithsonian National Air and Space Museum：A6M5 Model 52](https://airandspace.si.edu/collection-objects/mitsubishi-a6m5-reisen-zero-fighter-model-52-zeke/nasm_A19600335000) — A6M5 Model 52 实机收藏与塞班岛来源记录。
10. [U.S. War Department, TM-E 30-480 (1944)：Japanese Antiaircraft Artillery](https://mobile.lonesentry.com/manuals/handbook-japanese-military/japanese-antiaircraft.html) — 九六式双联/三联固定阵地、手轮控制、计算式瞄具和 15 发弹匣。
11. [CINCPAC-CINCPOA Bulletin SS-45 (1945)：25 mm Automatic Cannon Model 96](https://www.bulletpicker.com/pdf/CINCPAC-CINCPOA-Bulletin-55-45.pdf) — 58.5 英寸炮管、箱式弹匣和液压弹簧复进系统。
12. [Australian War Memorial：25 mm Type 96 Triple Mount Anti-Aircraft Gun](https://www.awm.gov.au/collection/C238576) — 保存实物照片与炮架细节，可对照炮管冷却环、炮手座椅和转台构造。


## 1944 年调查复核与本轮修订

[1944 年 JICPOA 沃莱艾调查原件](https://upload.wikimedia.org/wikipedia/commons/f/ff/NDL4009823_No._36-44%2C_10_March_1944%2C_supplement_to_above%2C_Woleai_target_survey._Report_No._11-b%288%29%2C_USSBS_Index_Section_6.pdf) 的 PDF 第 2–4 页包含平面示意、4 月空照拼图和文字。该版记录的**完工硬面**主跑道约 930 × 91 m，走向 048°/228°；东侧滑行道约 526 × 46 m，大致南北向，与主跑道不平行。另见东西向在建条带，不应画成第二条已完成硬面。北侧宽、南侧收尖的岸线也不同于现有椭圆示意。这里比较的是当期记录与游戏大形，不据此断言整个 1944 年布局相同。

当前入口仍为**可运行的概略演示**，没有用新档案尺寸替换旧 1,000 × 58 m 主跑道或 625 × 16 m 滑行硬面，也未改岸线或路线。本轮修正确认存在的几何交叠与遮挡：两条联络道硬面边界贴合跑道和滑行道，硬面统一为 3.72 m；机坪联络道与中央机坪拼边，两处停机坪下的地形留出铺面余量。远景镜头按离地和缩放距离动态调整近裁面，改善 Compatibility 透视深度精度；近地和近景维持 0.12 m。图像表现仍需在有渲染器的窗口复查。脚本 `tests/test_surface_geometry.gd` 能复查实际网格、默认镜头深度预算，并等待原演示完整返场。
