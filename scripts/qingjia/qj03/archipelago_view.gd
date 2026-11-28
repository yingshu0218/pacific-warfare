extends "res://scripts/presentation/maps/island_harbor_view.gd"
const GROUND := preload("res://scripts/qingjia/qj03/island_ground.gdshader")
const LABEL_FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const SHORE := preload("res://scripts/qingjia/qj03/reef_shore.gdshader")
var green_count: int = 0

func build(chart: Dictionary) -> void:
	super.build(chart)
	var land_material := ShaderMaterial.new()
	land_material.shader = GROUND
	$IslandTerrain.material_override = land_material
	_build_harbor_details()
	_build_airfield_details()
	_build_civil_and_shrine_details()
	_build_coastal_exhibits()
	statistics["tree_count"] = green_count

func _ground_color(_p: Vector3) -> Color:
	# QJ03 colors its same-source terrain in a spatial shader.
	return Color.WHITE

func _build_shore() -> void:
	_surface=SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for island: Dictionary in terrain.islands:
		var points: Array = island.outline
		for i: int in points.size():
			var p: Vector3 = points[i] + Vector3.UP*.12
			var q: Vector3 = points[(i+1)%points.size()] + Vector3.UP*.12
			var before: Vector3 = points[posmod(i-1,points.size())]
			var after: Vector3 = points[(i+2)%points.size()]
			var s: Vector3 = (q-before).normalized()
			var t: Vector3 = (after-p).normalized()
			var start: Vector3 = Vector3(s.z,0,-s.x)
			var end: Vector3 = Vector3(t.z,0,-t.x)
			if TerrainQueries.land_data(terrain,(p+q)*.5+start*5.0):
				start=-start
				end=-end
			var u: Vector3 = p+start*(36+15*sin(p.x*.007+p.z*.008)+10*sin(p.z*.014))
			var v: Vector3 = q+end*(36+15*sin(q.x*.007+q.z*.008)+10*sin(q.z*.014))
			for row: Array in [[p,1.],[q,1.],[v,0.],[p,1.],[v,0.],[u,0.]]:
				_surface.set_color(Color(1.,1.,1.,row[1]))
				_surface.add_vertex(row[0])
			_triangles += 2
	_surface.generate_normals()
	shore_material = ShaderMaterial.new()
	shore_material.shader = SHORE
	_add_mesh(_surface.commit(),shore_material,"ReefAndFoam")
	$ReefAndFoam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _surface_start() -> void:
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func _surface_finish(label: String, cast: bool) -> void:
	_surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .8
	_add_mesh(_surface.commit(),material,label)
	if not cast:
		get_node(label).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_vegetation(material: Material) -> void:
	_surface_start()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7223
	for x: int in range(-1760,2520,33):
		for z: int in range(-1910,1800,33):
			var p := Vector3(x + rng.randf_range(-9,9),0,z + rng.randf_range(-9,9))
			var coverage := sin(p.x*.011+p.z*.007)*.46+sin(p.z*.019+p.x*.008)*.36+cos(p.x*.033-p.z*.02)*.18
			if coverage < -.31 or rng.randf() > lerpf(.17,.99,smoothstep(-.33,.56,coverage)):
				continue
			p.y = TerrainQueries.height_data(terrain,p)
			if p.y < 14 or p.y > 257:
				continue
			var blocked := false
			for pad: Dictionary in terrain.source.pads:
				var pivot := SimData.vec3(pad.position_m)
				if Vector2(p.x-pivot.x,p.z-pivot.z).length() < float(pad.radius_m)+17.0:
					blocked = true
					break
			if blocked or _near_road(p):
				continue
			var size := rng.randf_range(4.1,10.2)
			var tint := Color("355b38").lerp(Color("627748"),rng.randf())
			_tree(p,size,tint,rng.randf())
			green_count += 1
	for p: Vector2 in [Vector2(510,565),Vector2(507,572),Vector2(521,552),Vector2(753,609),Vector2(759,614),
	Vector2(860,552),Vector2(869,554),Vector2(867,562),Vector2(650,716),Vector2(673,711),Vector2(681,718),
	Vector2(691,756),Vector2(802,748),Vector2(810,750),Vector2(887,733),Vector2(892,741),Vector2(907,731),
	Vector2(570,264),Vector2(605,241),Vector2(602,250),Vector2(578,246),Vector2(609,262)]:
		var local := Vector3(p.x,TerrainQueries.height_data(terrain,Vector3(p.x,0,p.y)),p.y)
		_tree(local,8.7+2.8*rng.randf(),Color("70834e").lerp(Color("496b46"),rng.randf()),rng.randf())
		green_count += 1
	_surface_finish("IslandTreeGroves",false)

