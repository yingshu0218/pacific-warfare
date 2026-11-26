extends Node3D
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export_file("*.json") var assembly_path: String
var configuration: Dictionary

func _ready() -> void:
	configuration = JSON.parse_string(FileAccess.get_file_as_string(assembly_path))
	var p: Dictionary = G.palette(configuration.country_id == "us")
	var rings: Array[PackedVector3Array] = []
	var underwater: Array[PackedVector3Array] = []
	var deck_groups: Dictionary = {"deck":PackedVector3Array(),"steel":PackedVector3Array()}
	for station: Array in configuration.hull.stations:
		var z: float = float(station[0])
		var beam: float = float(station[1])
		var deck_y: float = float(station[2])
		var keel_y: float = float(station[3])
		var rake: float = float(station[4]) if station.size() > 4 else 0.0
		# Each transverse section keeps flare, turn of bilge, keel and deck crown.
		var ring: PackedVector3Array = [Vector3(-beam * 0.94, 0, z + rake), Vector3(-beam, deck_y, z),
			Vector3(0, deck_y + 0.08, z), Vector3(beam, deck_y, z), Vector3(beam * 0.94, 0, z + rake)]
		rings.append(ring)
		underwater.append(PackedVector3Array([Vector3(-beam * 0.94, 0, z + rake), Vector3(-beam * 0.75, keel_y * 0.7, z + rake),
			Vector3(-beam * 0.25, keel_y, z + rake), Vector3(beam * 0.25, keel_y, z + rake),
			Vector3(beam * 0.75, keel_y * 0.7, z + rake), Vector3(beam * 0.94, 0, z + rake)]))
	G.mesh_node(self, "ShellAndSheer", G.loft(rings, true), p.gray)
	G.mesh_node(self, "UnderwaterHull", G.loft(underwater, true), p.red)
	# Separate visible deck strip, same loft station boundary as shell.
	for index: int in range(configuration.hull.stations.size() - 1):
		var a: Array = configuration.hull.stations[index]
		var b: Array = configuration.hull.stations[index + 1]
		var key: String = "deck" if configuration.country_id == "us" else "steel"
		var midpoint: float = (float(a[0]) + float(b[0])) * 0.5
		for span: Array in configuration.hull.get("linoleum_spans_m",[]):
			if midpoint >= float(span[0]) and midpoint <= float(span[1]):
				key = "deck"
		var deck_vertices: PackedVector3Array = deck_groups[key]
		deck_vertices.append_array([Vector3(-a[1], a[2] + 0.016, a[0]), Vector3(0, a[2] + 0.096, a[0]), Vector3(0, b[2] + 0.096, b[0]),
			Vector3(-a[1], a[2] + 0.016, a[0]), Vector3(0, b[2] + 0.096, b[0]), Vector3(-b[1], b[2] + 0.016, b[0]),
			Vector3(0, a[2] + 0.096, a[0]), Vector3(a[1], a[2] + 0.016, a[0]), Vector3(b[1], b[2] + 0.016, b[0]),
			Vector3(0, a[2] + 0.096, a[0]), Vector3(b[1], b[2] + 0.016, b[0]), Vector3(0, b[2] + 0.096, b[0])])
		deck_groups[key] = deck_vertices
	for key: String in deck_groups:
		var deck_vertices: PackedVector3Array = deck_groups[key]
		if deck_vertices.is_empty():
			continue
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in deck_vertices:
			surface.add_vertex(vertex)
		surface.generate_normals()
		G.mesh_node(self, "WeatherDeck_" + key, surface.commit(), p[key])
	set_meta("host_id", "hull")
	set_meta("source_ids", configuration.hull.source_ids)
	for record: Dictionary in configuration.hull.surfaces:
		var marker: Marker3D = Marker3D.new()
		marker.name = record.id
		marker.position = G.vector(record.position_m)
		marker.set_meta("surface_radius_m", record.radius_m)
		add_child(marker)
