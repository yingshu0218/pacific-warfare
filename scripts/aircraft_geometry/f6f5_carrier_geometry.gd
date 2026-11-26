class_name F6FCarrierGeometry
extends RefCounted

## Stable CPU geometry. No nodes, scene tree, renderer, clock or simulation writes.
const GEOMETRY_ID: String = "f6f5_carrier_usage_v2"
const MODEL_TO_FLIGHT_M: Vector3 = Vector3(0,-2.30,0)
const HOOK_INSTALLATION_M: Vector3 = Vector3(0,2.43,4.80)
const HOOK_STOWED_ANGLE_RAD: float = 2.0943951023932
const HOOK_FREE_ANGLE_RAD: float = 0.20943951023932
const HOOK_DEFLECTION_LIMIT_RAD: float = 0.698131700797732
const HOOK_CONTACT_LOCAL_M: Vector3 = Vector3(0,-.60,.60)
const HOOK_SHANK_END_M: Vector3 = Vector3(0,-.40,.60)
const HOOK_SHOE_OUTLINE_M: PackedVector2Array = [Vector2(.60,-.35),Vector2(.69,-.48),Vector2(.65,-.60),Vector2(.55,-.60),Vector2(.40,-.49),Vector2(.41,-.42),Vector2(.54,-.52),Vector2(.59,-.52),Vector2(.60,-.46),Vector2(.54,-.39)]
const HOOK_CONTACT_EDGE_M: PackedVector3Array = [Vector3(0,-.60,.55),Vector3(0,-.60,.65)]
const WHEEL_CENTRES_M: Dictionary = {"main_left":Vector3(-1.93,1.30,-1.27),"main_right":Vector3(1.93,1.30,-1.27),"tail":Vector3(0,2.00,4.52)}
const WHEEL_HOSTS: Dictionary = {"main_left":"wing_left","main_right":"wing_right","tail":"tail"}
const WHEEL_RADII_M: Dictionary = {"main_left":.43,"main_right":.43,"tail":.15}
const WHEEL_HALF_WIDTHS_M: Dictionary = {"main_left":.08,"main_right":.08,"tail":.0425}

static func tyre_support(centre: Vector3, axle: Vector3, radius_m: float, half_width_m: float, support_normal: Vector3) -> Vector3:
	var normal: Vector3 = support_normal.normalized()
	var axis: Vector3 = axle.normalized()
	var radial: Vector3 = normal-axis*normal.dot(axis)
	var point: Vector3 = centre
	if radial.length_squared() > .00000001: point -= radial.normalized()*radius_m
	if absf(normal.dot(axis)) > .000001: point -= axis*signf(normal.dot(axis))*half_width_m
	return point

static func configuration(gear_down: bool, hook_down: bool, deflection_rad: float = 0.0, support_normal: Vector3 = Vector3.UP) -> Dictionary:
	if not is_finite(deflection_rad) or not support_normal.is_finite() or support_normal.length_squared() < .00000001: return {}
	var bounded: float = clampf(deflection_rad,0.0,HOOK_DEFLECTION_LIMIT_RAD)
	var angle: float = HOOK_FREE_ANGLE_RAD-bounded if hook_down else HOOK_STOWED_ANGLE_RAD
	var pose: Transform3D = Transform3D(Basis(Vector3.RIGHT,angle),HOOK_INSTALLATION_M)
	var contacts_model: Dictionary = {}
	var contacts_flight: Dictionary = {}
	for id: String in WHEEL_CENTRES_M:
		var point: Vector3 = tyre_support(WHEEL_CENTRES_M[id],Vector3.RIGHT,WHEEL_RADII_M[id],WHEEL_HALF_WIDTHS_M[id],support_normal)
		contacts_model[id] = {"position_m":point,"centre_m":WHEEL_CENTRES_M[id],"radius_m":WHEEL_RADII_M[id],"half_width_m":WHEEL_HALF_WIDTHS_M[id],"host_part_id":WHEEL_HOSTS[id],"available":gear_down}
		contacts_flight[id] = {"position_m":point+MODEL_TO_FLIGHT_M,"centre_m":WHEEL_CENTRES_M[id]+MODEL_TO_FLIGHT_M,"radius_m":WHEEL_RADII_M[id],"half_width_m":WHEEL_HALF_WIDTHS_M[id],"host_part_id":WHEEL_HOSTS[id],"available":gear_down}
	var edge_model: Array[Vector3] = []
	var edge_flight: Array[Vector3] = []
	for point: Vector3 in HOOK_CONTACT_EDGE_M:
		edge_model.append(pose*point)
		edge_flight.append(pose*point+MODEL_TO_FLIGHT_M)
	return {"geometry_id":GEOMETRY_ID,"schema_version":1,"definition_id":"us_f6f5_1944","gear_down":gear_down,"hook_down":hook_down,"hook_deflection_rad":bounded,"hook_angle_rad":angle,"wheel_contacts_model":contacts_model,"wheel_contacts_flight":contacts_flight,"hook_tip_model_m":pose*HOOK_CONTACT_LOCAL_M,"hook_tip_flight_m":pose*HOOK_CONTACT_LOCAL_M+MODEL_TO_FLIGHT_M,"hook_contact_edge_model_m":edge_model,"hook_contact_edge_flight_m":edge_flight,"hook_pivot_model_m":HOOK_INSTALLATION_M,"hook_pivot_flight_m":HOOK_INSTALLATION_M+MODEL_TO_FLIGHT_M,"hook_available":hook_down,"hook_host_part_id":"tail"}

