extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Representative 1945 Pacific P-51D, static, clean airborne pose.
## Cosmetic geometry only. Source descriptions are in p51d.md.
const LABEL: String = "P-51D Mustang / Pacific 1945"
const LENGTH_M: float = 9.83
const SPAN_M: float = 11.28
# z, datum y, half breadth, crown height, lower depth.
const BODY: Array = [
	[-4.56,-.005,.358,.32,.33],[-4.47,.012,.401,.390,.355],[-4.21,.047,.470,.482,.386],
	[-3.88,.067,.524,.548,.406],[-3.50,.074,.546,.589,.422],[-3.08,.076,.554,.627,.448],
	[-2.64,.078,.562,.661,.48],[-2.19,.079,.574,.691,.53],[-1.74,.08,.583,.674,.57],
	[-1.30,.075,.577,.636,.598],[-.83,.062,.557,.595,.609],[-.32,.055,.525,.554,.608],
	[.23,.061,.474,.505,.582],[.81,.078,.424,.451,.514],[1.39,.102,.364,.384,.444],
	[1.98,.152,.312,.323,.366],[2.56,.198,.260,.263,.294],[3.13,.246,.213,.218,.23],
	[3.68,.284,.168,.174,.169],[4.13,.306,.123,.137,.119],[4.49,.32,.080,.105,.079],
	[4.76,.33,.046,.075,.052],[4.92,.33,.025,.043,.025]]
const WING: Array = [
	[.27,-1.88,2.87,-.28,.152],[.56,-1.76,2.82,-.34,.146],[.90,-1.60,2.66,-.396,.142],
	[1.35,-1.46,2.53,-.36,.134],[2.50,-1.29,2.23,-.26,.12],[3.65,-1.12,1.95,-.16,.11],
	[4.64,-.976,1.69,-.075,.099],[5.19,-.864,1.48,-.025,.087],[5.42,-.75,1.22,-.008,.075],
	[5.56,-.56,.89,.0,.065],[5.64,-.32,.48,.009,.046]]
const TAIL: Array = [
	[.0,3.15,1.29,.372,.116],[.44,3.23,1.24,.389,.105],[1.06,3.41,.99,.427,.091],
	[1.55,3.64,.75,.451,.076],[1.88,3.80,.55,.471,.065],[2.00,3.94,.34,.476,.043],
	[2.045,4.04,.17,.48,.032]]
const SCREEN: Array = [
	[-2.22,.749,.246,.037,.036],[-2.10,.741,.290,.148,.038],[-1.98,.724,.328,.265,.047],
	[-1.85,.710,.359,.390,.048],[-1.725,.704,.378,.501,.057]]
const BUBBLE: Array = [
	[-1.731,.704,.378,.501,.057],[-1.614,.693,.402,.565,.050],
	[-1.45,.678,.426,.605,.051],[-1.23,.655,.430,.635,.046],
	[-1.01,.636,.422,.634,.042],[-.80,.617,.397,.609,.040],
	[-.59,.596,.365,.550,.040],[-.39,.579,.330,.457,.036],
	[-.20,.567,.286,.334,.035],[-.032,.556,.231,.200,.031],
	[.104,.548,.165,.092,.029],[.248,.532,.079,.023,.020]]
const SCOOP: Array = [
	[-.704,-.650,.319,.182,.171],[-.622,-.652,.398,.245,.244],
	[-.430,-.642,.451,.331,.333],[-.151,-.631,.467,.363,.380],
	[.160,-.610,.456,.350,.399],[.48,-.579,.427,.323,.389],
	[.80,-.551,.385,.298,.351],[1.11,-.513,.337,.272,.313],
	[1.41,-.455,.279,.247,.275],[1.675,-.385,.208,.220,.228],
	[1.90,-.315,.142,.180,.175],[2.08,-.267,.082,.142,.111]]
const SCOOP_LIP: Array = [
	[-.748,-.654,.298,.159,.146],[-.733,-.654,.324,.183,.171],
	[-.698,-.652,.350,.211,.195],[-.66,-.651,.375,.236,.221]]
const SCOOP_INNER: Array = [
	[-.748,-.654,.264,.117,.111],[-.700,-.654,.259,.113,.103],
	[-.565,-.647,.263,.108,.100]]

