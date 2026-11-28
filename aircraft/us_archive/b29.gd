extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Representative standard 1945 B-29 exterior. Static art, not a simulation unit.
const LABEL: String = "B-29 Superfortress / Marianas, 1945"
const LENGTH_M: float = 30.1752
const SPAN_M: float = 43.053
const BODY: Array = [
	[-15.04,.13,.024,.035,.038],[-15.00,.13,.29,.29,.31],[-14.88,.13,.51,.54,.54],
	[-14.69,.12,.72,.73,.74],[-14.40,.11,.92,.92,.94],[-14.02,.09,1.10,1.09,1.12],
	[-13.55,.065,1.28,1.24,1.27],[-13.00,.043,1.42,1.38,1.41],[-12.40,.025,1.53,1.48,1.50],
	[-11.72,.014,1.61,1.57,1.57],[-10.94,.008,1.65,1.625,1.62],[-9.90,.003,1.669,1.65,1.657],
	[-9.15,0,1.675,1.66,1.66],
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
	[-2.54,0,.77,.77,.77],[-2.48,0,.867,.87,.88],[-2.36,0,.934,.94,.95],
	[-2.17,0,.968,.977,.985],[-1.85,0,.992,.991,1.006],[-1.28,0,1.004,.990,1.010],
	[-.76,.01,1.002,.978,1.013],[-.53,.018,.995,.967,1.011],[-.39,.028,.961,.931,.985],
	[.21,.054,.909,.881,.953],[.95,.09,.808,.765,.897],[1.78,.14,.709,.650,.813],
	[2.62,.197,.572,.526,.695],[3.43,.224,.428,.448,.534],[4.15,.251,.292,.367,.375],
	[4.75,.278,.173,.270,.225],[5.25,.30,.073,.159,.105],[5.52,.31,.022,.073,.049]]
const OUTBOARD: Array = [
	[-2.54,0,.75,.75,.75],[-2.48,0,.841,.843,.85],[-2.36,0,.909,.917,.914],
	[-2.17,0,.940,.951,.946],[-1.85,0,.960,.967,.959],[-1.28,.003,.966,.966,.962],
	[-.76,.015,.960,.951,.949],[-.53,.024,.950,.934,.935],[-.39,.037,.920,.902,.905],
	[.21,.061,.856,.829,.856],[.95,.10,.749,.725,.748],[1.75,.15,.637,.621,.629],
	[2.54,.196,.499,.502,.506],[3.25,.231,.362,.430,.361],[3.87,.259,.230,.338,.238],
	[4.40,.286,.118,.242,.134],[4.77,.30,.047,.134,.055],[4.91,.306,.016,.066,.019]]
const FIN: Array = [
	[.88,5.94,14.76,.25],[1.16,6.46,14.73,.275],[1.49,8.02,14.66,.27],
	[1.90,8.85,14.55,.25],[2.47,9.34,14.43,.23],[3.07,9.78,14.28,.20],
	[3.66,10.16,14.13,.172],[4.21,10.51,13.95,.147],[4.67,10.85,13.71,.117],
	[5.00,11.18,13.45,.089],[5.22,11.59,13.17,.059],[5.2886,12.02,12.76,.027]]
## This is a display pose only. No animation, collision, or controls.
@export var parked_gear: bool = false

func _ready() -> void:
	_set_batch_paint(Color("b6bbbe"),Color("a7adb0"))
	var fuselage: Node3D = GEO.group(self,"PressurizedFuselage")
	_blended_shell(fuselage,"AluminumShell",BODY)
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
		_radial(engines,side*5.39,.42,-4.74,.12,NACELLE)
		_radial(engines,side*10.15,.83,-3.45,.46,OUTBOARD)
		var tip: Vector3 = GEO.wing_point(WING,21.44,.36,true)
		tip.x *= side
		_ellipsoid(wing,"TipLight",Vector3(.085,.07,.19),tip,paint.red if side < 0 else paint.nav_green)
		_star_bar(decals,"body",BODY,Vector2(6.98,.16),.73,side)
	_star_bar(decals,"wing",WING,Vector2(-15.62,-.36),.92,1.)
	_star_bar(decals,"wing",WING,Vector2(15.62,-.36),.92,-1.)
	_fin(tail,"TallDorsalFin",FIN)
	for side: float in [-1.,1.]:
		for i: int in range(2,FIN.size()-1):
			var a: Vector3 = _fin_point(FIN[i],side*.82)
			var b: Vector3 = _fin_point(FIN[i+1],side*.82)
			GEO.rod(tail,"RudderJoint",a,b,.012,paint.seam)
	if parked_gear: _landing_display(GEO.group(self,"ParkedGearDisplay"))
	else: _retracted_door_seams(fuselage)

func _skin_tint(angle: float) -> Color:
	return paint.bottom.albedo_color.lerp(paint.top.albedo_color,smoothstep(-.86,.54,cos(angle)))

