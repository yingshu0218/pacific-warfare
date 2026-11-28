extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Representative standard 1945 B-29 exterior. Static art, not a simulation unit.
const LABEL: String = "B-29 Superfortress / Marianas, 1945"
const LENGTH_M: float = 30.1752
const SPAN_M: float = 43.053
const BODY: Array = [
	[-15.04,.11,.036,.040,.043],[-14.91,.12,.31,.30,.31],[-14.65,.15,.62,.59,.65],
	[-14.19,.15,.91,.89,.95],[-13.55,.13,1.16,1.11,1.18],[-12.76,.09,1.40,1.34,1.40],
	[-11.88,.04,1.58,1.49,1.56],[-10.65,.018,1.656,1.63,1.63],[-9.15,0,1.675,1.66,1.66],
	[-6.17,0,1.68,1.67,1.67],[-1.60,0,1.68,1.67,1.67],[2.50,0,1.68,1.67,1.67],
	[5.20,.01,1.65,1.65,1.64],[7.50,.06,1.52,1.54,1.52],[9.10,.10,1.37,1.36,1.35],
	[10.50,.15,1.15,1.16,1.05],[11.75,.21,.92,.90,.81],[12.78,.29,.72,.68,.62],
	[13.75,.38,.55,.52,.46],[14.49,.43,.40,.39,.34],[14.90,.48,.29,.26,.26],
	[15.095,.49,.18,.18,.19],[15.1352,.49,.04,.05,.05]]
const WING: Array = [
	[0.,-6.4,8.12,.17,.152],[1.12,-6.2,7.88,.17,.149],[2.36,-5.84,7.50,.29,.146],
	[4.20,-5.28,6.83,.43,.144],[6.33,-4.72,6.08,.59,.138],[8.69,-4.09,5.27,.84,.130],
	[10.87,-3.58,4.64,1.03,.124],[13.29,-2.97,3.94,1.25,.116],[15.74,-2.34,3.22,1.47,.104],
	[18.48,-1.65,2.44,1.72,.095],[19.86,-1.29,1.94,1.85,.081],[20.77,-.93,1.42,1.94,.069],
	[21.25,-.63,.97,1.98,.059],[21.5265,-.31,.43,1.99,.055]]
const TAIL: Array = [
	[0.,9.18,4.90,1.12,.122],[1.12,9.35,4.60,1.14,.119],[2.45,9.76,3.73,1.22,.110],
	[3.89,10.31,2.73,1.36,.098],[5.19,10.89,1.86,1.44,.087],[6.12,11.36,1.21,1.48,.075],
	[6.53,11.69,.81,1.51,.050],[6.78,11.96,.42,1.52,.043]]
const NACELLE: Array = [
	[-2.52,0,.77,.77,.79],[-2.38,0,.89,.91,.92],[-2.02,0,.97,.98,.99],
	[-1.48,0,.98,.99,1.05],[-.83,.02,.97,.95,1.06],[-.15,.03,.91,.89,1.02],
	[.65,.07,.83,.81,.99],[1.61,.11,.73,.70,.90],[2.49,.16,.61,.57,.75],
	[3.27,.20,.48,.47,.58],[4.04,.24,.35,.36,.41],[4.79,.29,.22,.27,.25],
	[5.38,.31,.11,.18,.13],[5.70,.32,.035,.067,.062]]
## This is a display pose only. No animation, collision, or controls.
@export var parked_gear: bool = false

