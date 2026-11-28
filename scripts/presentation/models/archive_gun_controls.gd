extends PanelContainer
## Standalone gallery control, never installed into a battle scene.
const RIG := preload("res://scripts/presentation/models/archive_gun_rig.gd")
const UI_FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const LABELS := {"main":"主炮","secondary":"副炮","dedicated_aa":"防空炮"}
var model: Node3D
var rows: Array[Dictionary] = []
var selection: OptionButton
var yaw: HSlider
var pitch: HSlider
var details: Label
var status: Label
var reset_button: Button
var yaw_value: Label
var pitch_value: Label
var selection_index: int = -1

func _ready() -> void:
	position = Vector2(22, 132)
	var panel_theme := Theme.new()
	panel_theme.default_font = UI_FONT
	panel_theme.default_font_size = 15
	theme = panel_theme
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("202e3bef")
	skin.border_color = Color("708396")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(5)
	skin.set_content_margin_all(12)
	add_theme_stylebox_override("panel", skin)
	var columns := VBoxContainer.new()
	columns.add_theme_constant_override("separation", 7)
	columns.custom_minimum_size.x = 295
	add_child(columns)
	var title := Label.new()
	title.text = "独立炮位检视"
	title.add_theme_font_size_override("font_size", 20)
	columns.add_child(title)
	status = Label.new()
	columns.add_child(status)
	selection = OptionButton.new()
	selection.get_popup().max_size = Vector2i(0, 370)
	selection.item_selected.connect(_select)
	columns.add_child(selection)
	yaw_value = Label.new()
	columns.add_child(yaw_value)
	yaw = _slider(columns)
	pitch_value = Label.new()
	columns.add_child(pitch_value)
	pitch = _slider(columns)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 14)
	columns.add_child(details)
	reset_button = Button.new()
	reset_button.text = "复位当前炮位"
	columns.add_child(reset_button)
	reset_button.pressed.connect(func() -> void:
		yaw.set_value_no_signal(0)
		pitch.set_value_no_signal(0)
		_apply(0)
	)
	hide()

func _slider(parent: Control) -> HSlider:
	var result := HSlider.new()
	result.step = 1
	result.value_changed.connect(_apply)
	result.custom_minimum_size.x = 253
	parent.add_child(result)
	return result

func set_model(new_model: Node3D, ship: bool) -> void:
	model = new_model
	selection.clear()
	rows.clear()
	selection_index = -1
	if not ship:
		hide()
		return
	var container := model.get_node_or_null("ArchiveGunPivots")
	if container != null:
		for gun: Node3D in container.get_children():
			_add(str(gun.mount_id), str(gun.role), gun, Vector2(-gun.yaw_limit_rad,gun.yaw_limit_rad),
				Vector2(gun.pitch_min_rad,gun.pitch_max_rad), gun.game_reach)
	elif model.has_method("mount_sockets"):
		for entry: Dictionary in model.mount_sockets():
			var role: String = str(entry.get("role", ""))
			if role in ["main_dual_purpose", "dual_purpose"]:
				role = "main"
			elif role == "light_aa":
				role = "dedicated_aa"
			if not RIG.PROFILES.has(role):
				continue
			var profile: Dictionary = RIG.PROFILES[role]
			var preview = null
			var axes := Vector2.ONE * deg_to_rad(profile.train)
			axes.x *= -1
			_add(str(entry.id), role, preview, axes,
				Vector2(deg_to_rad(profile.lower),deg_to_rad(profile.upper)), profile.reach)
	var enabled := not rows.is_empty()
	status.text = "%d 个可检视炮位" % rows.size() if enabled else "这个展品未制作火炮网格"
	for control: Control in [selection,yaw_value,yaw,pitch_value,pitch,details,reset_button]:
		control.visible = enabled
	if enabled:
		_select(0)

func _add(id: String, role: String, rig: Node3D, axes: Vector2, incline: Vector2, reach: float) -> void:
	rows.append({"id":id, "role":role, "rig":rig, "yaw":axes, "pitch":incline, "reach":reach, "pose":Vector2.ZERO})
	selection.add_item("%s  ·  %s" % [str(LABELS.get(role, role)), id])

func _select(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	selection_index = index
	selection.select(index)
	var row: Dictionary = rows[index]
	_set_bounds(yaw,row.yaw,row.pose.x)
	_set_bounds(pitch,row.pitch,row.pose.y)
	details.text = "检视射程档 %.1f  ·  非实际射程\n射界  %d°～%d°  /  俯仰 %d°～%d°" % [
		row.reach, roundi(rad_to_deg(row.yaw.x)), roundi(rad_to_deg(row.yaw.y)),
		roundi(rad_to_deg(row.pitch.x)), roundi(rad_to_deg(row.pitch.y))]
	_readout()

func _set_bounds(slider: HSlider, window: Vector2, value: float) -> void:
	slider.set_block_signals(true)
	slider.min_value = -180
	slider.max_value = 180
	slider.min_value = rad_to_deg(window.x)
	slider.max_value = rad_to_deg(window.y)
	slider.set_value_no_signal(rad_to_deg(value))
	slider.set_block_signals(false)

func _apply(_value: float) -> void:
	if selection_index < 0 or not is_instance_valid(model):
		return
	var row: Dictionary = rows[selection_index]
	var angles := Vector2(deg_to_rad(yaw.value), deg_to_rad(pitch.value))
	var rig: Node3D = row.rig
	var pose := {"train_rad":angles.x, "elevation_rad":angles.y}
	if is_instance_valid(rig):
		rig.pose(angles.x, angles.y)
	elif model.has_method("apply_weapon_state"):
		model.apply_weapon_state(row.id, pose)
	elif model.has_method("apply_state"):
		var by_id := {}
		by_id[row.id] = pose
		model.apply_state({"position_m":model.position,"rotation_rad":model.rotation,"weapons":by_id})
	row.pose = angles
	_readout()

func _readout() -> void:
	yaw_value.text = "水平  %d°" % roundi(yaw.value)
	pitch_value.text = "俯仰  %d°" % roundi(pitch.value)
