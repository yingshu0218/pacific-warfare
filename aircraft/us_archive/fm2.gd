extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Late-war FM-2 visual study. The wings are spread; no runtime aircraft or weapons.
const LABEL: String = "FM-2 Wildcat / Pacific, 1944"
const SPAN_M: float = 11.58
const LENGTH_M: float = 8.81
const BODY: Array = [
	[-4.15,.06,.54,.56,.54],[-4.09,.06,.63,.64,.61],[-3.94,.06,.68,.69,.65],[-3.68,.06,.69,.71,.66],
	[-3.30,.06,.69,.72,.68],[-3.09,.07,.685,.74,.71],[-2.73,.08,.70,.78,.79],[-2.31,.11,.706,.80,.85],
	[-1.91,.13,.699,.83,.87],[-1.52,.14,.67,.84,.87],[-1.12,.14,.61,.83,.84],[-.57,.15,.586,.81,.81],
	[0,.16,.54,.76,.77],[.54,.185,.48,.68,.69],[1.13,.22,.41,.58,.60],[1.73,.25,.333,.48,.51],
	[2.35,.29,.26,.38,.43],[2.92,.30,.20,.30,.33],[3.41,.32,.135,.22,.22],[3.83,.33,.088,.158,.144],
	[4.14,.34,.054,.103,.091],[4.32,.35,.025,.052,.044]]
const WING: Array = [
	[.38,-1.70,2.78,.012,.155],[.67,-1.70,2.77,.026,.15],[1.20,-1.68,2.71,.073,.147],
	[2.10,-1.62,2.57,.13,.138],[3.02,-1.53,2.35,.21,.125],[4.05,-1.44,2.12,.30,.112],
	[4.92,-1.36,1.93,.38,.101],[5.38,-1.31,1.79,.42,.085],[5.61,-1.23,1.58,.448,.069],
	[5.73,-1.13,1.24,.46,.052],[5.78,-.98,.91,.465,.036],[5.79,-.83,.54,.467,.024]]
const TAIL: Array = [[.05,2.86,1.32,.47,.089],[.40,2.90,1.30,.48,.086],[.84,3.00,1.18,.51,.077],
	[1.46,3.20,.99,.55,.068],[1.87,3.42,.72,.576,.056],[2.02,3.58,.45,.584,.036],[2.08,3.74,.18,.586,.021]]
const CANOPY: Array = [
	[-2.24,.91,.22,.045,.021],[-2.13,.92,.34,.12,.037],[-1.93,.925,.405,.34,.062],[-1.79,.94,.424,.438,.055],
	[-1.57,.95,.429,.46,.057],[-1.30,.952,.421,.432,.061],[-.99,.94,.398,.37,.053],
	[-.74,.905,.367,.285,.04],[-.54,.88,.33,.194,.04],[-.29,.845,.29,.115,.03],[-.10,.835,.25,.055,.03]]

@export var display_gear_down: bool = false

func _ready() -> void:
	_set_batch_paint(Color("496276"),Color("8395a0"))
	paint.rubber = GEO.material(Color("232a2b"))
	var body: Node3D = GEO.group(self,"Fuselage")
	var tail: Node3D = GEO.group(self,"TallEmpennage")
	var wings: Node3D = GEO.group(self,"SpreadWing")
	var cowl: Node3D = GEO.group(self,"ShortRadialCowling")
	var marks: Node3D = GEO.group(self,"USNMarkings")
	_body(body,"FuselageSkin",BODY)
	_canopy(GEO.group(self,"Cockpit"),CANOPY)
	_fin(tail,"TallFM2Fin",[[.40,2.46,4.30,.12],[.57,2.84,4.33,.128],[.95,3.13,4.37,.12],
		[1.35,3.37,4.39,.105],[1.74,3.53,4.38,.087],[2.10,3.64,4.34,.059],
		[2.38,3.76,4.24,.042],[2.49,3.89,4.12,.029],[2.51,3.99,4.045,.016]])
	for side: float in [-1.0,1.0]:
		_wing(wings,"RoundedMainplane",WING,side)
		_wing(tail,"Tailplane",TAIL,side)
		_wing_seam(wings,WING,side,2.82)
		_wing_hinge_line(wings,WING,side,2.88,5.37,.75,.011)
		_wing_hinge_line(tail,TAIL,side,.49,1.86,.73,.009)
		_star_bar(marks,"body",BODY,Vector2(.75,.29),.30,side)
		var tip: Vector3 = GEO.wing_point(WING,5.71,.43,true)
		tip.x *= side
		_ellipsoid(wings,"NavigationLens",Vector3(.046,.025,.071),tip,paint.red if side < 0.0 else paint.nav_green)
		_well(body,side)
	_star_bar(marks,"wing",WING,Vector2(-4.55,-.36),.395,1.0)
	_star_bar(marks,"wing",WING,Vector2(4.55,-.36),.395,-1.0)
	GEO.arch(cowl,"CowlBreak",BODY,-3.11,.026,paint.frame)
	for i: int in 9:
		var angle: float = TAU*i/9.0
		var radial: Vector3 = Vector3(sin(angle),cos(angle),0)
		GEO.rod(cowl,"RadialBaffle",Vector3(0,.06,-4.194)+radial*.15,Vector3(0,.06,-4.185)+radial*.515,.031,paint.frame)
	_ellipsoid(cowl,"ShadowedNoseFace",Vector3(.50,.514,.027),Vector3(0,.06,-4.157),paint.dark)
	_prop(cowl,Vector3(0,.06,-4.32),1.51,Vector3(.13,.13,.19),.31,1.0,paint.metal)
	GEO.rod(tail,"TailwheelFork",Vector3(0,.17,3.52),Vector3(0,-.08,3.77),.04,paint.metal)
	_ellipsoid(tail,"Tailwheel",Vector3(.067,.13,.13),Vector3(0,-.12,3.80),paint.rubber)
	for side: float in [-1.0,1.0]:
		GEO.rod(tail,"RudderSkinJoin",Vector3(side*.042,.61,4.08),Vector3(side*.024,2.39,4.075),.010,paint.seam)

func _well(host: Node3D, side: float) -> void:
	# Flush exterior well outlines distinguish the fuselage-mounted gear.
	var outline: Array[Vector2] = []
	for i: int in 22:
		var a: float = TAU*i/22.0
		outline.append(Vector2(-2.24+.342*cos(a),-.45+.335*sin(a)))
	_decal(host,"WheelWell", "body", BODY,outline,side,.014,paint.frame)
	if not display_gear_down:
		_ellipsoid(host,"RetractedWheel",Vector3(.13,.245,.245),Vector3(side*.455,-.435,-2.24),paint.rubber)
		return
	var hub: Vector3 = Vector3(side*.94,-1.57,-2.03)
	GEO.rod(host,"MainGearLeg",Vector3(side*.23,-.39,-2.62),hub,.08,paint.metal)
	GEO.rod(host,"MainGearBrace",Vector3(side*.43,-.49,-1.83),hub+Vector3.UP*.12,.033,paint.frame)
	_ellipsoid(host,"MainWheel",Vector3(.139,.348,.348),hub,paint.rubber)
	_ellipsoid(host,"MainWheelHub",Vector3(.032,.147,.147),hub+Vector3.RIGHT*side*.141,paint.metal)
