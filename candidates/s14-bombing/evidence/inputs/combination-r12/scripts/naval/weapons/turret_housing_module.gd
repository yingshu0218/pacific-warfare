extends Node3D
class_name TurretHousingModule

@export var profile_key: String = "main"
@export var geometry_scale: float = 1.0

var steel: StandardMaterial3D
var dark: StandardMaterial3D


func _ready() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_profiles.json"))
	if not profiles.has(profile_key):
		push_error("Unknown turret housing profile: "+profile_key)
		return
	var profile: Dictionary = profiles[profile_key]
	steel = _material(Color("596169"))
	dark = _material(Color("222a30"))
	_build_housing(profile)


func _material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.78
	return result


func _mesh_part(mesh: Mesh, position: Vector3, mat: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.position = position
	part.material_override = mat
	add_child(part)
	return part


func _box(position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh_part(mesh,position,mat)


func _cylinder(position: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.rings = 0
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh_part(mesh,position,mat)


func _rod(start: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	var part: MeshInstance3D = _cylinder((start+end)/2,radius,start.distance_to(end),mat)
	part.quaternion = Quaternion(Vector3.UP,(end-start).normalized())


func _outward_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var normal: Vector3 = (c-a).cross(b-a).normalized()
	var reverse: bool = normal.dot((a+b+c)/3-center) < 0
	if reverse: normal = -normal
	for vertex: Vector3 in ([a,c,b] if reverse else [a,b,c]):
		surface.set_normal(normal)
		surface.add_vertex(vertex)


func _build_housing(profile: Dictionary) -> void:
	var scale_factor: float = geometry_scale
	var roller_path_diameter: float = float(profile.get("roller_path_external_diameter_m",6.4))
	_cylinder(Vector3(0,0.5,0),roller_path_diameter/2.0,1.0,steel)
	_armored_housing(Vector3(0,1,0),scale_factor,profile_key == "main",float(profile.get("gun_spacing",3.5)))

	if profile_key == "main":
		_box(Vector3(0,3.6,-2.8),Vector3(10,4.2,0.15),dark)
	var range_half: float = float(profile.get("rangefinder_span",18*scale_factor))/2.0
	_rod(Vector3(-range_half,4*scale_factor,4*scale_factor),Vector3(range_half,4*scale_factor,4*scale_factor),0.4*scale_factor,steel)
	for side: int in [-1,1]:
		_box(Vector3(side*(range_half-0.5*scale_factor),4*scale_factor,4*scale_factor),Vector3(1.5,1.8,2.2)*scale_factor,steel)
		_box(Vector3(side*(range_half+0.27*scale_factor),4.2*scale_factor,3.8*scale_factor),Vector3(0.04,0.55,0.7)*scale_factor,dark)
		_cylinder(Vector3(side*3.7*scale_factor,6.3*scale_factor,2.4*scale_factor),0.65*scale_factor,0.5*scale_factor,steel)
		_box(Vector3(side*3.7*scale_factor,6.7*scale_factor,2.4*scale_factor),Vector3(0.6,0.5,0.8)*scale_factor,steel)
		_box(Vector3(side*3.7*scale_factor,6.7*scale_factor,1.98*scale_factor),Vector3(0.4,0.2,0.04)*scale_factor,dark)
	_box(Vector3(0,2.7*scale_factor,7.65*scale_factor),Vector3(1.5,2.4,0.1)*scale_factor,dark)
	_box(Vector3(0,2.7*scale_factor,7.72*scale_factor),Vector3(1.25,2.2,0.08)*scale_factor,steel)
	for rung: int in range(8):
		_rod(Vector3(-1.5*scale_factor,(1+rung*0.5)*scale_factor,7.6*scale_factor),Vector3(-0.8*scale_factor,(1+rung*0.5)*scale_factor,7.6*scale_factor),0.045*scale_factor,steel)


func _armored_housing(position: Vector3, scale_factor: float, open_gun_ports: bool, gun_spacing: float) -> void:
	var points: Array[Vector3] = [Vector3(-7,0,-8),Vector3(7,0,-8),Vector3(8,0,4),Vector3(5.5,0,8),Vector3(-5.5,0,8),Vector3(-8,0,4),Vector3(-5.8,5,-5.4),Vector3(5.8,5,-5.4),Vector3(6.4,5,3),Vector3(4.8,5,6),Vector3(-4.8,5,6),Vector3(-6.4,5,3)]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector3 = Vector3(0,2.5,0)*scale_factor
	for index: int in range(6):
		if open_gun_ports and index == 0: continue
		var next: int = (index+1)%6
		_outward_triangle(surface,points[index]*scale_factor,points[next]*scale_factor,points[index+6]*scale_factor,center)
		_outward_triangle(surface,points[next]*scale_factor,points[next+6]*scale_factor,points[index+6]*scale_factor,center)
	if open_gun_ports:
		var aperture_half_width: float = 1.0
		var aperture_top_width: float = 7.0-1.2*1.4/5.0
		var port_spacing_norm: float = gun_spacing/aperture_top_width
		var port_half_width_norm: float = aperture_half_width/aperture_top_width
		var columns: Array[float] = [-1.0,-port_spacing_norm-port_half_width_norm,-port_spacing_norm+port_half_width_norm,-port_half_width_norm,port_half_width_norm,port_spacing_norm-port_half_width_norm,port_spacing_norm+port_half_width_norm,1.0]
		for band: int in range(7):
			var opening: bool = band in [1,3,5]
			var top_y: float = 1.4 if opening else 5.0
			var a: Vector3 = Vector3(columns[band]*7,0,-8)*scale_factor
			var b: Vector3 = Vector3(columns[band+1]*7,0,-8)*scale_factor
			var c: Vector3 = Vector3(columns[band]*(7-1.2*top_y/5),top_y,-8+2.6*top_y/5)*scale_factor
			var d: Vector3 = Vector3(columns[band+1]*(7-1.2*top_y/5),top_y,-8+2.6*top_y/5)*scale_factor
			_outward_triangle(surface,a,b,c,center)
			_outward_triangle(surface,b,d,c,center)
			if opening: continue
			var rear_width: float = lerpf(5.8,6.4,2.4/8.4)
			a = Vector3(columns[band]*5.8,5,-5.4)*scale_factor
			b = Vector3(columns[band+1]*5.8,5,-5.4)*scale_factor
			c = Vector3(columns[band]*rear_width,5,-3)*scale_factor
			d = Vector3(columns[band+1]*rear_width,5,-3)*scale_factor
			_outward_triangle(surface,a,b,c,center)
			_outward_triangle(surface,b,d,c,center)
		var roof: Array[Vector3] = [Vector3(-5.97143,5,-3),Vector3(5.97143,5,-3),points[8],points[9],points[10],points[11]]
		for index: int in range(1,5):
			_outward_triangle(surface,roof[0]*scale_factor,roof[index]*scale_factor,roof[index+1]*scale_factor,center)
	else:
		for index: int in range(1,5):
			_outward_triangle(surface,points[6]*scale_factor,points[index+7]*scale_factor,points[index+6]*scale_factor,center)
	var armor: StandardMaterial3D = steel.duplicate() as StandardMaterial3D
	armor.cull_mode = BaseMaterial3D.CULL_BACK
	_mesh_part(surface.commit(),position,armor)


func _turret_roof_rails(position: Vector3, scale_factor: float, rail_height_m: float, post_spacing_m: float, bar_radius_m: float) -> void:
	# Low access rails follow the side and rear roof edges; leave the gun-port face clear.
	var roof_y: float = 1.0+5.0*scale_factor
	var rail_height: float = maxf(0.1,rail_height_m)
	var post_spacing: float = maxf(0.2,post_spacing_m)
	var paths: Array = [
		[Vector2(5.8,-5.4),Vector2(6.4,3.0),Vector2(4.8,6.0)],
		[Vector2(-5.8,-5.4),Vector2(-6.4,3.0),Vector2(-4.8,6.0)],
		[Vector2(-4.8,6.0),Vector2(4.8,6.0)]
	]
	for path: Array in paths:
		for segment: int in range(path.size()-1):
			var start_2d: Vector2 = path[segment]
			var end_2d: Vector2 = path[segment+1]
			var start: Vector3 = position+Vector3(start_2d.x*scale_factor,roof_y,start_2d.y*scale_factor)
			var end: Vector3 = position+Vector3(end_2d.x*scale_factor,roof_y,end_2d.y*scale_factor)
			var interval_count: int = maxi(1,int(ceil(start.distance_to(end)/post_spacing)))
			for post: int in range(interval_count+1):
				var foot: Vector3 = start.lerp(end,float(post)/float(interval_count))
				_rod(foot,foot+Vector3.UP*rail_height,bar_radius_m,steel)
			for rail_fraction: float in [0.5,1.0]:
				var rail_offset: Vector3 = Vector3.UP*rail_height*rail_fraction
				_rod(start+rail_offset,end+rail_offset,bar_radius_m,steel)
