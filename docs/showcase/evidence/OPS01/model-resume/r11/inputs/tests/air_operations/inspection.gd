extends Node3D

const FIX: Script = preload("res://tests/air_operations/fixture.gd")
const AIR_VISUAL: Script = preload("res://tests/air_operations/aircraft_visual.gd")
const CARRIER_SCENE: PackedScene = preload("res://naval/essex_cv9_1944_04_15/essex.tscn")
var auto_run: bool = true
var aircraft_count: int = 1
var fixture: Dictionary
var world: SimulationWorld
var operations: CarrierOperations
var carrier: Node3D
var aircraft: Dictionary = {}
var camera: Camera3D
var environment: CloudSeaEnvironment
var status_label: Label
var timeline_label: Label
var event_label: Label
var command_serial: int = 1
var observed_id: String = "hellcat_1"

func _ready() -> void:
	if auto_run and "--two" in OS.get_cmdline_user_args(): aircraft_count = 2
	environment = CloudSeaEnvironment.new(); add_child(environment)
	camera = Camera3D.new(); camera.current = true; camera.fov = 45; camera.near = 0.5; camera.far = 2000
	add_child(camera)
	carrier = CARRIER_SCENE.instantiate() as Node3D; add_child(carrier)
	for i: int in range(aircraft_count):
		var model: AircraftAdapter = AIR_VISUAL.new()
		model.model_id = "us_f6f5_1944"; add_child(model)
		aircraft["hellcat_%d"%(i+1)] = model
	_build_ui()
	restart()

func restart() -> void:
	fixture = FIX.build(aircraft_count); world = fixture.world; operations = fixture.operations
	command_serial = 1
	FIX.sortie(world,aircraft.keys(),"carrier_patrol")
	refresh()

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new(); add_child(canvas)
	var panel: ColorRect = ColorRect.new(); panel.position = Vector2(12,12); panel.size = Vector2(528,208); panel.color = Color(0.025,0.055,0.08,0.88); canvas.add_child(panel)
	status_label = Label.new(); status_label.position = Vector2(24,20); status_label.add_theme_font_size_override("font_size",17); canvas.add_child(status_label)
	status_label.add_theme_font_size_override("font_size",15)
	var bottom: ColorRect = ColorRect.new(); bottom.position = Vector2(12,455); bottom.size = Vector2(940,173); bottom.color = Color(0.025,0.055,0.08,0.88); canvas.add_child(bottom)
	timeline_label = Label.new(); timeline_label.position = Vector2(24,465); timeline_label.add_theme_font_size_override("font_size",14); canvas.add_child(timeline_label)
	timeline_label.size = Vector2(916,134); timeline_label.clip_text = true
	event_label = Label.new(); event_label.position = Vector2(24,610); event_label.add_theme_font_size_override("font_size",13); canvas.add_child(event_label)
	var buttons: HBoxContainer = HBoxContainer.new(); buttons.position = Vector2(552,18); canvas.add_child(buttons)
	for title: String in ["Pause","1x","4x","Recall","Sortie","Restart","Next"]:
		var button: Button = Button.new(); button.text = title; buttons.add_child(button)
		button.pressed.connect(_action.bind(title))

func _action(title: String) -> void:
	match title:
		"Pause": world.set_paused(not world.paused)
		"1x": world.set_time_scale(1.0)
		"4x": world.set_time_scale(4.0)
		"Restart": restart()
		"Sortie":
			command_serial += 1
			FIX.sortie(world,aircraft.keys(),"sortie_%d"%command_serial,"human")
		"Next": observed_id = "hellcat_2" if aircraft_count == 2 and observed_id == "hellcat_1" else "hellcat_1"
		"Recall":
			var order: BattleOrder = BattleOrder.new(); command_serial += 1
			order.order_id = "recall_%d"%command_serial; order.issuer_id = "observer_commander"; order.source = "human"; order.faction_id = "us"
			order.recipient_ids = [observed_id]; order.order_type = "retreat"; order.target_id = "essex"
			order.area = {"center_m":SimData.array3(world.get_unit("essex").position_m+Vector3(0,300,3000)),"radius_m":800.0}
			order.intent = "carrier_recall"
			world.submit_order(order)
	refresh()

