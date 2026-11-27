extends "res://aircraft/us_archive/visual_parts.gd"
## Pacific P-38J visual study. Museum geometry and documented wartime markings
## are separate references; not the Smithsonian museum airframe's paint.
const LABEL: String="P-38J Lightning / Marge-inspired / 1944"
const LENGTH_M: float=11.70
const SPAN_M: float=15.80
const POD: Array=[[-4.89,-.15,.055,.077,.08],[-4.73,-.12,.22,.23,.25],[-4.48,-.07,.36,.35,.40],
	[-4.10,-.04,.47,.43,.49],[-3.56,-.01,.55,.50,.55],[-2.95,.01,.61,.55,.64],[-2.20,.01,.65,.60,.70],
	[-1.42,.02,.63,.56,.65],[-.70,.02,.58,.48,.56],[.03,.02,.49,.39,.44],[.71,.04,.37,.29,.31],
	[1.31,.07,.26,.21,.23],[1.78,.12,.15,.138,.14],[2.11,.15,.046,.052,.07]]
const BOOM: Array=[[-5.48,.13,.16,.18,.15],[-5.28,.13,.36,.34,.41],[-4.99,.13,.45,.42,.58],
	[-4.65,.15,.49,.47,.63],[-4.23,.17,.51,.49,.63],[-3.79,.19,.54,.50,.59],[-3.19,.22,.55,.51,.56],
	[-2.52,.25,.56,.54,.56],[-1.72,.28,.56,.52,.52],[-.96,.30,.48,.43,.43],[-.32,.31,.40,.35,.38],
	[.38,.33,.37,.33,.34],[1.08,.34,.346,.30,.31],[1.78,.36,.32,.27,.27],[2.53,.41,.27,.23,.24],
	[3.28,.47,.222,.201,.213],[4.02,.52,.188,.181,.18],[4.65,.55,.152,.159,.154],[5.22,.59,.11,.122,.12],
	[5.59,.62,.052,.077,.082],[5.74,.62,.03,.04,.047]]
const WING: Array=[
	[0.,-2.27,3.12,.04,.148],[.64,-2.21,3.06,.055,.147],[1.62,-2.16,2.99,.09,.147],
	[2.37,-2.12,2.95,.12,.145],[2.89,-2.10,2.9,.15,.143],
	[3.77,-1.94,2.65,.21,.132],[4.78,-1.78,2.36,.29,.122],[5.83,-1.60,2.05,.37,.108],
	[6.64,-1.44,1.83,.44,.10],[7.20,-1.29,1.58,.50,.092],[7.57,-1.13,1.35,.53,.080],
	[7.75,-.95,1.02,.55,.063],[7.87,-.78,0.73,.56,.041],[7.90,-.63,0.48,.56,.032]]
const CANOPY: Array=[[-2.60,.57,.32,.065,.03],[-2.40,.58,.43,.34,.05],[-2.12,.59,.49,.54,.05],
	[-1.80,.58,.505,.605,.07],[-1.43,.54,.49,.615,.06],[-1.07,.50,.437,.49,.058],[-.73,.47,.37,.32,.05],
	[-.36,.42,.32,.18,.043],[-.12,.39,.26,.065,.04]]
const TAIL: Array=[[0.,4.13,1.57,.68,.089],[.62,4.15,1.55,.68,.088],[1.38,4.16,1.53,.68,.082],
	[1.95,4.17,1.50,.68,.075],[2.42,4.19,1.44,.685,.071]]

