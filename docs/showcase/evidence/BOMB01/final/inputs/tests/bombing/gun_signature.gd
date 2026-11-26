extends SceneTree
const FIX: Script=preload("res://tests/fixtures/combat_fixture.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a: Dictionary=FIX.arena([FIX.spawn("shooter","us",Vector3(100,120,0)),FIX.spawn("target","jp",Vector3(0,120,-180))])
	a.launcher.pending.assign([{"position":Vector3(0,120,0),"ammo":"us_127mm_m2_ball","direction":Vector3.FORWARD},{"position":Vector3(15,100,-180),"ammo":"us_127mm_5in38_shell","direction":Vector3.UP,"speed":10.,"gravity":0.,"fuze":.1}])
	a.world.step_ticks(600)
	var events: Array=[]
	for event: BattleEvent in a.world.drain_events(): events.append(event.snapshot())
	var records: Dictionary={"events":events,"units":a.world.snapshot().units,"rng":a.world.rng.state,"launched":a.projectiles.next_id,"terminated":a.projectiles.terminated}
	var out: String="res://.local/gun_signature.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f: FileAccess=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(_plain(records)));f.close()
	quit()
func _plain(value: Variant) -> Variant:
	if value is Vector3:return SimData.array3(value)
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value:result[str(key)]=_plain(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value:result.append(_plain(item))
		return result
	return value
