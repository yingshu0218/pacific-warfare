extends "res://tests/fixtures/combat_test.gd"

const IOWA := "us_iowa_bb61_1944_12_28"

func run_test() -> void:
	var config: CombatConfig = FIX.config()
	var catalog: DefinitionCatalog = FIX.catalog()
	var unit: UnitDefinition = catalog.unit(IOWA)
	var gun: WeaponDefinition = catalog.weapon(unit.mounts[0].weapon_definition_id)
	var base: Dictionary = config.mount_envelope(IOWA,"main_01",gun)
	var data: Dictionary = config.data.duplicate(true)
	data.unit_profiles[IOWA].mount_limits["main_01"] = {
		"range_scale":0.25, "train_window_deg":[-5,5], "maximum_elevation_deg":8
	}
	expect(config.load_data(data).is_empty(),"Valid per-mount game restriction loads")
	var limited: Dictionary = config.mount_envelope(IOWA,"main_01",gun)
	var neighbor: Dictionary = config.mount_envelope(IOWA,"main_03",gun)
	expect(is_equal_approx(float(limited.range_m),float(base.range_m)*.25) and neighbor.range_m == base.range_m,"Game reach narrows only the selected mount")
	expect(is_equal_approx(float(limited.train_rad.y),deg_to_rad(5.0)) and limited.train_rad.y < neighbor.train_rad.y,"Yaw window is station-specific")
	expect(is_equal_approx(float(limited.pitch_rad.y),deg_to_rad(8.0)) and limited.pitch_rad.y < neighbor.pitch_rad.y,"Pitch window is station-specific")
	data.unit_profiles[IOWA].mount_limits["main_01"].range_scale = 1.5
	expect(not config.load_data(data).is_empty(),"Per-station override cannot extend the existing range")
	expect(config.mount_envelope(IOWA,"main_01",gun) == limited,"Invalid values cannot mutate the loaded session")
	finish("Per-mount game envelope")
