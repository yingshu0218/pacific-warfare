extends SceneTree
const TEXT: Script=preload("res://scripts/showcase/training_labels.gd")
var checks: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: push_error("S14 UI contract "+label)
func run() -> void:
	var units: Dictionary={"pilot":{"task":{},"module_data":{}}}
	var orders: Array[Dictionary]=[{"order_id":"new","status":"issued","reason":"queued","execution":{}}]
	check(TEXT.view(units,orders,"pilot","new").status!="completed","receipt/queued order cannot announce completion")
	orders[0].status="completed";orders[0].execution={"pilot":{"status":"completed","reason":"training_geometry_complete"}}
	units.pilot.module_data.aircraft_training={"order_id":"old","phase":"completed","status":"completed","maneuver":"axial_roll","peak_roll_rad":TAU}
	check(TEXT.view(units,orders,"pilot","new").status!="completed","stale completed training cannot satisfy new order")
	units.pilot.module_data.aircraft_training.order_id="new"
	check(TEXT.view(units,orders,"pilot","new").status=="completed","matched actual per-unit state can announce completion")
	orders[0].status="failed";orders[0].reason="training_insufficient_start_agl:pilot";orders[0].execution={"pilot":{"status":"failed","reason":"training_insufficient_start_agl:pilot"}}
	check(TEXT.view(units,orders,"pilot","new").label.contains("离地高度不足"),"qualified rejection reason is readable Chinese")
	check(TEXT.reason("training_safety:terrain_recovery:pilot").contains("地形避让"),"safety reason is readable Chinese")
	var dir: String="res://docs/showcase/evidence/S14/final"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file: FileAccess=FileAccess.open(dir.path_join("ui_contract.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks},"\t"))
	quit(0 if checks.all(func(v: Dictionary) -> bool:return v.passed) else 1)