func _near_road(p: Vector3) -> bool:
	for road: Dictionary in terrain.source.roads:
		for i: int in road.points_m.size()-1:
			var a := SimData.vec3(road.points_m[i])
			var b := SimData.vec3(road.points_m[i+1])
			if Vector3(p.x,0,p.z).distance_to(Geometry3D.get_closest_point_to_segment(Vector3(p.x,0,p.z),a,b)) < 15.0:
				return true
	return false

func _tree(p: Vector3, size: float, tint: Color, phase: float) -> void:
	_box(p+Vector3.UP*size*.23,Vector3(.37,size*.48,.37),Color("645442"))
	for i: int in 5:
		var a := TAU*i/5.0+phase
		var b := TAU*(i+1)/5.0+phase
		var side1 := Vector3(cos(a),0,sin(a))
		var side2 := Vector3(cos(b),0,sin(b))
		var flare := (.29+sin(i*2.0+phase)*.043)*size
		var r1 := p+Vector3.UP*.52*size+side1*flare
		var r2 := p+Vector3.UP*.49*size+side2*flare
		var lower := p+Vector3.UP*.21*size
		var tip := p+Vector3(.05,.96,-.08)*size
		_tri(r1,r2,tip,tint.lightened(.1*sin(i*2.1)))
		_tri(r1,lower,r2,tint.darkened(.22))

func _build_airfield_details() -> void:
	_surface_start()
	var pavement := Color("777971")
	var dusty := Color("887e64")
	var paint := Color("e5ddbe")
	var glyph := Color("d9c8a0")
	for key: String in ["runway","apron","taxi"]:
		var row: Dictionary = terrain.source.features[key]
		var p := SimData.vec3(row.position_m)
		var s := SimData.vec3(row.size_m)
		_box(p+Vector3.UP*.07,s,pavement if key=="runway" else Color("99998a"))
		if key == "runway":
			for sg: float in [-1.,1.]:
				_box(p+Vector3(0,.035,sg*(s.z*.5+5.3)),Vector3(s.x,.14,11),dusty)
				_box(p+Vector3(0,.28,sg*(s.z*.5-2.1)),Vector3(s.x-15,.03,.46),paint)
				for offset: float in [-14.,-10.,-6.,6.,10.,14.]:
					_box(p+Vector3(sg*(s.x*.5-22.),.28,offset),Vector3(19,.03,2.2),paint)
				for l: float in [0.,6.,12.]:
					_box(p+Vector3(sg*(s.x*.5-57.+l),.28,-7.5),Vector3(2.3,.035,10.0),glyph)
			for x: int in range(-535,536,43):
				_box(p+Vector3(x,.28,0),Vector3(21,.03,.95),paint)
		if key == "apron":
			for x: int in range(-77,100,31):
				_box(p+Vector3(x,.28,5.0),Vector3(.36,.025,34),glyph)
	for i: int in 22:
		var c := Vector3(112.+float(i%6)*4.4,16.9,415.+float((i/6)%2)*5.0)
		if i >= 12: c.y += 1.6
		_crate(c,3.55, Color("968361").lightened(float(i%4)*.06))
	for x: float in [212.,282.]:
		var y := TerrainQueries.height_data(terrain,Vector3(x,0,392))
		_box(Vector3(x,y+3.6,406.22),Vector3(22.,7.2,.45),Color("5a6a63"))
		for rib: float in [-9.,-6.,-3.,0.,3.,6.,9.]:
			_box(Vector3(x+rib,y+3.6,406.50),Vector3(.16,7.2,.11),Color("889384"))
		_box(Vector3(x,y+6.6,406.55),Vector3(22.,.3,.06),Color("9aa396"))
	var pylon := Vector3(147,16,423)
	_box(pylon+Vector3.UP*5,Vector3(.6,10.,.6),Color("687267"))
	_box(pylon+Vector3(1.45,9.6,0),Vector3(2.8,.85,.87),Color("c17b52"))
	_surface_finish("AirfieldRoadMarkingsAndDetails",false)

