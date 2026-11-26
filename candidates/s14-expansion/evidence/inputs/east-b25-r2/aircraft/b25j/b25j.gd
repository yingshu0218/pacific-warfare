extends Node3D
## AV04 B-25J-1-NC, representative early glazed bomber / 1944-07.
## Pure snapshot model. Geometric datum is not a measured historical CG.
const G: Script = preload("res://aircraft/b25j/geometry.gd")
const LENGTH_M: float = 16.30045 # 53 ft 5.75 in, excluding armament
const SPAN_M: float = 20.5994 # 67 ft 7 in
const PROP_RADIUS_M: float = 1.91 # photo estimate; full swept disc must be checked
const ENGINE_CENTER_M: Vector3 = Vector3(3.12,0.12,-2.80)
const MAIN_WHEEL_CENTER_M: Vector3 = Vector3(3.12,-1.65,0.30)
const MAIN_WHEEL_RADIUS_M: float = 0.52
const NOSE_WHEEL_CENTER_M: Vector3 = Vector3(0,-1.85,-5.85)
const NOSE_WHEEL_RADIUS_M: float = 0.35
const BAY_START_M: float = -2.70
const BAY_END_M: float = 0.15
const CUT: Vector4 = Vector4(BAY_START_M,BAY_END_M,PI*0.75,PI*1.25)
# [z, centre_y, half_width, upper_radius, lower_radius]; new AV04 reconstruction.
const BODY: Array = [
	[-5.65,0.0,0.88,1.03,0.94],[-4.60,0.0,0.91,1.08,1.04],[-3.40,0.0,0.92,1.10,1.08],
	[-2.70,0.0,0.92,1.10,1.08],[-1.00,0.0,0.91,1.09,1.07],[0.15,0.0,0.89,1.07,1.04],
	[1.80,0.02,0.81,1.00,0.96],[3.20,0.04,0.71,0.88,0.82],[4.70,0.07,0.59,0.73,0.67],
	[5.65,0.10,0.49,0.62,0.54],[6.65,0.12,0.40,0.51,0.45],[7.30,0.13,0.35,0.44,0.39],
	[7.85,0.13,0.29,0.32,0.30],[8.150225,0.13,0.14,0.16,0.16]]
const NOSE: Array = [
	[-8.150225,0.02,0.025,0.035,0.035],[-8.06,0.02,0.28,0.31,0.29],[-7.82,0.02,0.49,0.55,0.49],
	[-7.45,0.01,0.66,0.73,0.64],[-6.90,0.0,0.78,0.88,0.79],[-6.22,0.0,0.85,0.99,0.91],[-5.65,0.0,0.88,1.03,0.94]]
const WING: Array = [
	[0,-2.60,4.45,0.12,0.16],[1.0,-2.59,4.42,0.14,0.16],[3.12,-2.40,4.00,0.40,0.14],
	[4.10,-2.22,3.78,0.40,0.13],[7.20,-1.46,3.02,0.41,0.115],[9.10,-1.00,2.55,0.42,0.105],
	[9.78,-0.76,2.16,0.42,0.10],[10.12,-0.51,1.64,0.42,0.10],[10.27,-0.22,1.02,0.42,0.10],[10.2997,0.04,0.50,0.42,0.10]]
const H_TAIL: Array = [[0,5.70,2.12,0.50,0.10],[0.55,5.70,2.12,0.50,0.10],[3.30,5.85,1.90,0.53,0.09],[3.86,5.99,1.66,0.54,0.09],[4.03,6.19,1.23,0.54,0.09]]
const NACELLE: Array = [
	[-1.56,0.0,0.73,0.73,0.73],[-1.38,0.0,0.83,0.82,0.84],[-0.72,0.0,0.84,0.83,0.86],
	[0.10,0.0,0.79,0.74,0.97],[1.20,0.04,0.73,0.54,1.03],[2.80,0.12,0.59,0.33,0.81],
	[3.95,0.16,0.39,0.24,0.49],[4.82,0.19,0.17,0.15,0.22],[5.24,0.20,0.015,0.02,0.025]]
