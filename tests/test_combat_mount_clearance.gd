extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("yamato","jp",Vector3.ZERO,"jp_yamato_1944_04"),FIX.spawn("iowa","us",Vector3(2000,0,0),"us_iowa_bb61_1944_12_28"),FIX.spawn("fletcher","us",Vector3(4000,0,0),"us_fletcher_dd445_1942_07_18"),FIX.spawn("yukikaze","jp",Vector3(6000,0,0),"jp_yukikaze_1942_06")])
	for id: String in a.world.unit_ids():
		for mount: MountSocket in (a.frame.definitions[id] as UnitDefinition).mounts:
			var gun: WeaponDefinition=a.frame.guns[mount.weapon_definition_id]
			var possible: bool=false
			for train: float in [-135.,-90.,-45.,0.,45.,90.,135.]:
				if deg_to_rad(train)<gun.train_limits_rad.x or deg_to_rad(train)>gun.train_limits_rad.y:continue
				for elevation: float in [5.,15.,30.,45.,60.,80.]:
					if deg_to_rad(elevation)<gun.elevation_limits_rad.x or deg_to_rad(elevation)>gun.elevation_limits_rad.y:continue
					var muzzle: Transform3D=mount.local_muzzle_transform(0,deg_to_rad(train),deg_to_rad(elevation))
					var pivot: Vector3=mount.position_m+Basis(Vector3.UP,mount.base_yaw_rad+deg_to_rad(train))*mount.elevation_pivot_m
					if not CombatGeometry.masked(pivot,muzzle.origin,a.frame.proxies[id],"weapon:"+mount.id) and not CombatGeometry.masked(muzzle.origin,muzzle.origin-muzzle.basis.z*400,a.frame.proxies[id],"weapon:"+mount.id):possible=true
			expect(possible,"Actual "+id+"/"+mount.id+" has a mechanically legal unobstructed firing direction; proxies cannot permanently mask a real gun")
	finish("all mount clearance")
