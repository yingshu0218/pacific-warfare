# 宾夕法尼亚号（BB-38）与塞缪尔·B·罗伯茨号（DE-413）外观

两舰是互相独立的 Godot 静态游戏展品。米制、舰艏沿 -Z、展示水线 Y=0。未加入对局、程序指挥、武器行为、碰撞、性能标定或内部构造；外露陈设仅保留可识别的非功能形态。水下体积、看不见的细部、色彩重建均非测绘。

## 宾夕法尼亚号：1944-07-21，关岛

- 实际打开 [NH 67584 同舰关岛俯斜照](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/pennsylvania-bb-38/NH-67584.html) 的历史镜像原图，仅用能看清的艏艉和上层布局；烟雾遮挡部分不从该图补猜。
- 实际打开 [80-G-K-2106 约 1944 年彩色进坞照片](https://www.history.navy.mil/our-collections/photography/us-navy-ships/battleships/pennsylvania-bb-38/80-G-K-2106.html) 及 [80-G-156820-A 布船局旁视、俯视原图](https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/g100000/g156820a.jpg)。前者核对外飘艏、船侧鼓包和前塔层级，后者核对宽短舰体、前后外形组、单烟囱和桅杆相对站位。年代不同，不作为当天细件清单。
- 源自 [80-G-156820 涂装原稿](https://www.ibiblio.org/hyperwar/OnlineLibrary/photos/images/g100000/g156820.jpg) 和彩色干坞照片的蓝灰折带仅为展示解释，未声称逐面复刻当日实涂。舰长 608 英尺与改装后 106 英尺 3 英寸舰宽依据 [NHHC 舰史](https://www.history.navy.mil/research/histories/ship-histories/danfs/p/pennsylvania-ii.html)，展示吃水 8.79 米是尺寸基线，不作当天载况。
- 独立场景 `res://scenes/ships/bb38_guam/bb38_viewer.tscn`。Godot 网格实测 185.3184×32.3850 m，展示吃水 8.7900 m；10,740 三角面，0 船壳开边或非流形边。

## 塞缪尔·B·罗伯茨号：1944 年 10 月

- 实际打开 [NH 96011 同舰 10 月右艏照](https://www.history.navy.mil/content/history/nhhc/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-96000/NH-96011.html) 与 [NH 90603 同舰约 6 月舷侧照](https://www.history.navy.mil/our-collections/photography/numerical-list-of-images/nhhc-series/nh-series/NH-90000/nh-90603-uss-samuel-b--roberts--de-413-.html)。10 月照片给出高艏、短舰桥和右舷曲线色带；早照提供较近正侧布局，不能用来判定 10 月所有小件。
- 独立重建其长高艏楼、迅速降到低后甲板、后倾单高桅、短单烟囱和前后各一组静态甲板造型。右舷曲带为宽略近似，远舷无确证故保留工作色，不冒称复刻。名义长宽与吃水依据 [NHHC 舰史](https://www.history.navy.mil/content/history/nhhc/research/histories/ship-histories/danfs/s/samuel-b-roberts-de-413-i.html)；吃水同为展示基线。
- 独立场景 `res://scenes/ships/de413_1944/de413_viewer.tscn`。Godot 网格实测 93.2688×11.1506 m，展示吃水 4.0640 m；5,912 三角面，0 船壳开边或非流形边。

## 复验

Godot 4.7.2；两个独立入口均实跑可启动，四相机检视入画、水面模式切换与纹理 UV 检查通过。按键：1 斜视，2 舷侧，3 俯视，4 全船体。使用 `godot --headless --path . --script tests/model_audit/test_bb38_de413_visual.gd` 可复验；设置环境变量 `PAIR_GLB_DIR` 为本地当前已存在目录，可由同检视场景导出实际 GLB。对照图用导出网格离线渲染，不是游戏实时截图。
