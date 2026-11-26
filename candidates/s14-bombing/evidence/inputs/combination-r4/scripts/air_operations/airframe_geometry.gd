class_name CarrierAirframeGeometry
extends RefCounted

## CPU-only consumer of the accepted helper plus offline mesh support hulls.
## Public aircraft sources are not installed by this module: use the OPS stage.
var helper: Script
var definition: Dictionary
var hulls: Dictionary = {}
var cache: Dictionary = {}
var stopped_propeller: Dictionary = {}

func _init() -> void:
	helper = load("res://scripts/aircraft_geometry/f6f5_carrier_geometry.gd") as Script
	assert(helper != null,"OPS01 real-model tests require the isolated prepared stage")
	definition = helper.call("definition")
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/air_operations/model_contact_proxy.json"))
	stopped_propeller = records.stopped_propeller
	for mode: String in records.states:
		hulls[mode] = {}
		for host: String in records.states[mode]:
			var points: PackedVector3Array = []
			for row: Array in records.states[mode][host]: points.append(SimData.vec3(row))
			hulls[mode][host] = points

func parked_pose() -> Transform3D:
	return helper.call("parked_transform_flight")

func configuration(state: Dictionary, basis: Basis, damage: Dictionary = {}) -> Dictionary:
	var value: Dictionary = helper.call("configuration",bool(state.get("gear_down",false)),bool(state.get("hook_down",false)),float(state.get("hook_deflection_rad",0.0)),basis.inverse()*Vector3.UP)
	for row: Dictionary in value.wheel_contacts_flight.values(): row.available = bool(row.available) and present(str(row.host_part_id),damage)
	value.hook_available = bool(value.hook_available) and present(str(value.hook_host_part_id),damage)
	return value

func present(host: String, damage: Dictionary) -> bool:
	return host not in damage.get("aircraft",{}).get("detached_parts",[]) and float(damage.get("parts",{}).get(host,1.0)) > 0.0

func wheel_features(basis: Basis, state: Dictionary, damage: Dictionary = {}) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var value: Dictionary = configuration(state,basis,damage)
	for id: String in value.wheel_contacts_flight:
		var row: Dictionary = value.wheel_contacts_flight[id]
		if row.available: rows.append({"id":"wheel:"+id,"point_m":row.position_m,"host":row.host_part_id,"kind":"wheel"})
	return rows

func body_features(basis: Basis, state: Dictionary, damage: Dictionary = {}) -> Array[Dictionary]:
	var normal: Vector3 = basis.inverse()*Vector3.UP
	var mode: String = "landing" if bool(state.get("flaps_down",false)) else "clean"
	var key: String = "%s:%.7f:%.7f:%.7f"%[mode,normal.x,normal.y,normal.z]
	if not cache.has(key):
		var result: Array[Dictionary] = []
		for host: String in hulls[mode]:
			var minimum: float = INF
			var lowest: Vector3 = Vector3.ZERO
			for point: Vector3 in hulls[mode][host]:
				var distance: float = normal.dot(point)
				if distance < minimum: minimum = distance; lowest = point
			result.append({"id":"mesh:"+host,"point_m":lowest,"host":host,"kind":"body"})
		var proxy: Dictionary = definition.gear_up_contact_proxy
		var axis: Vector3 = proxy.normal_flight
		var radial: Vector3 = normal-axis*normal.dot(axis)
		var support: Vector3 = proxy.center_flight_m
		if radial.length_squared() > 0.00000001: support -= radial.normalized()*float(proxy.radius_m)
		result.append({"id":"propeller_disc","point_m":support,"host":"body","kind":"body"})
		if cache.size() > 512: cache.clear()
		cache[key] = result
	var rows: Array[Dictionary] = []
	for row: Dictionary in cache[key]:
		if present(str(row.host),damage): rows.append(row)
	return rows

func features(basis: Basis, state: Dictionary, damage: Dictionary = {}) -> Array[Dictionary]:
	var rows: Array[Dictionary] = wheel_features(basis,state,damage)
	rows.append_array(body_features(basis,state,damage))
	return rows

func resting_features(basis: Basis, state: Dictionary, damage: Dictionary, propeller_phase_rad: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = wheel_features(basis,state,damage)
	for row: Dictionary in body_features(basis,state,damage):
		if row.id != "propeller_disc": rows.append(row)
	if present("body",damage):
		var spin: Basis = Basis(Vector3.BACK,propeller_phase_rad)
		var normal: Vector3 = basis.inverse()*Vector3.UP
		var minimum: float = INF
		var lowest: Vector3 = Vector3.ZERO
		var center: Vector3 = SimData.vec3(stopped_propeller.center_flight_m)
		for value: Array in stopped_propeller.points:
			var point: Vector3 = center+spin*SimData.vec3(value)
			if normal.dot(point) < minimum:
				minimum = normal.dot(point); lowest = point
		rows.append({"id":"stopped_propeller","point_m":lowest,"host":"body","kind":"body"})
	return rows

func resting_cloud(basis: Basis, state: Dictionary, damage: Dictionary, propeller_phase_rad: float) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var mode: String = "landing" if bool(state.get("flaps_down",false)) else "clean"
	for host: String in hulls[mode]:
		if present(host,damage): result.append_array(hulls[mode][host])
	if present("body",damage):
		var spin: Basis = Basis(Vector3.BACK,propeller_phase_rad)
		var center: Vector3 = SimData.vec3(stopped_propeller.center_flight_m)
		for value: Array in stopped_propeller.points: result.append(center+spin*SimData.vec3(value))
	for row: Dictionary in wheel_features(basis,state,damage): result.append(row.point_m)
	return result

func support_height(basis: Basis, state: Dictionary, damage: Dictionary = {}) -> float:
	var minimum: float = INF
	for row: Dictionary in wheel_features(basis,state,damage): minimum = minf(minimum,(basis*(row.point_m as Vector3)).y)
	return -minimum

func hook_at(origin: Vector3, basis: Basis, state: Dictionary, damage: Dictionary, deck_height: float) -> Dictionary:
	var free: Dictionary = state.duplicate(true); free.hook_deflection_rad = 0.0
	var value: Dictionary = configuration(free,basis,damage)
	if not value.hook_available: return {"available":false,"deflection_rad":0.0}
	var target: float = deck_height+0.02
	var low: float = 0.0
	var high: float = float(definition.hook_deflection_limit_rad)
	var free_tip: Vector3 = origin+basis*(value.hook_tip_flight_m as Vector3)
	if free_tip.y < target:
		for i: int in 20:
			var middle: float = (low+high)*0.5
			free.hook_deflection_rad = middle
			var probe: Dictionary = configuration(free,basis,damage)
			var minimum: float = INF
			for point: Vector3 in probe.hook_contact_edge_flight_m: minimum = minf(minimum,(origin+basis*point).y)
			if minimum < target: low = middle
			else: high = middle
	else: high = 0.0
	free.hook_deflection_rad = high
	value = configuration(free,basis,damage)
	var edge: Array[Vector3] = []
	for point: Vector3 in value.hook_contact_edge_flight_m: edge.append(origin+basis*point)
	return {"available":true,"deflection_rad":high,"free_tip_m":free_tip,"tip_m":origin+basis*(value.hook_tip_flight_m as Vector3),"edge_m":edge}