func _ready() -> void:
	_set_batch_paint(Color("aeb9be"),Color("8d9da6"))
	paint.olive = GEO.material(Color("4d5346"))
	paint.mouth = GEO.material(Color("242b30"))
	var hull: Node3D = GEO.group(self,"Fuselage")
	_body(hull,"TaperedMetalShell",BODY)
	_long_cowl(hull)
	_radiator(GEO.group(self,"BellyRadiator"))
	var glass: Node3D = GEO.group(self,"BubbleCockpit")
	_body_glass(glass)
	var panels: Node3D = GEO.group(self,"LaminarWings")
	var feathers: Node3D = GEO.group(self,"Empennage")
	var marks: Node3D = GEO.group(self,"NationalMarks")
	for side: float in [-1.0,1.0]:
		_wing(panels,"PortMainplane" if side<0.0 else "StarboardMainplane",WING,side)
		_wing(feathers,"Stabilizer",TAIL,side)
		_wing_joint(panels,WING,side,.69,2.78,.80)
		_wing_joint(panels,WING,side,2.89,5.26,.77)
		_wing_joint(feathers,TAIL,side,.40,1.92,.71)
		_retracted_main_gear(panels,side)
		var tip: Vector3=GEO.wing_point(WING,5.59,.42,true)
		tip.x*=side
		_ellipsoid(panels,"NavigationLens",Vector3(.042,.027,.061),tip,paint.red if side<0.0 else paint.nav_green)
		_star_bar(marks,"body",BODY,Vector2(1.30,.126),.267,side)
	_star_bar(marks,"wing",WING,Vector2(-3.83,-.11),.414,1.0)
	_star_bar(marks,"wing",WING,Vector2(3.83,-.12),.414,-1.0)
	_fin(feathers,"DorsalFinAndRudder",[
		[.395,1.81,4.94,.084],[.49,2.32,4.938,.091],[.62,2.74,4.93,.088],
		[.79,3.05,4.922,.079],[.97,3.27,4.916,.071],[1.21,3.405,4.882,.062],
		[1.47,3.54,4.818,.057],[1.72,3.67,4.755,.048],[1.91,3.80,4.69,.042],
		[2.045,3.94,4.625,.033],[2.105,4.105,4.550,.020],[2.106,4.232,4.439,.009]])
	GEO.rod(feathers,"RudderHingeLine",Vector3(.024,.58,4.54),Vector3(.019,2.07,4.40),.009,paint.panel)
	GEO.rod(feathers,"RudderHingeLine",Vector3(-.024,.58,4.54),Vector3(-.019,2.07,4.40),.009,paint.panel)
	_four_blade_prop(GEO.group(self,"FourBladePropeller",Vector3(0,-.009,-4.58)))

func _long_cowl(host: Node3D) -> void:
	var paint_strip: SurfaceTool = SurfaceTool.new()
	paint_strip.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 20:
		var z: float = lerpf(-4.25,-2.22,float(i)/20.)
		var z1: float = lerpf(-4.25,-2.22,float(i+1)/20.)
		for j: int in 16:
			var a: float = lerpf(-.43,.43,float(j)/16.)
			var b: float = lerpf(-.43,.43,float(j+1)/16.)
			var p: Vector3=GEO.shell_point(BODY,z,a)+Vector3.UP*.012
			var q: Vector3=GEO.shell_point(BODY,z1,a)+Vector3.UP*.012
			var r: Vector3=GEO.shell_point(BODY,z1,b)+Vector3.UP*.012
			var s: Vector3=GEO.shell_point(BODY,z,b)+Vector3.UP*.012
			GEO.quad(paint_strip,p,q,r,s,Vector3.UP)
	GEO.part(host,"OliveAntiglarePanel",GEO.finish(paint_strip),paint.olive)
	for side: float in [-1.0,1.0]:
		var panel_y: float=.276
		var outline: Array[Vector2] = [Vector2(-3.83,.231),Vector2(-3.77,.332),Vector2(-2.42,.332),Vector2(-2.38,.245)]
		_decal(host,"ExhaustRecessOutline","body",BODY,outline,side,.012,paint.mouth)
		for i: int in 6:
			var z: float = -3.68+.21*i
			var row: Array=GEO.sample(BODY,z)
			var x: float = side*float(row[2])*sqrt(1.0-pow((panel_y-row[1])/row[3],2.0))
			GEO.rod(host,"ExhaustStub",Vector3(x-side*.026,panel_y,z),Vector3(x+side*.070,panel_y-.008,z+.105),.040,paint.dark,.035)
	GEO.arch(host,"CowlingEndLine",BODY,-2.18,.014,paint.panel,-1.97,1.97)

