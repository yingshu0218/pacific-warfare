extends Node3D
## AV03 pure G4M1 Model11 / Kasei11, 1942-07 combat configuration.
## Metres, +X right/+Y up/-Z forward, immutable body datum (not measured CG).
## No process/timer/physics, flight, ammunition, fire control or random damage.
const G: Script = preload("res://aircraft/g4m1/geometry.gd")
const LENGTH_M: float = 19.97
const SPAN_M: float = 24.88
const PROP_RADIUS_M: float = 1.70 # photograph estimate, not a factory dimension
const ENGINE_CENTER_M: Vector3 = Vector3(3.85, 0.05, -4.90)
const MAIN_WHEEL_CENTER_M: Vector3 = Vector3(3.85, -1.98, -4.05)
const MAIN_WHEEL_RADIUS_M: float = 0.52
const TAIL_WHEEL_CENTER_M: Vector3 = Vector3(0.0, -0.96, 8.00)
const TAIL_WHEEL_RADIUS_M: float = 0.21
const BAY_START_M: float = -3.80
const BAY_END_M: float = 1.70
const CUT: Vector4 = Vector4(BAY_START_M, BAY_END_M, PI * 5.0 / 6.0, PI * 7.0 / 6.0)
# [z,centre_y,half_width,upper_radius,lower_radius], reconstructed from M01-M05.
const BODY: Array = [
	[-8.55,0.00,0.82,0.90,0.96],[-8.00,0.00,0.99,1.05,1.10],[-7.00,0.00,1.13,1.16,1.22],
	[-5.70,0.00,1.20,1.22,1.28],[-4.30,0.00,1.24,1.25,1.30],[-3.80,0.00,1.24,1.25,1.30],
	[-2.00,0.00,1.24,1.25,1.30],[0.00,0.00,1.20,1.23,1.27],[1.70,0.01,1.14,1.19,1.21],
	[3.10,0.02,1.04,1.10,1.10],[4.60,0.03,0.91,0.98,0.95],[5.90,0.04,0.78,0.85,0.80],
	[7.15,0.06,0.66,0.71,0.67],[8.10,0.08,0.56,0.60,0.57],[8.65,0.10,0.50,0.54,0.49]]
const NOSE: Array = [[-9.985,0.0,0.035,0.045,0.045],[-9.86,0.0,0.36,0.40,0.43],[-9.60,0.0,0.58,0.65,0.70],[-9.15,0.0,0.72,0.79,0.85],[-8.55,0.0,0.82,0.90,0.96]]
const TAIL_GLASS: Array = [[8.59,0.10,0.51,0.55,0.50],[8.95,0.10,0.46,0.50,0.45],[9.25,0.10,0.34,0.39,0.34],[9.48,0.10,0.16,0.19,0.18]]
const WING: Array = [
	[0.0,-3.95,4.85,0.02,0.145],[1.15,-3.91,4.77,0.04,0.145],[3.85,-3.65,4.25,0.18,0.13],
	[7.10,-3.27,3.30,0.38,0.115],[10.70,-2.85,2.20,0.60,0.105],[11.90,-2.70,1.76,0.67,0.10],
	[12.28,-2.65,1.61,0.69,0.10],[12.42,-2.58,1.47,0.70,0.10],[12.44,-2.45,1.21,0.70,0.10]]
const TAIL: Array = [
	[0.0,6.65,2.65,0.20,0.10],[0.65,6.78,2.50,0.22,0.10],[2.50,7.27,1.95,0.29,0.09],
	[4.10,7.84,1.22,0.35,0.09],[4.48,8.17,0.58,0.37,0.09],[4.58,8.43,0.025,0.38,0.09]]