func _ready() -> void:
	_set_paint(Color("64654b"),Color("969d93"))
	var nacelle: Node3D=GEO.group(self,"CentralCockpitPod")
	GEO.part(nacelle,"NoseAndPod",GEO.loft(POD,-4.10,2.11,paint.top.albedo_color,paint.bottom.albedo_color,Vector4.ZERO,true),paint.skin)
	GEO.part(nacelle,"RedNoseCone",GEO.loft(POD,-4.89,-4.10,Color.WHITE,Color.WHITE,Vector4.ZERO,true),paint.red)
	_canopy(GEO.group(nacelle,"SingleSeatCanopy"),CANOPY)
	var wing: Node3D=GEO.group(self,"Wing")
	var tail: Node3D=GEO.group(self,"Tail")
	var marks: Node3D=GEO.group(self,"Markings")
	for side: float in [-1.,1.]:
		var root: Node3D=GEO.group(self,"PortBoom" if side<0. else "StarboardBoom",Vector3(side*2.42,0,0))
		_body(root,"PowerNacelleAndBoom",BOOM)
		_engine_cooling(root,side)
		GEO.part(wing,"MainWing",GEO.wing(WING,side,.0,7.18,.0,1.,Vector3.ZERO,paint.top.albedo_color,paint.bottom.albedo_color),paint.skin)
		GEO.part(wing,"PaintedWingtip",GEO.wing(WING,side,7.18,7.90,.0,1.,Vector3.ZERO,Color.WHITE,Color.WHITE),paint.red)
		_wing(tail,"LinkStabilizer",TAIL,side)
		_fin(root,"RudderAndFin",[[-.14,4.73,5.67,.03],[.07,4.48,5.80,.065],[.30,4.40,5.84,.081],
			[.54,4.26,5.865,.094],[.83,4.20,5.86,.098],[1.13,4.25,5.81,.091],[1.50,4.34,5.73,.081],
			[1.79,4.45,5.60,.072],[2.01,4.59,5.48,.053],[2.18,4.76,5.34,.04],[2.25,4.94,5.15,.022]],Vector3.ZERO,true)
		for span: float in [3.20,5.65,7.29]:
			_wing_seam(wing,WING,side,span)
		var tip: Vector3=GEO.wing_point(WING,7.85,.39,true);tip.x*=side
		_ellipsoid(wing,"TipLamp",Vector3(.052,.032,.069),tip,paint.red if side<0. else paint.nav_green)
		_star_bar(root,"body",BOOM,Vector2(.31,.35),.255,side)
	_star_bar(marks,"wing",WING,Vector2(-6.02,-.48),.49,1.)
	_star_bar(marks,"wing",WING,Vector2(6.02,-.48),.49,-1.)

func _engine_cooling(host: Node3D,side: float) -> void:
	# J-model deeper chin with inset three-section dark face, not an engine model.
	var chin: Array=[[-5.34,-.39,.330,.189,.177],[-5.24,-.39,.39,.211,.221],[-4.98,-.39,.424,.22,.226],[-4.83,-.38,.42,.20,.205],
		[-4.48,-.41,.42,.19,.184],[-4.00,-.36,.36,.18,.14],[-3.61,-.27,.20,.12,.072],[-3.40,-.20,.10,.098,.04]]
	_body(host,"LowerIntakeFairing",chin)
	_ellipsoid(host,"PortChinOpening",Vector3(.091,.127,.017),Vector3(-.155,-.398,-5.344),paint.dark)
	_ellipsoid(host,"CenterChinOpening",Vector3(.061,.139,.019),Vector3(0,-.394,-5.349),paint.dark)
	_ellipsoid(host,"StarboardChinOpening",Vector3(.091,.127,.017),Vector3(.155,-.398,-5.344),paint.dark)
	for s: float in [-1.,1.]:
		var scoop: Array=[[-.67,.27,.15,.15,.15],[-.51,.26,.29,.27,.25],[-.22,.25,.31,.28,.28],
			[.37,.27,.29,.28,.25],[.82,.30,.24,.26,.21],[1.39,.34,.16,.18,.16],[1.75,.36,.07,.09,.09]]
		_body(host,"SideCoolerFairing",scoop,Vector3(s*.285,0,0))
		_ellipsoid(host,"RecessedSideOpening",Vector3(.109,.121,.023),Vector3(s*.41,.267,-.545),paint.dark)
	GEO.arch(host,"EngineCoverSeam",BOOM,-3.64,.024,paint.seam,-PI*.54,PI*.54)
	GEO.arch(host,"RearPanelSeam",BOOM,-2.76,.020,paint.seam,-PI*.47,PI*.47)
	_prop(host,Vector3(0,.13,-5.43),1.78,Vector3(.235,.231,.31),.21 if side<0. else -.35,side,paint.red)
