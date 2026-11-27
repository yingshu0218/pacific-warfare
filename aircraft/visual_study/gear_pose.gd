extends RefCounted
## Render-only gear controls. Each visual assembly owns its pivot. A fixed
## assembly is never changed by the state follower.

static func fraction_from(data: Dictionary) -> float:
	for source: String in ["carrier_ops", "airfield_ops", "aircraft_motion"]:
		var state: Dictionary = data.get(source, {})
		if state.has("gear_fraction"):
			var value: float = float(state.gear_fraction)
			if is_finite(value): return clampf(value, 0., 1.)
		if state.has("gear_down"):
			return 1.0 if bool(state.gear_down) else 0.0
	return 0.0


static func pose(pivot: Node3D, retracted: Vector3, deployment: float, fixed: bool = false, partly_visible: bool = false) -> void:
	if fixed:
		return
	var amount: float = clampf(deployment, 0.0, 1.0)
	pivot.rotation = retracted * (1.0 - amount)
	pivot.visible = amount > 0.001 or partly_visible


static func move_about_attachment(group: Node3D, attachment_local: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = str(group.name) + " pivot"
	var parent := group.get_parent() as Node3D
	parent.add_child(pivot)
	pivot.position = group.position + attachment_local
	group.reparent(pivot, false)
	group.position = -attachment_local
	return pivot



static func add_display_leg(host: Node3D, label: String, hinge: Vector3, foot: Vector3, radius: float, paint: Material) -> Node3D:
	var root := Node3D.new()
	root.name = label
	host.add_child(root)
	root.position = hinge
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("637076")
	steel.metallic = .36
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("252629")
	rubber.roughness = .86
	var leg := CylinderMesh.new()
	leg.top_radius = radius * .17
	leg.bottom_radius = radius * .22
	leg.height = foot.length()
	leg.radial_segments = 10
	leg.rings = 1
	var strut := _part(root, "Strut", leg, steel)
	strut.position = foot * .5
	strut.quaternion = Quaternion(Vector3.UP, foot.normalized())
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = radius
	tyre_mesh.bottom_radius = radius
	tyre_mesh.height = radius * .47
	tyre_mesh.radial_segments = 22
	tyre_mesh.rings = 1
	var tyre := _part(root, "Tyre", tyre_mesh, rubber)
	tyre.position = foot
	tyre.rotation.z = PI / 2.0
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * .48
	hub_mesh.bottom_radius = radius * .48
	hub_mesh.height = radius * .5
	hub_mesh.radial_segments = 16
	hub_mesh.rings = 1
	var hub := _part(root, "Hub", hub_mesh, steel)
	hub.position = foot
	hub.rotation.z = PI / 2.0
	if paint != null:
		var door := BoxMesh.new()
		door.size = Vector3(.05, absf(foot.y) * .70, radius * 1.35)
		var face := _part(root, "Outer visual panel", door, paint)
		face.position = foot * .47 + Vector3(signf(hinge.x) * radius * .27, 0., 0.)
		face.quaternion = strut.quaternion
	return root


static func _part(host: Node3D, label: String, shape: Mesh, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = shape
	result.material_override = material
	host.add_child(result)
	return result