func _road(road: Dictionary) -> void:
	var points: Array[Vector3] = []
	for row: Array in road.points_m:
		points.append(SimData.vec3(row))
	var color := Color("938771").lerp(Color("667267"), .34)
	if road.id == "shrine_approach":
		color = Color("a39a7d")
	for i: int in points.size()-1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var inward := (b-a).cross(Vector3.UP).normalized() * float(road.width_m)*.5
		var sections := maxi(1,ceili(a.distance_to(b)/2.5))
		for j: int in sections:
			var p := a.lerp(b,float(j)/sections)
			var q := a.lerp(b,float(j+1)/sections)
			var quad: Array[Vector3] = [p-inward,p+inward,q+inward,q-inward]
			for corner: int in quad.size():
				quad[corner].y = TerrainQueries.height_data(terrain,quad[corner])+.29
			_quad(quad[0],quad[1],quad[2],quad[3],color)
	for p: Vector3 in points:
		var radius := float(road.width_m)*.48
		var around: Vector3 = p
		around.y = TerrainQueries.height_data(terrain,p)+.30
		for j: int in 8:
			var a := p+Vector3(cos(j*TAU/8.0),0,sin(j*TAU/8.0))*radius
			var b := p+Vector3(cos((j+1)*TAU/8.0),0,sin((j+1)*TAU/8.0))*radius
			a.y = TerrainQueries.height_data(terrain,a)+.29
			b.y = TerrainQueries.height_data(terrain,b)+.29
			_tri(around,b,a,color)

func _build_harbor_details() -> void:
	_surface_start()
	var wood := Color("5a493c")
	var rust := Color("986e4b")
	var tire := Color("333936")
	for z: int in range(106,207,10):
		_box(Vector3(1173,2.9,z),Vector3(2.1,5.5,1.8),tire)
		_box(Vector3(1170.2,7,z),Vector3(1.2,1.75,1.4),rust)
	for x: int in range(1175,1295,11):
		for sign_z: float in [-1.,1.]:
			_box(Vector3(x,4.7,146+sign_z*15),Vector3(1.5,5,1.4),wood)
			_box(Vector3(x,5.55,146+sign_z*12),Vector3(1.16,.7,1.22),rust)
	for x: int in range(1154,1201,4):
		_box(Vector3(x,.86,203),Vector3(.20,.06,7.8),wood.darkened(.21))
	var crane := Vector3(1174,6.3,154)
	for dz: float in [-5.,5.]:
		_box(crane+Vector3(0,8.0,dz),Vector3(1.5,16,1.7),Color("9d8456"))
	_box(crane+Vector3(14,16,0),Vector3(34.5,2.4,2.0),Color("b19a65"))
	_box(crane+Vector3(25,10.5,0),Vector3(.24,10,.23),tire)
	for id: int in 16:
		var cargo := Vector3(1124+id%5*5.9,7.0+float(id/10)*1.8,175+float((id/5)%2)*8.0)
		_crate(cargo,4.8,Color("918661").lerp(Color("be9f70"),float(id%5)*.2))
	# Lighter segmented cap with an unbroken land tie identifies the berthing pier.
	_box(Vector3(1272,6.14,82),Vector3(228,.28,31),Color("c5bba3"))
	_box(Vector3(1160,6.13,109),Vector3(29,.26,47),Color("b9b29b"))
	_box(Vector3(1228,5.25,146),Vector3(139,.16,29),Color("a89c7d"))
	_box(Vector3(1272,5.34,66.65),Vector3(228,1.10,.78),Color("a7a38f"))
	_box(Vector3(1272,5.34,97.34),Vector3(228,1.10,.78),Color("b8b19d"))
	for x: int in range(1164,1384,11):
		_box(Vector3(x,6.318,82),Vector3(.21,.07,29.6),Color("b3a88d"))
		_box(Vector3(x,6.33,88.8),Vector3(4.2,.072,.34),Color("9c885d"))
	for x: int in range(1190,1384,17):
		_box(Vector3(x,6.66,95.5),Vector3(.92,1.35,.93),Color("647069"))
	_small_boat(Vector3(1308,.16,103),55.0,8.9,Color("697771"))
	_small_boat(Vector3(1203,.18,190),11.0,3.4,Color("c7b49d"))
	_small_boat(Vector3(1199,.18,219),9.0,2.7,Color("637b73"))
	_small_boat(Vector3(1249,.18,173),21.5,5.7,Color("77766a"))
	_surface_finish("HarborShoresideDetails",true)

