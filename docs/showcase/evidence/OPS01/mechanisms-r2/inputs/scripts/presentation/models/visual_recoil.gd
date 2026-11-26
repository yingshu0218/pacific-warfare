class_name VisualRecoil
extends RefCounted

## Only gun visual meshes move. Installation axes and simulation/model muzzle markers stay fixed.
## Existing Yamato merged gun meshes recoil as a mount; independent Iowa/DD axes stay independent.
var mounts: Dictionary = {}
var generation: int = -1
var last_sequence: int = 0
var triggered: int = 0

func bind_model(model: Node3D) -> void:
	mounts.clear()
	var visuals: Variant = model.get("mount_visuals")
	if not visuals is Dictionary: return
	for id: String in visuals:
		var record: Variant = visuals[id]
		if not record is Dictionary: continue
		var axes: Array = record.get("elevation_axes", [])
		if record.has("weapon"): axes = record.weapon.elevation_axes
		if record.has("recoil_axes"): axes=record.recoil_axes
		var pieces: Array[Dictionary] = []
		for index: int in range(axes.size()):
			var axis: Node3D = axes[index]
			for mesh: Node in axis.find_children("*", "MeshInstance3D", true, false):
				var node: Node3D = mesh as Node3D
				var direction: Vector3 = node.get_parent_node_3d().global_basis.inverse() * axis.global_basis.z
				pieces.append({"node":node, "rest":node.position, "direction":direction, "barrel":index})
		mounts[id] = {"pieces":pieces, "axes":axes.size(), "pulses":{},"stroke":float(record.get("recoil_stroke_m",-1.0))}

func consume(events: Array[BattleEvent], entity_id: String, new_generation: int) -> void:
	if generation != new_generation: reset(new_generation)
	for event: BattleEvent in events:
		if event.sequence <= last_sequence: continue
		last_sequence = event.sequence
		if event.kind != "fired" or event.entity_id != entity_id: continue
		var id: String = event.weapon_id.get_slice("/", 1)
		if not mounts.has(id): continue
		var record: Dictionary = mounts[id]
		var barrel: int = int(event.data.get("barrel_index", 0)) if int(record.axes) > 1 else 0
		record.pulses[barrel] = {"age":0.0, "stroke":clampf(float(event.data.get("caliber_m", 0.1)) * 2.2, 0.025, 1.05)}
		if float(record.stroke)>0.0: record.pulses[barrel].stroke=record.stroke
		triggered += 1

func advance(simulation_delta_s: float) -> void:
	for record: Dictionary in mounts.values():
		for barrel: int in record.pulses:
			var pulse: Dictionary = record.pulses[barrel]
			pulse.age += maxf(0.0, simulation_delta_s)
		for piece: Dictionary in record.pieces:
			var offset: float = 0.0
			var pulse: Dictionary = record.pulses.get(piece.barrel, {})
			if not pulse.is_empty():
				var age: float = float(pulse.age)
				var fraction: float = minf(1.0, age / 0.055) if age < 0.055 else maxf(0.0, 1.0 - (age - 0.055) / 0.65)
				offset = float(pulse.stroke) * fraction
			(piece.node as Node3D).position = piece.rest + (piece.direction as Vector3) * offset
		for barrel: int in record.pulses.keys():
			if float(record.pulses[barrel].age) > 0.705: record.pulses.erase(barrel)

func reset(new_generation: int) -> void:
	generation = new_generation
	last_sequence = 0
	triggered = 0
	for record: Dictionary in mounts.values():
		record.pulses.clear()
		for piece: Dictionary in record.pieces: (piece.node as Node3D).position = piece.rest