const CANOPY: Array = [[-6.82,1.03,0.65,0.08,0.0],[-6.15,1.03,0.82,0.88,0.0],[-5.60,1.03,0.87,0.96,0.0],[-4.65,1.04,0.85,0.93,0.0],[-3.80,1.08,0.74,0.62,0.0],[-3.22,1.12,0.30,0.13,0.0]]
const NACELLE: Array = [[-1.80,0.0,0.77,0.78,0.78],[-1.52,0.0,0.85,0.85,0.86],[-0.70,0.0,0.84,0.83,0.88],[0.10,0.0,0.81,0.77,1.00],[1.25,0.05,0.73,0.64,1.02],[2.50,0.10,0.55,0.47,0.76],[3.55,0.16,0.30,0.25,0.37],[4.20,0.18,0.015,0.02,0.025]]
const GUN_SPECS: Dictionary = {
	"nose":{"weapon":"Type92_7_7mm","at":Vector3(0.0,-0.18,-9.55),"forward":Vector3.FORWARD,"limits":Vector4(-40,40,-35,45),"length":0.60},
	"dorsal":{"weapon":"Type92_7_7mm","at":Vector3(0.0,1.58,-2.35),"forward":Vector3.BACK,"limits":Vector4(-180,180,15,80),"length":0.74},
	"waist_left":{"weapon":"Type92_7_7mm","at":Vector3(-1.37,0.20,1.38),"forward":Vector3(-1.0,0.0,0.25),"limits":Vector4(-35,35,-30,50),"length":0.65},
	"waist_right":{"weapon":"Type92_7_7mm","at":Vector3(1.37,0.20,1.38),"forward":Vector3(1.0,0.0,0.25),"limits":Vector4(-35,35,-30,50),"length":0.65},
	"tail":{"weapon":"Type99_Model1_20mm","at":Vector3(0.0,0.10,9.12),"forward":Vector3.BACK,"limits":Vector4(-22,22,-20,25),"length":0.865}}

var damage_modules: Dictionary = {}
var markers: Dictionary = {}
var surfaces: Dictionary = {}
var propellers: Dictionary = {}
var guns: Dictionary = {}
var materials: Dictionary = {}
var gear_axes: Dictionary = {}
var gear_covers: Array[Node3D] = []
var fixed_groups: Array[Node3D] = []
var bomb_visuals: Array[Node3D] = []
var fairing: Node3D
var dorsal_cover: Node3D
var state: Dictionary = {"gear":1.0,"flap":0.0,"payload_mode":"bombs_12x60","propeller_left_rad":0.0,"propeller_right_rad":0.0,"dorsal_open":true}
var raw_mesh_count: int = 0

func _ready() -> void:
	_materials()
	for id: String in ["center","left_wing","right_wing","tail"]:
		damage_modules[id] = G.group(self,id.to_pascal_case())
	for side: String in ["left","right"]:
		damage_modules["engine_"+side] = G.group(damage_modules[side+"_wing"],"Engine"+side.to_pascal_case(), ENGINE_CENTER_M * Vector3(-1.0 if side=="left" else 1.0,1,1))
	for id: String in damage_modules:
		damage_modules[id].set_meta("damage_part_id",id)
	_build_body()
	_build_wings()
	_build_tail()
	_build_glazing()
	_build_engines()
	_build_bay()
	_build_guns()
	_build_tail_gear()
	mark(damage_modules.center,"FLIGHT_DATUM",Vector3.ZERO,"fixed geometric datum, NOT measured CG")
	mark(damage_modules.tail,"DAMAGE_TAIL_CUT",Vector3(0,0.04,5.90),"closed tail module cut")
	raw_mesh_count = G.meshes(self,false).size()
	for group: Node3D in fixed_groups: G.merge_fixed(group)
	apply_visual_state({})
	set_meta("configuration","G4M1 Model11 / Kasei11 / 1942-07; land based; no carrier hook or folding wings")

func _materials() -> void:
	for row: Array in [["top","30483f"],["bottom","b7bbaf"],["glass","65828c"],["frame","263a34"],["dark","202827"],["steel","606c6c"],["tyre","202322"],["red","a63831"],["prop","4a4139"],["bomb","4c5546"]]:
		materials[row[0]] = G.material(Color(row[1]),0.25 if row[0]=="steel" else 0.0)
	materials.skin = G.material(Color.WHITE)
	materials.skin.vertex_color_use_as_albedo = true

func fixed(host: Node3D, id: String = "FixedSkin") -> Node3D:
	var node: Node3D = G.group(host,id)
	fixed_groups.append(node)
	return node

func mark(host: Node3D, id: String, at: Vector3, source: String, forward: Vector3 = Vector3.FORWARD) -> Marker3D:
	var node: Marker3D = Marker3D.new()
	node.name = id; node.position = at
	if not forward.is_equal_approx(Vector3.FORWARD): node.basis = Basis.looking_at(forward.normalized(),Vector3.UP)
	node.set_meta("source_status",source); node.set_meta("host_id",str(host.name))
	host.add_child(node); markers[id] = node
	return node