# Width/top/sill values for a stepped, flat-panel cockpit, not a bubble canopy.
const COCKPIT: Array = [[-5.55,0.0,0.67,1.03,0.68],[-5.04,0.0,0.79,1.59,0.66],[-4.45,0.0,0.81,1.66,0.63],[-3.56,0.0,0.76,1.58,0.66],[-3.38,0.0,0.66,1.09,0.69]]
const TAIL_HOOD: Array = [[6.65,0.45,0.25,0.19,0],[7.06,0.45,0.37,0.59,0],[7.55,0.45,0.36,0.57,0],[8.00,0.35,0.26,0.19,0],[8.11,0.30,0.16,0.08,0]]
const GUN_SPECS: Dictionary = {
	"nose_flexible":{"at":Vector3(0,0.07,-7.91),"forward":Vector3.FORWARD,"limits":Vector4(-22,22,-25,25),"barrels":1,"length":0.59},
	"nose_fixed":{"at":Vector3(0.55,0.03,-7.32),"forward":Vector3.FORWARD,"limits":Vector4(0,0,0,0),"barrels":1,"length":1.05},
	"cheek_left_upper":{"at":Vector3(-1.05,-0.04,-4.49),"forward":Vector3.FORWARD,"limits":Vector4(0,0,0,0),"barrels":1,"length":1.12},
	"cheek_left_lower":{"at":Vector3(-1.05,-0.46,-4.49),"forward":Vector3.FORWARD,"limits":Vector4(0,0,0,0),"barrels":1,"length":1.12},
	"cheek_right_upper":{"at":Vector3(1.05,-0.04,-4.49),"forward":Vector3.FORWARD,"limits":Vector4(0,0,0,0),"barrels":1,"length":1.12},
	"cheek_right_lower":{"at":Vector3(1.05,-0.46,-4.49),"forward":Vector3.FORWARD,"limits":Vector4(0,0,0,0),"barrels":1,"length":1.12},
	"dorsal":{"at":Vector3(0,1.42,-2.76),"forward":Vector3.FORWARD,"limits":Vector4(-180,180,10,80),"barrels":2,"length":1.18},
	"waist_left":{"at":Vector3(-0.81,0.25,2.11),"forward":Vector3(-1,0,0.24),"limits":Vector4(-30,30,-30,40),"barrels":1,"length":0.73},
	"waist_right":{"at":Vector3(0.81,0.25,2.60),"forward":Vector3(1,0,0.24),"limits":Vector4(-30,30,-30,40),"barrels":1,"length":0.73},
	"tail":{"at":Vector3(0,0.15,8.03),"forward":Vector3.BACK,"limits":Vector4(-25,25,-25,35),"barrels":2,"length":0.94}}
var damage_modules: Dictionary = {}
var markers: Dictionary = {}
var surfaces: Dictionary = {}
var propellers: Dictionary = {}
var gear_axes: Dictionary = {}
var gear_covers: Array[Node3D] = []
var guns: Dictionary = {}
var materials: Dictionary = {}
var fixed_groups: Array[Node3D] = []
var bomb_visuals: Array[Node3D] = []
var bay_doors: Dictionary = {}
var raw_mesh_count: int = 0
var state: Dictionary = {"gear":1.0,"flap":0.0,"bay_door":0.0,"payload_mode":"bombs_6x500","propeller_left_rad":0.0,"propeller_right_rad":0.0}

func _ready() -> void:
	for row: Array in [["top","414832"],["bottom","999e98"],["glass","344c59"],["frame","444d40"],["dark","222a2c"],["steel","8d9698"],["tyre","262a2b"],["yellow","d0ae43"],["bomb","5c6250"],["blue","263e51"],["white","deded2"]]:
		materials[row[0]]=G.material(Color(row[1]),0.2 if row[0]=="steel" else 0.0)
	materials.skin=G.material(Color.WHITE);materials.skin.vertex_color_use_as_albedo=true
	for id: String in ["center","left_wing","right_wing","tail"]:damage_modules[id]=G.group(self,id.to_pascal_case())
	for id: String in ["left","right"]:
		damage_modules["engine_"+id]=G.group(damage_modules[id+"_wing"],"Engine"+id.to_pascal_case(),ENGINE_CENTER_M*Vector3(-1 if id=="left" else 1,1,1))
	for id: String in damage_modules:damage_modules[id].set_meta("damage_part_id",id)
	_build_body();_build_wings();_build_tail();_build_glazing();_build_engines();_build_gear();_build_bay();_build_guns()
	mark(damage_modules.center,"FLIGHT_DATUM",Vector3.ZERO,"immutable geometric datum; NOT measured CG")
	mark(damage_modules.tail,"DAMAGE_TAIL_CUT",Vector3(0,0.1,5.65),"tail assembly includes fins, rudders, elevators and tail guns")
	raw_mesh_count=G.meshes(self,false).size()
	for host: Node3D in fixed_groups:G.merge_fixed(host)
	apply_visual_state({})
	set_meta("configuration","B-25J-1-NC representative early glazed bomber / 1944-07; land based, no hook/fold/torpedo/rockets")

func fixed(host: Node3D,id: String="FixedSkin") -> Node3D:
	var node: Node3D=G.group(host,id);fixed_groups.append(node);return node

func mark(host: Node3D,id: String,at: Vector3,source: String,forward: Vector3=Vector3.FORWARD) -> Marker3D:
	var node: Marker3D=Marker3D.new();node.name=id;node.position=at
	if not forward.is_equal_approx(Vector3.FORWARD):node.basis=Basis.looking_at(forward.normalized(),Vector3.UP)
	node.set_meta("source_status",source);host.add_child(node);markers[id]=node;return node