func _blended_shell(host: Node3D,key: String,profile: Array) -> void:
	# Keep the same archive finish. Soften the old false hard band at the belly.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	const SEG: int = 96
	for k: int in profile.size()-1:
		var z0: float = profile[k][0]
		var z1: float = profile[k+1][0]
		for i: int in SEG:
			var a: float = TAU*i/SEG
			var b: float = TAU*(i+1)/SEG
			var normal := Vector3(sin((a+b)*.5),cos((a+b)*.5),0.)
			GEO.quad(st,GEO.shell_point(profile,z0,a),GEO.shell_point(profile,z1,a),GEO.shell_point(profile,z1,b),
				GEO.shell_point(profile,z0,b),normal,_skin_tint((a+b)*.5))
	st.set_smooth_group(-1)
	for row: Array in [profile[0],profile[-1]]:
		for i: int in SEG:
			var a: float = TAU*i/SEG
			var b: float = TAU*(i+1)/SEG
			GEO.triangle(st,Vector3(0.,row[1],row[0]),GEO.shell_point(profile,row[0],a),
				GEO.shell_point(profile,row[0],b),Vector3.FORWARD if row==profile[0] else Vector3.BACK,_skin_tint((a+b)*.5))
	GEO.part(host,key,GEO.finish(st),paint.skin)

func _pane(host: Node3D,z0: float,z1: float,a0: float,a1: float,key: String = "NosePane",
		lift: float = .016,splay: Vector2 = Vector2.ZERO) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var stations: Array[float] = [z0,z1]
	for row: Array in BODY:
		if row[0]>z0 and row[0]<z1: stations.append(row[0])
	stations.sort()
	for iz: int in stations.size()-1:
		var p: float = stations[iz]
		var q: float = stations[iz+1]
		var tp: float = (p-z0)/(z1-z0)
		var tq: float = (q-z0)/(z1-z0)
		for ia: int in 9:
			var a: float = lerpf(a0,a1,ia/9.0)
			var b: float = lerpf(a0,a1,(ia+1)/9.0)
			var da: float = lerpf(splay.x,splay.y,ia/9.)
			var db: float = lerpf(splay.x,splay.y,(ia+1)/9.)
			var mid: float = (a+b+(da+db)*(tp+tq)*.5)*.5
			var outward := Vector3(sin(mid),cos(mid),-.68 if p < -14.4 else -.15)
			GEO.quad(st,_raised(p,a+da*tp,lift),_raised(q,a+da*tq,lift),
				_raised(q,b+db*tq,lift),_raised(p,b+db*tp,lift),outward)
	GEO.part(host,key,GEO.finish(st),paint.glass)

func _raised(z: float,angle: float,lift: float) -> Vector3:
	return GEO.shell_point(BODY,z,angle) + Vector3(sin(angle),cos(angle),-.60*(1.-smoothstep(-15.02,-12.,z)))*lift

func _nose_windows(host: Node3D) -> void:
	var glazing: Node3D = GEO.group(host,"SteplessNoseGlazing")
	# The leading observer cap wraps to the lower nose. The crew glazing is
	# staggered across the crown and shoulders, not a rectangular grid.
	_ellipsoid(glazing,"ObserverGlazedTip",Vector3(.135,.138,.025),Vector3(0,.13,-15.015),paint.glass)
	for lane: int in 12:
		var a: float = TAU*lane/12.
		var b: float = TAU*(lane+1)/12.
		_pane(glazing,-15.018,-14.72,a+.052,b-.052,"ObserverFrontPane")
		if cos((a+b)*.5) > -.72:
			_pane(glazing,-14.676,-14.245,a+.029,b-.029,"ObserverWrapPane")
	for lane: int in range(-2,2):
		_pane(glazing,-14.20,-13.52,lane*.50+.024,(lane+1)*.50-.024,"PilotWindshield",.016,
			Vector2(lane*.075,(lane+1)*.075))
		_pane(glazing,-13.465,-12.64,lane*.575+.024,(lane+1)*.575-.024,"PilotRoofPane",.016,
			Vector2(lane*.055,(lane+1)*.055))
	for side: float in [-1.,1.]:
		_pane(glazing,-14.39,-13.48,side*1.13,side*1.41,"ObserverSidePane",.017,Vector2(.07,.03)*side)
		_pane(glazing,-13.43,-12.72,side*1.18,side*1.59,"PilotCornerPane",.017,Vector2(.12,.05)*side)
		_pane(glazing,-12.67,-11.72,side*1.29,side*1.58,"PilotSidePane",.017,Vector2(.03,-.06)*side)
		_pane(glazing,-12.59,-11.83,side*.77,side*1.18,"PilotShoulderPane",.016,Vector2(.09,.07)*side)
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

func _radial(host: Node3D,x: float,y: float,z: float,phase: float,profile: Array) -> void:
	var nacelle: Node3D = GEO.group(host,"RadialNacelle",Vector3(x,y,z))
	_blended_shell(nacelle,"StreamlinedCowling",profile)
	var mouth: float=profile[0][2]
	_ellipsoid(nacelle,"CowlOpening",Vector3(mouth*.93,mouth*.93,.036),Vector3(0,0,-2.536),paint.dark)
	GEO.arch(nacelle,"RolledCowlLip",profile,-2.48,.051,paint.metal)
	GEO.arch(nacelle,"CowlingRingJoin",profile,-1.88,.019,paint.panel)
	GEO.arch(nacelle,"RearCowlJoin",profile,-.46,.026,paint.seam)
	for side: float in [-1.,1.]:
		_ellipsoid(nacelle,"ExhaustShadow",Vector3(.035,.104,.20),Vector3(side*profile[9][2]*.99,-.32,.23),paint.dark)
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