static func parked_transform_flight() -> Transform3D:
	# Three circular tyre contacts solve the level-deck pitch and origin height.
	# The raw body/wing/muzzle geometry and model-to-flight offset never change.
	var delta: Vector3 = WHEEL_CENTRES_M.tail-WHEEL_CENTRES_M.main_left
	var pitch: float = atan2(delta.y,delta.z)+asin((WHEEL_RADII_M.main_left-WHEEL_RADII_M.tail)/Vector2(delta.y,delta.z).length())
	var basis: Basis = Basis(Vector3.RIGHT,pitch)
	var height: float = WHEEL_RADII_M.main_left-(basis*(WHEEL_CENTRES_M.main_left+MODEL_TO_FLIGHT_M)).y
	return Transform3D(basis,Vector3(0,height,0))

static func parked_transform_model() -> Transform3D:
	return parked_transform_flight()*Transform3D(Basis.IDENTITY,MODEL_TO_FLIGHT_M)

static func definition() -> Dictionary:
	var parked: Transform3D = parked_transform_flight()
	var normal: Vector3 = parked.basis.inverse()*Vector3.UP
	return {"geometry_id":GEOMETRY_ID,"schema_version":1,"definition_id":"us_f6f5_1944","units":"metres_radians_seconds","axes":"+X right, +Y up, -Z forward","model_to_flight_translation_m":MODEL_TO_FLIGHT_M,"wheel_centres_model_m":WHEEL_CENTRES_M.duplicate(true),"wheel_radii_m":WHEEL_RADII_M.duplicate(true),"wheel_half_widths_m":WHEEL_HALF_WIDTHS_M.duplicate(true),"wheel_contact_basis":"Support of circular tyres in a supplied aircraft-local deck normal. Level body-axis bottom points are not fixed contact points after pitching.","parked":{"rotation_rad":parked.basis.get_euler(),"origin_height_above_deck_m":parked.origin.y,"contacts":configuration(true,false,0,normal).wheel_contacts_flight,"source":"Solved from three tyre centres/radii; not a world-Y display offset."},"hook_free":configuration(true,true),"hook_stowed":configuration(false,false),"hook_deflection_limit_rad":HOOK_DEFLECTION_LIMIT_RAD,"hook_contact_edge_local_m":[HOOK_CONTACT_EDGE_M[0],HOOK_CONTACT_EDGE_M[1]],"gear_up_contact_proxy":{"kind":"rotating_propeller_disc","center_flight_m":Vector3(0,.22,-4.68),"radius_m":1.995,"normal_flight":Vector3.FORWARD,"sample_points_flight_m":[Vector3(0,-1.775,-4.68),Vector3(-1.995,.22,-4.68),Vector3(1.995,.22,-4.68)],"scope":"Conservative swept propeller disc; not a complete aircraft collision mesh. Visible airframe bounds are measured separately."},"source_status":"Revised simple wheel extension and short hook are engineering approximations constrained by original ground photographs. Old r1-r4 coplanar contacts/OPS parked snapshots are withdrawn; body, wing, muzzle and flight origin unchanged."}
