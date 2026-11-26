extends Node3D

const TYPE94_TURRET_HOUSING: PackedScene = preload("res://assets/naval/weapons/jp_type94_46cm_triple/turret_housing.tscn")
const TYPE3_155MM_TURRET_HOUSING: PackedScene = preload("res://assets/naval/weapons/jp_type3_155mm_triple/turret_housing.tscn")

var weapons: Array[Dictionary] = []
var static_clearance: Array[Dictionary] = []
var weapon_profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_profiles.json"))
var deck_sheer_stations: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/hull_stations.json")).deck_sheer_stations_m
var hull_stations: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/hull_stations.json")).stations
var _hull_longitudinal_stations: Array[float] = []
var steel: StandardMaterial3D = material(Color("596169"))
var deck: StandardMaterial3D = material(Color("9a8765"))
var module_roots: Dictionary = {}
var canvas_cover: StandardMaterial3D = material(Color("777d7b"))
var dark: StandardMaterial3D = material(Color("222a30"))

func material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.78
	return result

func mesh_part(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.material_override = mat
	add_child(part)
	return part

func box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh_part(mesh, pos, mat)

func cylinder(pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.rings = 0
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh_part(mesh, pos, mat)

func rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var part: MeshInstance3D = cylinder((a+b)/2, radius, a.distance_to(b), mat)
	part.quaternion = Quaternion(Vector3.UP, (b-a).normalized())

func tapered_rod(a: Vector3, b: Vector3, base_radius: float, tip_radius: float) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.rings = 0
	mesh.bottom_radius = base_radius
	mesh.top_radius = tip_radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	var part: MeshInstance3D = mesh_part(mesh,(a+b)/2,steel)
	part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func hull_width(z: float) -> float:
	var stations: Array[Vector2] = []
	for station: Array in hull_stations: stations.append(Vector2(station[0],station[1]))
	for i: int in range(stations.size()-1):
		if z <= stations[i+1].x:
			var t: float = inverse_lerp(stations[i].x,stations[i+1].x,z)
			var previous: float = stations[maxi(0,i-1)].y
			var following: float = stations[mini(stations.size()-1,i+2)].y
			var a: float = stations[i].y
			var b: float = stations[i+1].y
			return clampf(0.5*((2*a)+(-previous+b)*t+(2*previous-5*a+4*b-following)*t*t+(-previous+3*a-3*b+following)*t*t*t),0.12,19.45)
	return float(hull_stations.back()[1])

func deck_half_width(z: float) -> float:
	# The digitized plan is the weather-deck envelope (38.9m maximum), not the waterline.
	return hull_width(z)

func deck_height(z: float) -> float:
	var points: Array = deck_sheer_stations
	if z <= float(points.front()[0]): return float(points.front()[1])
	for index: int in range(points.size() - 1):
		var first: Array = points[index]
		var second: Array = points[index + 1]
		if z <= float(second[0]):
			# Shape-preserving cubic Hermite: retain every source ordinate and the
			# fore-deck trough, without the old jumps in slope or spline overshoot.
			var span: float = float(second[0])-float(first[0])
			var t: float = (z-float(first[0]))/span
			var t2: float = t*t
			var t3: float = t2*t
			return (2*t3-3*t2+1)*float(first[1])+(t3-2*t2+t)*span*_sheer_tangent(index) \
				+(-2*t3+3*t2)*float(second[1])+(t3-t2)*span*_sheer_tangent(index+1)
	return float(points.back()[1])

func _sheer_secant(index: int) -> float:
	var a: Array = deck_sheer_stations[index]
	var b: Array = deck_sheer_stations[index+1]
	return (float(b[1])-float(a[1]))/(float(b[0])-float(a[0]))

func _sheer_tangent(index: int) -> float:
	var last: int = deck_sheer_stations.size()-1
	if index > 0 and index < last:
		var before: float = _sheer_secant(index-1)
		var after: float = _sheer_secant(index)
		if before*after <= 0.0: return 0.0
		var before_span: float = float(deck_sheer_stations[index][0])-float(deck_sheer_stations[index-1][0])
		var after_span: float = float(deck_sheer_stations[index+1][0])-float(deck_sheer_stations[index][0])
		var w1: float = 2*after_span+before_span
		var w2: float = after_span+2*before_span
		return (w1+w2)/(w1/before+w2/after)
	var edge: int = 0 if index == 0 else last-1
	var neighbor: int = 1 if index == 0 else last-2
	var edge_span: float = float(deck_sheer_stations[edge+1][0])-float(deck_sheer_stations[edge][0])
	var neighbor_span: float = float(deck_sheer_stations[neighbor+1][0])-float(deck_sheer_stations[neighbor][0])
	var edge_slope: float = _sheer_secant(edge)
	var neighbor_slope: float = _sheer_secant(neighbor)
	var tangent: float = ((2*edge_span+neighbor_span)*edge_slope-edge_span*neighbor_slope)/(edge_span+neighbor_span)
	if tangent*edge_slope <= 0.0: return 0.0
	if edge_slope*neighbor_slope <= 0.0 and absf(tangent) > absf(3*edge_slope): return 3*edge_slope
	return tangent

func hull_longitudinal_stations() -> Array[float]:
	if not _hull_longitudinal_stations.is_empty(): return _hull_longitudinal_stations
	# Include each measured/proportioned ordinate and the midship draft datum.
	# Two-metre maximum spans resolve the rounded fore/aft shoulders in geometry.
	for index: int in range(deck_sheer_stations.size()-1):
		var start: float = float(deck_sheer_stations[index][0])
		var end: float = float(deck_sheer_stations[index+1][0])
		var count: int = ceili((end-start)/2.0)
		for step: int in range(count):
			_append_hull_span(lerpf(start,end,float(step)/float(count)),lerpf(start,end,float(step+1)/float(count)))
	_hull_longitudinal_stations.append(float(deck_sheer_stations.back()[0]))
	if not _hull_longitudinal_stations.has(0.0): _hull_longitudinal_stations.append(0.0)
	_hull_longitudinal_stations.sort()
	return _hull_longitudinal_stations

func _append_hull_span(start: float, end: float) -> void:
	var chord_error: float = 0.0
	for t: float in [0.25,0.5,0.75]:
		chord_error = maxf(chord_error,absf(deck_height(lerpf(start,end,t))-lerpf(deck_height(start),deck_height(end),t)))
	if chord_error > 0.004:
		_append_hull_span(start,(start+end)*0.5)
		_append_hull_span((start+end)*0.5,end)
	else:
		_hull_longitudinal_stations.append(start)

func deck_surface_height(z: float) -> float:
	# Mount contacts use the actual tessellated deck, not an unrelated cached Y.
	var stations: Array[float] = hull_longitudinal_stations()
	for index: int in range(stations.size()-1):
		if z <= stations[index+1]:
			var t: float = clampf(inverse_lerp(stations[index],stations[index+1],z),0,1)
			return lerpf(deck_height(stations[index]),deck_height(stations[index+1]),t)
	return deck_height(stations.back())

func hull() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck_surface: SurfaceTool = SurfaceTool.new()
	deck_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector3] = []
	var longitudinal: Array[float] = hull_longitudinal_stations()
	for z: float in longitudinal:
		var t: float = absf(z / 131.5)
		var width: float = hull_width(z)
		var sheer: float = deck_height(z)
		var end_taper: float = 0.15 if z < 0 else 0.55
		var section_depth: float = (sheer+10.4)*(1.0-end_taper*pow(t,8))
		var levels: Array[Vector2] = [Vector2(0,1.0),Vector2(0.374,1.0),Vector2(0.4526,18.45/19.45),Vector2(0.6105,1.0),Vector2(0.7684,0.98),Vector2(0.9,0.85),Vector2(1.0,0.55)]
		var profile: Array[Vector3] = []
		for level: Vector2 in levels: profile.append(Vector3(width*level.y,sheer-level.x*section_depth,z))
		profile.append(Vector3(0,sheer-section_depth,z))
		for index: int in range(levels.size()-1,-1,-1):
			var level: Vector2 = levels[index]
			profile.append(Vector3(-width*level.y,sheer-level.x*section_depth,z))
		for j: int in range(33):
			var parameter: float = j*(profile.size()-1)/32.0
			var index: int = mini(int(parameter),profile.size()-2)
			var point: Vector3 = profile[index].lerp(profile[index+1],parameter-index)
			point.z += -signf(z)*4.5*((sheer-point.y)/section_depth)*pow(t,8)
			rings.append(point)
	for i: int in range(longitudinal.size()-1):
		for j: int in range(32):
			var a: int = i*33+j
			for index: int in [a,a+1,a+33,a+1,a+34,a+33]: surface.add_vertex(rings[index])
		var a: Vector3 = rings[i*33]
		var b: Vector3 = rings[i*33+32]
		var c: Vector3 = rings[(i+1)*33]
		var d: Vector3 = rings[(i+1)*33+32]
		for vertex: Vector3 in [a,c,b,b,c,d]: deck_surface.add_vertex(vertex)
	# Close transom and stem; the earlier open rings exposed the interior below water.
	for ring_index: int in [0,longitudinal.size()-1]:
		# Keep the fan inside the actual raked end ring, not on the old vertical stem.
		var center: Vector3 = Vector3.ZERO
		for j: int in range(33): center += rings[ring_index*33+j]/33.0
		for j: int in range(32):
			var a: Vector3 = rings[ring_index*33+j]
			var b: Vector3 = rings[ring_index*33+j+1]
			var vertices: Array[Vector3] = [center,b,a]
			if ring_index != 0: vertices.reverse()
			for vertex: Vector3 in vertices: surface.add_vertex(vertex)
		var top_closure: Array[Vector3] = [center,rings[ring_index*33],rings[ring_index*33+32]]
		if ring_index != 0: top_closure.reverse()
		for vertex: Vector3 in top_closure: surface.add_vertex(vertex)
	surface.generate_normals()
	var hull_material: ShaderMaterial = ShaderMaterial.new()
	hull_material.shader = preload("res://assets/naval/hulls/yamato_simple_hull.gdshader")
	var hull_part: MeshInstance3D = mesh_part(surface.commit(), Vector3.ZERO, hull_material)
	hull_part.name = "HullShell"
	deck_surface.generate_normals()
	var deck_material: StandardMaterial3D = deck.duplicate() as StandardMaterial3D
	deck_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var deck_part: MeshInstance3D = mesh_part(deck_surface.commit(),Vector3.ZERO,deck_material)
	deck_part.name = "WeatherDeck"

func outward_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var normal: Vector3 = (c-a).cross(b-a).normalized()
	var reverse: bool = normal.dot((a+b+c)/3-center) < 0
	if reverse: normal = -normal
	for vertex: Vector3 in ([a,c,b] if reverse else [a,b,c]):
		surface.set_normal(normal)
		surface.add_vertex(vertex)

func bridge_section(half_width: float, front_z: float, rear_z: float, y: float) -> Array[Vector3]:
	var chamfer: float = minf(half_width*0.28,(rear_z-front_z)*0.18)
	return [Vector3(-half_width+chamfer,y,front_z),Vector3(half_width-chamfer,y,front_z),Vector3(half_width,y,front_z+chamfer),Vector3(half_width,y,rear_z-chamfer),Vector3(half_width-chamfer,y,rear_z),Vector3(-half_width+chamfer,y,rear_z),Vector3(-half_width,y,rear_z-chamfer),Vector3(-half_width,y,front_z+chamfer)]

func section_loft(sections: Array[Array], center: Vector3) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level: int in range(sections.size()-1):
		for index: int in range(sections[level].size()):
			var next: int = (index+1)%sections[level].size()
			outward_triangle(surface,sections[level][index],sections[level][next],sections[level+1][index],center)
			outward_triangle(surface,sections[level][next],sections[level+1][next],sections[level+1][index],center)
	for level: int in [0,sections.size()-1]:
		for index: int in range(1,sections[level].size()-1):
			outward_triangle(surface,sections[level][0],sections[level][index],sections[level][index+1],center)
	return mesh_part(surface.commit(),Vector3.ZERO,steel)

func rounded_bridge_section(half_width: float, front_z: float, rear_z: float, y: float, front_ratio: float = 0.82) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var center_z: float = (front_z+rear_z)/2.0
	var radius_z: float = (rear_z-front_z)/2.0
	for index: int in range(24):
		var angle: float = TAU*float(index)/24.0
		var longitudinal: float = sin(angle)
		var width_ratio: float = lerpf(front_ratio,1.0,(longitudinal+1.0)*0.5)
		result.append(Vector3(cos(angle)*half_width*width_ratio,y,center_z+longitudinal*radius_z))
	return result

func bridge_platform(y: float, width: float, depth: float, height: float, z: float) -> void:
	var sections: Array[Array] = [rounded_bridge_section(width/2,z-depth/2,z+depth/2,y-height/2,0.94),rounded_bridge_section(width/2,z-depth/2,z+depth/2,y+height/2,0.94)]
	section_loft(sections,Vector3(0,y,z))

func bridge_side_rail(x: float, top_y: float, front_z: float, rear_z: float, z_offset: float) -> void:
	var gaps: Array[Vector2] = []
	for entry: Dictionary in weapons:
		var mount: WeaponMount = entry.pivot
		if not mount.has_meta("platform_radius"): continue
		if absf(float(mount.get_meta("platform_floor_y"))-(top_y-1.1)) > 0.65: continue
		var profile: Dictionary = weapon_profiles[str(mount.get_meta("profile"))]
		var barrel_reach: float = float(profile.get("forward_barrel_length",0))
		# Leave the full mount/barrel sweep clear, plus working room before the rail resumes.
		var clearance_radius: float = float(mount.get_meta("platform_radius"))+barrel_reach+0.8
		var x_distance: float = absf(mount.global_position.x-x)
		if x_distance >= clearance_radius: continue
		var local_z: float = mount.global_position.z-z_offset
		var half_gap: float = sqrt(clearance_radius*clearance_radius-x_distance*x_distance)
		var gap_start: float = maxf(front_z,local_z-half_gap)
		var gap_end: float = minf(rear_z,local_z+half_gap)
		if gap_end > gap_start: gaps.append(Vector2(gap_start,gap_end))
	gaps.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x < b.x)
	var cursor: float = front_z
	for gap: Vector2 in gaps:
		if gap.y <= cursor: continue
		if gap.x > cursor: rod(Vector3(x,top_y,cursor),Vector3(x,top_y,gap.x),0.025,steel)
		cursor = maxf(cursor,gap.y)
	if cursor < rear_z: rod(Vector3(x,top_y,cursor),Vector3(x,top_y,rear_z),0.025,steel)

