extends Node3D

## The same readonly presentation sample as aircraft/rack slots and cameras.
## No integration or writes to physical rounds; a budget never changes simulation.
const CAPACITY: int = 96
var visuals: Dictionary = {}
var generation: int = -1

func present(session: FirstPlayableSession, models: Dictionary) -> void:
	if generation != session.world.generation:
		clear();generation = session.world.generation
	var rounds: Dictionary = session.presentation_bombs
	for id: String in visuals.keys():
		if not rounds.has(id): (visuals[id] as Node3D).free();visuals.erase(id)
	for id: String in rounds:
		var round: Dictionary = rounds[id]
		if not visuals.has(id):
			if visuals.size() >= CAPACITY or not models.has(round.entity_id): continue
			var source: Node3D = models[round.entity_id]
			if not source.has_method("bomb_template"): continue
			var template: Node3D = source.bomb_template(round.slot)
			if template == null: continue
			var body: Node3D = template.duplicate(0) as Node3D
			body.transform = Transform3D.IDENTITY;body.visible = true
			add_child(body);visuals[id] = body
		(visuals[id] as Node3D).transform = Transform3D(Basis.from_euler(round.rotation_rad),round.position_m)

func clear() -> void:
	for value: Node3D in visuals.values(): value.free()
	visuals.clear()
