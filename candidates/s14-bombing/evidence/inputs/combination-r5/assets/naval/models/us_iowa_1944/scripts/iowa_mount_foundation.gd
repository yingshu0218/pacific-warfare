class_name IowaMountFoundation
extends Node3D

const GEOMETRY = preload("iowa_geometry.gd")

var station_id: String = ""
var foundation_type: String = ""
var foundation_height_m: float = 0.0
var weapon_seat: Marker3D
var interface_size_m: float = 0.0
var compatible_interface: String = ""

func configure(record: Dictionary, palette: Dictionary) -> void:
	station_id = str(record.get("id", "unknown_station"))
	var mount_type: String = str(record.get("type", "main_16in"))
	var default_height: float = 0.0
	var default_diameter: float = 0.0
	var default_name: String = ""
	match mount_type:
		"main_16in":
			default_height = float(record.get("barbette_height", 0.0))
			default_diameter = float(record.get("foundation_interface_diameter_m", 14.0))
			default_name = "16in_barbette"
			compatible_interface = "main_16in_turret_seat"
		"secondary_5in":
			default_height = 0.64
			default_diameter = 4.0
			default_name = "5in_twin_mount_ring"
			compatible_interface = "secondary_5in_twin_seat"
		"bofors_40mm":
			default_height = 0.28
			default_diameter = 2.1
			default_name = "40mm_quad_mount_ring"
			compatible_interface = "bofors_40mm_quad_seat"
		"oerlikon_20mm":
			default_height = 0.24
			default_diameter = 0.76
			default_name = "20mm_single_mount_foot"
			compatible_interface = "oerlikon_20mm_single_seat"
		_:
			push_error("No foundation interface defined for mount type %s" % mount_type)
			return
	foundation_type = str(record.get("foundation_type", default_name))
	foundation_height_m = float(record.get("foundation_height_m", default_height))
	interface_size_m = float(record.get("foundation_interface_diameter_m", default_diameter))
	name = "Foundation_%s" % station_id
	set_meta("station_id", station_id)
	set_meta("foundation_type", foundation_type)
	set_meta("compatible_interface", compatible_interface)
	set_meta("interface_size_m", interface_size_m)
	set_meta("foundation_height_m", foundation_height_m)
	set_meta("source_status", str(record.get("source_status", "provisional visual estimate")))
	set_meta("confidence", str(record.get("confidence", "low")))
	if foundation_height_m <= 0.0:
		push_error("Foundation height must be positive for %s" % station_id)
		return
	var side_count: int = 32 if mount_type == "main_16in" else (24 if mount_type == "secondary_5in" else 20)
	var foundation_material: Material = palette.barbettes if mount_type == "main_16in" else palette.deck_detail
	GEOMETRY.add_cylinder(self, "FoundationBody_%s" % station_id, Vector3(0.0, foundation_height_m * 0.5, 0.0), interface_size_m * 0.5, foundation_height_m, foundation_material, side_count)
	weapon_seat = Marker3D.new()
	weapon_seat.name = "WeaponSeat"
	weapon_seat.position.y = foundation_height_m
	weapon_seat.set_meta("station_id", station_id)
	weapon_seat.set_meta("interface", compatible_interface)
	weapon_seat.set_meta("interface_size_m", interface_size_m)
	add_child(weapon_seat)