func bridge_core() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bridge_geometry.json"))
	var sections: Array[Array] = []
	for section: Dictionary in data.sections:
		var outline: Array[Vector3] = rounded_bridge_section(float(section.half_width),float(section.front_z),float(section.rear_z),float(section.y),0.82)
		sections.append(outline)
	var part: MeshInstance3D = section_loft(sections,Vector3(0,24,-15))
	part.name = "BridgeCore"
	bridge_core_window_bands(data)

func bridge_core_window_bands(data: Dictionary) -> void:
	var sections: Array = data.sections
	for row_y: float in data.get("window_rows_y",[]):
		var upper_index: int = 1
		while upper_index < sections.size()-1 and row_y > float(sections[upper_index].y):
			upper_index += 1
		var lower: Dictionary = sections[upper_index-1]
		var upper: Dictionary = sections[upper_index]
		var fraction: float = clampf(inverse_lerp(float(lower.y),float(upper.y),row_y),0,1)
		var half_width: float = lerpf(float(lower.half_width),float(upper.half_width),fraction)
		var front_z: float = lerpf(float(lower.front_z),float(upper.front_z),fraction)
		var rear_z: float = lerpf(float(lower.rear_z),float(upper.rear_z),fraction)
		var center_z: float = (front_z+rear_z)/2.0
		var radius_z: float = (rear_z-front_z)/2.0
		for index: int in range(9):
			var angle: float = PI + float(index+1)*PI/10.0
			var width: float = half_width*lerpf(0.82,1.0,(sin(angle)+1.0)*0.5)
			var point: Vector3 = Vector3(cos(angle)*width,row_y,center_z+sin(angle)*radius_z)
			var normal: Vector3 = Vector3(cos(angle)/width,0,sin(angle)/radius_z).normalized()
			var pane: MeshInstance3D = box(point+normal*0.035,Vector3(0.52,0.36,0.045),dark)
			pane.rotation.y = atan2(normal.x,normal.z)

