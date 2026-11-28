extends SceneTree

const PLAY := preload("res://showcase/qingjia_geography.tscn")
const CHART := "res://data/maps/qj02_geography.json"
const MAP_ID := "qj02_geography"
const WEST := Vector3(1300, 0, -2580)
const EAST := Vector3(4780, 0, -2410)

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var level := PLAY.instantiate() as FirstPlayableGame
	root.add_child(level)
	_check(level.running, "Playable runtime loaded")
	if not level.running:
		quit(1)
		return
	level.set_process(false)
	var world := level.session.world
	var chart: Dictionary = world.shared_state.terrain
	_check(level.session.scenario.environment.terrain_path == CHART, "Selected chart")
	_check(chart.source.id == MAP_ID and level.map_view.terrain.source.id == MAP_ID, "Display and world use the same chart")
	_check(chart.islands.size() == 8, "Seven source islands, headland, and one opposing new island")
	_check(TerrainQueries.height_data(chart, WEST) > 350.0 and TerrainQueries.height_data(chart, EAST) > 375.0, "Recognizable high flanks")
	for z: int in range(-4100,-2020,210):
		_check(TerrainQueries.land_data(chart,Vector3(1480,0,z)), "West headland is continuously attached to harbor island")
	var ridge_hit := TerrainQueries.hit_data(chart, WEST + Vector3.UP*950.0, WEST - Vector3.UP*15.0, true)
	_check(ridge_hit.get("target_id","") == "north_east" and ridge_hit.get("surface","") == "ground", "New ridge in gameplay terrain collision")
	_check(ridge_hit.has("position_m") and is_equal_approx((ridge_hit.get("position_m",Vector3.ZERO) as Vector3).y, TerrainQueries.height_data(chart, WEST)), "Collision height equals display input")
	for z: int in range(-4150, 1250, 200):
		_check(not TerrainQueries.land_data(chart, Vector3(3250,0,z)), "Continuous open water in fjord at z=%d" % z)
	var harbor_water := TerrainQueries.hit_data(chart, Vector3(3250,150,-3820), Vector3(3250,-20,-3820), true)
	_check(harbor_water.get("surface","") == "sea", "Sea level remains a collision surface inside port")
	for z: int in range(-3040,-1730,75):
		var p := Vector3(6900, 0, z)
		_check(TerrainQueries.land_data(chart,p) and absf(TerrainQueries.height_data(chart,p)-8.0) < .2, "Flat runway height at z=%d" % z)
	_check(level.map_view.has_node("HarborTown") and level.map_view.has_node("RunwayShoulders"), "Town and airport instantiated")
	_check(int(level.map_view.statistics.get("moored_scenery_ships",0)) == 2, "Two static berthing models")
	_check(int(level.map_view.statistics.get("civilian_silhouettes",0)) == 15, "Civilian ambient set on street")
	var town: Dictionary = level.map_view.statistics.get("harbor_town",{})
	_check(int(town.get("homes",0)) >= 20 and int(town.get("shops",0)) >= 12, "Grounded town retains its original shops and homes")
	_check(float(town.get("max_main_grade",INF)) < 0.37, "Town main street remains navigable")
	_check(TerrainQueries.height_data(chart,Vector3(2224,0,-4918)) < 51.0, "Western peninsula does not bury the lower street")
	print("QJ02_TOWN ", town)
	var seen: Dictionary = {}
	for id: String in world.unit_ids():
		var state: UnitState = world.get_unit(id)
		var definition: UnitDefinition = level.session.catalog.unit(state.definition_id)
		seen[definition.domain] = true
		if definition.domain == "ship":
			_check(not TerrainQueries.land_data(chart,state.position_m), "Runtime ship on water: " + id)
	_check(seen.has("ship") and seen.has("aircraft") and seen.has("ground"), "Sea, air and ground test actors loaded")
	var before: int = world.tick
	world.set_paused(false)
	level.session.advance(.25, 16)
	_check(world.tick > before, "Battle advances on revised map")
	print("QJ02_GEOGRAPHY checks=", checks, " failures=", failures, " actors=", world.unit_ids().size(), " terrain_triangles=", chart.triangles.size())
	level.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
