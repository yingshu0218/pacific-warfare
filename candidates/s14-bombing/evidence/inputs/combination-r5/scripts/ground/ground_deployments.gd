class_name GroundDeployments
extends RefCounted
## Resolve stable S09 site IDs before configure; validate compiled terrain afterwards.
static func expand(scenario: Dictionary, catalog: DefinitionCatalog) -> PackedStringArray:
	var deployments: Array = scenario.get("ground_deployments",[])
	if deployments.is_empty(): return []
	var path: String = str(scenario.get("environment",{}).get("terrain_path",""))
	if path.is_empty(): return ["ground_requires_terrain"]
	var terrain: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not terrain is Dictionary: return ["ground_invalid_terrain"]
	var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ground/models.json"))
	var sites: Dictionary = {}
	for site: Dictionary in terrain.deployment_sites: sites[site.id]=site
	var used: Dictionary = {}
	var spawns: Array = []
	for deployment: Dictionary in deployments:
		var id: String = str(deployment.get("id",""))
		var site_id: String = str(deployment.get("site_id",""))
		var type: String = str(deployment.get("unit_definition_id",""))
		var definition: UnitDefinition = catalog.unit(type)
		if not sites.has(site_id): return ["ground_unknown_site:"+site_id]
		if used.has(site_id): return ["ground_site_occupied:"+site_id]
		if definition==null or definition.domain!="ground" or not specs.has(type): return ["ground_invalid_equipment:"+type]
		var site: Dictionary = sites[site_id]
		var spec: Dictionary = specs[type]
		if spec.role not in site.roles: return ["ground_site_role_mismatch:"+site_id]
		if float(spec.footprint_radius_m)>float(site.radius_m): return ["ground_site_too_small:"+site_id]
		used[site_id]=true
		spawns.append({"id":id,"unit_definition_id":type,"faction_id":deployment.get("faction_id",site.suggested_faction),
			"position_m":site.position_m.duplicate(),"rotation_rad":[0,site.yaw_rad,0],"velocity_mps":[0,0,0],
			"module_data":{"ground_initial":{"site_id":site_id,"role":spec.role,"radius_m":spec.footprint_radius_m,
				"train_limits_deg":site.train_limits_deg.duplicate(),"elevation_limits_deg":site.elevation_limits_deg.duplicate()}}})
	scenario.spawns.append_array(spawns)
	return []

static func validate(world: SimulationWorld) -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: String in world.unit_ids():
		var unit: UnitState = world.get_unit(id)
		if world.unit_definition(unit.definition_id).domain!="ground": continue
		var site: Dictionary = unit.module_data.get("ground_initial",{})
		if site.is_empty(): errors.append("ground_missing_site:"+id);continue
		var radius: float = float(site.radius_m)
		for sample: int in range(17):
			var at: Vector3 = unit.position_m
			if sample>0: at+=Vector3(cos(TAU*sample/16.0),0,sin(TAU*sample/16.0))*radius
			if not TerrainQueries.is_land(world,at): errors.append("ground_off_land:"+id);break
			if absf(TerrainQueries.height_m(world,at)-unit.position_m.y)>.035: errors.append("ground_uneven_or_unsupported:"+id);break
			if TerrainQueries.height_m(world,at,true)>unit.position_m.y+.05: errors.append("ground_obstructed_host:"+id);break
		for mount: MountSocket in world.unit_definition(unit.definition_id).mounts:
			var gun: WeaponDefinition = world.weapon_definition(mount.weapon_definition_id)
			var low: float = maxf(gun.elevation_limits_rad.x,deg_to_rad(float(site.elevation_limits_deg[0])))
			var high: float = minf(gun.elevation_limits_rad.y,deg_to_rad(float(site.elevation_limits_deg[1])))
			if low>high: errors.append("ground_empty_elevation_arc:"+id)
			for train: float in [deg_to_rad(float(site.train_limits_deg[0])),0.0,deg_to_rad(float(site.train_limits_deg[1]))]:
				var muzzle: Vector3 = unit.world_transform()*mount.local_muzzle_transform(0,train,low).origin
				if muzzle.y <= TerrainQueries.height_m(world,muzzle,true)+.1: errors.append("ground_buried_muzzle:"+id)
	return errors