func _radiator(host: Node3D) -> void:
	# Visibly dipped belly, forward lip and shaded cavity; exterior geometry only.
	GEO.part(host,"FairingShell",GEO.loft(SCOOP,SCOOP[0][0],SCOOP[-1][0],paint.top.albedo_color,paint.bottom.albedo_color,Vector4.ZERO,false),paint.skin)
	GEO.part(host,"RoundedIntakeLip",GEO.loft(SCOOP_LIP,SCOOP_LIP[0][0],SCOOP_LIP[-1][0],Color.WHITE,Color.WHITE,Vector4.ZERO,false),paint.silver)
	var ring: SurfaceTool = SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 48:
		var a: float = TAU*float(i)/48.
		var b: float = TAU*float(i+1)/48.
		var outer_a: Vector3 = GEO.shell_point(SCOOP_LIP,-.748,a)
		var outer_b: Vector3 = GEO.shell_point(SCOOP_LIP,-.748,b)
		var inner_a: Vector3 = GEO.shell_point(SCOOP_INNER,-.748,a)
		var inner_b: Vector3 = GEO.shell_point(SCOOP_INNER,-.748,b)
		GEO.quad(ring,outer_a,outer_b,inner_b,inner_a,Vector3.FORWARD)
	GEO.part(host,"IntakeOpeningRim",GEO.finish(ring),paint.silver)
	GEO.part(host,"DarkIntakeWall",GEO.loft(SCOOP_INNER,-.748,-.565,Color.WHITE,Color.WHITE,Vector4.ZERO,false),paint.mouth)
	_ellipsoid(host,"RecessedDarkFace",Vector3(.261,.110,.045),Vector3(0,-.646,-.562),paint.mouth)
	# Small trailing seam in the same satin finish; no separate projecting box.
	for side: float in [-1.,1.]:
		GEO.rod(host,"RadiatorExitPanelSeam",Vector3(side*.160,-.692,1.44),
			Vector3(side*.120,-.577,1.77),.011,paint.panel)

func _body_glass(host: Node3D) -> void:
	# One windscreen frame, then a clear silhouette without extra canopy ribs.
	for pack: Array in [["WindscreenGlass",SCREEN],["SlidingBubbleGlass",BUBBLE]]:
		var p: Array=pack[1]
		GEO.part(host,pack[0],GEO.loft(p,p[0][0],p[-1][0],Color.WHITE,Color.WHITE),paint.glass)
	GEO.arch(host,"WindscreenMainBow",BUBBLE,-1.723,.031,paint.frame,-PI*.57,PI*.57)
	for side: float in [-1.0,1.0]:
		var s: Vector3=GEO.shell_point(SCREEN,-2.236,side*.83)
		var t: Vector3=GEO.shell_point(SCREEN,-1.743,side*.54)
		GEO.rod(host,"WindscreenSideMullion",s,t,.017,paint.frame)
		for i: int in range(BUBBLE.size()-1):
			var a: Vector3=GEO.shell_point(BUBBLE,BUBBLE[i][0],side*PI*.44)
			var b: Vector3=GEO.shell_point(BUBBLE,BUBBLE[i+1][0],side*PI*.44)
			GEO.rod(host,"CanopyLowerFrame",a,b,.020,paint.frame)

func _four_blade_prop(host: Node3D) -> void:
	var spinner: Array=[[-.33,.0,.029,.029,.029],[-.30,0,.089,.089,.089],[-.23,0,.159,.159,.159],
		[-.13,0,.223,.223,.223],[-.035,0,.279,.279,.279],[.026,0,.330,.325,.329]]
	GEO.part(host,"TaperedSpinner",GEO.loft(spinner,-.33,.026,Color.WHITE,Color.WHITE),paint.silver)
	for i: int in 4:
		var blade: Node3D = GEO.group(host,"Blade%d"%i)
		blade.rotation.z=.35+TAU*float(i)/4.0
		var slab: Node3D = GEO.group(blade,"BladePlane")
		slab.rotation.y=PI*.5
		_plate(slab,"PropellerAirfoil",[[.24,-.032],[.57,-.10],[1.07,-.139],[1.56,-.128],[1.78,-.074],
			[1.82,-.003],[1.78,.072],[1.45,.108],[.96,.107],[.42,.062],[.24,.029]],.038,paint.dark)
		_plate(slab,"TipColor",[[1.676,-.100],[1.78,-.074],[1.82,-.003],[1.78,.072],[1.676,.084]],.040,paint.yellow)

func _wing_joint(host: Node3D,p: Array,side: float,x0: float,x1: float,t: float) -> void:
	for i: int in 10:
		var a: Vector3 = GEO.wing_point(p,lerpf(x0,x1,float(i)/10.0),t,true)
		var b: Vector3 = GEO.wing_point(p,lerpf(x0,x1,float(i+1)/10.0),t,true)
		a.x*=side;b.x*=side
		GEO.rod(host,"ControlSurfaceJoin",a+Vector3.UP*.008,b+Vector3.UP*.008,.008,paint.panel)

func _retracted_main_gear(host: Node3D,side: float) -> void:
	var points: Array[Vector2] = [Vector2(.64,-.92),Vector2(.68,-.42),Vector2(1.13,-.39),
		Vector2(1.68,-.49),Vector2(1.92,-.61),Vector2(1.87,-.89),Vector2(1.18,-.96)]
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		for j: int in 5:
			var p: Vector2 = a.lerp(b,float(j)/5.)
			var q: Vector2 = a.lerp(b,float(j+1)/5.)
			GEO.rod(host,"ClosedGearDoorLine",_projection("wing",WING,Vector2(p.x*side,p.y),-1.0,.009),
				_projection("wing",WING,Vector2(q.x*side,q.y),-1.0,.009),.009,paint.panel)
