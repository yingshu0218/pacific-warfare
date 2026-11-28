class_name BombingAircraftView
extends Node3D

## Pure consumer of motion, actuator and finite-inventory snapshots.
var definition_id: String
var model: Node3D
var sb_bomb: Node3D
var door_angles: Dictionary={}
var fragments: Dictionary={}
var damage_anchors: Dictionary={}
const PART_MAP: Dictionary={"wing_left":"left_wing","wing_right":"right_wing","tail":"tail"}
func _init(id: String) -> void:definition_id=id
func _ready() -> void:
	var path: String="res://aircraft/"+{"us_sb2c4_1944":"sb2c4/sb2c4.gd","jp_d4y2_model12_1944_10":"d4y2/d4y2.gd","jp_g4m1_1942_07":"g4m1/g4m1.gd","us_b25j_1944_07":"b25j/b25j.gd"}[definition_id]
	model=load(path).new();add_child(model)
	if definition_id!="us_sb2c4_1944":
		var name: String="b25j" if "b25j" in definition_id else ("g4m1" if "g4m1" in definition_id else "d4y2")
		var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://aircraft/"+name+"/data/interfaces.json"))
		for marker: Dictionary in contract.markers:
			if marker.id in ["DAMAGE_LEFT_WING_CUT","DAMAGE_WING_LEFT_CUT"]:damage_anchors["wing_left"]=marker.position_m
			elif marker.id in ["DAMAGE_RIGHT_WING_CUT","DAMAGE_WING_RIGHT_CUT"]:damage_anchors["wing_right"]=marker.position_m
			elif marker.id=="DAMAGE_TAIL_CUT":damage_anchors["tail"]=marker.position_m
	if definition_id=="us_sb2c4_1944":
		model.position.y=-2.38
		model.call("set_showcase_configuration",true)
		sb_bomb=model.find_child("One 500 lb general purpose bomb",true,false) as Node3D
		for child: Node in model.get("bay_open_group").get_children():
			if child is Node3D and "door pivot" in str(child.name):door_angles[child]=child.rotation.z
func apply(unit: UnitState) -> void:
	position=unit.position_m;rotation=unit.rotation_rad
	var flight: Dictionary=unit.module_data.get("aircraft_motion",{})
	var rack: Dictionary=unit.module_data.get("bomb_rack",{})
	var mask: Array=[]
	for slot: Dictionary in rack.get("slots",[]):mask.append(bool(slot.loaded))
	var phase: float=float(flight.get("propeller_phase_rad",0.0))
	var damage: Dictionary=unit.module_data.get("damage",{})
	visible=unit.active or str(damage.get("phase","operational")) in ["crashing","wreck"]
	var aileron: float=float(flight.get("aileron_rad",0.0))
	var elevator: float=float(flight.get("elevator_rad",0.0))
	if definition_id=="us_sb2c4_1944":
		model.get("propeller").rotation.z=phase
		model.call("set_landing_gear_deployed",false)
		model.call("set_bomb_bay_open",float(rack.get("bay",0))>0.01)
		model.call("set_dive_brakes_deployed",float(rack.get("brake",0))>0.5)
		for door: Node3D in door_angles:door.rotation.z=float(door_angles[door])*float(rack.get("bay",0))
		if sb_bomb!=null:sb_bomb.visible=not mask.is_empty() and mask[0]
		for surface: Node3D in model.get("animated_surfaces"):
			var label: String=str(surface.name).to_lower()
			if "aileron" in label:surface.rotation.z=aileron*(-1.0 if "port" in label else 1.0)
			elif "elevator" in label:surface.rotation.x=elevator
	elif definition_id=="jp_d4y2_model12_1944_10":
		model.call("apply_visual_state",{"gear":0.,"hook":0.,"bay":rack.get("bay",0.),"crutch":rack.get("crutch",0.),"brake":rack.get("brake",0.),"bomb_visible":not mask.is_empty() and mask[0],"propeller_rad":phase,"aileron_left_rad":aileron,"aileron_right_rad":-aileron,"elevator_left_rad":elevator,"elevator_right_rad":elevator})
	else:
		var state: Dictionary={"gear":0.,"flap":0.,"bomb_visible":mask,"propeller_left_rad":flight.get("propeller_left_phase_rad",phase),"propeller_right_rad":flight.get("propeller_right_phase_rad",phase+0.4),"aileron_left_rad":aileron,"aileron_right_rad":-aileron,"elevator_left_rad":elevator,"elevator_right_rad":elevator}
		if "b25j" in definition_id:state["bay_door"]=rack.get("bay",0.);state["payload_mode"]="bombs_6x500"
		else:state["payload_mode"]="bombs_12x60"
		model.call("apply_visual_state",state)
	if definition_id!="us_sb2c4_1944": _damage(damage)

func _damage(damage: Dictionary) -> void:
	var aircraft: Dictionary=damage.get("aircraft",{})
	var detached: Array=aircraft.get("detached_parts",[])
	var attached: Dictionary={}
	for sim_part: String in PART_MAP:attached[PART_MAP[sim_part]]=sim_part not in detached
	model.call("apply_damage_state",attached)
	var live: Array=[]
	for piece: Dictionary in aircraft.get("fragments",[]):
		var id: String=str(piece.part_id)
		if not PART_MAP.has(id) or live.size()>=AircraftDamageMotion.FRAGMENT_LIMIT:continue
		live.append(id)
		if not fragments.has(id):
			var group: Node3D=Node3D.new();add_child(group);group.top_level=true
			var original: Node3D=model.get("damage_modules")[PART_MAP[id]]
			var part: Node3D=original.duplicate(0) as Node3D
			part.visible=true
			# AV groups have identity body datum; translate by the simulation anchor.
			part.position=-SimData.vec3(damage_anchors[id])
			group.add_child(part);fragments[id]=group
		(fragments[id] as Node3D).global_transform=Transform3D(Basis.from_euler(piece.rotation_rad),piece.position_m)
	for id: String in fragments.keys():
		if id not in live:(fragments[id] as Node3D).queue_free();fragments.erase(id)

func bomb_template(index: int) -> Node3D:
	if definition_id=="us_sb2c4_1944":return sb_bomb
	if definition_id=="jp_d4y2_model12_1944_10":return model.get("bomb_visual")
	return model.get("bomb_visuals")[index]
func slot_position(index: int) -> Vector3:
	if definition_id=="us_sb2c4_1944":return model.find_child("STORE_RELEASE_INTERNAL_BOMB",true,false).global_position
	if definition_id=="jp_d4y2_model12_1944_10":return model.find_child("BOMB_RELEASE",true,false).global_position
	return model.find_child("BOMB_%02d_RELEASE"%index,true,false).global_position