func _process(dt: float) -> void:
	if auto_run:
		world.advance(dt)
		world.drain_events()
		refresh()

func refresh() -> void:
	var ship: UnitState = world.get_unit("essex")
	carrier.call("apply_state",ship.snapshot())
	for id: String in aircraft: (aircraft[id] as AircraftAdapter).apply_state(world.get_unit(id).snapshot())
	var unit: UnitState = world.get_unit(observed_id)
	var s: Dictionary = operations.roster[observed_id]
	var local: Vector3 = ship.world_transform().affine_inverse()*unit.position_m
	camera.position = unit.position_m+Vector3(-22,5,13)
	camera.look_at(unit.position_m,Vector3.UP)
	environment.advance(world.time_s()); environment.update_observer(camera.position)
	var queues: String = "launch [%s] / recovery [%s]"%[", ".join(operations.launch_queue),", ".join(operations.recovery_queue)]
	status_label.text = "OPS01 | Essex CV-9 / F6F-5 | %.2fs  %.1fx %s\n%s: %s\n%s\n%s\nstrip: %s (%s) | deck speed %.2fm/s\nair %.2fm/s | deck-relative %.2fm/s | fuel %.1fkg\ngear %s / hook command %s / flaps %s"%[world.time_s(),world.time_scale,"PAUSED" if world.paused else "",observed_id,s.phase,s.reason,queues,operations.strip_owner,operations.strip_use,ship.velocity_mps.length(),unit.velocity_mps.length(),(ship.world_transform().basis.inverse()*(unit.velocity_mps-ship.velocity_mps)).length(),unit.module_data.aircraft_motion.fuel_kg,s.gear_down,s.hook_down,s.flaps_down]
	var flight: Dictionary = unit.module_data.aircraft_motion
	status_label.text += "\npath %+.1f° / body %+.1f° / AoA %+.1f° / hook %.1f°"%[rad_to_deg(float(flight.path_pitch_rad)),rad_to_deg(float(flight.get("body_pitch_rad",0))),rad_to_deg(float(flight.get("angle_of_attack_rad",0))),rad_to_deg(float(s.get("hook_deflection_rad",0)))]
	var lines: PackedStringArray = []
	var orders: Array[Dictionary] = world.orders_snapshot()
	for i: int in range(maxi(0,orders.size()-2),orders.size()):
		var order: Dictionary = orders[i]
		lines.append("%s / %s -> %s | %s | %s"%[order.issuer_id,order.order_type,", ".join(order.recipient_ids),order.status,order.reason])
	for i: int in range(maxi(0,operations.history.size()-4),operations.history.size()):
		var row: Dictionary = operations.history[i]
		lines.append("%7.2fs  %s  %s -> %s  [%s]"%[row.time_s,row.unit_id,row.from,row.phase,row.reason])
	timeline_label.text = "\n".join(lines)
	event_label.text = "Deck position m: %.2f %.2f %.2f | actual S04 r10 tyre/hook geometry | completed cycles %d"%[local.x,local.y,local.z,s.recoveries]

func geometry_diagnostics() -> Dictionary:
	var ship: UnitState = world.get_unit("essex")
	var maximum_wheel: float = 0.0
	var maximum_hook: float = 0.0
	for id: String in aircraft:
		var unit: UnitState = world.get_unit(id)
		var basis: Basis = ship.world_transform().basis.inverse()*unit.world_transform().basis
		var cpu: Dictionary = operations.airframe.configuration(operations.roster[id],basis,unit.module_data.damage)
		var visual: Dictionary = (aircraft[id] as AircraftAdapter).call("carrier_usage_local",unit.world_transform().basis.inverse()*ship.world_transform().basis.y)
		for key: String in visual.wheel_contacts:
			if not visual.wheel_contacts[key].available: continue
			maximum_wheel = maxf(maximum_wheel,(visual.wheel_contacts[key].position_m as Vector3).distance_to(cpu.wheel_contacts_flight[key].position_m))
		if visual.hook_available: maximum_hook = maxf(maximum_hook,(visual.hook_tip_m as Vector3).distance_to(cpu.hook_tip_flight_m))
	return {"wheel_error_m":maximum_wheel,"hook_error_m":maximum_hook}