func _build_body() -> void:
	var skin: Node3D=fixed(damage_modules.center)
	G.part(skin,"Fuselage",G.loft(BODY,-5.65,5.65,materials.top.albedo_color,materials.bottom.albedo_color,CUT),materials.skin)
	G.part(fixed(damage_modules.tail),"TailFuselage",G.loft(BODY,5.65,8.150225,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
	for side: float in [-1.0,1.0]:
		for y: float in [-0.04,-0.46]:
			G.sphere(skin,"CheekFairing",Vector3(0.29,0.16,0.75),Vector3(side*0.90,y,-4.18),materials.top)
		# Waist window panels follow the narrowing shell; no floating bubbles.
		var z: float=2.11 if side<0 else 2.60
		var shell: Array=G.sample(BODY,z)
		var window: MeshInstance3D=G.box(skin,"WaistGlazing",Vector3(0.025,0.65,0.71),Vector3(side*(shell[2]-0.025),0.25,z),materials.glass)
		window.rotation.z=-side*0.13
		for dz: float in [-0.37,0.37]:G.rod(skin,"WaistFrame",Vector3(side*shell[2],-0.07,z+dz),Vector3(side*(shell[2]-0.06),0.59,z+dz),0.023,materials.frame)
		# Omit optional fuselage paint rather than permit curved-surface clipping.

func _build_wings() -> void:
	for side: float in [-1.0,1.0]:
		var id: String="left" if side<0 else "right"
		var host: Node3D=damage_modules[id+"_wing"];var skin: Node3D=fixed(host)
		G.part(skin,"WingLeading",G.wing(WING,side,0.65,10.2997,0,0.73,Vector3.ZERO,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		for row: Array in [["flap_inner",0.88,2.45],["flap_outer",3.84,5.90],["aileron",5.90,10.2997]]:
			var pivot: Vector3=G.wing_point(WING,row[1],0.73,true);pivot.x*=side
			var axis: Node3D=G.group(host,row[0].to_pascal_case(),pivot)
			G.part(axis,"Surface",G.wing(WING,side,row[1],row[2],0.73,1,pivot,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
			surfaces[row[0]+"_"+id]=axis
			mark(axis,(row[0]+"_"+id+"_HINGE").to_upper(),Vector3.ZERO,"photo-estimated finite +X control hinge; no aerodynamic authority")
		# Nacelle interrupts flap, but a fixed strip closes the wing behind its host.
		G.part(skin,"NacelleTrailingWing",G.wing(WING,side,2.45,3.84,0.73,1,Vector3.ZERO,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		G.part(skin,"RootTrailingWing",G.wing(WING,side,0.65,0.88,0.73,1,Vector3.ZERO,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		mark(host,"DAMAGE_WING_"+id.to_upper()+"_CUT",Vector3(side*0.65,0.14,-0.6),"whole wing carries its engine, propeller and main landing gear")
		if side<0:_wing_insignia(skin,side,true)
		else:_wing_insignia(skin,side,false)

func _build_tail() -> void:
	var host: Node3D=damage_modules.tail;var skin: Node3D=fixed(host,"Empennage")
	for side: float in [-1.0,1.0]:
		var id: String="left" if side<0 else "right"
		G.part(skin,"Stabilizer",G.wing(H_TAIL,side,0,4.03,0,0.70,Vector3.ZERO,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		var pivot: Vector3=G.wing_point(H_TAIL,0.5,0.70,true);pivot.x*=side
		var elevator: Node3D=G.group(host,"Elevator"+id.to_pascal_case(),pivot)
		G.part(elevator,"Skin",G.wing(H_TAIL,side,0.5,4.03,0.70,1,pivot,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		surfaces["elevator_"+id]=elevator
		mark(elevator,"ELEVATOR_"+id.to_upper()+"_HINGE",Vector3.ZERO,"photo-estimated +X finite hinge")
		var fin: Node3D=G.group(skin,"Fin"+id.to_pascal_case(),Vector3(side*3.82,0,0))
		var outline: PackedVector2Array=PackedVector2Array([Vector2(-0.42,5.94),Vector2(-0.59,6.15),Vector2(-0.64,7.44),Vector2(2.70,7.44),Vector2(2.81,7.08),Vector2(2.81,6.67),Vector2(2.66,6.31),Vector2(2.35,6.08),Vector2(0.05,5.82)])
		G.plate(fin,"FinSkin",outline,0.11,materials.top)
		var rudder_pivot: Vector3=Vector3(side*3.82,0.45,7.44)
		var rudder: Node3D=G.group(host,"Rudder"+id.to_pascal_case(),rudder_pivot)
		var rudder_shape: PackedVector2Array=PackedVector2Array([Vector2(-0.64,7.44),Vector2(-0.59,7.66),Vector2(-0.40,7.82),Vector2(2.45,7.82),Vector2(2.63,7.65),Vector2(2.70,7.44)])
		G.plate(rudder,"RudderSkin",rudder_shape,0.10,materials.top,Vector3(0,0.45,7.44))
		surfaces["rudder_"+id]=rudder
		mark(rudder,"RUDDER_"+id.to_upper()+"_HINGE",Vector3.ZERO,"photo-estimated local +Y hinge; no common centre fin")

func _cockpit_point(z: float,index: int) -> Vector3:
	var s: Array=G.sample(COCKPIT,z)
	match index:
		0:return Vector3(-s[2],s[4],z)
		1:return Vector3(-s[2]*0.72,s[3]-0.05,z)
		2:return Vector3(0,s[3],z)
		3:return Vector3(s[2]*0.72,s[3]-0.05,z)
	return Vector3(s[2],s[4],z)

func _build_glazing() -> void:
	var skin: Node3D=fixed(damage_modules.center,"Glazing")
	G.part(skin,"GlazedBombardierNose",G.loft(NOSE,-8.150225,-5.65,Color.WHITE,Color.WHITE,Vector4.ZERO,false),materials.glass)
	# Painted lower keel remains continuous with the belly, glass itself is opaque stylization.
	var keel: SurfaceTool=SurfaceTool.new();keel.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(NOSE.size()-1):
		for i: int in range(10):
			var a: float=lerpf(PI*0.70,PI*1.30,i/10.0);var b: float=lerpf(PI*0.70,PI*1.30,(i+1)/10.0)
			G.quad(keel,G.shell_point(NOSE,NOSE[j][0],a)*Vector3(1.004,1.004,1),G.shell_point(NOSE,NOSE[j+1][0],a)*Vector3(1.004,1.004,1),G.shell_point(NOSE,NOSE[j+1][0],b)*Vector3(1.004,1.004,1),G.shell_point(NOSE,NOSE[j][0],b)*Vector3(1.004,1.004,1),Vector3.DOWN)
	G.part(skin,"NoseLowerKeel",G.finish(keel),materials.bottom)
	for z: float in [-7.84,-7.37,-6.65,-5.68]:G.arch(skin,"NoseCrossFrame",NOSE,z,0.033,materials.frame)
	for a: float in [0,PI*0.34,PI*0.66,PI*1.34,PI*1.66]:
		for j: int in range(NOSE.size()-1):G.rod(skin,"NoseFrame",G.shell_point(NOSE,NOSE[j][0],a),G.shell_point(NOSE,NOSE[j+1][0],a),0.016,materials.frame)
	var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(COCKPIT.size()-1):
		for i: int in range(4):G.quad(st,_cockpit_point(COCKPIT[j][0],i),_cockpit_point(COCKPIT[j+1][0],i),_cockpit_point(COCKPIT[j+1][0],i+1),_cockpit_point(COCKPIT[j][0],i+1),Vector3(0,1,0))
	G.part(skin,"SteppedCockpit",G.finish(st),materials.glass)
	for z: float in [-5.04,-4.41,-3.57]:
		for i: int in range(4):G.rod(skin,"CockpitFrame",_cockpit_point(z,i),_cockpit_point(z,i+1),0.024,materials.frame)
	for i: int in [0,1,2,3,4]:
		for j: int in range(COCKPIT.size()-1):G.rod(skin,"CockpitLongFrame",_cockpit_point(COCKPIT[j][0],i),_cockpit_point(COCKPIT[j+1][0],i),0.021,materials.frame)
	var tail: Node3D=fixed(damage_modules.tail,"TailGlass")
	G.part(tail,"TailGunnerHood",G.loft(TAIL_HOOD,6.65,8.11,Color.WHITE,Color.WHITE,Vector4.ZERO,false),materials.glass)
	for z: float in [7.07,7.55,7.99]:G.arch(tail,"TailHoodFrame",TAIL_HOOD,z,0.03,materials.frame,PI*1.5,PI*2.5)
	for side: float in [-1,1]:G.rod(tail,"TailHoodRail",Vector3(side*0.25,0.51,6.70),Vector3(side*0.28,0.45,8.04),0.022,materials.frame)

func _build_engines() -> void:
	for id: String in ["left","right"]:
		var engine: Node3D=damage_modules["engine_"+id];var skin: Node3D=fixed(engine)
		G.part(skin,"Nacelle",G.loft(NACELLE,-1.56,5.24,materials.top.albedo_color,materials.bottom.albedo_color),materials.skin)
		G.sphere(skin,"DarkCowlFace",Vector3(0.68,0.68,0.03),Vector3(0,0,-1.58),materials.dark)
		G.box(skin,"CarburetorIntake",Vector3(0.38,0.17,0.65),Vector3(0,0.77,-0.69),materials.top)
		G.box(skin,"IntakeMouth",Vector3(0.26,0.085,0.018),Vector3(0,0.78,-1.02),materials.dark)
		
		var prop: Node3D=G.group(engine,"Propeller",Vector3(0,0,-1.64));propellers[id]=prop
		G.sphere(prop,"Hub",Vector3(0.17,0.17,0.27),Vector3(0,0,-0.04),materials.steel)
		for i: int in range(3):
			var blade: Node3D=G.group(prop,"Blade%d"%i);blade.rotation.z=TAU*i/3.0
			var shape: PackedVector2Array=PackedVector2Array([Vector2(0.13,-0.07),Vector2(0.65,-0.15),Vector2(1.47,-0.19),Vector2(1.82,-0.13),Vector2(1.91,-0.035),Vector2(1.86,0.08),Vector2(1.48,0.14),Vector2(0.62,0.12),Vector2(0.13,0.05)])
			var panel: MeshInstance3D=G.plate(blade,"BladeSkin",shape,0.036,materials.dark);panel.rotation.y=PI*0.5
			var tip: MeshInstance3D=G.plate(blade,"PaintedTip",PackedVector2Array([Vector2(1.75,-0.15),Vector2(1.82,-0.13),Vector2(1.91,-0.035),Vector2(1.86,0.08),Vector2(1.75,0.10)]),0.039,materials.yellow);tip.rotation.y=PI*0.5
		mark(prop,"PROP_CENTER_"+id.to_upper(),Vector3.ZERO,"full swept radius photo estimate 1.91m")
		mark(engine,"ENGINE_"+id.to_upper()+"_SMOKE",Vector3(0,0.35,0.2),"simulation requested smoke only")
		mark(engine,"ENGINE_"+id.to_upper()+"_CUT",Vector3.ZERO,"engine subhost inherits entire corresponding wing")

func _wheel(host: Node3D,id: String,at: Vector3,radius: float,width: float) -> void:
	var mesh: CylinderMesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=width;mesh.radial_segments=48
	var node: MeshInstance3D=G.part(host,id,mesh,materials.tyre,at);node.rotation.z=PI*0.5
	var hub: CylinderMesh=CylinderMesh.new();hub.top_radius=radius*0.48;hub.bottom_radius=radius*0.48;hub.height=width+0.018;hub.radial_segments=20
	node=G.part(host,id+"Hub",hub,materials.steel,at);node.rotation.z=PI*0.5

func _build_gear() -> void:
	for id: String in ["left","right","nose"]:
		var is_nose: bool=id=="nose";var side: float=-1 if id=="left" else 1
		var host: Node3D=damage_modules.center if is_nose else damage_modules["engine_"+id]
		var body_center: Vector3=NOSE_WHEEL_CENTER_M if is_nose else MAIN_WHEEL_CENTER_M*Vector3(side,1,1)
		var pivot: Vector3=Vector3(0,-0.66,-5.90) if is_nose else Vector3(0,-0.43,2.35)
		var center: Vector3=body_center-(Vector3.ZERO if is_nose else host.position)-pivot
		var axis: Node3D=G.group(host,"Gear"+id.to_pascal_case(),pivot);gear_axes[id]=axis
		G.rod(axis,"Oleo",Vector3.ZERO,center+Vector3(0,0.12,0),0.055 if is_nose else 0.07,materials.steel)
		G.rod(axis,"SimpleBrace",Vector3(0,0,0.52),center*0.5,0.032,materials.steel)
		G.rod(axis,"Fork",center+Vector3(0.15,0.25,0),center+Vector3(0.15,0,0),0.04,materials.steel)
		G.rod(axis,"Axle",center-Vector3(0.16,0,0),center+Vector3(0.16,0,0),0.055,materials.steel)
		var radius: float=NOSE_WHEEL_RADIUS_M if is_nose else MAIN_WHEEL_RADIUS_M
		_wheel(axis,"Tyre",center,radius,0.20 if is_nose else 0.31)
		mark(axis,"WHEEL_"+id.to_upper(),center,"photo-estimated actual wheel cylinder center; circle radius below").set_meta("radius_m",radius)
		mark(axis,"GEAR_"+id.to_upper()+"_HINGE",Vector3.ZERO,"simplified finite aft retraction +X; not precise multi-link mechanics")
		var cover: Node3D=G.group(host,"FlushGearCover"+id);gear_covers.append(cover)
		if is_nose:G.box(cover,"Cover",Vector3(0.39,0.04,1.23),Vector3(0,-0.98,-5.58),materials.bottom)
		else:
			# Keep the nacelle continuous; no detailed well/door sequencing in this model.
			# Actual strut support intersects the nacelle shell. Retracted gear hides inside it.
			pass

func _build_bay() -> void:
	var host: Node3D=damage_modules.center;var skin: Node3D=fixed(host,"BayFixed")
	G.box(skin,"Ceiling",Vector3(1.24,0.05,2.75),Vector3(0,0.41,-1.27),materials.dark)
	for side: float in [-1,1]:
		G.box(skin,"Wall",Vector3(0.05,1.07,2.75),Vector3(side*0.63,-0.25,-1.27),materials.dark)
		G.box(skin,"LadderRack",Vector3(0.06,1.03,0.09),Vector3(side*0.60,-0.24,-1.30),materials.steel)
		var id: String="left" if side<0 else "right"
		var hinge: Vector3=G.shell_point(BODY,-1.27,CUT.w if side<0 else CUT.z)
		var door: Node3D=G.group(host,"BayDoor"+id.to_pascal_case(),hinge);bay_doors[id]=door
		var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j: int in range(18):
			for i: int in range(8):
				var z: float=lerpf(BAY_START_M,BAY_END_M,j/18.0);var z1: float=lerpf(BAY_START_M,BAY_END_M,(j+1)/18.0)
				var a: float=lerpf(PI,CUT.w,i/8.0) if side<0 else lerpf(CUT.z,PI,i/8.0)
				var b: float=lerpf(PI,CUT.w,(i+1)/8.0) if side<0 else lerpf(CUT.z,PI,(i+1)/8.0)
				G.quad(st,G.shell_point(BODY,z,a)-hinge,G.shell_point(BODY,z1,a)-hinge,G.shell_point(BODY,z1,b)-hinge,G.shell_point(BODY,z,b)-hinge,Vector3.DOWN)
		var mat: StandardMaterial3D=materials.bottom.duplicate();mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		G.part(door,"DoorSkin",G.finish(st),mat)
		mark(door,"BAY_DOOR_"+id.to_upper()+"_HINGE",Vector3.ZERO,"outer longitudinal +Z hinge; simplified outward/down 0-85deg")
	for z: float in [BAY_START_M+0.04,BAY_END_M-0.04]:G.box(skin,"EndBulkhead",Vector3(1.25,1.04,0.06),Vector3(0,-0.24,z),materials.dark)
	# Two vertical ladder racks, three 500-lb stores each. Coordinates are conservative fit estimates.
	# Lower tier indices first; BOMB must clear lower stores before dropping higher tiers.
	for tier: int in range(3):
		for side_index: int in range(2):
			var index: int=tier*2+side_index;var side: float=-1 if side_index==0 else 1
			var at: Vector3=Vector3(side*0.36,-0.77+tier*0.47,-1.26)
			var bomb: Node3D=G.group(host,"AN_M64_%02d"%index,at);bomb_visuals.append(bomb)
			var profile: Array=[[-0.7513,0,0.008,0.008,0.008],[-0.67,0,0.09,0.09,0.09],[-0.50,0,0.178,0.178,0.178],[0.30,0,0.178,0.178,0.178],[0.48,0,0.085,0.085,0.085],[0.62,0,0.04,0.04,0.04]]
			G.part(bomb,"Body",G.loft(profile,-0.7513,0.62,Color.WHITE,Color.WHITE),materials.bomb)
			G.box(bomb,"VerticalFin",Vector3(0.015,0.40,0.39),Vector3(0,0,0.5563),materials.bomb)
			G.box(bomb,"HorizontalFin",Vector3(0.40,0.015,0.39),Vector3(0,0,0.5563),materials.bomb)
			G.rod(skin,"RackArm",Vector3(side*0.60,at.y+0.05,at.z),Vector3(side*0.48,at.y+0.05,at.z),0.022,materials.steel)
			mark(bomb,"BOMB_%02d_RELEASE"%index,Vector3.ZERO,"actual displayed store centre; nominal 500lb AN-M64-class; BOMB owns inventory")
			mark(bomb,"BOMB_%02d_NOSE"%index,Vector3(0,0,-0.7513),"actual nose; -Z forward, fins aft")
			mark(host,"BOMB_%02d_RACK"%index,at+Vector3(side*0.18,0.05,0),"approximate side suspension to ladder rack; not top-hung extra deck")

func _build_guns() -> void:
	for id: String in GUN_SPECS:
		var spec: Dictionary=GUN_SPECS[id]
		var host: Node3D=damage_modules.tail if id=="tail" else damage_modules.center
		var base: Node3D=G.group(host,"Gun"+id.to_pascal_case(),spec.at);base.basis=Basis.looking_at(spec.forward.normalized(),Vector3.UP)
		var yaw: Node3D=G.group(base,"Yaw");var elevation: Node3D=G.group(yaw,"Elevation")
		if id=="dorsal":
			G.rod(base,"TurretBearing",Vector3(0,-0.37,0),Vector3(0,-0.24,0),0.51,materials.frame)
			G.sphere(yaw,"DorsalDome",Vector3(0.52,0.45,0.52),Vector3(0,-0.08,0),materials.glass)
			G.rod(yaw,"DomeTopFrame",Vector3(-0.36,0.20,0),Vector3(0.36,0.20,0),0.022,materials.frame)
		elif id.begins_with("cheek_"):
			G.rod(base,"FixedMount",Vector3(-0.09 if "right" in id else 0.09,0,0.20),Vector3(0,0,0.07),0.06,materials.frame)
		elif id.begins_with("waist_"):G.rod(base,"WindowBearing",Vector3(0,-0.27,0.06),Vector3.ZERO,0.048,materials.steel)
		elif id=="nose_flexible":G.sphere(base,"NoseBallBearing",Vector3(0.13,0.13,0.12),Vector3.ZERO,materials.frame)
		elif id=="tail":G.sphere(base,"TailCanvasBoot",Vector3(0.27,0.20,0.22),Vector3(0,0,0.04),materials.frame)
		else:G.rod(base,"FixedNoseSupport",Vector3(0,-0.16,0.15),Vector3.ZERO,0.035,materials.steel)
		var muzzles: Array[Marker3D]=[]
		for i: int in range(spec.barrels):
			var dx: float=(i-(spec.barrels-1)*0.5)*0.22
			G.box(elevation,"Receiver",Vector3(0.12,0.13,0.29),Vector3(dx,0,0.08),materials.dark)
			G.rod(elevation,"Barrel",Vector3(dx,0,-0.05),Vector3(dx,0,-spec.length),0.021,materials.dark)
			muzzles.append(mark(elevation,"MUZZLE_"+id.to_upper()+"_%d"%i,Vector3(dx,0,-spec.length),"real moving .50 muzzle; conservative view limit is not historical firing clearance"))
		mark(base,"GUN_"+id.to_upper()+"_PIVOT",Vector3.ZERO,"photo-estimated local +Y yaw / +X elevation; fixed mounts have zero travel")
		guns[id]={"base":base,"yaw":yaw,"elevation":elevation,"muzzles":muzzles,"limits_deg":spec.limits,"barrels":spec.barrels,"weapon":"AN_M2_50_aircraft"}

func _insignia(host: Node3D,at: Vector3,normal: Vector3,radius: float) -> Node3D:
	# Original geometry paint only: USAAF star/bar. No copied image texture.
	var node: Node3D=G.group(host,"StarAndBar",at);node.basis=Basis.looking_at(normal,Vector3.FORWARD if absf(normal.y)>0.9 else Vector3.UP)
	var disc: CylinderMesh=CylinderMesh.new();disc.top_radius=radius;disc.bottom_radius=radius;disc.height=0.009;disc.radial_segments=32
	var mesh: MeshInstance3D=G.part(node,"BlueDisc",disc,materials.blue);mesh.rotation.x=PI*0.5
	G.box(node,"BlueBar",Vector3(radius*3.7,radius*0.57,0.01),Vector3.ZERO,materials.blue)
	G.box(node,"WhiteBar",Vector3(radius*3.45,radius*0.39,0.012),Vector3(0,0,-0.009),materials.white)
	var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(10):
		var a: float=PI*0.5+TAU*i/10.0;var b: float=PI*0.5+TAU*(i+1)/10.0
		var r0: float=radius*(0.94 if i%2==0 else 0.37);var r1: float=radius*(0.94 if (i+1)%2==0 else 0.37)
		G.triangle(st,Vector3(0,0,-0.020),Vector3(cos(a)*r0,sin(a)*r0,-0.020),Vector3(cos(b)*r1,sin(b)*r1,-0.020),Vector3.FORWARD)
	G.part(node,"WhiteStar",G.finish(st),materials.white)
	return node

func _wing_insignia(host: Node3D,side: float,upper: bool) -> void:
	var at: Vector3=G.wing_point(WING,7.72,0.44,upper);at.x*=side
	var paint: Node3D=_insignia(host,at,Vector3.UP if upper else Vector3.DOWN,0.62)
	paint.basis=Basis(Vector3(-1 if upper else 1,0,0),Vector3.FORWARD,Vector3(0,-1 if upper else 1,0))
	_conform_paint(paint,true,side,upper)

func _conform_paint(paint: Node3D,wing: bool,side: float,upper: bool) -> void:
	for node: MeshInstance3D in G.meshes(paint,false):
		var xf: Transform3D=paint.transform*node.transform
		var st: SurfaceTool=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface: int in range(node.mesh.get_surface_count()):
			var data: Array=node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for i: int in range(indices.size() if not indices.is_empty() else verts.size()):
				var v: Vector3=xf*verts[indices[i] if not indices.is_empty() else i]
				var layer: float=maxf(0.0,-(node.transform*verts[indices[i] if not indices.is_empty() else i]).z)
				if wing:
					var row: Array=G.sample(WING,absf(v.x));v.y=G.wing_point(WING,absf(v.x),(v.z-row[1])/row[2],upper).y+(0.006+layer)*(1 if upper else -1)
				else:
					var row: Array=G.sample(BODY,v.z);var height: float=row[3] if v.y>=row[1] else row[4]
					v.x=side*(row[2]*sqrt(maxf(0,1.0-pow((v.y-row[1])/height,2)))+0.006+layer)
				st.add_vertex(xf.affine_inverse()*v)
		st.generate_normals();node.mesh=st.commit()

func _number(snapshot: Dictionary,key: String,fallback: float,low: float,high: float) -> float:
	var v: Variant=snapshot.get(key,fallback)
	return clampf(float(v),low,high) if (v is int or v is float) and is_finite(float(v)) else fallback

func apply_visual_state(snapshot: Dictionary) -> void:
	for key: String in ["gear","flap","bay_door"]:state[key]=_number(snapshot,key,float(state[key]),0,1)
	for id: String in ["left","right"]:
		var key: String="propeller_"+id+"_rad";state[key]=_number(snapshot,key,float(state[key]),-1e8,1e8);propellers[id].rotation.z=fposmod(state[key],TAU)
		gear_axes[id].rotation.x=deg_to_rad(-88)*(1.0-state.gear);gear_axes[id].visible=state.gear>0.001
		bay_doors[id].rotation.z=deg_to_rad(-85 if id=="left" else 85)*state.bay_door
		for kind: String in ["flap_inner","flap_outer"]:surfaces[kind+"_"+id].rotation.x=deg_to_rad(35)*state.flap
	gear_axes.nose.rotation.x=deg_to_rad(-95)*(1.0-state.gear);gear_axes.nose.visible=state.gear>0.001
	for node: Node3D in gear_covers:node.visible=state.gear<0.035
	if snapshot.get("payload_mode",state.payload_mode) in ["bombs_6x500","empty"]:state.payload_mode=snapshot.get("payload_mode",state.payload_mode)
	var mask: Variant=snapshot.get("bomb_visible",null)
	for i: int in range(bomb_visuals.size()):
		if mask is Array and i<mask.size() and mask[i] is bool:bomb_visuals[i].set_meta("inventory_visible",mask[i])
		bomb_visuals[i].visible=state.payload_mode=="bombs_6x500" and bool(bomb_visuals[i].get_meta("inventory_visible",true))
	for key: String in ["aileron_left","aileron_right","elevator_left","elevator_right","rudder_left","rudder_right"]:
		var angle: float=_number(snapshot,key+"_rad",float(state.get(key+"_rad",0.0)),-0.35,0.35);state[key+"_rad"]=angle
		if key.begins_with("rudder"):surfaces[key].rotation.y=angle
		else:surfaces[key].rotation.x=angle
	var aims: Dictionary=snapshot.get("guns",{}) if snapshot.get("guns",{}) is Dictionary else {}
	for id: String in guns:
		var old: Dictionary=state.get("gun_"+id,{"yaw_rad":0.0,"elevation_rad":deg_to_rad(12 if id=="dorsal" else 0)})
		var aim: Dictionary=aims.get(id,{}) if aims.get(id,{}) is Dictionary else {}
		var lim: Vector4=guns[id].limits_deg
		var yaw: float=_number(aim,"yaw_rad",old.yaw_rad,deg_to_rad(lim.x),deg_to_rad(lim.y))
		var elevation: float=_number(aim,"elevation_rad",old.elevation_rad,deg_to_rad(lim.z),deg_to_rad(lim.w))
		state["gun_"+id]={"yaw_rad":yaw,"elevation_rad":elevation};guns[id].yaw.rotation.y=yaw;guns[id].elevation.rotation.x=elevation

func apply_damage_state(attached: Dictionary) -> void:
	for id: String in damage_modules:
		if attached.get(id,null) is bool:damage_modules[id].visible=attached[id]

func set_flight_configuration() -> void:apply_visual_state({"gear":0.0,"flap":0.0})
func set_landing_gear_deployed(deployed: bool) -> void:apply_visual_state({"gear":1.0 if deployed else 0.0})

func get_parked_transform() -> Transform3D:
	# Solve wheel-circle centres/radii; main wheels are symmetric. No scale/gear stretching.
	var dy: float=NOSE_WHEEL_CENTER_M.y-MAIN_WHEEL_CENTER_M.y
	var dz: float=NOSE_WHEEL_CENTER_M.z-MAIN_WHEEL_CENTER_M.z
	var pitch: float=asin((NOSE_WHEEL_RADIUS_M-MAIN_WHEEL_RADIUS_M)/Vector2(dy,dz).length())-atan2(dy,-dz)
	var basis: Basis=Basis(Vector3.RIGHT,pitch)
	return Transform3D(basis,Vector3(0,MAIN_WHEEL_RADIUS_M-(basis*MAIN_WHEEL_CENTER_M).y,0))
