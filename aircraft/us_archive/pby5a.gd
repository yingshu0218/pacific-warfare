extends "res://aircraft/us_archive/visual_parts.gd"
## Independent amphibian visual. Show retracted wheels with the wingtip floats down.
const LABEL: String = "PBY-5A Catalina / Pacific, 1944"
const SPAN_M: float = 31.699
const LENGTH_M: float = 19.456
const HULL: Array = [
	[-9.53,.22,.13,.13,.13],[-9.40,.25,.38,.26,.27],[-9.08,.26,.65,.35,.42],[-8.64,.25,.82,.40,.63],
	[-8.08,.25,.96,.47,.92],[-7.45,.30,1.035,.53,1.13],[-6.79,.37,1.075,.63,1.37],[-6.0,.37,1.11,.65,1.60],
	[-5.23,.33,1.15,.72,1.64],[-4.30,.30,1.19,.77,1.67],[-3.35,.31,1.22,.78,1.70],[-2.23,.32,1.235,.79,1.75],
	[-1.19,.34,1.24,.76,1.81],[.14,.33,1.24,.76,1.87],[1.02,.33,1.23,.76,1.92],
	[1.26,.34,1.22,.75,1.89],[1.38,.34,1.22,.75,1.53],[2.30,.39,1.17,.71,1.50],
	[3.25,.43,1.10,.65,1.42],[4.22,.53,.987,.60,1.31],[5.19,.62,.86,.52,1.14],[6.10,.71,.71,.46,.93],
	[7.08,.81,.55,.37,.68],[7.99,.91,.39,.29,.47],[8.71,1.01,.28,.20,.30],[9.28,1.07,.149,.14,.18],[9.62,1.09,.05,.075,.07]]
const WING: Array = [
	[0,-5.45,5.23,3.0,.18],[2.4,-5.44,5.22,3.0,.18],[4.0,-5.42,5.19,3.0,.173],
	[6.12,-5.40,5.13,3.0,.165],[7.82,-5.37,5.05,3.0,.151],[9.48,-5.18,4.66,3.01,.139],
	[11.28,-4.98,4.22,3.015,.127],[13.0,-4.78,3.72,3.02,.111],
	[14.26,-4.61,3.27,3.043,.097],[15.15,-4.46,2.88,3.05,.081],
	[15.60,-4.28,2.43,3.06,.068],[15.80,-4.08,1.93,3.07,.052],[15.85,-3.83,1.28,3.08,.034]]
const TAIL: Array = [[0,6.23,2.88,1.34,.115],[.75,6.25,2.79,1.34,.109],[1.65,6.44,2.47,1.36,.096],
	[2.70,6.68,2.06,1.39,.085],[3.74,6.99,1.64,1.42,.071],[4.56,7.29,1.20,1.45,.061],
	[4.98,7.53,.86,1.46,.048],[5.24,7.79,.39,1.47,.029]]
const DECK: Array = [[-8.26,.70,.43,.048,.05],[-8.08,.74,.54,.22,.11],[-7.86,.78,.68,.52,.16],[-7.56,.84,.745,.62,.21],
	[-7.15,.92,.775,.58,.22],[-6.67,1.005,.775,.49,.20],[-6.10,1.011,.74,.425,.14],[-5.64,.98,.69,.34,.15],[-5.27,.99,.56,.176,.10]]
const NACELLE: Array = [[-6.66,.00,.64,.66,.64],[-6.56,0,.71,.72,.70],[-6.30,0,.75,.76,.74],[-5.88,0,.75,.765,.755],
	[-5.49,.03,.72,.76,.77],[-5.12,.04,.68,.72,.73],[-4.72,.03,.65,.69,.69],[-4.24,.03,.591,.61,.60],
	[-3.73,.025,.50,.53,.49],[-3.14,.02,.39,.37,.28],[-2.58,.05,.21,.23,.14],[-2.35,.09,.075,.085,.058]]
const FLOAT: Array = [[-4.18,.02,.035,.05,.07],[-4.03,.05,.13,.105,.13],[-3.77,.06,.23,.15,.23],[-3.40,.055,.31,.18,.30],
	[-2.98,.052,.32,.18,.33],[-2.51,.04,.31,.17,.35],[-2.19,.045,.285,.16,.29],[-2.08,.07,.25,.14,.21],
	[-1.63,.10,.19,.118,.16],[-1.19,.13,.105,.085,.102],[-.97,.15,.035,.036,.04]]

@export var display_gear_down: bool = false