func aft_bridge() -> float:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/aft_bridge_geometry.json"))
	var center_z: float = float(data.center_z)
	var sections: Array[Array] = []
	for section: Dictionary in data.sections:
		sections.append(bridge_section(float(section.half_width),float(section.front_z),float(section.rear_z),float(section.y)))
	var core: MeshInstance3D = section_loft(sections,Vector3(0,17,center_z))
	core.name = "AftBridgeCore"
	for platform: Dictionary in data.platforms:
		bridge_platform(float(platform.y),float(platform.width),float(platform.depth),float(platform.thickness),center_z+float(platform.z_offset))
	return float(data.local_z_offset)

func funnel_body() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/funnel_geometry.json"))
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	var bottom_y: float = float(data.bottom_y)
	var top_y: float = float(data.top_ring_y)
	var bottom_center_z: float = float(data.bottom_center_z)
	var top_center_z: float = float(data.top_center_z)
	var normal_tilt: float = float(data.tilt_radians)
	var transition_y: float = float(data.tilt_transition_y)
	var segments: int = 48
	var levels: int = 24
	var center: Vector3 = Vector3(0,(bottom_y+top_y)/2,(bottom_center_z+top_center_z)/2)
	for level: int in range(levels+1):
		var t: float = float(level)/levels
		var y: float = lerpf(bottom_y,top_y,t)
		var center_z: float = lerpf(bottom_center_z,top_center_z,t)
		var radius_x: float = lerpf(float(data.bottom_radius_x),float(data.top_radius_x),t)
		var radius_z: float = lerpf(float(data.bottom_radius_z),float(data.top_radius_z),t)
		var tilt: float = normal_tilt*clampf((y-bottom_y)/(transition_y-bottom_y),0,1)
		var ring: Array[Vector3] = []
		for segment: int in range(segments):
			var angle: float = TAU*segment/segments
			var local_z: float = radius_z*sin(angle)
			ring.append(Vector3(radius_x*cos(angle),y-sin(tilt)*local_z,center_z+cos(tilt)*local_z))
		rings.append(ring)
	for level: int in range(levels):
		for segment: int in range(segments):
			var next: int = (segment+1)%segments
			var a: Vector3 = rings[level][segment]
			var b: Vector3 = rings[level][next]
			var c: Vector3 = rings[level+1][segment]
			var d: Vector3 = rings[level+1][next]
			outward_triangle(surface,a,b,c,center)
			outward_triangle(surface,b,d,c,center)
	var body: MeshInstance3D = mesh_part(surface.commit(),Vector3.ZERO,steel)
	body.name = "FunnelBody"

func clip_panel(polygon: Array[Vector3], axis: Vector3, boundary: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if polygon.is_empty(): return result
	var previous: Vector3 = polygon.back()
	var previous_distance: float = previous.dot(axis)-boundary
	for point: Vector3 in polygon:
		var distance: float = point.dot(axis)-boundary
		if (distance >= 0) != (previous_distance >= 0):
			result.append(previous.lerp(point,previous_distance/(previous_distance-distance)))
		if distance >= 0: result.append(point)
		previous = point
		previous_distance = distance
	return result

func emit_panel(surface: SurfaceTool, polygon: Array[Vector3], center: Vector3) -> void:
	for index: int in range(1,polygon.size()-1):
		if (polygon[index]-polygon[0]).cross(polygon[index+1]-polygon[0]).length_squared() < 0.000000001: continue
		outward_triangle(surface,polygon[0],polygon[index],polygon[index+1],center)

func aa_panel(surface: SurfaceTool, triangle: Array[Vector3], center: Vector3, count: int, spacing: float) -> void:
	# Subtract vertical rectangular port volumes from the actual curved panels.
	emit_panel(surface,clip_panel(triangle,Vector3.DOWN,-0.3),center)
	var upper: Array[Vector3] = clip_panel(triangle,Vector3.UP,0.3)
	emit_panel(surface,clip_panel(upper,Vector3.BACK,-0.1),center)
	var remaining: Array[Vector3] = clip_panel(upper,Vector3.FORWARD,0.1)
	for gun: int in range(count):
		var x: float = (gun-(count-1)*0.5)*spacing
		emit_panel(surface,clip_panel(remaining,Vector3.LEFT,-(x-spacing*0.43)),center)
		remaining = clip_panel(remaining,Vector3.RIGHT,x+spacing*0.43)
	emit_panel(surface,remaining,center)

func aa_shield(pos: Vector3, heavy: bool, gun_count: int, spacing: float, axis_height: float) -> void:
	var width: float = 3.6 if heavy else 2.1
	var depth: float = 4.0 if heavy else 2.4
	var height: float = 2.3 if heavy else 1.65
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector3] = []
	const SEGMENTS: int = 64
	for level: int in range(4):
		var radius: float = [1.0,1.0,0.98,0.72][level]
		var y: float = [0.0,0.3,height*0.66,height][level]
		for segment: int in range(SEGMENTS):
			var angle: float = TAU*segment/SEGMENTS
			rings.append(Vector3(cos(angle)*width*radius/2,y,sin(angle)*depth*radius/2))
	var center: Vector3 = Vector3(0,height/2,0)
	for level: int in range(3):
		for segment: int in range(SEGMENTS):
			var next: int = (segment+1)%SEGMENTS
			var a: Vector3 = rings[level*SEGMENTS+segment]
			var b: Vector3 = rings[level*SEGMENTS+next]
			var c: Vector3 = rings[(level+1)*SEGMENTS+segment]
			var d: Vector3 = rings[(level+1)*SEGMENTS+next]
			aa_panel(surface,[a,b,c],center,gun_count,spacing)
			aa_panel(surface,[b,d,c],center,gun_count,spacing)
	for segment: int in range(SEGMENTS):
		aa_panel(surface,[Vector3(0,height,0),rings[3*SEGMENTS+segment],rings[3*SEGMENTS+(segment+1)%SEGMENTS]],center,gun_count,spacing)
	mesh_part(surface.commit(),pos,steel)
	box(pos+Vector3(0,axis_height,depth*0.2),Vector3((gun_count-1)*spacing+0.5,height*0.8,0.08),dark)

func control_wheel(pos: Vector3, radius: float) -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = radius*0.82
	mesh.outer_radius = radius
	mesh.rings = 8
	mesh.ring_segments = 6
	var wheel: MeshInstance3D = mesh_part(mesh,pos,steel)
	wheel.rotation.z = PI/2
	for spoke: int in range(4):
		var angle: float = spoke*PI/2
		rod(pos,pos+Vector3(0,cos(angle),sin(angle))*radius,0.018,steel)
	rod(pos+Vector3(0,radius,0),pos+Vector3(0.08,radius,0),0.025,dark)

func small_gun_receiver(pos: Vector3, profile: String) -> void:
	if profile == "heavy_aa":
		box(pos+Vector3(0,0,0.35),Vector3(0.32,0.38,1.1),steel)
		box(pos+Vector3(0,0,0.92),Vector3(0.27,0.3,0.12),dark)
		rod(pos+Vector3(0,0.23,-0.9),pos+Vector3(0,0.23,0.55),0.09,steel)
		box(pos+Vector3(0,-0.22,0.35),Vector3(0.4,0.12,1.2),steel)
	else:
		var factor: float = 0.72 if profile == "bridge_mg" else 1.0
		box(pos+Vector3(0,0,0.25)*factor,Vector3(0.12,0.16,0.65)*factor,steel)
		box(pos+Vector3(0,0.015,0.59)*factor,Vector3(0.1,0.12,0.08)*factor,dark)
		var magazine: MeshInstance3D = box(pos+Vector3(0,0.24,0.12)*factor,Vector3(0.075,0.38,0.19)*factor,steel)
		magazine.rotation.x = -0.18
		box(pos+Vector3(0,0.09,0.12)*factor,Vector3(0.15,0.05,0.23)*factor,dark)
		for side: int in [-1,1]:
			rod(pos+Vector3(0,0,0.52)*factor,pos+Vector3(side*0.13,-0.03,0.65)*factor,0.018*factor,steel)
			rod(pos+Vector3(side*0.13,-0.03,0.65)*factor,pos+Vector3(side*0.13,-0.15,0.65)*factor,0.025*factor,dark)

