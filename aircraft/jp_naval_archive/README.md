# 日军海航展厅外观：D3A1 / B5N2

两个场景独立运行，均为展开翼、合上座舱的静态艺术外观，无武器和飞行逻辑。透过合上的座舱不显示后席活动枪架；照片里的手动枪架不是动力炮塔，因此没有为这两架飞机增设虚构炮塔。无挂载、物理或战局接口。

| 展厅场景 | 识别重点 | 原始档案对照 |
|---|---|---|
| `d3a1.tscn`，D3A1 九九舰爆（约 1942 型貌） | 圆顺椭圆翼梢、显眼的固定式整流罩起落架、较短的双席分段座舱、宽圆形尾翼。档案中的后席开盖和飞行人员不复刻。 | [澳大利亚战争纪念馆 P02886.001，约 1942 年，翔鹤两架 D3A](https://www.awm.gov.au/collection/C374851) · [澳大利亚战争纪念馆 RELAWM32663，D3A1 实物翼梢](https://www.awm.gov.au/collection/RELAWM32663) · [美国海军博物馆 80-G-32643，D3A1](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/wwii/wwii-pacific/us-entry-into-wwii-japanese-offensive/1941-december-7-japanese-attack-on-pearl-harbor/japanese-pearl-harbor-striking-force/japanese-aircraft/80-g-32643.html) |
| `b5n2.tscn`，B5N2 九七舰攻（早期战争型貌） | 收起主起落架、长框架座舱、收窄的外翼和醒目的翼段分缝、圆形机头。用战后档案核对连续座舱轮廓及翼面，不把投降涂装搬入游戏。 | [澳大利亚战争纪念馆 P03132.001，1945 年 8 月拉包尔 B5N2](https://www.awm.gov.au/collection/C387656) · [澳大利亚战争纪念馆 129706，B5N2 全机侧后照](https://www.awm.gov.au/collection/129706) · [美国海军博物馆 80-G-32684，1941 年 B5N2](https://www.history.navy.mil/content/history/museums/nmusn/explore/photography/wwii/wwii-pacific/us-entry-into-wwii-japanese-offensive/1941-december-7-japanese-attack-on-pearl-harbor/japanese-pearl-harbor-striking-force/japanese-aircraft/80-g-32684.html) |

灰米色与灰绿色是展厅辨识用的美术涂装；黑白档案只核对外形，未将色相、序号或挂载状态当史实复原。按相同正投影机位对照各自的侧观、俯观和前斜视轮廓。Godot 4.7.2 实例化两模型检查正常；渲染包围盒最大翼展为 14.36 / 15.50 米（展厅模型值）。没有把档案照片写入仓库。