func _small_boat(center: Vector3,length: float,beam: float,tint: Color) -> void:
	var stern := center + Vector3(0,0,length*.52)
	var bow := center - Vector3(0,0,length*.52)
	var deck := center + Vector3.UP*(beam*.18)
	var left := deck+Vector3(-beam*.48,0,0)
	var right := deck+Vector3(beam*.48,0,0)
	_tri(bow,left,deck,tint); _tri(bow,deck,right,tint)
	_tri(stern,deck,left,tint); _tri(stern,right,deck,tint)
	_tri(bow,center+Vector3(0,-.4,.0),left,tint.darkened(.36))
	_tri(bow,right,center+Vector3(0,-.4,.0),tint.darkened(.36))
	_tri(stern,left,center+Vector3(0,-.4,.0),tint.darkened(.36))
	_tri(stern,center+Vector3(0,-.4,.0),right,tint.darkened(.36))
	_box(deck+Vector3(0,beam*.23,length*.12),Vector3(beam*.68,beam*.47,length*.30),Color("b6b9a9"))
	_box(deck+Vector3(0,beam*.28,-length*.027),Vector3(beam*.6,beam*.16,.07),Color("394748"))

func _crate(p: Vector3, width: float, wood: Color) -> void:
	_box(p,Vector3(width,1.7,width*.65),wood)
	for x: float in [-width*.31,width*.31]:
		_box(p+Vector3(x,0,width*.326),Vector3(.24,1.72,.04),wood.darkened(.23))
		_box(p+Vector3(x,.868,0),Vector3(.24,.06,width*.66),wood.darkened(.23))

func _object(obj: Dictionary) -> void:
	if not str(obj.id).begins_with("civil_") and obj.id != "shrine":
		super._object(obj)
		return
	var p := SimData.vec3(obj.position_m)
	var s := SimData.vec3(obj.size_m)
	var stucco := Color(str(obj.color))
	var pillar := Color("65574a")
	var roof_palette := [Color("77786f"),Color("7c7265"),Color("777e77"),Color("626e71"),Color("866e60")]
	var roof: Color = roof_palette[posmod(roundi(p.x+p.z*2.),roof_palette.size())]
	var bottom := float(obj.get("foundation_bottom_m",p.y-.45))
	_box(Vector3(p.x,(p.y+bottom)*.5,p.z),Vector3(s.x,p.y-bottom,s.z),Color("8f8a72"))
	_box(p+Vector3.UP*s.y*.5,s,stucco)
	for x: float in [-s.x*.47,s.x*.47]:
		for z: float in [-s.z*.5,s.z*.5]:
			_box(p+Vector3(x,s.y*.5,z),Vector3(.45,s.y,.41),pillar)
	var front_z := s.z*.503
	_box(p+Vector3(0,1.9,front_z),Vector3(s.x*.74,2.58,.16),Color("4b5550"))
	for x: float in [-s.x*.32,-s.x*.12,s.x*.12,s.x*.32]:
		_box(p+Vector3(x,2.25,front_z+.17),Vector3(.22,2.85,.25),pillar)
	if obj.id != "shrine":
		var porch_width := s.x*(.61+.23*sin(p.x*2.)*.5)
		_box(p+Vector3(0,3.27,front_z+1.09),Vector3(porch_width,.18,2.1),Color("a88460").lerp(Color("688180"),.5+cos(p.z*.3)*.5))
		_box(p+Vector3(0,.16,front_z+1.28),Vector3(s.x*.94,.31,2.6),Color("a1997a"))
		for px: float in [-porch_width*.43,porch_width*.43]:
			_box(p+Vector3(px,1.6,front_z+2.02),Vector3(.22,3.2,.24),pillar)
		if posmod(roundi(p.x),3)!=0:
			var wall_x := s.x*.64
			_box(p+Vector3(wall_x,.51,0),Vector3(.16,.96,s.z+1.4),Color("8f8065"))
			for dz: float in [-s.z*.47,0,s.z*.47]:
				_box(p+Vector3(wall_x,.6,dz),Vector3(.34,1.2,.33),pillar)
	else:
		_box(p+Vector3(0,.16,front_z+2.14),Vector3(s.x*1.16,.35,4.2),Color("a4997d"))
		for x: float in [-s.x*.37,s.x*.37]:
			_box(p+Vector3(x,s.y*.41,front_z+1.30),Vector3(.57,s.y*.82,.6),Color("965a43"))
	_roof(p,s,roof,obj.id == "shrine")