func _ready() -> void:
	_set_batch_paint(Color("afbac0"),Color("929fa7"))
	var fuselage: Node3D = GEO.group(self,"PressurizedFuselage")
	_body(fuselage,"AluminumShell",BODY)
	_nose_windows(fuselage)
	_detail_fuselage(fuselage)
	var wing: Node3D = GEO.group(self,"HighAspectMainplane")
	var tail: Node3D = GEO.group(self,"TailAssembly")
	var engines: Node3D = GEO.group(self,"FourNacelles")
	var decals: Node3D = GEO.group(self,"ArchiveMarkings")
	for side: float in [-1.,1.]:
		_wing(wing,"Mainplane",WING,side)
		_wing(tail,"HorizontalTail",TAIL,side)
		_control_line(wing,WING,side,3.34,19.82,.72)
		_control_line(tail,TAIL,side,.68,6.30,.71)
		_radial(engines,side*5.39,.47,-4.74,.12)
		_radial(engines,side*10.15,.90,-3.45,.46)
		var tip: Vector3 = GEO.wing_point(WING,21.44,.36,true)
		tip.x *= side
		_ellipsoid(wing,"TipLight",Vector3(.085,.07,.19),tip,paint.red if side < 0 else paint.nav_green)
		_star_bar(decals,"body",BODY,Vector2(6.98,.16),.73,side)
	_star_bar(decals,"wing",WING,Vector2(-15.62,-.36),.92,1.)
	_star_bar(decals,"wing",WING,Vector2(15.62,-.36),.92,-1.)
	_fin(tail,"TallDorsalFin",[
		[0.8800,5.94,14.66,.22],[1.1863,6.62,14.71,.258],[1.4927,7.96,14.66,.27],
		[1.9056,8.81,14.55,.25],[2.4650,9.37,14.47,.23],[3.0643,9.84,14.31,.20],
		[3.6504,10.33,14.09,.171],[4.1698,10.76,13.91,.145],[4.6559,11.13,13.62,.111],
		[5.0089,11.57,13.27,.081],[5.2353,11.98,12.86,.053],[5.2886,12.23,12.62,.025]])
	for side: float in [-1.,1.]:
		GEO.rod(tail,"RudderJoint",Vector3(side*.19,1.84,13.24),Vector3(side*.059,5.05,12.72),.016,paint.seam)
	if parked_gear: _landing_display(GEO.group(self,"ParkedGearDisplay"))
	else: _retracted_door_seams(fuselage)

func _pane(host: Node3D,z0: float,z1: float,a0: float,a1: float,key: String = "NosePane",lift: float = .033) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for iz: int in 5:
		for ia: int in 5:
			var p: float = lerpf(z0,z1,iz/5.0)
			var q: float = lerpf(z0,z1,(iz+1)/5.0)
			var a: float = lerpf(a0,a1,ia/5.0)
			var b: float = lerpf(a0,a1,(ia+1)/5.0)
			GEO.quad(st,_raised(p,a,lift),_raised(q,a,lift),_raised(q,b,lift),_raised(p,b,lift),Vector3(sin((a+b)*.5),cos((a+b)*.5),-.2))
	GEO.part(host,key,GEO.finish(st),paint.glass)

func _raised(z: float,angle: float,lift: float) -> Vector3:
	return GEO.shell_point(BODY,z,angle) + Vector3(sin(angle),cos(angle),-.31 if z < -12.6 else 0.)*lift

func _nose_windows(host: Node3D) -> void:
	var glazing: Node3D = GEO.group(host,"SteplessNoseGlazing")
	# Separate gently curved glazing panels leave real aluminum mullions visible.
	for pair: Array in [[-14.943,-14.55],[-14.5,-13.97],[-13.91,-13.24],[-13.17,-12.42]]:
		for lane: int in range(-3,3):
			if float(pair[0]) > -14.2 and lane in [-3,2]: continue
			_pane(glazing,pair[0],pair[1],lane*.49+.028,(lane+1)*.49-.027)
	for side: float in [-1.,1.]:
		for lo: float in [-1.09,-.70]:
			var a: float = lo if side < 0 else -(lo+.35)
			_pane(glazing,-12.35,-11.25,a,a+.35,"PilotSidePane")
		for z: float in [-9.56,-8.73,3.13,3.78]:
			var a: float = -1.68 if side < 0 else 1.43
			_pane(host,z,z+.31,a,a+.23,"CabinPort")
	_pane(host,14.42,14.82,-.53,.53,"TailObserverPane")

func _detail_fuselage(host: Node3D) -> void:
	for z: float in [-10.40,-6.55,-2.76,2.16,6.45,9.69,12.20]:
		GEO.arch(host,"SkinJoin",BODY,z,.019,paint.panel)
	# Neutral low fairing forms identify the standard exterior in profile.
	for z: float in [-8.15,4.73]:
		var row: Array = GEO.sample(BODY,z)
		_ellipsoid(host,"UpperExteriorFairing",Vector3(.67,.31,.79),Vector3(0,row[1]+row[3]-.08,z),paint.metal)
	for z: float in [-7.78,4.36]:
		var row: Array = GEO.sample(BODY,z)
		_ellipsoid(host,"LowerExteriorFairing",Vector3(.60,.28,.65),Vector3(0,row[1]-row[4]+.12,z),paint.metal)
	for side: float in [-1.,1.]:
		_ellipsoid(host,"ObservationBlister",Vector3(.18,.29,.33),Vector3(side*1.64,.07,4.54),paint.glass)
		GEO.rod(host,"BellyClosureLine",Vector3(side*.55,-1.58,-5.40),Vector3(side*.55,-1.58,2.26),.016,paint.seam)
	GEO.rod(host,"AerialMast",Vector3(0,1.62,-8.91),Vector3(0,2.01,-8.68),.041,paint.metal)
	GEO.rod(host,"TailLight",Vector3(0,.49,15.00),Vector3(0,.49,15.132),.055,paint.white)

