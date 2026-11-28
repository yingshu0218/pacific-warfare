extends "res://scripts/map02/expanded_map_view.gd"

const TAKAO := preload("res://scenes/ships/takao_1944/takao_visual.tscn")
const PARKED_PLANE := preload("res://aircraft/a6m2_21/a6m2_21.tscn")
const AGANO := preload("res://scenes/ships/agano_1942/agano_visual.tscn")
const DOCKED: Array[Dictionary] = [
	{"scene": TAKAO, "label": "MooredCruiserOuter", "position": Vector3(2660,.05,-3975), "length": 205.5},
	{"scene": AGANO, "label": "MooredCruiserInner", "position": Vector3(3837,.06,-4060), "length": 174.5},
]
var docked_models: Array[Node3D] = []
var _color_cache: Dictionary = {}

func build(data: Dictionary) -> void:
	# Preserve the original port and civilian geometry adapters: they dispatch on
	# MAP02's source ID. Only present that alias while they build. Their routes and
	# buildings are unchanged; simulation continues to use the new chart's ID.
	var rendering := data.duplicate(false)
	rendering.source = data.source.duplicate(false)
	rendering.source.id = "island_harbor_expanded"
	super.build(rendering)
	_color_cache.clear()
	terrain = data
	var fleet := Node3D.new()
	fleet.name = "PortAtmosphere"
	add_child(fleet)
	for row: Dictionary in DOCKED:
		var model := (row.scene as PackedScene).instantiate() as Node3D
		model.name = row.label
		fleet.add_child(model)
		model.position = row.position
		docked_models.append(model)
	statistics["moored_scenery_ships"] = docked_models.size()
	_add_airfield_detail()
	_add_civilian_detail()
	_add_landscape_detail()

func _ground_color(p: Vector3) -> Color:
	if _color_cache.has(p):
		return _color_cache[p]
	var color := super._ground_color(p)
	if p.x < 600 or p.x > 5860 or p.z < -4325 or p.z > 260:
		_color_cache[p] = color
		return color
	var step := 27.0
	var lateral := (TerrainQueries.height_data(terrain, p + Vector3(step, 0, 0)) - TerrainQueries.height_data(terrain, p - Vector3(step, 0, 0))) / (2.0 * step)
	var longitudinal := (TerrainQueries.height_data(terrain, p + Vector3(0, 0, step)) - TerrainQueries.height_data(terrain, p - Vector3(0, 0, step))) / (2.0 * step)
	var slope := Vector2(lateral, longitudinal).length()
	var striation := sin(p.y*.115 + sin(p.z*.014 + p.x*.005))*0.10 + sin(p.y*.037 + p.x*.016)*0.12
	var granite := Color("687c76").lerp(Color("a2a392"), clampf(.44 + striation, 0.0, 1.0))
	var foliage := Color("465d4c").lerp(Color("71805d"), clampf(.50 + sin(p.x*.037)*.12 + cos(p.z*.019)*.19, 0.0, 1.0))
	var mountain := foliage.lerp(granite, smoothstep(.24, .65, slope + smoothstep(480.0, 670.0, p.y)*.22))
	var result := color.lerp(mountain, smoothstep(12.0, 60.0, p.y))
	_color_cache[p] = result
	return result

