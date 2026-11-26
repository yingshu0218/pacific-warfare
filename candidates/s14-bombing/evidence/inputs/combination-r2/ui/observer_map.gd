class_name ObserverMap
extends Control

signal unit_selected(id: String)
signal point_selected(id: String)
var terrain: Dictionary = {}
var locations: Dictionary = {}
var units: Dictionary = {}
var domains: Dictionary = {}
var markers: Dictionary = {}
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func apply_view(views: Dictionary, definitions: Dictionary) -> void:
	units = views
	domains = definitions
	queue_redraw()

func _draw() -> void:
	draw_style_box(_style(), Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(12, 23), "观众态势 · 双方", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9e9ee"))
	markers = {}
	var active: Array[Dictionary] = []
	for view: Dictionary in units.values():
		if view.active: active.append(view)
	if active.is_empty(): return
	var bounds: Rect2 = Rect2(Vector2(active[0].position_m.x, active[0].position_m.z), Vector2.ZERO)
	for view: Dictionary in active: bounds = bounds.expand(Vector2(view.position_m.x, view.position_m.z))
	var scale_value: float = maxf(6000.0, maxf(bounds.size.x, bounds.size.y) * 1.2)
	var origin: Vector2 = bounds.get_center()
	if not terrain.is_empty():
		var map_bounds: Array = terrain.bounds_m
		scale_value = maxf(float(map_bounds[2]),float(map_bounds[3]))
		origin = Vector2(float(map_bounds[0])+float(map_bounds[2])*.5,float(map_bounds[1])+float(map_bounds[3])*.5)
	var extent: float = minf(size.x - 30, size.y - 60)
	var center: Vector2 = Vector2(size.x * 0.5, (size.y + 24) * 0.5)
	locations.clear()
	for island: Dictionary in terrain.get("islands", []):
		var polygon: PackedVector2Array = PackedVector2Array()
		for p: Vector3 in island.outline: polygon.append(center+(Vector2(p.x,p.z)-origin)*extent/scale_value)
		draw_colored_polygon(polygon,Color("73866c"))
		draw_polyline(polygon,Color("b1bb92"),1.0)
	for point: Dictionary in terrain.get("source", {}).get("viewpoints", []):
		if point.id == "overview": continue
		var p: Vector3 = SimData.vec3(point.focus_m)
		var icon: Vector2 = center+(Vector2(p.x,p.z)-origin)*extent/scale_value
		locations[point.id]=icon
		draw_circle(icon,2.5,Color("d0d4a6"))
	draw_string(font,Vector2(size.x-30,43),"北",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d7db"))
	draw_line(center - Vector2(extent * 0.5, 0), center + Vector2(extent * 0.5, 0), Color(0.5, 0.7, 0.75, 0.22))
	draw_line(center - Vector2(0, extent * 0.5), center + Vector2(0, extent * 0.5), Color(0.5, 0.7, 0.75, 0.22))
	for view: Dictionary in active:
		var point: Vector2 = center + (Vector2(view.position_m.x, view.position_m.z) - origin) * extent / scale_value
		markers[view.id] = point
		var color: Color = Color("ecb28e") if view.faction_id == "jp" else Color("8fccea")
		if domains.get(view.id, {}).get("domain", "ship") == "aircraft":
			draw_polyline(PackedVector2Array([point + Vector2(-4, 3), point + Vector2(0, -4), point + Vector2(4, 3)]), color, 1.5)
		elif domains.get(view.id,{}).get("domain","")=="ground":
			draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),color,false,1.5)
			draw_line(point+Vector2(0,2),point+Vector2(0,-6),color,1.5)
		else: draw_rect(Rect2(point - Vector2(3, 5), Vector2(6, 10)), color)
	draw_string(font, Vector2(12, size.y - 9), "%.0f 千米 · 点击定位/跟随" % (scale_value / 1000), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("bdd3dc"))

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var best: String = ""
	var distance_value: float = 16.0
	for id: String in markers:
		var distance_to: float = event.position.distance_to(markers[id])
		if distance_to < distance_value:
			best = id
			distance_value = distance_to
	if not best.is_empty(): unit_selected.emit(best)
	else:
		var nearest: String = ""
		for id: String in locations:
			var d: float = event.position.distance_to(locations[id])
			if d < distance_value: distance_value=d; nearest=id
		if not nearest.is_empty(): point_selected.emit(nearest)
	accept_event()

static func _style() -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = Color(0.03, 0.07, 0.10, 0.88)
	result.border_color = Color("42616f")
	result.set_border_width_all(1)
	result.set_corner_radius_all(8)
	return result