func _ready() -> void:
	_set_paint(Color("476278"),Color("b2b6ac"))
	paint.glass.albedo_color = Color("587789")
	paint.rubber = GEO.material(Color("252d31"))
	var hull: Node3D = GEO.group(self,"SteppedAmphibianHull")
	var wing: Node3D = GEO.group(self,"HighParasolWing")
	var tail: Node3D = GEO.group(self,"Tail")
	var marks: Node3D = GEO.group(self,"USNMarkings")
	_boat_hull(hull)
	_canopy(GEO.group(hull,"FlightDeck"),DECK)
	_bow(hull)
	_fin(tail,"TallRudder",[[1.21,5.74,9.42,.24],[1.53,6.1,9.45,.24],[2.05,6.63,9.47,.23],
		[2.66,7.22,9.50,.20],[3.24,7.61,9.42,.164],[3.80,7.96,9.37,.125],[4.24,8.27,9.26,.095],
		[4.48,8.51,9.12,.056],[4.57,8.72,8.94,.026]])
	_body(hull,"BroadWingPylon",[[-5.37,1.94,.08,.10,.80],[-4.96,1.87,.48,1.16,.81],[-4.38,1.88,.63,1.17,.84],
		[-3.55,1.87,.66,1.15,.84],[-2.64,1.87,.57,1.15,.83],[-1.71,1.88,.40,1.11,.85],
		[-1.06,1.96,.17,.81,.90],[-.81,2.23,.03,.32,1.09]])
	for side: float in [-1.0,1.0]:
		_wing(wing,"Mainplane",WING,side)
		_wing(tail,"Stabilizer",TAIL,side)
		_nacelle(wing,side)
		_outrigger(wing,side)
		_blister(hull,side)
		_main_wheel(hull,side)
		GEO.rod(wing,"ForwardWingBrace",Vector3(side*.97,.06,-4.59),Vector3(side*5.18,2.91,-4.23),.122,paint.bottom,.104)
		GEO.rod(wing,"RearWingBrace",Vector3(side*1.03,.09,-3.18),Vector3(side*5.21,2.91,-2.28),.115,paint.bottom,.10)
		_star_bar(marks,"body",HULL,Vector2(5.45,.61),.44,side)
	_star_bar(marks,"wing",WING,Vector2(-11.86,-2.90),.77,1.0)
	_star_bar(marks,"wing",WING,Vector2(11.86,-2.73),.77,-1.0)
	if display_gear_down:
		GEO.rod(hull,"NoseLeg",Vector3(0,-.47,-7.25),Vector3(0,-1.66,-7.39),.092,paint.metal)
		_ellipsoid(hull,"NoseWheel",Vector3(.174,.37,.37),Vector3(0,-1.72,-7.39),paint.rubber)

func _boat_hull(host: Node3D) -> void:
	# Bow-to-stern closed loft with a harder visual chine and a distinct step.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i: int in range(HULL.size()-1):
		for j: int in 52:
			var a: float = TAU*j/52.0
			var b: float = TAU*(j+1)/52.0
			var n: Vector3 = Vector3(sin((a+b)*.5),cos((a+b)*.5),0)
			GEO.quad(st,_hull_point(HULL[i],a),_hull_point(HULL[i+1],a),_hull_point(HULL[i+1],b),_hull_point(HULL[i],b),n,paint.top.albedo_color if n.y > -.27 else paint.bottom.albedo_color)
	st.set_smooth_group(-1)
	for index: int in [0,HULL.size()-1]:
		var row: Array = HULL[index]
		for j: int in 52:
			GEO.triangle(st,Vector3(0,row[1],row[0]),_hull_point(row,TAU*j/52.0),_hull_point(row,TAU*(j+1)/52.0),Vector3.FORWARD if index==0 else Vector3.BACK,paint.top.albedo_color)
	GEO.part(host,"SteppedBoatSkin",GEO.finish(st),paint.skin)
	for side: float in [-1.0,1.0]:
		for i: int in range(2,16):
			GEO.rod(host,"ChineEdge",_hull_point(HULL[i],side*2.08),_hull_point(HULL[i+1],side*2.08),.023,paint.bottom)

func _hull_point(row: Array,angle: float) -> Vector3:
	var c: float = cos(angle)
	var x: float = row[2]*sin(angle)
	if c < 0.0: x *= 1.0+.23*sin(c*PI)
	return Vector3(x,row[1]+c*(row[3] if c>=0.0 else row[4]),row[0])

