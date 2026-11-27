# B-24D 解放者 | 静态飞行外观重建

独立入口 `res://aircraft/b24d/b24d_viewer.tscn`，1 / 2 / 3 为斜前、侧面、俯视。展翼、收轮、固定桨相位。这个版本是在此前源资产未能恢复的情况下重新制作的，不冒充原提交的逐字节恢复。未接入正式观战、Web、AI、飞行、损伤或装备系统。

## 影像和尺度

- 实际查看 [美国军方 AN 01-5E-3 第 viii 页，B-24D 三视图](https://commons.wikimedia.org/wiki/File:Consolidated_B-24D_Liberator_3-view_line_drawing.png)。只参照可见外壳轮廓：窄尖高翼、短水平尾翼、超过水平尾面的卵形双垂尾、前后错位四短舱、深箱型机身和 D 型透明机鼻。
- 实际查看 [第七航空队 B-24D 41-23929 飞行照片](https://pacificwrecks.com/aircraft/b-24/41-23929/b24d-41-23929-in-flight.html)，补核四短舱、机身尾部收分和外部白星圆形标识。上部橄榄色、下部灰色为代表性工作配色，不还原特定机号、战区机队涂装或鼻绘。
- [美国空军国家博物馆 B-24D](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/196286/consolidated-b-24d-liberator/)给出翼展 110 英尺、机长 66 英尺 4 英寸。三视图是外观比例参考，不用于实物装配或内部构造；显示高与实机停放高度不是同一口径。
- 重做互相分开的机鼻窗格、阶梯风挡与侧窗、低背透明罩、鼻舱与尾舱外皮、圆形短舱唇口、机身观察窗、控制面外表线、浅色桨尖。纯外观网格与代表性配色，无第三方照片材质。

## Godot 审核

Godot 4.7.2 起用独立观察场景，按网格验证翼展 33.528 米、机长 20.218 米、显示高度 4.794 米、双垂尾外宽 7.933 米；4 具短舱、12 片桨叶、16 个鼻窗片、13,730 三角形，七个主部件无开边或非流形边。三个观察角度逐点验框通过。展示图由 Godot 实际网格导出后离线渲染，非原生游戏截屏。

```sh
godot --headless --path . --script tests/model_audit/test_b24d_visual.gd -- /tmp/b24d.glb
```