func deck_barbette(pos: Vector3, radius: float) -> void:
	# The real barbette retains a level roller path. Its lower skirt is cut to
	# the deck sheer, rather than leaving a flat cylinder hovering on a slope.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom_center: Vector3 = Vector3(pos.x,deck_surface_height(pos.z),pos.z)
	var center: Vector3 = (bottom_center+pos)*0.5
	for segment: int in range(16):
		var angle: float = TAU*float(segment)/16.0
		var next_angle: float = TAU*float(segment+1)/16.0
		var a: Vector3 = Vector3(pos.x+cos(angle)*radius,0,pos.z+sin(angle)*radius)
		var b: Vector3 = Vector3(pos.x+cos(next_angle)*radius,0,pos.z+sin(next_angle)*radius)
		a.y = deck_surface_height(a.z)
		b.y = deck_surface_height(b.z)
		var c: Vector3 = Vector3(a.x,pos.y,a.z)
		var d: Vector3 = Vector3(b.x,pos.y,b.z)
		outward_triangle(surface,a,b,c,center)
		outward_triangle(surface,b,d,c,center)
		outward_triangle(surface,pos,c,d,center)
		outward_triangle(surface,bottom_center,b,a,center)
	mesh_part(surface.commit(),Vector3.ZERO,steel)

func mount(pos: Vector3, heading: float, small: bool, count: int, secondary: bool = false, shield_variant: String = "enclosed", profile_override: String = "", host_deck_y: float = -1.0, station_id: String = "", follows_hull_deck: bool = false) -> void:
	var weapon: WeaponMount = WeaponMount.new()
	weapon.position = Vector3.ZERO
	weapon.base_heading = heading
	weapon.rotation.y = 0.0
	weapon.phase = float(weapons.size()) * 1.37
	var profile_key: String = ("single_aa" if count == 1 else ("heavy_aa" if count == 2 else "light_aa")) if small else ("secondary" if secondary else "main")
	if not profile_override.is_empty(): profile_key = profile_override
	var profile: Dictionary = weapon_profiles[profile_key]
	weapon.name = profile_key+"_"+str(weapons.size()+1)
	weapon.set_meta("profile",profile_key)
	weapon.set_meta("station_id",station_id)
	weapon.set_meta("barrels",count)
	weapon.set_meta("geometry_scale",float(profile.get("geometry_scale",(0.19 if count == 2 else 0.075) if small else (0.48 if secondary else 1.0))))
	weapon.train_speed = float(profile.train_speed)
	weapon.elevation_speed = float(profile.elevation_speed)
	weapon.train_limits = Vector2(profile.train_min,profile.train_max)
	weapon.elevation_limits = Vector2(profile.elevation_min,profile.elevation_max)
	var foundation_first: int = get_child_count()
	var actual_surface_y: float = host_deck_y if host_deck_y >= 0.0 else deck_height(pos.z)
	var s: float = float(profile.get("geometry_scale",(0.19 if count == 2 else 0.075) if small else (0.48 if secondary else 1.0)))
	var seat_radius: float = float(profile.get("roller_path_external_diameter_m",6.4))/2.0
	if not small:
		var deck_y: float = actual_surface_y
		var support_height: float = maxf(0.02,pos.y-deck_y)
		if follows_hull_deck:
			deck_barbette(pos,seat_radius)
		else:
			cylinder(Vector3(pos.x,deck_y+support_height/2,pos.z),seat_radius,support_height,steel)
	else:
		cylinder(Vector3(pos.x,actual_surface_y+0.045,pos.z),maxf(0.15,8.7*s),0.09,steel)
	var foundation_parts: Array[Node] = get_children().slice(foundation_first)
	var foundation: Node3D = Node3D.new()
	foundation.name = "Foundation_"+(station_id if not station_id.is_empty() else profile_key+"_"+str(weapons.size()+1))
	foundation.position = Vector3(pos.x,actual_surface_y,pos.z)
	foundation.set_meta("station_id",station_id)
	add_child(foundation)
	for piece: Node in foundation_parts: piece.reparent(foundation)
	batch_static_geometry(foundation)
	var weapon_seat: Marker3D = Marker3D.new()
	weapon_seat.name = "weapon_seat"
	weapon_seat.position = Vector3(0.0,pos.y-actual_surface_y,0.0)
	weapon_seat.set_meta("interface",str(profile.get("foundation_interface","roller_path" if not small else "deck_mount")))
	foundation.add_child(weapon_seat)
	var instance_id: String = station_id if not station_id.is_empty() else profile_key+"_"+str(weapons.size()+1)
	var weapon_instance: Node3D = Node3D.new()
	weapon_instance.name = "WeaponInstance_"+instance_id
	weapon_instance.set_meta("station_id",station_id)
	foundation.add_child(weapon_instance)
	weapon_instance.transform = weapon_seat.transform
	weapon.name = "TrainPivot_"+instance_id
	weapon_instance.add_child(weapon)
	weapon.position = Vector3.ZERO
	if not small:
		var housing_scene: PackedScene = TYPE3_155MM_TURRET_HOUSING if profile_key == "secondary" else TYPE94_TURRET_HOUSING
		var housing_module: TurretHousingModule = housing_scene.instantiate() as TurretHousingModule
		housing_module.profile_key = profile_key
		housing_module.geometry_scale = s
		housing_module.name = "HousingAndControls"
		weapon.add_child(housing_module)
		batch_static_geometry(housing_module)
	var first: int = get_child_count()
	if small and shield_variant == "enclosed" and count > 1:
		aa_shield(pos+Vector3(0,0.1,0),profile_key == "heavy_aa",count,float(profile.get("gun_spacing",3.2*s)),float(profile.get("trunnion_height",3*s)))
	elif small:
		box(pos+Vector3(0,0.6,0),Vector3(16,8,10)*s,steel)
	if small and (shield_variant != "enclosed" or count == 1):
		var axis_y: float = float(profile.get("trunnion_height",3*s))
		var axis_z: float = -float(profile.get("trunnion_forward",5*s))
		var half_span: float = (count-1)*float(profile.get("gun_spacing",3.2*s))/2+2*s
		# Train-fixed fork and controls; only the gun assembly elevates between them.
		for side: int in [-1,1]:
			box(pos+Vector3(side*half_span,axis_y/2,axis_z),Vector3(1.2*s,axis_y,3*s),steel)
			rod(pos+Vector3(side*half_span,axis_y,axis_z),pos+Vector3(side*(half_span+1.2*s),axis_y,axis_z),0.9*s,steel)
			if count == 1: continue
			control_wheel(pos+Vector3(side*(half_span+1.5*s),axis_y*0.8,1.5*s),0.2 if profile_key == "heavy_aa" else 0.12)
			var seat: Vector3 = pos+Vector3(side*(half_span+2*s),axis_y*0.45,4*s)
			box(seat,Vector3(3.2*s,0.8*s,3.4*s),steel)
			rod(seat-Vector3(0,axis_y*0.4,0),seat,0.6*s,steel)
			box(seat+Vector3(0,1.7*s,1.5*s),Vector3(3.2*s,3*s,0.6*s),steel)
	for piece: Node in get_children().slice(first): piece.reparent(weapon)
	var gun_height: float = float(profile.get("trunnion_height",3*s))
	var trunnion: float = float(profile.get("trunnion_forward",5*s))
	var spacing: float = float(profile.get("gun_spacing",3.2*s))
	weapon.elevation_axis.position = Vector3(0,gun_height,-trunnion)
	for k: int in range(count):
		first = get_child_count()
		var start: Vector3 = pos+Vector3((k-(count-1)*0.5)*spacing,gun_height,-trunnion)
		if not small:
			ellipsoid(start+Vector3(0,0,-1.6*s),Vector3(2.2,2.3,3.3)*s,canvas_cover)
		if small:
			small_gun_receiver(start,profile_key)
		var length: float = float(profile.get("forward_barrel_length",(25.5 if count == 2 else 20.7)*s))
		var middle: Vector3 = start+Vector3(0,0,-length*0.38)
		tapered_rod(start,middle,0.8*s,0.55*s)
		tapered_rod(middle,start+Vector3(0,0,-length),0.55*s,0.29*s)
		rod(start,start+Vector3(0,0,-2*s),0.95*s,dark)
		# Recessed muzzle reads as a bore at inspection distance.
		rod(start+Vector3(0,0,-length-0.01),start+Vector3(0,0,-length-0.025),0.23*s,dark)
		for piece: Node in get_children().slice(first): piece.reparent(weapon.elevation_axis)
	for gun_index: int in range(count):
		var muzzle: Marker3D = Marker3D.new()
		muzzle.name = "Muzzle_%02d" % (gun_index + 1)
		muzzle.position = Vector3((gun_index-(count-1)*0.5)*spacing,0.0,-float(profile.get("forward_barrel_length",(25.5 if count == 2 else 20.7)*s)))
		muzzle.set_meta("barrel_index",gun_index)
		weapon.elevation_axis.add_child(muzzle)
	batch_static_geometry(weapon)
	batch_static_geometry(weapon.elevation_axis)
	weapon.rotation.y = heading
	weapons.append({"pivot": weapon,"foundation":foundation,"station_id":station_id})

