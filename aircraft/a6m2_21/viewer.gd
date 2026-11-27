extends "res://aircraft/visual_study/airframe_viewer.gd"
## Hangar-only preview of the game flash. No projectile, targeting or damage.

const FLASH_SECONDS := 0.09

var _flash: MeshInstance3D
var _flash_timer: Timer
var _flash_light: OmniLight3D


func _ready() -> void:
	super()
	var mount := Node3D.new()
	mount.name = "PreviewEffect"
	mount.position = Vector3(0.0, 2.22, -4.28)
	$A6M2.add_child(mount)
	_flash = MeshInstance3D.new()
	_flash.name = "PreviewFlash"
	var burst := SphereMesh.new()
	burst.radius = 0.22
	burst.height = 0.44
	burst.radial_segments = 12
	burst.rings = 6
	_flash.mesh = burst
	_flash.scale = Vector3(.70, .68, 2.05)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffe79d")
	_flash.material_override = glow
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("ffbb63")
	_flash_light.light_energy = 1.65
	_flash_light.omni_range = 2.4
	mount.add_child(_flash_light)
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_hide_flash)
	add_child(_flash_timer)
	_hide_flash()
	var button := Button.new()
	button.text = "Preview flash  [F]"
	button.position = Vector2(22, 119)
	button.pressed.connect(preview_fire)
	_label.get_parent().add_child(button)


func _unhandled_key_input(event: InputEvent) -> void:
	super(event)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		preview_fire()
		get_viewport().set_input_as_handled()


func preview_fire() -> void:
	_flash.show()
	_flash_light.show()
	_flash_timer.start(FLASH_SECONDS)


func _hide_flash() -> void:
	_flash.hide()
	_flash_light.hide()