func _control_line(host: Node3D,profile: Array,side: float,x0: float,x1: float,frac: float) -> void:
	for i: int in 20:
		var a: Vector3 = GEO.wing_point(profile,lerpf(x0,x1,i/20.),frac,true)
		var b: Vector3 = GEO.wing_point(profile,lerpf(x0,x1,(i+1)/20.),frac,true)
		a.x *= side; b.x *= side
		GEO.rod(host,"ControlSurfaceJoint",a+Vector3.UP*.009,b+Vector3.UP*.009,.019,paint.seam)

func _radial(host: Node3D,x: float,y: float,z: float,phase: float) -> void:
	var nacelle: Node3D = GEO.group(host,"RadialNacelle",Vector3(x,y,z))
	_body(nacelle,"StreamlinedCowling",NACELLE)
	_ellipsoid(nacelle,"DarkCowlOpening",Vector3(.73,.73,.055),Vector3(0,0,-2.528),paint.dark)
	var cowl_joint: StandardMaterial3D = GEO.material(Color("858d8b"),.28)
	GEO.arch(nacelle,"CowlingRingJoin",NACELLE,-1.88,.048,cowl_joint)
	GEO.arch(nacelle,"RearCowlJoin",NACELLE,-.58,.041,cowl_joint)
	for side: float in [-1.,1.]:
		_ellipsoid(nacelle,"ExhaustShadow",Vector3(.034,.123,.27),Vector3(side*.895,-.33,-.12),paint.dark)
	var prop: Node3D = GEO.group(nacelle,"FourBladePropeller",Vector3(0,0,-2.70))
	_ellipsoid(prop,"CentralPropHub",Vector3(.22,.22,.28),Vector3(0.,0.,-.12),paint.metal)
	for i: int in 4:
		var blade: Node3D = GEO.group(prop,"Blade_%d"%i)
		blade.rotation.z = phase + TAU*i/4.0
		var flat: Node3D = GEO.group(blade,"BladePlane")
		flat.rotation.y = PI*.5
		_plate(flat,"BladeSkin",[[.12,-.07],[.64,-.22],[1.36,-.30],[2.22,-.27],[2.48,-.12],[2.56,.025],[2.53,.14],[2.24,.22],[1.25,.26],[.52,.16],[.12,.062]],.053,paint.dark)
		_plate(flat,"PaintedTip",[[2.35,-.195],[2.48,-.12],[2.56,.025],[2.53,.14],[2.35,.192]],.057,paint.yellow)

func _retracted_door_seams(host: Node3D) -> void:
	for side: float in [-1.,1.]:
		GEO.rod(host,"NoseWheelDoor",Vector3(side*.28,-1.44,-10.76),Vector3(side*.28,-1.63,-8.42),.019,paint.seam)

func _landing_display(host: Node3D) -> void:
	_wheel_pair(host,"TwinNoseWheels",Vector3(0,-2.73,-9.01),.43,.256,-1.41)
	for side: float in [-1.,1.]:
		_wheel_pair(host,"TwinMainWheels",Vector3(side*5.39,-2.60,-3.67),.57,.405,-.40)

func _wheel_pair(host: Node3D,key: String,axle: Vector3,radius: float,offset: float,anchor: float) -> void:
	var leg: Node3D = GEO.group(host,key,axle)
	GEO.rod(leg,"PatchedStrutExterior",Vector3.ZERO,Vector3(0,anchor-axle.y,-.25),.11,paint.metal)
	GEO.rod(leg,"AxleExterior",Vector3(-offset,0,0),Vector3(offset,0,0),.10,paint.frame)
	for side: float in [-1.,1.]:
		_ellipsoid(leg,"Tyre",Vector3(radius*.44,radius,radius),Vector3(side*offset,0,0),paint.dark)
		_ellipsoid(leg,"WheelHub",Vector3(radius*.12,radius*.57,radius*.57),Vector3(side*(offset+radius*.39),0,0),paint.metal)
