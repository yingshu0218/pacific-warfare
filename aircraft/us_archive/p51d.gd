extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Representative 1945 Pacific P-51D, static, clean airborne pose.
## Cosmetic geometry only. Source descriptions are in p51d.md.
const LABEL: String = "P-51D Mustang / Pacific 1945"
const LENGTH_M: float = 9.83
const SPAN_M: float = 11.28
# z, datum y, half breadth, crown height, lower depth.
const BODY: Array = [
	[-4.56,.02,.35,.42,.39],[-4.48,.03,.41,.48,.41],[-4.18,.05,.49,.56,.46],
	[-3.73,.06,.52,.62,.49],[-3.20,.07,.54,.66,.51],[-2.66,.08,.55,.69,.53],
	[-2.14,.09,.56,.70,.56],[-1.69,.085,.57,.71,.59],[-1.24,.075,.57,.68,.61],
	[-.72,.07,.55,.65,.63],[-.15,.07,.52,.62,.625],[.47,.09,.47,.575,.59],
	[1.02,.13,.40,.49,.51],[1.65,.17,.34,.40,.425],[2.28,.21,.28,.33,.34],
	[2.91,.245,.22,.26,.25],[3.49,.275,.17,.21,.19],[4.05,.30,.13,.16,.13],
	[4.48,.32,.083,.111,.084],[4.76,.33,.046,.080,.054],[4.92,.33,.025,.043,.025]]
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
	[-2.24,.774,.235,.018,.023],[-2.09,.773,.294,.157,.036],[-1.91,.760,.349,.35,.043],
	[-1.74,.750,.375,.477,.065]]
const BUBBLE: Array = [
	[-1.746,.749,.375,.47,.054],[-1.62,.748,.397,.527,.049],
	[-1.37,.739,.423,.568,.051],[-1.13,.725,.42,.565,.046],
	[-.83,.707,.398,.512,.044],[-.53,.681,.363,.417,.037],
	[-.28,.660,.307,.284,.034],[-.06,.643,.244,.161,.032],[.12,.631,.17,.060,.027],
	[.245,.611,.082,.018,.017]]
const SCOOP: Array = [
	[-.79,-.335,.37,.31,.328],[-.62,-.38,.44,.38,.41],[-.40,-.40,.47,.395,.486],
	[-.11,-.45,.46,.409,.53],[.22,-.47,.425,.396,.477],[.63,-.46,.38,.39,.37],
	[1.07,-.371,.311,.37,.34],[1.47,-.289,.232,.31,.29],
	[1.79,-.215,.16,.245,.237],[2.06,-.143,.074,.147,.137]]
const SCOOP_LIP: Array = [
	[-.805,-.334,.334,.229,.290],[-.79,-.334,.362,.259,.324],
	[-.737,-.345,.393,.30,.368],[-.67,-.364,.422,.34,.392]]

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
		[.42,2.05,4.94,.096],[.58,2.68,4.94,.094],[.84,3.18,4.928,.079],
		[1.17,3.46,4.89,.065],[1.48,3.64,4.83,.053],[1.78,3.81,4.756,.042],
		[1.98,3.95,4.682,.033],[2.07,4.08,4.613,.028],[2.104,4.275,4.511,.017]])
	GEO.rod(feathers,"RudderHingeLine",Vector3(.021,.58,4.54),Vector3(.02,2.05,4.39),.009,paint.panel)
	GEO.rod(feathers,"RudderHingeLine",Vector3(-.021,.58,4.54),Vector3(-.02,2.05,4.39),.009,paint.panel)
	_four_blade_prop(GEO.group(self,"FourBladePropeller",Vector3(0,.028,-4.58)))

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
	# Round inlet rim in front of a recessed, dark and non-functional mesh face.
	var shell: ArrayMesh = GEO.loft(SCOOP,SCOOP[0][0],SCOOP[-1][0],paint.top.albedo_color,paint.bottom.albedo_color,Vector4.ZERO,false)
	GEO.part(host,"FairingShell",shell,paint.skin)
	GEO.part(host,"RoundedIntakeLip",GEO.loft(SCOOP_LIP,SCOOP_LIP[0][0],SCOOP_LIP[-1][0],Color.WHITE,Color.WHITE,Vector4.ZERO,false),paint.silver)
	_ellipsoid(host,"RecessedRadiatorDark",Vector3(.318,.172,.056),Vector3(0,-.469,-.666),paint.mouth)
	var door: MeshInstance3D = GEO.box(host,"RadiatorExitDoor",Vector3(.40,.040,.49),Vector3(0,-.538,1.38),paint.panel)
	door.rotation.x=.18

func _body_glass(host: Node3D) -> void:
	# One windscreen frame, then a clear silhouette without extra canopy ribs.
	for pack: Array in [["WindscreenGlass",SCREEN],["SlidingBubbleGlass",BUBBLE]]:
		var p: Array=pack[1]
		GEO.part(host,pack[0],GEO.loft(p,p[0][0],p[-1][0],Color.WHITE,Color.WHITE),paint.glass)
	GEO.arch(host,"WindscreenMainBow",BUBBLE,-1.726,.036,paint.frame,-PI*.57,PI*.57)
	for side: float in [-1.0,1.0]:
		var s: Vector3=GEO.shell_point(SCREEN,-2.236,side*.83)
		var t: Vector3=GEO.shell_point(SCREEN,-1.743,side*.54)
		GEO.rod(host,"WindscreenSideMullion",s,t,.017,paint.frame)
		for i: int in range(BUBBLE.size()-1):
			var a: Vector3=GEO.shell_point(BUBBLE,BUBBLE[i][0],side*PI*.44)
			var b: Vector3=GEO.shell_point(BUBBLE,BUBBLE[i+1][0],side*PI*.44)
			GEO.rod(host,"CanopyLowerFrame",a,b,.020,paint.frame)

func _four_blade_prop(host: Node3D) -> void:
	var spinner: Array=[[-.33,.0,.025,.025,.025],[-.27,0,.108,.108,.108],[-.16,0,.203,.203,.203],
		[-.05,0,.270,.270,.270],[.071,0,.315,.315,.315]]
	GEO.part(host,"TaperedSpinner",GEO.loft(spinner,-.33,.071,Color.WHITE,Color.WHITE),paint.silver)
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