func load_mount_layout() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/yamato_1944_mounts.json"))
	for entry: Dictionary in layout.mounts:
		var coordinates: Array = entry.position
		var pos: Vector3 = Vector3(coordinates[0],coordinates[1],coordinates[2])
		if entry.has("hull_edge_offset"): pos.x = signf(pos.x)*(hull_width(pos.z)-float(entry.hull_edge_offset))
		var kind: String = entry.profile
		var host_deck_y: float = -1.0
		var follows_hull_deck: bool = str(entry.get("attachment",{}).get("host","")) == "main_deck"
		if entry.has("attachment") and str(entry.attachment.get("kind","")) == "deck_surface":
			host_deck_y = float(entry.attachment.get("surface_y",-1.0))
		if follows_hull_deck: host_deck_y = deck_surface_height(pos.z)
		mount(pos,deg_to_rad(float(entry.heading_degrees)),kind not in ["main","secondary"],int(entry.barrels),kind == "secondary",str(entry.get("shield_variant","enclosed")),kind,host_deck_y,str(entry.id),follows_hull_deck)
		var weapon: WeaponMount = weapons.back().pivot
		weapon.name = "TrainPivot_"+str(entry.id)
		weapon.set_meta("placement_status",entry.placement_status)
		var foundation: Node3D = weapons.back().foundation
		foundation.set_meta("host_module",str(entry.get("attachment",{}).get("host","main_deck")))
		foundation.set_meta("surface_y",host_deck_y)
		var station: Marker3D = Marker3D.new()
		station.name = "Station_"+str(entry.id)
		station.position = Vector3(pos.x,host_deck_y,pos.z)
		station.set_meta("station_id",str(entry.id))
		station.set_meta("host_module",str(entry.get("attachment",{}).get("host","main_deck")))
		station.set_meta("source_status",entry.placement_status)
		add_child(station)
		weapons.back()["station"] = station
		if entry.has("platform"):
			var mounting: String = str(entry.platform.get("mounting","unverified"))
			weapon.set_meta("platform_radius",float(entry.platform.radius))
			weapon.set_meta("platform_floor_y",float(entry.platform.floor_y))
			if mounting != "deck_surface": aa_platform(pos,float(entry.platform.radius),float(entry.platform.floor_y),mounting)

func aa_platform(pos: Vector3, radius: float, floor_y: float, mounting: String = "unverified") -> void:
	# Platform envelope only; no invented posts or automatic braces.
	if mounting != "deck_surface": cylinder(Vector3(pos.x,pos.y-0.5,pos.z),radius,0.35,steel)
	var shield_y: float = floor_y+0.4 if mounting == "deck_surface" else pos.y-0.1
	# Partial splinter shield leaves inboard access open.
	var outward: float = signf(pos.x)
	for segment: int in range(12):
		var a: float = -PI*0.6+segment*PI*1.2/12
		var b: float = -PI*0.6+(segment+1)*PI*1.2/12
		var start: Vector3 = Vector3(pos.x+outward*cos(a)*radius,shield_y,pos.z+sin(a)*radius)
		var end: Vector3 = Vector3(pos.x+outward*cos(b)*radius,shield_y,pos.z+sin(b)*radius)
		var shield: MeshInstance3D = box((start+end)/2,Vector3(0.09,0.8,start.distance_to(end)),steel)
		shield.rotation.y = atan2(end.x-start.x,end.z-start.z)