func _add_airfield_detail() -> void:
	# Render dirt and grass shoulders immediately off the existing, unchanged runway.
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [6861.5, 6938.5]:
		for z: int in range(-3090, -1710, 24):
			var a := Vector3(x-9.0, 8.028, z)
			var b := a + Vector3(18,0,0)
			var c := b + Vector3(0,0,24)
			var d := a + Vector3(0,0,24)
			var color := Color("928975").lerp(Color("a29676"), .5+.42*sin(float(z)*.022+x))
			_quad(a,b,c,d,color)
	_surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .98
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(_surface.commit(), material, "RunwayShoulders")
	var shoulders := get_node("RunwayShoulders") as MeshInstance3D
	shoulders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _add_civilian_detail() -> void:
	# Anonymous street-dressing silhouettes only. No unit registration, labels,
	# objectives, collision, hit logic, or individual simulation.
	const PALETTE: Array[Color] = [Color("8f806c"), Color("646e61"), Color("a28b74"), Color("757880"), Color("965d47")]
	var spots: Array[Vector2] = [Vector2(2112,-4937),Vector2(2132,-4935),Vector2(2162,-4930),Vector2(2173,-4936),Vector2(2201,-4923),Vector2(2224,-4918),Vector2(2228,-4895),Vector2(2242,-4907),Vector2(2249,-4913),Vector2(2276,-4923),Vector2(2317,-4918),Vector2(2314,-4851),Vector2(2331,-4795),Vector2(2376,-4924),Vector2(2150,-5159)]
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in spots.size():
		var spot := spots[i]
		var pos := Vector3(spot.x, 0, spot.y)
		pos.y = TerrainQueries.height_data(terrain, pos) + .25
		var tint := PALETTE[i%PALETTE.size()]
		var shift := -.17 if i%2 == 0 else .17
		_box(pos+Vector3(-.14,.44,shift),Vector3(.18,.88,.26),tint.darkened(.35))
		_box(pos+Vector3(.14,.43,-shift),Vector3(.18,.86,.26),tint.darkened(.35))
		_box(pos+Vector3(0,1.10,0),Vector3(.47,.63,.34),tint)
		_box(pos+Vector3(-.28,1.09,shift*.5),Vector3(.12,.56,.16),tint.darkened(.06))
		_box(pos+Vector3(.28,1.08,-shift*.5),Vector3(.12,.56,.16),tint.darkened(.06))
		_box(pos+Vector3(0,1.56,.015),Vector3(.23,.27,.22),Color("b19276"))
		_box(pos+Vector3(0,1.69,0),Vector3(.30,.085,.28),Color("544f44").lerp(tint,.3))
	_surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .94
	_add_mesh(_surface.commit(), material, "CivilianStreetDressing")
	statistics["civilian_silhouettes"] = spots.size()

func _add_landscape_detail() -> void:
	var airplane_display := Node3D.new()
	airplane_display.name = "ParkedDisplayAircraft"
	add_child(airplane_display)
	for i: int in 3:
		var aircraft := PARKED_PLANE.instantiate() as Node3D
		airplane_display.add_child(aircraft)
		aircraft.position = Vector3(6400 + i*18,9.6,-2510 + i*29)
		aircraft.rotation.y = PI*.46
	# Distant tree silhouettes are drawn as a single, deterministic geometry batch.
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: int in range(6000,7460,63):
		for z: int in range(-3160,-1480,61):
			if x > 6210 and x < 7070:
				continue
			var p := Vector3(x+22*sin(z*.18+x*.14),0,z+22*cos(z*.13+x*.16))
			p.y = TerrainQueries.height_data(terrain,p)
			if p.y < 2.5 or sin(p.x*.021+p.z*.034)<-.42:
				continue
			_palm(p, 4.4 + sin(p.x*.07)*1.7, p.x*.14)
	for i: int in 22:
		var p := Vector3(2040+i*43 + 12*cos(i*.6),0,-4755+33*cos(i*.62))
		var h := TerrainQueries.height_data(terrain,p,true)
		if h < 5.0 or h > 75.0:
			continue
		p.y = h
		_palm(p, 4.3 + .9*cos(i*.4), i*.49)
	_surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .94
	_add_mesh(_surface.commit(), material, "CoastalPalmGroves")

func _palm(base: Vector3, height: float, turn: float) -> void:
	var bend := Vector3(cos(turn),0,sin(turn))*.42
	var top := base + Vector3.UP*height + bend
	var mid := base.lerp(top,.55)
	var wood := Color("756b57")
	_box(base.lerp(mid,.5), Vector3(.23,mid.y-base.y,.22), wood)
	_box(mid.lerp(top,.5), Vector3(.21,top.y-mid.y,.22), wood.lightened(.12))
	for i: int in 7:
		var phase := float(i)*TAU/7.0 + turn
		var offset := Vector3(cos(phase),0,sin(phase))*(1.82 + .24*sin(phase+turn))
		var side := Vector3(-offset.z,0,offset.x)*.22
		var spine := top + offset*.49 + Vector3.UP*.37
		var end := top + offset - Vector3.UP*.38
		var leaf := Color("506d54").lerp(Color("718058"), .5 + .4*cos(phase))
		_tri(top,spine+side,spine,leaf)
		_tri(top,spine,spine-side,leaf)
		_tri(spine+side,end,spine,leaf)
		_tri(spine,end,spine-side,leaf)
