extends "res://aircraft/us_archive/visual_parts.gd"
## VF-17 F4U-1A raised-canopy exterior, BuNo 55995. Visual only.
const LABEL: String="F4U-1A Corsair / VF-17 / February 1944"
const LENGTH_M: float=10.225
const SPAN_M: float=12.497
const BODY: Array=[
	[-4.95,.07,.63,.65,.61],[-4.87,.07,.72,.74,.70],[-4.63,.07,.75,.77,.74],[-4.22,.07,.76,.78,.75],
	[-3.78,.08,.76,.79,.74],[-3.17,.10,.75,.83,.72],[-2.60,.10,.74,.87,.73],[-1.94,.11,.73,.90,.76],
	[-1.30,.11,.72,.92,.76],[-.72,.12,.72,.88,.72],[0.,.12,.70,.77,.65],[.74,.13,.62,.68,.59],
	[1.60,.17,.51,.56,.47],[2.45,.23,.40,.43,.35],[3.16,.27,.30,.33,.24],[3.78,.31,.22,.25,.17],
	[4.28,.39,.15,.18,.13],[4.67,.42,.075,.116,.077],[4.88,.43,.032,.063,.04]]
const WING: Array=[
	[.35,-2.36,3.06,-.25,.18],[.76,-2.29,3.06,-.32,.177],[1.03,-2.15,3.01,-.49,.16],
	[1.42,-1.99,2.96,-.68,.145],[1.73,-1.88,2.91,-.78,.137],[2.02,-1.79,2.83,-.76,.131],
	[2.24,-1.74,2.7,-.70,.128],[2.65,-1.65,2.62,-.62,.125],[3.55,-1.50,2.33,-.46,.116],
	[4.63,-1.29,2.03,-.27,.103],[5.41,-1.10,1.79,-.12,.096],[5.82,-.96,1.53,-.043,.083],
	[6.02,-.81,1.29,.0,.073],[6.17,-.63,0.99,.02,.059],[6.228,-.47,0.68,.03,.048],[6.2485,-.36,0.44,.03,.039]]
const TAIL: Array=[[0.,3.17,1.55,.60,.095],[.43,3.18,1.52,.61,.088],[1.09,3.34,1.31,.66,.073],
	[1.79,3.61,.98,.70,.061],[2.20,3.81,.70,.73,.051],[2.36,3.94,.42,.74,.039],[2.41,4.08,.17,.745,.019]]
const CANOPY: Array=[[-1.67,1.015,.35,.06,.03],[-1.49,1.02,.43,.27,.061],[-1.24,1.03,.46,.49,.073],
	[-.94,1.02,.48,.53,.10],[-.62,.99,.475,.50,.08],[-.27,.93,.44,.37,.07],[.10,.86,.37,.20,.05],[.33,.785,.27,.07,.03]]

func _ready() -> void:
	_set_paint(Color("365469"),Color("acb5aa"))
	_body(GEO.group(self,"Fuselage"),"MetalSkin",BODY,Vector3.ZERO,false)
	var wing: Node3D=GEO.group(self,"InvertedGullWing")
	var tail: Node3D=GEO.group(self,"Empennage")
	var engine: Node3D=GEO.group(self,"Cowling")
	var markings: Node3D=GEO.group(self,"Markings")
	_radial_cowl(engine)
	for side: float in [-1.0,1.0]:
		_wing(wing,"Wing",WING,side)
		_wing(tail,"Stabilizer",TAIL,side)
		for span: float in [2.25,4.58]:
			_wing_seam(wing,WING,side,span)
		var tip: Vector3=GEO.wing_point(WING,6.19,.44,true)
		tip.x*=side
		_ellipsoid(wing,"TipLight",Vector3(.047,.029,.073),tip,paint.red if side<0 else paint.nav_green)
		_encode_number(markings,BODY,Vector2(.04,.13),.251,side,"29")
		_star_bar(markings,"body",BODY,Vector2(1.86,.19),.335,side)
		_tank_tape(markings,side)
	_star_bar(markings,"wing",WING,Vector2(-4.66,-.30),.43,1.)
	_star_bar(markings,"wing",WING,Vector2(4.66,-.30),.43,-1.)
	_canopy(GEO.group(self,"RaisedCockpit"),CANOPY)
	_fin(tail,"Fin",[[.53,2.74,4.86,.14],[.81,3.18,4.91,.14],[1.16,3.52,4.87,.13],[1.59,3.74,4.84,.11],
		[1.87,3.89,4.82,.09],[2.12,4.05,4.74,.064],[2.30,4.19,4.64,.047],[2.39,4.31,4.55,.028],[2.44,4.40,4.48,.014]])
	GEO.rod(tail,"RudderJoin",Vector3(0,1.04,4.46),Vector3(0,2.39,4.48),.013,paint.seam)

func _radial_cowl(host: Node3D) -> void:
	var ring_front: Array=[[-4.966,.07,.585,.60,.57],[-4.955,.07,.619,.646,.608],[-4.92,.07,.650,.682,.637],[-4.84,.07,.683,.708,.672]]
	GEO.part(host,"RoundedCowlingLip",GEO.loft(ring_front,-4.966,-4.84,Color.WHITE,Color.WHITE,Vector4.ZERO,false),paint.top)
	_ellipsoid(host,"DeepCowlFace",Vector3(.617,.629,.058),Vector3(0,.07,-4.802),paint.dark)
	for i: int in 14:
		var a: float=TAU*i/14.
		var dir:=Vector3(cos(a),sin(a),0.)
		GEO.rod(host,"RadialFaceDetail",Vector3(0,.07,-4.875)+dir*.26,Vector3(0,.07,-4.871)+dir*.58,.039,paint.frame)
	for i: int in 13:
		var a: float=(TAU*i/13.)-.08
		GEO.rod(host,"CowlPetalLine",GEO.shell_point(BODY,-3.87,a),GEO.shell_point(BODY,-3.76,a),.008,paint.seam)
	_prop(host,Vector3(0,.07,-5.04),2.03,Vector3(.165,.165,.21),.23,1.,paint.metal)

func _tank_tape(host: Node3D,side: float) -> void:
	for a: float in [.43,.66]:
		GEO.arch(host,"TankTape",BODY,-2.40,.036,paint.white,side*(a-.23),side*(a+.09))
	var z: float=-2.40
	for i: int in 8:
		var t0: float=lerpf(.57,1.33,i/8.)
		var t1: float=lerpf(.57,1.33,(i+1)/8.)
		var a: Vector3=GEO.shell_point(BODY,z,side*t0)
		var b: Vector3=GEO.shell_point(BODY,z,side*t1)
		GEO.rod(host,"TankTapeSeam",a,b,.012,paint.white)
	for j: int in 7:
		var a: Vector3=GEO.shell_point(BODY,lerpf(-2.4,-1.45,j/7.),side*1.33)
		var b: Vector3=GEO.shell_point(BODY,lerpf(-2.4,-1.45,(j+1)/7.),side*1.33)
		GEO.rod(host,"TankTapeSide",a,b,.012,paint.white)