func ellipsoid(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.radius = 1
	mesh.height = 2
	var part: MeshInstance3D = mesh_part(mesh,pos,mat)
	part.scale = size/2

func seaplane(pos: Vector3) -> void:
	var paint: StandardMaterial3D = material(Color("586b61"))
	ellipsoid(pos+Vector3(0,1.8,0),Vector3(1.1,1.3,9.0),paint)
	ellipsoid(pos+Vector3(0,0,0),Vector3(0.9,0.85,5.5),steel)
	ellipsoid(pos+Vector3(0,2.5,-0.3),Vector3(0.8,0.65,2.4),dark)
	for y: float in [1.3,3.2]:
		box(pos+Vector3(0,y,-0.3),Vector3(11,0.12,1.9),paint)
	box(pos+Vector3(0,2,3.6),Vector3(3.5,0.1,1.2),paint)
	box(pos+Vector3(0,2.65,3.7),Vector3(0.1,1.6,1.2),paint)
	for side: int in [-1,1]:
		ellipsoid(pos+Vector3(side*3.8,0.5,0),Vector3(0.4,0.45,1.9),steel)
		rod(pos+Vector3(side*3.8,0.7,0),pos+Vector3(side*3.8,1.3,0),0.05,steel)
		for z: float in [-1,0.6]:
			rod(pos+Vector3(side*3.5,1.3,z),pos+Vector3(side*4,3.2,z),0.045,steel)
			rod(pos+Vector3(side*0.3,0.3,z),pos+Vector3(side*0.4,1.5,z),0.055,steel)
	rod(pos+Vector3(-1.5,1.8,-4.6),pos+Vector3(1.5,1.8,-4.6),0.07,dark)

func shift_new_parts(first: int, offset: Vector3) -> void:
	for part: Node3D in get_children().slice(first): part.position += offset

func shelter_deck() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shelter_deck.json"))
	var outline: Array = data.outline_xz
	var bottom: float = data.bottom_y
	var top: float = data.top_y
	var center: Vector3 = Vector3(0,(bottom+top)/2,18)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(outline.size()):
		var next: int = (index+1)%outline.size()
		var a: Vector3 = Vector3(outline[index][0],bottom,outline[index][1])
		var b: Vector3 = Vector3(outline[next][0],bottom,outline[next][1])
		var c: Vector3 = Vector3(a.x,top,a.z)
		var d: Vector3 = Vector3(b.x,top,b.z)
		outward_triangle(surface,a,b,c,center)
		outward_triangle(surface,b,d,c,center)
		outward_triangle(surface,Vector3(0,top,18),c,d,center)
	var shelter_material: StandardMaterial3D = steel.duplicate() as StandardMaterial3D
	shelter_material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_part(surface.commit(),Vector3.ZERO,shelter_material)

func bow_anchor(side: int) -> void:
	var z: float = -119
	var pos: Vector3 = Vector3(side*(hull_width(z)+0.15),3.7,z)
	rod(pos+Vector3(0,0.8,0),pos+Vector3(0,-1.5,0),0.12,steel)
	rod(pos+Vector3(0,-1.4,-0.9),pos+Vector3(0,-1.4,0.9),0.16,steel)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.14
	ring.outer_radius = 0.25
	var shackle: MeshInstance3D = mesh_part(ring,pos+Vector3(0,0.9,0),steel)
	shackle.rotation.z = PI/2
	for direction: int in [-1,1]:
		var face: Array[Vector3] = [Vector3(0,deck_height(111)-7.5,0),Vector3(0,-1.4,direction*0.95),Vector3(0,-0.3,direction*1.25),Vector3(0,-0.85,direction*0.4)]
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center: Vector3 = Vector3(0,-1.05,direction*0.65)
		for offset: float in [-0.1,0.1]:
			outward_triangle(surface,face[0]+Vector3(offset,0,0),face[1]+Vector3(offset,0,0),face[2]+Vector3(offset,0,0),center)
			outward_triangle(surface,face[0]+Vector3(offset,0,0),face[2]+Vector3(offset,0,0),face[3]+Vector3(offset,0,0),center)
		for index: int in range(4):
			var next: int = (index+1)%4
			var a: Vector3 = face[index]-Vector3(0.1,0,0)
			var b: Vector3 = face[next]-Vector3(0.1,0,0)
			outward_triangle(surface,a,b,a+Vector3(0.2,0,0),center)
			outward_triangle(surface,b,b+Vector3(0.2,0,0),a+Vector3(0.2,0,0),center)
		mesh_part(surface.commit(),pos,steel)
	var hawse: MeshInstance3D = cylinder(pos+Vector3(0,2.4,0),0.45,0.12,dark)
	hawse.rotation.z = PI/2
	hawse.scale.z = 1.5
	rod(pos+Vector3(0,1.1,0),pos+Vector3(0,2.4,0),0.1,dark)

func rudder_foil(pos: Vector3, area: float, height: float, thickness: float) -> void:
	var profile: Array[Vector2] = [Vector2(-0.5,-0.35),Vector2(-0.35,-0.5),Vector2(0.35,-0.5),Vector2(0.5,-0.3),Vector2(0.5,0.45),Vector2(-0.4,0.5)]
	var unit_area: float = 0
	for i: int in range(profile.size()):
		var next: Vector2 = profile[(i+1)%profile.size()]
		unit_area += profile[i].x*next.y-next.x*profile[i].y
	var chord: float = area/(absf(unit_area)*0.5*height)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in [-1,1]:
		for i: int in range(profile.size()):
			var next: int = (i+1)%profile.size()
			var a: Vector3 = Vector3(side*thickness/2,profile[i].x*height,profile[i].y*chord)
			var b: Vector3 = Vector3(side*thickness/2,profile[next].x*height,profile[next].y*chord)
			outward_triangle(surface,Vector3(side*thickness/2,0,0),a,b,Vector3.ZERO)
	for i: int in range(profile.size()):
		var next: int = (i+1)%profile.size()
		var a: Vector3 = Vector3(-thickness/2,profile[i].x*height,profile[i].y*chord)
		var b: Vector3 = Vector3(-thickness/2,profile[next].x*height,profile[next].y*chord)
		outward_triangle(surface,a,b,a+Vector3(thickness,0,0),Vector3.ZERO)
		outward_triangle(surface,b,b+Vector3(thickness,0,0),a+Vector3(thickness,0,0),Vector3.ZERO)
	mesh_part(surface.commit(),pos,steel)

func underwater_appendages() -> void:
	var bronze: StandardMaterial3D = material(Color("7d795c"))
	for side: int in [-1,1]:
		for outer: bool in [false,true]:
			var pos: Vector3 = Vector3(side*(11.0 if outer else 5.0),-6.4 if outer else -7.0,105 if outer else 113)
			rod(pos-Vector3(0,0,19),pos,0.25,steel)
			rod(pos-Vector3(0,0,1),pos+Vector3(0,0,0.8),0.55,bronze)
			rod(pos-Vector3(0,0,2),pos+Vector3(-side*1.8,3,-2),0.23,steel)
			for blade: int in range(3):
				var angle: float = TAU*blade/3
				var mesh: SphereMesh = SphereMesh.new()
				mesh.radial_segments = 12
				mesh.rings = 6
				mesh.radius = 1
				mesh.height = 2
				var part: MeshInstance3D = mesh_part(mesh,pos+Vector3(cos(angle),sin(angle),0)*1.65,bronze)
				part.basis = Basis(Vector3.BACK,angle-PI/2)*Basis(Vector3.UP,side*0.45)
				part.scale *= Vector3(0.65,1.35,0.12)
	# Inline main/auxiliary rudders, not port/starboard twins. Areas 46 and 17 m².
	rudder_foil(Vector3(0,-5.7,121),46,7.1,0.5)
	rudder_foil(Vector3(0,-6.8,106),17,5.0,0.35)

func build_ship() -> Node3D:
	var hull_first: int = get_child_count()
	hull()
	underwater_appendages()
	bow_anchor(-1)
	bow_anchor(1)
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radial_segments = 24
	bulb.rings = 12
	bulb.radius = 1.0
	bulb.height = 2.0
	var bulb_part: MeshInstance3D = mesh_part(bulb,Vector3(0,-5.5,-126),steel)
	bulb_part.scale = Vector3(3.0,3.3,5.4)
	_group_new_parts(hull_first, "Hull")
	load_mount_layout()
	var shelter_first: int = get_child_count()
	shelter_deck()
	_build_dated_battery_decks()
	_group_new_parts(shelter_first, "SuperstructureDecks")
	var bridge_first: int = get_child_count()
	# Continuous bridge core with irregular projecting observation decks.
	bridge_core()
	var bridge_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bridge_geometry.json"))
	var bridge_z_offset: float = float(bridge_data.local_z_offset)
	for level: Dictionary in bridge_data.platforms:
		var y: float = float(level.y)
		var width: float = float(level.width)
		var depth: float = float(level.depth)
		var center_z: float = float(level.center_z)-bridge_z_offset
		bridge_platform(y,width,depth,float(level.thickness),center_z)
		if level.has("upper_platform"):
			var upper: Dictionary = level.upper_platform
			var upper_y: float = float(upper.y)
			var upper_width: float = float(upper.width)
			var upper_depth: float = float(upper.depth)
			var upper_center_z: float = float(upper.center_z)-bridge_z_offset
			bridge_platform(upper_y,upper_width,upper_depth,float(upper.thickness),upper_center_z)

		for side: int in [-1,1]:
			var front_z: float = center_z-depth/2
			var rear_z: float = center_z+depth/2
			rod(Vector3(side*width/2,y+0.2,front_z),Vector3(side*width/2,y+1.1,front_z),0.035,steel)
			bridge_side_rail(side*width/2,y+1.1,front_z,rear_z,bridge_z_offset)
	cylinder(Vector3(0,35.5,-15),1.9,1.7,steel)
	rod(Vector3(-7.5,35.9,-15),Vector3(7.5,35.9,-15),0.42,steel)
	for side: int in [-1,1]:
		ellipsoid(Vector3(side*7.4,35.9,-15),Vector3(1.1,1.35,1.8),steel)
	cylinder(Vector3(0,37.0,-15),1.8,2.0,steel)
	box(Vector3(0,37.9,-15.2),Vector3(3.3,1.5,3.0),steel)
	box(Vector3(0,37.9,-16.75),Vector3(1.5,0.5,0.12),dark)
	rod(Vector3(0,38.7,-15),Vector3(0,39.6,-15),0.13,steel)
	# Type 21 paired mattress panels on the rangefinder arms; dimensions provisional.
	for side: int in [-1,1]:
		var center_x: float = side*5.2
		for column: int in range(7):
			var x: float = center_x-1.4+column*2.8/6
			rod(Vector3(x,36.5,-13),Vector3(x,38.3,-13.4),0.03,steel)
		for row: int in range(4):
			var y: float = 36.5+row*0.6
			rod(Vector3(center_x-1.4,y,-13-(y-36.5)*0.22),Vector3(center_x+1.4,y,-13-(y-36.5)*0.22),0.03,steel)
		rod(Vector3(side*4,35.9,-15),Vector3(center_x,36.5,-13),0.07,steel)
		# Type 22 paired horns, vertically stacked on each bridge side.
		for offset: float in [-0.35,0.35]:
			tapered_rod(Vector3(side*4.8,28.8+offset,-12),Vector3(side*4.8,28.8+offset,-14),0.08,0.3)
	shift_new_parts(bridge_first,Vector3(0,0,17))
	_group_new_parts(bridge_first, "Bridge")
	var funnel_first: int = get_child_count()
	for side: int in [-1,1]:
		rod(Vector3(side*10,35,35),Vector3(side*5,34,5),0.018,dark)
		rod(Vector3(side*10,35,35),Vector3(side*8,10,90),0.018,dark)
		rod(Vector3(0,37,35),Vector3(side*13,9,55),0.02,dark)
	funnel_body()
	var funnel_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/funnel_geometry.json"))
	var cap_thickness: float = float(funnel_data.cap_thickness)
	var top_radius_x: float = float(funnel_data.top_radius_x)
	var top_radius_z: float = float(funnel_data.top_radius_z)
	var cap: MeshInstance3D = cylinder(Vector3(0,float(funnel_data.top_ring_y)+cap_thickness/2,float(funnel_data.top_center_z)),1.0,cap_thickness,dark)
	cap.scale = Vector3(top_radius_x,1,top_radius_z)
	cap.rotation.x = float(funnel_data.tilt_radians)
	# Shared funnel-top lattice from Tamiya 78030 printed p13 step24.
	# Layout is proportioned from the diagram, not a dimensioned original drawing.
	var lattice_margin: float = float(funnel_data.lattice_margin_ratio)
	var lattice_y: float = cap_thickness/2+0.12
	for row: int in range(-5,6):
		var z: float = row*float(funnel_data.lattice_row_spacing)
		var half_chord: float = top_radius_x*lattice_margin*sqrt(1-pow(z/(top_radius_z*lattice_margin),2))
		rod(cap.transform*Vector3(-half_chord/top_radius_x,lattice_y,z/top_radius_z),cap.transform*Vector3(half_chord/top_radius_x,lattice_y,z/top_radius_z),0.06,steel)
	for column: int in range(-3,4):
		var x: float = column*float(funnel_data.lattice_column_spacing)
		var half_chord: float = top_radius_z*lattice_margin*sqrt(1-pow(x/(top_radius_x*lattice_margin),2))
		rod(cap.transform*Vector3(x/top_radius_x,lattice_y,-half_chord/top_radius_z),cap.transform*Vector3(x/top_radius_x,lattice_y,half_chord/top_radius_z),0.07,steel)

	_group_new_parts(funnel_first, "FunnelAndRigging")
	var equipment_first: int = get_child_count()
	for side: int in [-1,1]:
		# Small service craft stay on their aft deck stations, independent of the funnel transform.
		for z: float in [33.5,47.5]:
			var boat_pos: Vector3 = Vector3(side*7.5,12,z)
			var boat: SphereMesh = SphereMesh.new()
			boat.radial_segments = 16
			boat.rings = 8
			boat.radius = 1.0
			boat.height = 2.0
			var boat_part: MeshInstance3D = mesh_part(boat,boat_pos,steel)
			boat_part.scale = Vector3(1.2,0.65,4.2)
			box(boat_pos+Vector3(0,0.55,0),Vector3(1.6,0.2,5.5),dark)
			box(boat_pos+Vector3(0,0.75,-0.5),Vector3(1.4,0.7,1.8),deck)
			for x: float in [-0.9,0.9]: rod(boat_pos+Vector3(x,0.6,-2.7),boat_pos+Vector3(x,0.6,2.7),0.05,steel)
	_group_new_parts(equipment_first, "ServiceBoats")
	var aft_first: int = get_child_count()
	# Faceted aft-bridge body and connected deck plates; dimensions remain image-proportioned.
	var aft_z_offset: float = aft_bridge()
	rod(Vector3(-5,23.5,32),Vector3(5,23.5,32),0.25,steel)
	for side: int in [-1,1]:
		box(Vector3(side*4.8,23.5,32),Vector3(1,1.1,1.5),steel)
	for side: int in [-1,1]:
		cylinder(Vector3(side*4,18.8,32),0.85,1.4,steel)
	shift_new_parts(aft_first,Vector3(0,0,aft_z_offset))
	_group_new_parts(aft_first, "AftBridge")
	var aft_equipment_first: int = get_child_count()
	for side: int in [-1,1]:
		rod(Vector3(side*5,11,38),Vector3(0,37,35),0.38,steel)
		rod(Vector3(0,37,35),Vector3(side*12,35,35),0.2,steel)
		rod(Vector3(side*0.7,37,34.3),Vector3(side*0.7,41,34.3),0.045,steel)
		rod(Vector3(side*0.7,37,35.7),Vector3(side*0.7,41,35.7),0.045,steel)
		# Separate port/starboard ladder arrays (Skulski/Draminski printed p25).
		for row: int in range(9):
			rod(Vector3(side*0.7,37+row*0.5,34.3),Vector3(side*0.7,37+row*0.5,35.7),0.03,steel)
		# Stern catapult trusses and handling rails.
		var catapult_first: int = get_child_count()
		var base: Vector3 = Vector3(side*10.125,deck_height(114.7)+0.5,114.7)
		cylinder(base,1.8,1.0,steel)
		var catapult_length: float = 19.5 # Skulski/Draminski, printed p25.
		var half_length: float = catapult_length/2
		var bay_length: float = catapult_length/10
		for edge: float in [-0.7,0.7]:
			rod(base+Vector3(edge,1,-half_length),base+Vector3(edge,1,half_length),0.12,steel)
			rod(base+Vector3(edge,0,-half_length),base+Vector3(edge,0,half_length),0.1,steel)
		for segment: int in range(11):
			var z: float = -half_length+segment*bay_length
			rod(base+Vector3(-0.7,1,z),base+Vector3(0.7,1,z),0.08,steel)
			rod(base+Vector3(-0.7,0,z),base+Vector3(0.7,0,z),0.08,steel)
			if segment == 10: continue
			rod(base+Vector3(-0.7,0,z),base+Vector3(0.7,1,z+bay_length),0.065,steel)
			rod(base+Vector3(0.7,0,z),base+Vector3(-0.7,1,z+bay_length),0.065,steel)
		var catapult_parts: Array[Node] = get_children().slice(catapult_first)
		for part: MeshInstance3D in catapult_parts:
			part.position = base+(part.position-base).rotated(Vector3.UP,side*deg_to_rad(3.2))
			part.basis = Basis(Vector3.UP,side*deg_to_rad(3.2))*part.basis
		for rail_x: float in [side*4,side*4+0.8]:
			for segment: int in range(10):
				var rail_z: float = 88+segment*3.0
				rod(Vector3(rail_x,deck_height(rail_z)+0.1,rail_z),Vector3(rail_x,deck_height(rail_z+3)+0.1,rail_z+3),0.07,steel)

	for z: float in [-110,-100,95,110]:
		for x: float in [-5,5]: cylinder(Vector3(x,deck_height(z)+0.4,z),0.7,0.8,steel)
	seaplane(Vector3(-7,deck_height(112)+0.65,112))
	seaplane(Vector3(7,deck_height(93)+0.65,93))
	var crane_first: int = get_child_count()
	# 20m boom length: Skulski/Draminski printed p25; display angle remains estimated.
	cylinder(Vector3(0,10,111),1.3,5,steel)
	var hinge: Vector3 = Vector3(0,12,111)
	var boom_direction: Vector3 = Vector3(0,8,9).normalized()
	var boom_tip: Vector3 = hinge+boom_direction*20
	var boom_up: Vector3 = Vector3.RIGHT.cross(boom_direction).normalized()
	var rings: Array[Array] = []
	for bay: int in range(11):
		var t: float = bay/10.0
		var center: Vector3 = hinge.lerp(boom_tip,t)
		var half_width: float = lerpf(0.65,0.22,t)
		var ring: Array[Vector3] = [center+Vector3.LEFT*half_width,center+Vector3.RIGHT*half_width,center+boom_up*half_width]
		rings.append(ring)
		for corner: int in range(3): rod(ring[corner],ring[(corner+1)%3],0.05,steel)
		if bay == 0: continue
		for corner: int in range(3):
			rod(rings[bay-1][corner],ring[corner],0.11,steel)
			rod(rings[bay-1][corner],ring[(corner+1)%3],0.055,steel)
	var hook: Vector3 = Vector3(0,deck_height(126)+2.0,boom_tip.z)
	rod(boom_tip,hook,0.025,dark)
	var pulley: MeshInstance3D = cylinder(boom_tip,0.28,0.2,steel)
	pulley.rotation.z = PI/2
	cylinder(hook,0.16,0.45,steel)
	rod(Vector3(0,15,111),boom_tip+boom_up*0.22,0.035,dark)
	shift_new_parts(crane_first,Vector3(0,deck_height(111)-7.5,0))
	for side: int in [-1,1]:
		for z: float in [-111,-106]:
			cylinder(Vector3(side*4,deck_height(z)+0.5,z),0.8,0.7,steel)
		rod(Vector3(side*4,deck_height(-111)+0.85,-111),Vector3(side*(hull_width(-119)-0.3),deck_height(-119)+0.05,-119),0.12,dark)
	_group_new_parts(aft_equipment_first, "AftEquipment")
	var ship: Node3D = Node3D.new()
	ship.name = "Yamato1944"
	var ship_parts: Array[Node] = get_children()
	add_child(ship)
	for part: Node in ship_parts: part.reparent(ship, false)
	batch_static_geometry(ship)
	for entry: Dictionary in weapons:
		var foundation: Node3D = entry.foundation
		var station: Marker3D = entry.station
		var semantic_host: String = str(station.get_meta("host_module"))
		var host_key: String = "Hull"
		if semantic_host.begins_with("aft_bridge"):
			host_key = "AftBridge"
		elif semantic_host.contains("bridge_deck"):
			host_key = "Bridge"
		elif semantic_host != "main_deck":
			host_key = "SuperstructureDecks"
		station.reparent(module_roots[host_key],true)
		foundation.reparent(station,true)
	for part_node: Node in ship.find_children("*","MeshInstance3D",true,false):
		var part: MeshInstance3D = part_node as MeshInstance3D
		if part.get_parent().name.to_lower().begins_with("foundation") or part.find_parent("TrainPivot_*") != null:
			continue
		static_clearance.append({"part":part,"triangles":part.mesh.generate_triangle_mesh()})
	for entry: Dictionary in weapons:
		var foundation: Node3D = entry.foundation
		for child: Node in foundation.get_children():
			if child is MeshInstance3D:
				var part: MeshInstance3D = child
				static_clearance.append({"part":part,"triangles":part.mesh.generate_triangle_mesh()})
	for entry: Dictionary in weapons:
		var mount: WeaponMount = entry.pivot
		mount.pose_guard = weapon_pose_clear.bind(mount)
	return ship

func batch_static_geometry(ship_root: Node3D) -> void:
	var groups: Dictionary = {}
	for child: Node in ship_root.get_children():
		if child is not MeshInstance3D: continue
		var part: MeshInstance3D = child as MeshInstance3D
		var key: int = part.material_override.get_instance_id()
		if not groups.has(key): groups[key] = {"parts": [], "material": part.material_override}
		groups[key].parts.append(part)
	for key: int in groups:
		var group: Dictionary = groups[key]
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in group.parts:
			# Mixing indexed primitives with non-indexed custom meshes drops the latter.
			var expanded: SurfaceTool = SurfaceTool.new()
			expanded.create_from(part.mesh,0)
			expanded.deindex()
			surface.append_from(expanded.commit(),0,part.transform)
		var merged: MeshInstance3D = MeshInstance3D.new()
		merged.name = "Static_"+str(key)
		merged.mesh = surface.commit()
		merged.material_override = group.material
		ship_root.add_child(merged)
		for part: MeshInstance3D in group.parts:
			ship_root.remove_child(part)
			part.free()

func weapon_pose_clear(heading: float, elevation: float, mount: WeaponMount) -> bool:
	var profile: Dictionary = weapon_profiles[str(mount.get_meta("profile"))]
	var count: int = int(mount.get_meta("barrels",3))
	var scale_factor: float = float(mount.get_meta("geometry_scale",1.0))
	var spacing: float = float(profile.get("gun_spacing",3.2*scale_factor))
	var length: float = float(profile.get("forward_barrel_length",(25.5 if count == 2 else 20.7)*scale_factor))
	var pose: Transform3D = mount.get_parent_node_3d().global_transform*Transform3D(Basis(Vector3.UP,heading),mount.position)*Transform3D(Basis(Vector3.RIGHT,elevation),mount.elevation_axis.position)
	for obstacle: Dictionary in static_clearance:
		var part: MeshInstance3D = obstacle.part
		var triangles: TriangleMesh = obstacle.triangles
		var local_pose: Transform3D = part.global_transform.affine_inverse()*pose
		for barrel: int in range(count):
			for sample: int in range(9):
				var radial: Vector2 = Vector2.ZERO if sample == 0 else Vector2.from_angle((sample-1)*TAU/8)
				var start: Vector3 = local_pose*Vector3((barrel-(count-1)*0.5)*spacing+radial.x*0.8*scale_factor,radial.y*0.8*scale_factor,0)
				var end: Vector3 = local_pose*Vector3((barrel-(count-1)*0.5)*spacing+radial.x*0.29*scale_factor,radial.y*0.29*scale_factor,-length)
				if not part.mesh.get_aabb().intersects_segment(start,end): continue
				var hit: Dictionary = triangles.intersect_segment(start,end)
				if not hit.is_empty():
					var ship_root: Node3D = mount.get_parent_node_3d().get_parent_node_3d().get_parent_node_3d()
					var point: Vector3 = ship_root.to_local(part.to_global(hit.position))
					mount.set_meta("last_obstruction_point",[point.x,point.y,point.z])
					return false
	for entry: Dictionary in weapons:
		var target_mount: WeaponMount = entry.pivot
		if target_mount == mount or target_mount.get_meta("profile") not in ["main","secondary"]: continue
		if target_mount.global_position.distance_to(mount.global_position) > 45: continue
		for child: Node in target_mount.find_children("*","MeshInstance3D",true,false):
			var part: MeshInstance3D = child as MeshInstance3D
			var inverse: Transform3D = part.global_transform.affine_inverse()
			if not part.has_meta("clearance_faces"):
				part.set_meta("clearance_faces",part.mesh.get_faces())
			var faces: PackedVector3Array = part.get_meta("clearance_faces")
			for barrel: int in range(count):
				for sample: int in range(9):
					var radial: Vector2 = Vector2.ZERO if sample == 0 else Vector2.from_angle((sample-1)*TAU/8)
					var start: Vector3 = inverse*(pose*Vector3((barrel-(count-1)*0.5)*spacing+radial.x*0.8*scale_factor,radial.y*0.8*scale_factor,0))
					var end: Vector3 = inverse*(pose*Vector3((barrel-(count-1)*0.5)*spacing+radial.x*0.29*scale_factor,radial.y*0.29*scale_factor,-length))
					if not part.mesh.get_aabb().intersects_segment(start,end): continue
					for index: int in range(0,faces.size(),3):
						if Geometry3D.segment_intersects_triangle(start,end,faces[index],faces[index+1],faces[index+2]) != null: return false

	return true

func _group_new_parts(first_index: int, module_name: String) -> Node3D:
	var parts: Array[Node] = get_children().slice(first_index)
	var module: Node3D = Node3D.new()
	module.name = module_name
	add_child(module)
	for part: Node in parts:
		part.reparent(module,false)
	batch_static_geometry(module)
	module_roots[module_name] = module
	return module

func _build_dated_battery_decks() -> void:
	# Source: Tamiya 78030 p14/29 common structural shells; 1944 plan retains stations.
	# A continuous shaped upper battery house carries the inner Type89 row.
	for side: int in [-1,1]:
		var before: int = get_child_count()
		var outline: Array[Array] = [bridge_section(2.6,5.0,36.0,11.45),bridge_section(2.4,6.0,35.5,15.5)]
		section_loft(outline,Vector3(0,13.5,20))
		for part: MeshInstance3D in get_children().slice(before):
			part.position.x += side*7.8
	# Fore secondary is carried by the real bridge-base deckhouse, aft by its lobed enclosure.
	var fore_sections: Array[Array] = [bridge_section(5.2,-14.0,3.0,8.3),bridge_section(5.1,-14.0,3.0,13.3)]
	var fore_base: MeshInstance3D = section_loft(fore_sections,Vector3(0,10.8,-5.5))
	fore_base.name = "ForeSecondaryBridgeBase"
