class_name CombatFrame
extends SimulationModule

var config: CombatConfig
var starts: Dictionary = {}
var proxies: Dictionary = {}
var definitions: Dictionary = {}
var bounds: Dictionary = {}
var guns: Dictionary = {}
var ammunition: Dictionary = {}

func _init(parameters: CombatConfig) -> void:
	module_id = "combat_frame"
	priority = 80
	config = parameters

func reset(world_ref: RefCounted) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	starts.clear()
	proxies.clear()
	definitions.clear()
	bounds.clear()
	guns.clear()
	ammunition.clear()
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		var definition: UnitDefinition = world.unit_definition(unit.definition_id)
		definitions[id] = definition
		starts[id] = unit.world_transform()
		var profile: Dictionary = config.unit_profile(unit.definition_id)
		var boxes: Array = profile.get("boxes", []).duplicate(true)
		for mount: MountSocket in definition.mounts:
			var gun: WeaponDefinition = world.weapon_definition(mount.weapon_definition_id)
			gun.ammo_id = str(config.data.weapon_profiles[gun.id].get("ammo_id", gun.ammo_id))
			guns[gun.id] = gun
			ammunition[gun.ammo_id] = config.effective_ammo(world, gun.ammo_id)
			var caliber: float = (ammunition[gun.ammo_id] as AmmoDefinition).caliber_m
			if definition.domain == "aircraft":
				continue
			var half_size: Vector3 = Vector3(0.8, 0.7, 1.0)
			if caliber > 0.3:
				half_size = Vector3(6.2, 2.4, 6.5)
			elif caliber > 0.1:
				half_size = Vector3(2.6, 1.5, 2.5)
			var weapon_profile: Dictionary = config.data.weapon_profiles[gun.id]
			if weapon_profile.has("proxy_half_extents_m"):
				half_size = SimData.vec3(weapon_profile.proxy_half_extents_m)
			var armor: float = float(profile.get("weapon_armor_mm", 12.0)) if caliber > 0.1 else 2.0
			if caliber > 0.3:
				armor = float(profile.get("main_weapon_armor_mm", armor))
			boxes.append({"part": "weapon:" + mount.id, "center_m": SimData.array3(mount.position_m + Vector3.UP * half_size.y), "half_extents_m": SimData.array3(half_size), "armor_mm": armor})
		proxies[id] = boxes
		var bound: float = 1.0
		for box: Dictionary in boxes:
			bound = maxf(bound, SimData.vec3(box.center_m).length() + SimData.vec3(box.half_extents_m).length())
		bounds[id] = bound

## Keep the remaining fuselage interceptable; discarded visual debris has no combat proxy.
func remove_aircraft_part(unit_id: String, part_id: String) -> void:
	var retained: Array = []
	for box: Dictionary in proxies[unit_id]:
		if str(box.part) != part_id: retained.append(box)
	proxies[unit_id] = retained


func fixed_update(world_ref: RefCounted, _delta_s: float) -> void:
	var world: SimulationWorld = world_ref as SimulationWorld
	for id: String in world.unit_ids():
		starts[id] = world.get_unit(id).world_transform()

func snapshot_state() -> Dictionary:
	var positions: Dictionary = {}
	for id: String in starts:
		positions[id] = (starts[id] as Transform3D).origin
	return {"start_positions_m": positions}
