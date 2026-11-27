extends Node3D

const PROP_MESH: Script = preload("res://assets/scenery/port_support/prop_mesh.gd")
# Visual-only placements on the existing MAP02 chart. No collision or simulation IDs.
# Airport items intentionally sit beside the hangar row, not on a live taxi path.
const LAYOUT: Array[Dictionary] = [
	{"id":"NavalTug","kind":"tug","xz":Vector2(2672,-3894),"yaw":0.0,"water":true},
	{"id":"NavalBarge","kind":"barge","xz":Vector2(2672,-3975),"yaw":0.0,"water":true},
	{"id":"CivilTug","kind":"tug","xz":Vector2(-4158,-2686),"yaw":3.12,"water":true},
	{"id":"CivilBarge","kind":"barge","xz":Vector2(-4157,-2757),"yaw":3.13,"water":true},
	{"id":"ChannelWestInner","kind":"buoy_red","xz":Vector2(3137,-3180),"yaw":0.0,"water":true},
	{"id":"ChannelEastInner","kind":"buoy_green","xz":Vector2(3438,-3180),"yaw":0.0,"water":true},
	{"id":"ChannelWestOuter","kind":"buoy_red","xz":Vector2(3137,-3027),"yaw":0.0,"water":true},
	{"id":"ChannelEastOuter","kind":"buoy_green","xz":Vector2(3438,-3027),"yaw":0.0,"water":true},
	{"id":"ServiceTractor","kind":"tractor","xz":Vector2(6299,-2635),"yaw":-1.4,"water":false},
	{"id":"ServiceLadder","kind":"ladder","xz":Vector2(6295,-2628),"yaw":-.65,"water":false},
	{"id":"ServiceCart","kind":"cart","xz":Vector2(6301,-2627),"yaw":.76,"water":false},
	{"id":"ServiceDrums","kind":"drums","xz":Vector2(6303,-2625),"yaw":.07,"water":false},
	{"id":"ReserveTractor","kind":"tractor","xz":Vector2(6299,-2395),"yaw":1.10,"water":false},
	{"id":"ReserveCart","kind":"cart","xz":Vector2(6298,-2389),"yaw":-.48,"water":false},
	{"id":"ReserveDrums","kind":"drums","xz":Vector2(6302,-2388),"yaw":.0,"water":false},
]

const INSPECTION_POINTS: Array[Dictionary] = [
	{"id":"support_tug","label":"港勤拖船","focus_m":[2672,3.2,-3894],"distance_m":38,"yaw_rad":2.30,"pitch_rad":.32},
	{"id":"support_barge","label":"载货驳船","focus_m":[2672,1.8,-3975],"distance_m":52,"yaw_rad":.80,"pitch_rad":.37},
	{"id":"support_buoys","label":"航道浮标","focus_m":[3137,1.6,-3180],"distance_m":13,"yaw_rad":.82,"pitch_rad":.32},
	{"id":"support_service","label":"机库旁地勤维修组","focus_m":[6299,9.0,-2630],"distance_m":18,"yaw_rad":-.78,"pitch_rad":.34}
]

func build(chart: Dictionary) -> void:
	assert(get_child_count() == 0)
	var builder: RefCounted = PROP_MESH.new()
	for entry: Dictionary in LAYOUT:
		var part := MeshInstance3D.new()
		part.name = entry.id
		part.mesh = builder.mesh_for(entry.kind)
		part.rotation.y = entry.yaw
		var center: Vector3 = Vector3(entry.xz.x,0,entry.xz.y)
		center.y = float(chart.get("sea_level_m",0.0)) if entry.water else _ground(chart,center,part)
		part.position = center
		part.set_meta("kind",entry.kind)
		# Tiny static props do not each create a second shadow draw call. The
		# big workboats retain shadows; this does not change navigation.
		if entry.kind not in ["tug","barge"]:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)

func _ground(chart: Dictionary, center: Vector3, model: MeshInstance3D) -> float:
	var box: AABB = model.mesh.get_aabb()
	var height: float = TerrainQueries.height_data(chart,center,false)
	for corner: int in 8:
		var local: Vector3 = box.get_endpoint(corner)
		local.y = 0.0
		height = maxf(height,TerrainQueries.height_data(chart,center + model.basis*local,false))
	# Only a tiny buffer against contact shimmer. Strict visual tests verify
	# these placements stay on the flat yard and do not visibly float on a slope.
	return height + .016