func _nacelle(host: Node3D,side: float) -> void:
	var engine: Node3D = GEO.group(host,"RadialNacelle",Vector3(side*3.72,2.99,0))
	_body(engine,"NacelleSkin",NACELLE)
	_ellipsoid(engine,"CowlRecess",Vector3(.615,.635,.043),Vector3(0,0,-6.67),paint.dark)
	for i: int in 14:
		var a: float = TAU*i/14.0
		var radial: Vector3 = Vector3(cos(a),sin(a),0)
		GEO.rod(engine,"DarkCowlBaffle",Vector3(0,0,-6.72)+radial*.20,Vector3(0,0,-6.704)+radial*.562,.038,paint.frame)
	GEO.arch(engine,"CowlingPanel",NACELLE,-5.71,.036,paint.frame)
	_prop(engine,Vector3(0,0,-6.83),1.71,Vector3(.15,.15,.22),.2+side*.35,1.0,paint.metal)

func _outrigger(host: Node3D,side: float) -> void:
	var x: float = side*14.87
	var float_assembly: Node3D = GEO.group(host,"DeployedWingtipFloat",Vector3(x,.45,0))
	_body(float_assembly,"FloatHull",FLOAT)
	GEO.rod(host,"FloatFrontStrut",Vector3(x-side*.22,2.96,-3.51),Vector3(x,.54,-3.28),.074,paint.bottom)
	GEO.rod(host,"FloatRearStrut",Vector3(x-side*.24,2.96,-1.49),Vector3(x,.56,-2.13),.071,paint.bottom)
	GEO.rod(host,"FloatDiagonalBrace",Vector3(x-side*1.32,2.93,-2.65),Vector3(x,.54,-2.83),.042,paint.bottom)

func _bow(host: Node3D) -> void:
	_ellipsoid(host,"LowBowGlazing",Vector3(.55,.31,.46),Vector3(0,.63,-8.92),paint.glass)
	for i: int in 2:
		var side: float = -1.0 if i==0 else 1.0
		GEO.rod(host,"BowGlazingFrame",Vector3(side*.32,.82,-9.192),Vector3(side*.29,.55,-9.323),.018,paint.frame)
	for side: float in [-1.0,1.0]:
		for pos: float in [-4.93,-3.78,-2.59,-1.38,4.44]:
			var row: Array = GEO.sample(HULL,pos)
			var p: Vector3 = Vector3(side*(float(row[2])-.045),.57,pos)
			_ellipsoid(host,"CabinPort",Vector3(.085,.095,.13),p,paint.glass)

func _blister(host: Node3D,side: float) -> void:
	var center: Vector3 = Vector3(side*.92,.49,2.80)
	_ellipsoid(host,"BlisterFairing",Vector3(.375,.59,1.035),center,paint.frame)
	_ellipsoid(host,"LargeObservationGlazing",Vector3(.465,.523,.958),center+Vector3(0,.022,.019),paint.glass)
	for i: int in 20:
		var a: float = PI*i/20.0
		var b: float = PI*(i+1)/20.0
		GEO.rod(host,"BlisterCenterBow",center+Vector3(side*.465*sin(a),.022+.521*cos(a),.018),
			center+Vector3(side*.465*sin(b),.022+.521*cos(b),.018),.026,paint.frame)

func _main_wheel(host: Node3D,side: float) -> void:
	var at: Vector3 = Vector3(side*1.02,-.62,-.54)
	var surround: Array[Vector2] = []
	for i: int in 25:
		var a: float = TAU*i/25.0
		surround.append(Vector2(at.z+.52*cos(a),at.y+.53*sin(a)))
	_decal(host,"AmphibianMainGearRecess","body",HULL,surround,side,.019,paint.frame)
	if not display_gear_down:
		_ellipsoid(host,"MainWheelInRecess",Vector3(.186,.372,.372),Vector3(side*.895,at.y,at.z),paint.rubber)
		return
	var hub: Vector3 = Vector3(side*1.81,-1.77,at.z+.17)
	GEO.rod(host,"MainLeg",at+Vector3(0,.49,.25),hub,.097,paint.metal)
	GEO.rod(host,"DragBrace",at+Vector3(0,-.11,-.75),hub,.064,paint.frame)
	_ellipsoid(host,"MainWheel",Vector3(.23,.49,.49),hub,paint.rubber)
	_ellipsoid(host,"MainWheelHub",Vector3(.032,.235,.235),hub+Vector3.RIGHT*side*.235,paint.metal)