func _roof(p: Vector3,s: Vector3,color: Color,shrine: bool) -> void:
	var e := s.x*.56
	var d := s.z*.60
	var h := s.y
	var pitch := 2.8 if shrine else 2.25
	var a := p+Vector3(-e,h,-d)
	var b := p+Vector3(e,h,-d)
	var c := p+Vector3(e,h,d)
	var d2 := p+Vector3(-e,h,d)
	var ridge_a := p+Vector3(-e*.96,h+pitch,0)
	var ridge_b := p+Vector3(e*.96,h+pitch,0)
	_quad(a,ridge_a,ridge_b,b,color);_quad(ridge_a,d2,c,ridge_b,color.darkened(.18))
	_tri(a,d2,ridge_a,color.darkened(.20));_tri(b,ridge_b,c,color.darkened(.20))
	_box(p+Vector3(0,h+pitch,0),Vector3(e*2.,.45,.38),color.darkened(.28))
	for side: float in [-1.,1.]:
		for i: int in 6:
			var f := (float(i)+.02)/6.0
			var y := h+pitch*(1.-f)
			_box(p+Vector3(0,y+.075,d*f*side),Vector3(e*(1.91+.07*f),.11,.13),color.lightened(.06))
		_box(p+Vector3(0,h,d*side),Vector3(e*2.02,.29,.19),color.darkened(.32))

func _build_civil_and_shrine_details() -> void:
	_surface_start()
	var stone := Color("a49c82")
	var red := Color("ab6147")
	var dark := Color("5d5147")
	var x := 590.0
	for i: int in 37:
		var z := 229.0+float(i)*1.04
		var p := Vector3(x,0,z)
		var level := TerrainQueries.height_data(terrain,p)
		var prev := TerrainQueries.height_data(terrain,p-Vector3.BACK*.57)
		var next := TerrainQueries.height_data(terrain,p+Vector3.BACK*.57)
		var floor_y := maxf(level,maxf(prev,next))+.18
		var riser := floor_y-minf(prev,next)+.29
		_box(Vector3(x,floor_y-riser*.5,z),Vector3(4.8,riser,1.10),stone.darkened(float(i%4)*.035))
		for sg: float in [-1.,1.]:
			_box(Vector3(x+sg*2.46,floor_y+.12,z),Vector3(.20,.33,1.10),stone.darkened(.18))
	for z: float in [249.,265.]:
		var p := Vector3(x,TerrainQueries.height_data(terrain,Vector3(x,0,z)),z)
		for side: float in [-1.,1.]:
			_box(p+Vector3(side*2.1,2.4,0),Vector3(.52,4.8,.54),red)
			_box(p+Vector3(side*2.1,.40,0),Vector3(.74,.8,.77),stone)
		_box(p+Vector3(0,3.62,0),Vector3(5.5,.37,.56),red.darkened(.17))
		_box(p+Vector3(0,4.72,0),Vector3(6.2,.39,.69),red)
		_box(p+Vector3(0,5.05,0),Vector3(6.54,.28,.77),dark)
		_box(p+Vector3(0,4.15,0),Vector3(.55,.77,.14),Color("c2a678"))
	for z: float in [234.,242.,257.]:
		var y := TerrainQueries.height_data(terrain,Vector3(x,0,z))
		for side: float in [-1.,1.]:
			var p := Vector3(x+side*3.42,y,z)
			_box(p+Vector3.UP*.76,Vector3(.44,1.52,.46),stone.darkened(.20))
			_box(p+Vector3.UP*1.55,Vector3(.78,.39,.82),stone)
			_box(p+Vector3.UP*1.8,Vector3(.33,.33,.34),stone.darkened(.12))
	var landing := Vector3(856,0,858)
	for i: int in 21:
		_box(landing+Vector3(0,1.4,i*1.9),Vector3(6,.31,1.86),Color("8b7460").darkened(float(i%4)*.04))
		if i%5==0:
			for side: float in [-1.,1.]:
				_box(landing+Vector3(side*2.74,.25,i*1.9),Vector3(.56,3.4,.56),dark)
	_small_boat(Vector3(862,.18,887),9,2.3,Color("af926d"))
	_civic_details()
	_surface_finish("TownShrineAndFishingLanding",true)

