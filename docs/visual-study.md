# 大和视觉研究样件

> 2026-11-10 S02：本文件保留历次研究日志。当前39座游戏清单、修正后主副炮标高、模块宿主与真实炮口以 [S02交付](showcase/deliveries/S02.md) / [dated参考包](references/ships/yamato_1944_04/modeling-brief.md) 为准；旧69/75座说明、旧坐标与旧测试结论不作为当前状态。历史编制与专用AA游戏配置继续分开。

运行：`/Applications/Godot.app/Contents/MacOS/Godot --path /Users/infinity/Desktop/Dev/game-pacific`

Godot 4.7.2，Compatibility，米制。拖动环绕、滚轮缩放、右键平移，1/2/3 切换全舰/舰桥/主炮近景，L 改变灯光。

选取 1944 年拆除舷侧 155 mm 炮塔后的总体布局，263 m 总长、38.9 m 最大宽度、三座三联装 460 mm 主炮，两座中线三联装副炮、十二座双联装高炮。尺寸依据：https://navypedia.org/ships/japan/jap_bb_yamato.htm ，改装与武器数量参考：https://pwencycl.kgbudge.com/Y/a/Yamato_class.htm 。不同资料的改装日期与小口径武器数量存在差异，此版本不宣称逐阵位复原。

所有几何与海面着色器为本项目原创，无第三方美术资产。模型使用程序化截面舰体、模块化炮塔和设施，未使用 AI 图片。现阶段仍有显著简化：舰首与艉部截面待线图核对，舰桥为体量研究，部分舷窗、索具、舰载艇和双翼水上机已用简化几何表示，仍缺真实炮盾曲面与精确防空阵位。海面为双正弦位移与程序法线，没有真实反射或流体计算。

现有75座武器均有独立回转与俯仰轴，按主炮、副炮、双联高炮、三联机炮区分速度和范围。Tab逐座选择并近看，方向键手动操纵，R恢复自动，空格暂停。F切换静态与轻微漂浮。射界仍为展示参数，尚未校准历史遮挡与禁射区；当前小口径数量与阵位未完成1944年配置复原。不可视为精密舰模交付。

验证：引擎版本、headless导入与启动通过；Apple M5 Compatibility实际渲染截图见preview.png。test_weapon_motion.gd验证75座武器60秒运动的回转速度与双轴限位。截图模式 -- --capture 自动保存并退出，不保留窗口。浏览器、Safari/Chrome帧率与16GB内存基准尚未完成。

## 参数依据与未校准项

主炮2°/s回转、10°/s俯仰、−5…45°；高炮A1采用6.5°/s回转、12°/s俯仰、−7…90°。资料：https://www.navweaps.com/Weapons/WNJAP_18-45_t94.php 与 https://www.navweaps.com/Weapons/WNJAP_5-40_t89.php 。机炮与副炮参数仍需原始资料复核；所有局部回转限位尚不能替代上层建筑遮挡禁射区。当前采用32座三联加26座单装25毫米炮的1944年春编制研究，阵位未逐项核对。

网页导出已通过，内置浏览器已实际显示舰体、武器和海面。发现中文默认字体缺字，待嵌入中文字体。此检查不能替代Safari/Chrome性能验收。可执行 `./tools/preview_web.sh`，再访问 http://127.0.0.1:8765 ，结束后Ctrl-C关闭服务。测试标签页与服务已关闭。

水上机为原创双翼浮筒飞机外形研究，不宣称已经还原某一生产批次的F1M；停放姿态、数量和固定点尚待历史照片核对。

共有结构辅助参考：Tamiya 78030说明书第17页，https://www.towerhobbies.com/on/demandware.static/-/Sites-horizon-master/default/dwc6976d52/Manuals/TAM78030_Manual_MULTI.pdf 。据此修正弹射器横向朝舷外；该套件的晚期防空阵位未直接套入本1944年样件。

按说明书第18页共有结构的纵向比例进行首次位置校正：前主炮炮座中心约z=-58、-38米，后主炮约z=63米（模型坐标舰艏为负）。这属于图像比例估计，不是原舰站位测量；另补烟囱后方后舰桥。

逐座检查：Tab下一座、Shift+Tab上一座；选中面板显示自动/目标/手动保持及几何受阻状态。可通过Godot --path . -- --capture --weapon=light_aa_07直接截取指定炮位近景，输出docs/inspection.png；ID来自炮位数据。命中坐标保存在审计JSON，界面仅显示状态。
