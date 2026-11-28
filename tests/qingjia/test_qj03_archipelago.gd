extends SceneTree

const SCENE := preload("res://scenes/qingjia/qj03_archipelago.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool,text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)

func _run() -> void:
	var observer := SCENE.instantiate()
	root.add_child(observer)
	var chart: Dictionary = observer.terrain
	var source: Dictionary = chart.source
	expect(chart.id == "qj03_archipelago" and chart.islands.size() == 4,"Own independent four-island data")
	expect(source.islands[0].id == "qingjia_main","Main island first")
	var wide: Vector3 = chart.islands[0].bounds[1] - chart.islands[0].bounds[0]
	for small: Dictionary in chart.islands.slice(1):
		var ext: Vector3 = small.bounds[1]-small.bounds[0]
		expect(wide.x*wide.z/(ext.x*ext.z)>8,"Minor islands visibly smaller")
	var original_mesh: MeshInstance3D = observer.island_view.get_node("IslandTerrain")
	expect(is_instance_valid(original_mesh) and original_mesh.mesh.get_surface_count()==1,"Displayed ground uses terrain")
	expect(chart.max_height_m > 240 and chart.max_height_m < 350,"Distinct main ridge")
	for x: int in range(-770,377,22):
		for z: int in [507,525,544]:
			var p := Vector3(x,0,z)
			expect(TerrainQueries.land_data(chart,p),"Runway belongs to main-island land")
			expect(absf(TerrainQueries.height_data(chart,p)-16.0)<.31,"Flat same-source runway")
	var important := ["quay_wall","berth_north","service_pier","shed_north","cargo_hall","shrine","civil_0_0","hospital_main","fire_station","supply_store","cargo_store_a","cargo_store_d"]
	for solid_id: String in important:
		var found: Dictionary = {}
		for solid: Dictionary in chart.solids:
			if solid.id == solid_id: found = solid; break
		expect(not found.is_empty(),"Chart has "+solid_id)
		if found.is_empty(): continue
		var p: Vector3 = found.center
		var hit := TerrainQueries.hit_data(chart,p+Vector3.UP*100,p,false)
		expect(str(hit.get("target_id","")) == solid_id,"Same-source geometry hits "+solid_id)
	expect(TerrainQueries.land_data(chart,Vector3(636,0,498)) and TerrainQueries.land_data(chart,Vector3(1030,0,163)),"Both civic and service districts on same island")
	expect(not TerrainQueries.land_data(chart,Vector3(1680,0,310)),"Open water beyond harbor")
	expect(observer.island_view.green_count > 950,"Visible forest clusters")
	for i: int in source.viewpoints.size():
		observer.show_view(i)
		expect(observer.camera.position.y > TerrainQueries.height_data(chart,observer.camera.position,true)+.25,"View above ground/buildings")
	print("QJ03_ARCHIPELAGO checks=",checks," failures=",failures," trees=",observer.island_view.green_count," triangles=",chart.triangles.size()," solids=",chart.solids.size())
	quit(0 if failures == 0 else 1)
