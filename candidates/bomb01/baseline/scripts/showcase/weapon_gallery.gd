class_name ShowcaseWeaponGallery
extends Node3D

## Existing weapons, displayed on their actual available mounts. Bare modules
## without an admitted mount rest on a marked inspection cradle, never float.
var entries: Array[Dictionary] = []
var terrain: Dictionary = {}

func build(data: Dictionary) -> void:
	terrain = data
	var definitions: Array[Dictionary] = [
		{"id":"gallery_vickers","name":"7.7mm Vickers + 九二式F三脚架","scene":"res://scenes/mounts/japanese_92_model_f_tripod.tscn","weapon":"res://scenes/weapons/navy_vickers_77mm.tscn","distance":3.8},
		{"id":"gallery_type96","name":"25mm 九六式双联 + 舰用炮架","scene":"res://scenes/mounts/type96_ship_twin_mount.tscn","weapon":"res://scenes/weapons/type96_twin_25mm.tscn","distance":8.0},
		{"id":"gallery_m2","name":"M2HB 枪体 · 检视托架","scene":"res://assets/naval/weapons/us_browning_50cal/m2hb/us_browning_50cal_m2hb.tscn","cradle":true,"distance":3.3},
		{"id":"gallery_m1917","name":"M1917A1 枪体 · 检视托架","scene":"res://assets/naval/weapons/us_browning_30cal/m1917a1/us_browning_30cal_m1917a1.tscn","cradle":true,"distance":2.7},
		{"id":"gallery_bofors","name":"40mm Mk2 Mod5 四联 · 兵器检视","scene":"res://assets/naval/weapons/usn_bofors_40mm/mark2_mod5/usn_bofors_40mm_quad_mk2_mod5.tscn","distance":11.0}
	]
	for index: int in definitions.size():
		var entry: Dictionary = definitions[index].duplicate(true)
		# Harbor quayside pad, outside buildings and the three live ground sites.
		var at: Vector3 = Vector3(-4400.0, 0, -3350.0+index*8.0)
		# Include the authored quay's real top, not only the underlying terrain.
		# The 12cm plinth embeds its bottom 4cm into the quay; its top and the
		# supported weapon sit 8cm above it. Coplanar tops otherwise z-fight.
		at.y = TerrainQueries.height_data(terrain,at,true)+.08
		var root: Node3D = Node3D.new()
		root.name = entry.id
		root.position = at
		add_child(root)
		var model: Node3D = (load(entry.scene) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		if entry.has("weapon"):
			var socket: Node3D = model.get_node("WeaponSocket")
			var weapon: Node3D = (load(entry.weapon) as PackedScene).instantiate() as Node3D
			socket.add_child(weapon)
		elif bool(entry.get("cradle",false)):
			# Museum fixtures, explicitly not historical combat mounts.
			model.position.y = 0.90
			for z: float in [-0.10,0.25]:
				_box(root,Vector3(0.0,0.4,z),Vector3(.32,.8,.10),Color("6d7478"))
				_box(root,Vector3(0.0,.83,z),Vector3(.35,.10,.16),Color("899294"))
		_box(root,Vector3(0,-.06,0),Vector3(5,.12,5),Color("596668"))
		var label: Label3D = Label3D.new()
		label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		label.text = entry.name + "\n兵器检视 · 未接战斗"
		label.font_size = 32
		label.pixel_size = .002
		label.position = Vector3(0,.03,1.9)
		label.rotation.x = -PI*.5
		label.no_depth_test = false
		root.add_child(label)
		entry["position_m"] = at
		entry["focus_m"] = at+Vector3.UP*(1.3 if not entry.get("cradle",false) else 1)
		entries.append(entry)

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.position = at
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
