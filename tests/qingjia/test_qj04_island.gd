extends SceneTree
const PREVIEW := preload("res://scenes/qingjia/qj04_island.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var map := PREVIEW.instantiate()
	root.add_child(map)
	var chart: Dictionary = map.terrain
	var source: Dictionary = chart.source
	var seen := {}
	var remaining: Array = source.roads.duplicate()
	var first: Dictionary = remaining.pop_front()
	for row: Array in first.points_m:
		seen[SimData.vec3(row)] = true
	var changed := true
	while changed:
		changed = false
		for i: int in range(remaining.size()-1,-1,-1):
			var road: Dictionary = remaining[i]
			if not road.points_m.any(func(p:Array)->bool: return seen.has(SimData.vec3(p))):
				continue
			remaining.remove_at(i)
			changed = true
			for p: Array in road.points_m:
				seen[SimData.vec3(p)] = true
	expect(chart.islands.size()==4 and source.roads.size()==24 and remaining.is_empty(),"All 24 paths connect within the main island network")
	var facades := {}
	for obj: Dictionary in source.objects:
		if not obj.has("frontage_m"): continue
		var at := SimData.vec3(obj.position_m)
		var facing := Basis(Vector3.UP,obj.heading_rad)*Vector3.BACK
		var off := SimData.vec3(obj.frontage_m) - at
		off.y = 0.
		expect(facing.dot(off.normalized())>.995,"Facade faces street: " + obj.id)
		expect(TerrainQueries.land_data(chart,at) and TerrainQueries.land_data(chart,SimData.vec3(obj.frontage_m)), "Street parcel on main island")
		facades[roundi(rad_to_deg(obj.heading_rad))]=true
	expect(facades.size()>=16 and map.island_view.statistics.frontage_houses==84,"Streets do not all share a building orientation")
	for id: String in ["shrine_honden","shrine_haiden","shrine_office","shrine_store",
			"upland_weather","upland_keeper","upland_water_house","upland_rest",
			"east_reclamation","quay_extension_n","east_cargo_annex","hospital_main","fire_station","supply_store"]:
		expect(chart.solids.any(func(v:Dictionary)->bool: return v.id==id),"Compiled chart contains "+id)
	expect(map.island_view.statistics.canvas_tents == 8,"Eight individually shaped canvas tents")
	expect(map.island_view.statistics.small_support == 3,"Three support cottages")
	expect(map.island_view.statistics.traditional_halls == 3,"Three larger timber/tile halls")
	for row: Dictionary in source.objects:
		var style := str(row.get("style",""))
		if style not in ["canvas_tent","camp_one","camp_two","wood_hall"]:
			continue
		var at := SimData.vec3(row.position_m)
		expect(TerrainQueries.land_data(chart,at),"Campus scenery stands on main-island terrain: "+row.id)
		expect(TerrainQueries.height_data(chart,at) <= at.y+.15, "Campus footing sits at terrain grade: "+row.id)
		if style == "wood_hall":
			expect(float(row.visual_size_m[0]) >= 21.0,"Traditional larger building is distinguishable")
	var port := TerrainQueries.hit_data(chart,Vector3(1199,30,198),Vector3(1199,-5,198),true)
	expect(str(port.get("target_id",""))=="east_reclamation" and float(port.position_m.y)>5.,"Concrete extension is a contiguous solid surface")
	var props: Node3D = map.island_view.get_node("StaticCoastalScenery")
	expect(props.get_child_count()==2 and props.find_children("*","CollisionObject3D",true,false).is_empty(),"Two non-interactive shore exhibits")
	for i: int in range(source.viewpoints.size()):
		map.show_view(i)
		expect(map.camera.position.y>TerrainQueries.height_data(chart,map.camera.position,true)+.3,"Observation camera stays above terrain")
	print("QJ04_ISLAND checked=",checks," failures=",failures," roads=",source.roads.size()," facades=",facades.size()," houses=",map.island_view.statistics.frontage_houses)
	quit(0 if failures==0 else 1)

func expect(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