func _civic_details() -> void:
	var plaster := Color("d9cfb7")
	var iron := Color("4c615a")
	var signage := Color("839481")
	for obj: Dictionary in terrain.source.objects:
		if str(obj.id).begins_with("hospital"):
			var p := SimData.vec3(obj.position_m)
			var s := SimData.vec3(obj.size_m)
			var wall_z := s.z*.503
			for fy: float in [3.2,6.9]:
				if fy + 1. >= s.y: continue
				for fx: float in [-s.x*.36,-s.x*.21,s.x*.21,s.x*.36]:
					_box(p+Vector3(fx,fy,wall_z),Vector3(2.6,1.55,.16),iron)
					_box(p+Vector3(fx,fy,wall_z+.12),Vector3(.14,1.58,.10),plaster)
			if obj.id == "hospital_main":
				_box(p+Vector3(0,3.38,wall_z+1.7),Vector3(9.9,.32,3.8),signage)
				_box(p+Vector3(0,4.7,wall_z+.12),Vector3(7.1,.94,.19),iron)
				_civic_sign("诊疗所",p+Vector3(0,4.7,wall_z+.24))
				for dx: float in [-3.7,3.7]:
					_box(p+Vector3(dx,1.57,wall_z+2.9),Vector3(.43,3.15,.43),plaster)
			_box(p+Vector3(0,s.y-.31,wall_z+.11),Vector3(s.x,.36,.35),signage)
		elif obj.id == "fire_station":
			var p := SimData.vec3(obj.position_m)
			for x: float in [-8.5,0.,8.5]:
				_box(p+Vector3(x,2.15,13.08),Vector3(6.8,4.3,.23),Color("95533d"))
				for y: float in [1.12,2.18,3.24]:
					_box(p+Vector3(x,y,13.235),Vector3(6.5,.12,.05),Color("bb826a"))
			_box(p+Vector3(-12.1,7.25,-8.0),Vector3(5.8,14.5,5.8),Color("c0a78b"))
			_box(p+Vector3(-12.1,14.68,-8),Vector3(6.3,.45,6.3),Color("865744"))
			_box(p+Vector3(-12.1,12.8,-4.99),Vector3(3.6,1.15,.19),iron)
			_civic_sign("消防所",p+Vector3(0,5.36,13.26))
		elif obj.id == "supply_store":
			var p := SimData.vec3(obj.position_m)
			for x: float in [-10,8]:
				_box(p+Vector3(x,2.55,12.12),Vector3(8.,5.1,.24),Color("746351"))
			_box(p+Vector3(0,5.3,13.26),Vector3(40.,.35,2.52),Color("81785f"))
			_box(p+Vector3(0,7.12,12.2),Vector3(12,1.,.11),Color("635d4f"))
			_civic_sign("民用物资仓",p+Vector3(0,7.14,12.27))
			for i: int in 7:
				var q := p+Vector3(-17+i*3.75,1.05,14.5)
				_crate(q,2.8,Color("ae9867"))


func _civic_sign(label_text: String, p: Vector3) -> void:
	var sign := Label3D.new()
	sign.text = label_text
	sign.font = LABEL_FONT
	sign.font_size = 42
	sign.pixel_size = .030
	sign.outline_size = 3
	sign.modulate = Color("eee1bc")
	sign.outline_modulate = Color("403b32")
	sign.position = p
	add_child(sign)

func _build_coastal_exhibits() -> void:
	var instances := Node3D.new()
	instances.name = "StaticCoastalScenery"
	add_child(instances)
	# Three visual remnants on a single headland, not part of gameplay or sighting.
	var scenery := [
		["res://scenes/qingjia/qj03_props/open_plinth.tscn",Vector3(1423,0,-157),2.0],
		["res://scenes/qingjia/qj03_props/shielded_housing.tscn",Vector3(1460,0,-179),2.14],
		["res://scenes/qingjia/qj03_props/cliff_facade.tscn",Vector3(1443,0,-218),2.26],
	]
	for row: Array in scenery:
		var packed := load(row[0]) as PackedScene
		if packed == null:
			continue
		var placement: Vector3 = row[1]
		placement.y = TerrainQueries.height_data(terrain,placement)
		var model := packed.instantiate() as Node3D
		model.position = placement
		model.rotation.y = row[2]
		instances.add_child(model)