func _build_body() -> void:
	var center: Node3D = fixed(damage_modules.center)
	G.part(center,"ContinuousCigarBody",G.loft(BODY,-8.55,5.90,materials.top.albedo_color,materials.bottom.albedo_color,CUT),materials.skin)
	var tail: Node3D = fixed(damage_modules.tail)
	G.part(tail,"TaperedAftBody",G.loft(BODY,5.90,8.65,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
	# Minor observation windows omitted; V1 keeps the continuous, clean shell.

func _build_wings() -> void:
	for side: float in [-1.0,1.0]:
		var id: String = "left" if side<0.0 else "right"
		var host: Node3D = damage_modules[id+"_wing"]
		var skin: Node3D = fixed(host)
		for row: Array in [[0.0,1.10,0.0,1.0],[1.10,7.10,0.0,0.72],[7.10,12.10,0.0,0.72],[12.10,12.44,0.0,1.0]]:
			G.part(skin,"WingSkin",G.wing(WING,side,row[0],row[1],row[2],row[3],Vector3.ZERO,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		for row: Array in [["flap_"+id,1.10,7.10],["aileron_"+id,7.10,12.10]]:
			var pivot: Vector3 = G.wing_point(WING,row[1],0.72,true); pivot.x *= side
			var axis: Node3D = G.group(host,row[0].to_pascal_case(),pivot)
			G.part(axis,"ControlSkin",G.wing(WING,side,row[1],row[2],0.72,1.0,pivot,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
			surfaces[row[0]] = axis
			mark(axis,row[0].to_upper()+"_HINGE",Vector3.ZERO,"photo-estimated hinge; local +X rotation")
		mark(host,"DAMAGE_WING_"+id.to_upper()+"_CUT",Vector3(side*1.10,0.04,-1.0),"closed wing root; engine and gear inherit wing detachment")
		# Wing insignia only. Simplified paint does not claim a specific aircraft code.
		for upper: bool in [true,false]:
			var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var c: Vector2 = Vector2(9.1,-1.74)
			for ring: int in range(8):
				for i: int in range(32):
					var a: float=TAU*i/32.0;var b: float=TAU*(i+1)/32.0
					var r0: float=0.70*ring/8.0;var r1: float=0.70*(ring+1)/8.0
					var points: Array[Vector3]=[]
					for p: Vector2 in [c+Vector2(cos(a),sin(a))*r0,c+Vector2(cos(a),sin(a))*r1,c+Vector2(cos(b),sin(b))*r1,c+Vector2(cos(b),sin(b))*r0]:
						var s: Array=G.sample(WING,p.x)
						var point: Vector3=G.wing_point(WING,p.x,(p.y-s[1])/s[2],upper)
						point.x*=side;point.y+=0.016 if upper else -0.016;points.append(point)
					G.quad(st,points[0],points[1],points[2],points[3],Vector3.UP if upper else Vector3.DOWN)
			G.part(skin,"Hinomaru",G.finish(st),materials.red)

func _build_tail() -> void:
	var skin: Node3D = fixed(damage_modules.tail,"TailFixed")
	for side: float in [-1.0,1.0]:
		var id: String = "left" if side<0 else "right"
		G.part(skin,"Stabilizer",G.wing(TAIL,side,0.0,4.58,0.0,0.72,Vector3.ZERO,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		var pivot: Vector3 = G.wing_point(TAIL,0.45,0.72,true); pivot.x *= side
		var axis: Node3D = G.group(damage_modules.tail,"Elevator"+id.to_pascal_case(),pivot)
		G.part(axis,"ElevatorSkin",G.wing(TAIL,side,0.45,4.58,0.72,1.0,pivot,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		surfaces["elevator_"+id] = axis
		mark(axis,"ELEVATOR_"+id.to_upper()+"_HINGE",Vector3.ZERO,"photo-estimated local +X axis")
	var fin: PackedVector2Array = PackedVector2Array([Vector2(0.25,6.45),Vector2(0.72,6.82),Vector2(2.65,7.75),Vector2(3.10,8.18),Vector2(3.13,8.72),Vector2(2.94,8.99),Vector2(0.32,8.99)])
	G.plate(skin,"SweptRoundedFin",fin,0.14,materials.top)
	var pivot: Vector3 = Vector3(0.0,0.40,8.99)
	var axis: Node3D = G.group(damage_modules.tail,"Rudder",pivot)
	G.plate(axis,"RudderSkin",PackedVector2Array([Vector2(0.32,8.99),Vector2(2.94,8.99),Vector2(2.70,9.39),Vector2(0.35,9.50)]),0.12,materials.top,pivot)
	surfaces.rudder = axis
	mark(axis,"RUDDER_HINGE",Vector3.ZERO,"photo-estimated local +Y axis")

func _build_glazing() -> void:
	var skin: Node3D = fixed(damage_modules.center,"Glazing")
	G.part(skin,"GlazedNose",G.loft(NOSE,-9.985,-8.55,Color.WHITE,Color.WHITE,Vector4.ZERO,false),materials.glass)
	for z: float in [-9.65,-9.17,-8.57]: G.arch(skin,"NoseFrame",NOSE,z,0.035,materials.frame)
	for a: float in [0.0,PI*0.5,PI,PI*1.5]:
		for j: int in range(NOSE.size()-1): G.rod(skin,"NoseLongitudinalFrame",G.shell_point(NOSE,NOSE[j][0],a),G.shell_point(NOSE,NOSE[j+1][0],a),0.017,materials.frame)
	# Broad flat windshield and roof panels, with sills embedded in the real body.
	var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(CANOPY.size()-1):
		for i: int in range(4):
			var n: Vector3=Vector3(-1.0 if i<2 else 1.0,1.0,0).normalized()
			G.quad(st,_canopy_point(CANOPY[j][0],i),_canopy_point(CANOPY[j+1][0],i),_canopy_point(CANOPY[j+1][0],i+1),_canopy_point(CANOPY[j][0],i+1),n)
	G.part(skin,"SteppedCockpitCanopy",G.finish(st),materials.glass)
	for z: float in [-6.15,-5.45,-4.45,-3.75]:
		for i: int in range(4): G.rod(skin,"CanopyCrossFrame",_canopy_point(z,i),_canopy_point(z,i+1),0.018,materials.frame)
	for i: int in [0,1,3,4]:
		for j: int in range(CANOPY.size()-1): G.rod(skin,"CanopyMainLongitudinal",_canopy_point(CANOPY[j][0],i),_canopy_point(CANOPY[j+1][0],i),0.020,materials.frame)
	var tail: Node3D = fixed(damage_modules.tail,"TailGlazing")
	G.part(tail,"OriginalTailCone",G.loft(TAIL_GLASS,8.59,9.48,Color.WHITE,Color.WHITE,Vector4.ZERO,false),materials.glass)
	for z: float in [8.62,8.99,9.30]: G.arch(tail,"TailConeFrame",TAIL_GLASS,z,0.03,materials.frame)
	for a: float in [0.0,PI*0.5,PI,PI*1.5]:
		for j: int in range(TAIL_GLASS.size()-1): G.rod(tail,"TailConeLongitudinalFrame",G.shell_point(TAIL_GLASS,TAIL_GLASS[j][0],a),G.shell_point(TAIL_GLASS,TAIL_GLASS[j+1][0],a),0.016,materials.frame)
	# The dorsal hood is a low teardrop blister, not a powered cannon turret.
	dorsal_cover = G.group(damage_modules.center,"DorsalSlidingHood")
	var hood: Array = [[-3.25,1.18,0.035,0.025,0.0],[-2.90,1.18,0.40,0.38,0.0],[-2.35,1.18,0.48,0.58,0.0],[-1.70,1.18,0.32,0.40,0.0],[-1.45,1.18,0.025,0.025,0.0]]
	G.part(dorsal_cover,"Hood",G.loft(hood,-3.25,-1.45,Color.WHITE,Color.WHITE,Vector4.ZERO,false),materials.glass)
	G.arch(dorsal_cover,"HoodFrame",hood,-2.35,0.03,materials.frame)
	G.sphere(skin,"DorsalRim",Vector3(0.46,0.06,0.82),Vector3(0,1.24,-2.34),materials.frame)
	G.sphere(skin,"DorsalOpeningShadow",Vector3(0.39,0.062,0.72),Vector3(0,1.25,-2.34),materials.dark)
	for side: float in [-1.0,1.0]:
		# Embedded into the shell; only the outer hemisphere protrudes.
		G.sphere(skin,"WaistBlister",Vector3(0.34,0.37,0.66),Vector3(side*1.14,0.20,1.38),materials.glass)
		G.rod(skin,"WaistBlisterCentreFrame",Vector3(side*1.46,-0.12,1.38),Vector3(side*1.46,0.52,1.38),0.018,materials.frame)

func _canopy_point(z: float,index: int) -> Vector3:
	var row: Array=G.sample(CANOPY,z)
	var body: Array=G.sample(BODY,z)
	var w: float=row[2]
	var top: float=row[1]+row[3]
	var sill_y: float=body[1]+body[3]*sqrt(maxf(0.0,1.0-pow(w/body[2],2)))-0.035
	match index:
		0:return Vector3(-w,sill_y,z)
		1:return Vector3(-w*0.68,top-0.10,z)
		2:return Vector3(0,top,z)
		3:return Vector3(w*0.68,top-0.10,z)
	return Vector3(w,sill_y,z)

func _build_engines() -> void:
	for id: String in ["left","right"]:
		var engine: Node3D = damage_modules["engine_"+id]
		var skin: Node3D = fixed(engine)
		var opening: Vector4 = Vector4(0.10,2.50,PI*0.75,PI*1.25)
		G.part(skin,"RadialNacelle",G.loft(NACELLE,-1.80,4.20,materials.top.albedo_color,materials.bottom.albedo_color,opening),materials.skin)
		G.box(skin,"WellCeiling",Vector3(0.96,0.05,2.10),Vector3(0,-0.36,1.25),materials.dark)
		var lip: Array = [[-1.815,0.0,0.77,0.78,0.78],[-1.72,0.0,0.79,0.80,0.80]]
		G.part(skin,"SimpleCowlLip",G.loft(lip,-1.815,-1.72,Color.WHITE,Color.WHITE),materials.dark)
		# A dark flat mouth; no engine cylinders or cooling ring microgeometry.
		G.sphere(skin,"CowlMouth",Vector3(0.68,0.68,0.025),Vector3(0,0,-1.825),materials.dark)
		var prop: Node3D = G.group(engine,"Propeller",Vector3(0,0,-1.88))
		propellers[id] = prop
		var spinner: Array = [[-0.40,0.0,0.015,0.015,0.015],[-0.25,0.0,0.24,0.24,0.24],[0.05,0.0,0.31,0.31,0.31]]
		G.part(prop,"Spinner",G.loft(spinner,-0.40,0.05,Color.WHITE,Color.WHITE),materials.steel)
		for i: int in range(3):
			var blade: Node3D = G.group(prop,"Blade%d"%i); blade.rotation.z = i*TAU/3.0
			var outline: PackedVector2Array = PackedVector2Array([Vector2(0.22,-0.06),Vector2(0.72,-0.16),Vector2(1.38,-0.14),Vector2(1.66,-0.07),Vector2(1.70,0),Vector2(1.61,0.045),Vector2(0.85,0.11),Vector2(0.22,0.05)])
			var panel: MeshInstance3D = G.plate(blade,"BladeSkin",outline,0.035,materials.prop); panel.rotation.y = PI*0.5
		mark(prop,"PROP_CENTER_"+id.to_upper(),Vector3.ZERO,"photo-estimated 1.70m full rotation radius")
		mark(engine,"ENGINE_"+id.to_upper()+"_SMOKE",Vector3(0,0.40,0.50),"emission only when simulation requests")
		mark(engine,"ENGINE_"+id.to_upper()+"_CUT",Vector3(0,0,2.5),"whole nacelle damage host; no automatic detachment")
		_build_main_gear(id,engine)

func _wheel(host: Node3D, id: String, center: Vector3, radius: float, width: float) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=width; mesh.radial_segments=64
	var tyre: MeshInstance3D = G.part(host,id,mesh,materials.tyre,center); tyre.rotation.z=PI*0.5
	var hub: CylinderMesh = CylinderMesh.new(); hub.top_radius=radius*0.48; hub.bottom_radius=radius*0.48; hub.height=width+0.014; hub.radial_segments=20
	var metal: MeshInstance3D = G.part(host,id+"Hub",hub,materials.steel,center); metal.rotation.z=PI*0.5

func _build_main_gear(id: String, host: Node3D) -> void:
	var pivot: Vector3 = Vector3(0,-0.40,0.25)
	var axis: Node3D = G.group(host,"MainGear",pivot)
	gear_axes[id] = axis
	var center: Vector3 = MAIN_WHEEL_CENTER_M * Vector3(-1.0 if id=="left" else 1.0,1,1) - host.position - pivot
	G.rod(axis,"Oleo",Vector3.ZERO,center+Vector3(0,0.14,0),0.065,materials.steel)
	G.rod(axis,"AftBrace",Vector3(0,0,0.62),center*0.52,0.038,materials.dark)
	G.rod(axis,"Axle",center-Vector3(0.17,0,0),center+Vector3(0.17,0,0),0.07,materials.steel)
	_wheel(axis,"MainTyre",center,MAIN_WHEEL_RADIUS_M,0.28)
	mark(axis,"WHEEL_"+id.to_upper(),center,"photo-estimated real cylinder centre, 0.52m radius").set_meta("radius_m",MAIN_WHEEL_RADIUS_M)
	mark(axis,"GEAR_"+id.to_upper()+"_HINGE",Vector3.ZERO,"simple aft folding +X axis, -75deg when stowed; not full linkage")
	var cover: Node3D = G.group(host,"ClosedGearCover"); gear_covers.append(cover)
	var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(12):
		for i: int in range(12):
			var z: float = lerpf(0.10,2.50,j/12.0); var z1: float=lerpf(0.10,2.50,(j+1)/12.0)
			var a: float = lerpf(PI*0.75,PI*1.25,i/12.0); var b: float=lerpf(PI*0.75,PI*1.25,(i+1)/12.0)
			G.quad(st,G.shell_point(NACELLE,z,a),G.shell_point(NACELLE,z1,a),G.shell_point(NACELLE,z1,b),G.shell_point(NACELLE,z,b),Vector3(0,-1,0))
	G.part(cover,"SimpleFlushCover",G.finish(st),materials.bottom)

func _build_tail_gear() -> void:
	var pivot: Vector3 = Vector3(0,-0.41,7.80)
	var axis: Node3D = G.group(damage_modules.tail,"TailGear",pivot)
	gear_axes.tail = axis
	G.rod(axis,"ShortOleo",Vector3.ZERO,TAIL_WHEEL_CENTER_M-pivot+Vector3(0,0.08,0),0.04,materials.steel)
	G.rod(axis,"Fork",TAIL_WHEEL_CENTER_M-pivot+Vector3(0,0.17,-0.05),TAIL_WHEEL_CENTER_M-pivot,0.032,materials.steel)
	_wheel(axis,"TailTyre",TAIL_WHEEL_CENTER_M-pivot,TAIL_WHEEL_RADIUS_M,0.12)
	mark(axis,"WHEEL_TAIL",TAIL_WHEEL_CENTER_M-pivot,"photo-estimated real cylinder centre, short root intersects aft belly").set_meta("radius_m",TAIL_WHEEL_RADIUS_M)
	mark(axis,"GEAR_TAIL_HINGE",Vector3.ZERO,"simplified forward fold -X axis, exact mechanism unverified")

func _build_bay() -> void:
	var host: Node3D = damage_modules.center
	var skin: Node3D = fixed(host,"BombBayFixed")
	G.box(skin,"BayCeiling",Vector3(1.18,0.06,5.45),Vector3(0,-0.56,-1.05),materials.dark)
	for side: float in [-1.0,1.0]:
		G.box(skin,"BaySideWall",Vector3(0.06,0.51,5.45),Vector3(side*0.57,-0.83,-1.05),materials.dark)
	for z: float in [BAY_START_M+0.035,BAY_END_M-0.035]: G.box(skin,"BayEndWall",Vector3(1.18,0.53,0.07),Vector3(0,-0.84,z),materials.dark)
	fairing = G.group(host,"RemovableFerryFairing")
	var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(24):
		for i: int in range(8):
			var z: float=lerpf(BAY_START_M,BAY_END_M,j/24.0);var z1: float=lerpf(BAY_START_M,BAY_END_M,(j+1)/24.0)
			var a: float=lerpf(CUT.z,CUT.w,i/8.0);var b: float=lerpf(CUT.z,CUT.w,(i+1)/8.0)
			G.quad(st,G.shell_point(BODY,z,a),G.shell_point(BODY,z1,a),G.shell_point(BODY,z1,b),G.shell_point(BODY,z,b),Vector3.DOWN)
	G.part(fairing,"LiftOffFairing",G.finish(st),materials.bottom)
	for rack: int in range(2):
		var z: float=-2.82+float(rack)*2.60
		G.box(skin,"SixBombRack",Vector3(1.03,0.07,2.12),Vector3(0,-0.74,z+0.60),materials.steel)
		mark(host,"RACK_%02d"%rack,Vector3(0,-0.74,z+0.60),"two six-bomb carriers from D01/Tamiya steps15-16; detailed geometry estimated")
	for row: int in range(4):
		for column: int in range(3):
			var at: Vector3=Vector3((column-1)*0.35,-1.12,-3.04+row*1.30)
			var index: int=row*3+column
			var bomb: Node3D=G.group(host,"Bomb60kg_%02d"%index,at);bomb_visuals.append(bomb)
			var profile: Array=[[-0.57,0.0,0.008,0.008,0.008],[-0.48,0.0,0.095,0.095,0.095],[-0.30,0.0,0.13,0.13,0.13],[0.20,0.0,0.13,0.13,0.13],[0.43,0.0,0.035,0.035,0.035],[0.54,0.0,0.025,0.025,0.025]]
			G.part(bomb,"BombShell",G.loft(profile,-0.57,0.54,Color.WHITE,Color.WHITE),materials.bomb)
			G.box(bomb,"TailFinVertical",Vector3(0.015,0.31,0.27),Vector3(0,0,0.40),materials.bomb)
			G.box(bomb,"TailFinHorizontal",Vector3(0.31,0.015,0.27),Vector3(0,0,0.40),materials.bomb)
			G.rod(skin,"BombCarrierLug",at+Vector3(0,0.40,0),at+Vector3(0,0.10,0),0.021,materials.steel)
			mark(bomb,"BOMB_%02d_RELEASE"%index,Vector3.ZERO,"displayed 60kg store centre; host simulation owns release/inventory")
			mark(bomb,"BOMB_%02d_NOSE"%index,Vector3(0,0,-0.57),"actual nose, -Z; fins aft")
	mark(host,"TORPEDO_RESERVED",Vector3(0,-1.27,-1.05),"future alternative carrier datum ONLY; no torpedo mesh/qualified release or mixed load")

func _build_guns() -> void:
	for id: String in GUN_SPECS:
		var spec: Dictionary=GUN_SPECS[id]
		var host: Node3D=damage_modules.tail if id=="tail" else damage_modules.center
		var base: Node3D=G.group(host,"Gun_"+id,spec.at)
		base.basis=Basis.looking_at(spec.forward.normalized(),Vector3.UP)
		var yaw: Node3D=G.group(base,"Yaw")
		var elevation: Node3D=G.group(yaw,"Elevation")
		var support_root: Vector3=Vector3(0,-0.13,0.03)
		if id=="dorsal":support_root=Vector3(0,-0.37,0.03)
		elif id.begins_with("waist_"):support_root=Vector3(0,-0.10,0.27)
		G.rod(base,"Bearing",support_root,Vector3.ZERO,0.048,materials.steel)
		G.box(elevation,"Receiver",Vector3(0.12,0.13,0.28),Vector3(0,0,0.05),materials.dark)
		G.rod(elevation,"Barrel",Vector3(0,0,-0.06),Vector3(0,0,-spec.length),0.025 if id=="tail" else 0.016,materials.dark)
		var muzzle: Marker3D=mark(elevation,"MUZZLE_"+id.to_upper(),Vector3(0,0,-spec.length),"independent moving muzzle; calibre/count sourced, mount axes/limits photo estimates")
		mark(base,"GUN_"+id.to_upper()+"_PIVOT",Vector3.ZERO,"photo-estimated manual gun mount; +Y yaw/+X elevation in local frame")
		guns[id]={"base":base,"yaw":yaw,"elevation":elevation,"muzzle":muzzle,"limits_deg":spec.limits,"weapon":spec.weapon}

func _number(snapshot: Dictionary,key: String,fallback: float,min_value: float,max_value: float) -> float:
	var v: Variant=snapshot.get(key,fallback)
	if not (v is float or v is int) or not is_finite(float(v)): return fallback
	return clampf(float(v),min_value,max_value)

func apply_visual_state(snapshot: Dictionary) -> void:
	for key: String in ["gear","flap"]: state[key]=_number(snapshot,key,float(state[key]),0.0,1.0)
	for id: String in ["left","right"]:
		var key: String="propeller_"+id+"_rad"
		state[key]=_number(snapshot,key,float(state[key]),-1.0e8,1.0e8)
		propellers[id].rotation.z=fposmod(state[key],TAU)
	if snapshot.get("payload_mode",state.payload_mode) in ["bombs_12x60","empty_open","ferry"]: state.payload_mode=snapshot.get("payload_mode",state.payload_mode)
	if snapshot.get("dorsal_open",state.dorsal_open) is bool: state.dorsal_open=snapshot.get("dorsal_open",state.dorsal_open)
	dorsal_cover.visible=not state.dorsal_open
	for id: String in ["left","right"]: gear_axes[id].rotation.x=deg_to_rad(-75.0)*(1.0-state.gear); gear_axes[id].visible=state.gear>0.001
	gear_axes.tail.rotation.x=deg_to_rad(100.0)*(1.0-state.gear);gear_axes.tail.visible=state.gear>0.001
	for node: Node3D in gear_covers: node.visible=state.gear<0.04
	fairing.visible=state.payload_mode=="ferry"
	var bomb_mask: Variant=snapshot.get("bomb_visible",null)
	for i: int in range(bomb_visuals.size()):
		if bomb_mask is Array and i<bomb_mask.size() and bomb_mask[i] is bool: bomb_visuals[i].set_meta("inventory_visible",bomb_mask[i])
		bomb_visuals[i].visible=state.payload_mode=="bombs_12x60" and bool(bomb_visuals[i].get_meta("inventory_visible",true))
	for id: String in ["left","right"]:
		surfaces["flap_"+id].rotation.x=deg_to_rad(-35.0)*state.flap
	for key: String in ["aileron_left","aileron_right","elevator_left","elevator_right","rudder"]:
		var angle: float=_number(snapshot,key+"_rad",float(state.get(key+"_rad",0.0)),-0.35,0.35)
		state[key+"_rad"]=angle
		if key=="rudder": surfaces[key].rotation.y=angle
		else: surfaces[key].rotation.x=angle
	var aims: Dictionary=snapshot.get("guns",{}) if snapshot.get("guns",{}) is Dictionary else {}
	for id: String in guns:
		var old: Dictionary=state.get("gun_"+id,{"yaw_rad":0.0,"elevation_rad":deg_to_rad(30.0 if id=="dorsal" else 0.0)})
		var aim: Dictionary=aims.get(id,{}) if aims.get(id,{}) is Dictionary else {}
		var limit: Vector4=guns[id].limits_deg
		var yaw: float=_number(aim,"yaw_rad",old.yaw_rad,deg_to_rad(limit.x),deg_to_rad(limit.y))
		var elevation: float=_number(aim,"elevation_rad",old.elevation_rad,deg_to_rad(limit.z),deg_to_rad(limit.w))
		state["gun_"+id]={"yaw_rad":yaw,"elevation_rad":elevation}
		guns[id].yaw.rotation.y=yaw;guns[id].elevation.rotation.x=elevation
		guns[id].base.visible=id!="dorsal" or state.dorsal_open

func apply_damage_state(attached: Dictionary) -> void:
	for id: String in damage_modules:
		if attached.get(id,null) is bool: damage_modules[id].visible=attached[id]

func set_flight_configuration() -> void:
	apply_visual_state({"gear":0.0,"flap":0.0})

func set_landing_gear_deployed(deployed: bool) -> void:
	apply_visual_state({"gear":1.0 if deployed else 0.0})

func get_parked_transform() -> Transform3D:
	var dy: float=TAIL_WHEEL_CENTER_M.y-MAIN_WHEEL_CENTER_M.y
	var dz: float=TAIL_WHEEL_CENTER_M.z-MAIN_WHEEL_CENTER_M.z
	var pitch: float=atan2(dy,dz)+asin((MAIN_WHEEL_RADIUS_M-TAIL_WHEEL_RADIUS_M)/Vector2(dy,dz).length())
	var basis: Basis=Basis(Vector3.RIGHT,pitch)
	return Transform3D(basis,Vector3(0,MAIN_WHEEL_RADIUS_M-(basis*MAIN_WHEEL_CENTER_M).y,0))
