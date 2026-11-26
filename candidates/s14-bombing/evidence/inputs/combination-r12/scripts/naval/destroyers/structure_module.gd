extends Node3D
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
@export_file("*.json") var assembly_path: String
@export var group_id: String = "bridge"

func _ready() -> void:
	var configuration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(assembly_path))
	var p: Dictionary = G.palette(configuration.country_id == "us")
	for record: Dictionary in configuration.structures[group_id]:
		var host: Node3D = Node3D.new()
		host.name = record.id
		host.position = G.vector(record.position_m)
		host.set_meta("host_id", record.id)
		host.set_meta("source_ids", record.source_ids)
		add_child(host)
		var shape: Array[Vector2]
		match str(record.shape):
			"ellipse": shape = G.ellipse(record.width_m, record.length_m)
			"round_front": shape = G.rounded_front(record.width_m, record.length_m)
			"beveled": shape = G.beveled_rect(record.width_m,record.length_m)
			_: shape = G.polygon(record.polygon_m)
		var top: float = float(record.height_m)
		G.prism(host, "Shell", shape, 0.0, top, p[str(record.get("material", "gray"))],
			float(record.get("top_scale", 1.0)), Vector2(0, float(record.get("rake_m", 0.0))))
		# Real continuous roof, no unrelated pillars beneath the weapon seats.
		if record.get("roof", true):
			G.prism(host, "Roof", shape, top, top + 0.06, p.deck if configuration.country_id == "us" else p.steel,
				float(record.get("top_scale", 1.0)), Vector2(0, float(record.get("rake_m", 0.0))))
		if record.get("funnel", false):
			var cap: MeshInstance3D = G.prism(host, "BlackCap", shape, top - 0.65, top + 0.15, p.dark)
			cap.position.z = float(record.get("rake_m", 0))
			for side: float in [-1.0, 1.0]:
				G.rod(host, "SteamPipe", Vector3(side * float(record.width_m) * 0.46, 0.2, 0.5),
					Vector3(side * float(record.width_m) * 0.46, top - 0.1, float(record.get("rake_m", 0)) + 0.5), 0.10, p.steel)
		for window: Array in record.get("windows", []):
			var pane: MeshInstance3D = G.box(host, "BridgeWindow", G.vector(window[1]), G.vector(window[0]), p.glass)
			pane.rotation.y = deg_to_rad(float(window[2]))
		for surface: Dictionary in record.get("surfaces", []):
			var marker: Marker3D = Marker3D.new()
			marker.name = surface.id
			marker.position = G.vector(surface.position_m)
			marker.set_meta("surface_radius_m", surface.radius_m)
			host.add_child(marker)
