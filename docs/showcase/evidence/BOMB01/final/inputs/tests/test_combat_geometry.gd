extends "res://tests/fixtures/combat_test.gd"

func run_test() -> void:
	var boxes: Array=[{"part":"control","center_m":[0,0,0],"half_extents_m":[.1,.1,5.],"armor_mm":0.}]
	var point: Vector3=Vector3(0,0,-4)
	var begin: Transform3D=Transform3D(Basis(Vector3.UP,-PI/4),Vector3.ZERO)
	var end: Transform3D=Transform3D(Basis(Vector3.UP,PI/4),Vector3.ZERO)
	expect(not CombatGeometry.contains(begin.affine_inverse()*point,boxes) and not CombatGeometry.contains(end.affine_inverse()*point,boxes),"Rotating thin target excludes stationary projectile at both endpoints")
	var result: Dictionary=CombatGeometry.moving_boxes(point,point,begin,end,boxes)
	expect(float(result.fraction)>.45 and float(result.fraction)<.55,"Intermediate rotation sweep detects wing/bar passing through stationary projectile")
	boxes=[{"part":"structure","center_m":[0,0,0],"half_extents_m":[1.,1.,1.],"armor_mm":0.}]
	result=CombatGeometry.moving_boxes(Vector3.ZERO,Vector3(0,0,-10),Transform3D(Basis.IDENTITY,Vector3(-5,0,-5)),Transform3D(Basis.IDENTITY,Vector3(5,0,-5)),boxes)
	expect(absf(float(result.fraction)-.4)<.00001,"Relative crossing sweep matches independently computed simultaneous cube entry at t=.4")
	expect(not is_finite(CombatGeometry.segment_box(Vector3(2,0,0),Vector3(2,0,-100),Vector3.ZERO,Vector3.ONE)),"Parallel ray outside slab never falsely hits")
	expect(CombatGeometry.segment_box(Vector3.ZERO,Vector3(20,0,0),Vector3.ZERO,Vector3.ONE)==0.,"Starts-inside collision is resolved at initial fraction")
	var config: CombatConfig=FIX.config()
	var zero: Dictionary=config.data.unit_profiles.jp_a6m5a_1944
	for x: float in [-.16,.16]:
		var muzzle: Vector3=Vector3(x,.56,-3.94)
		expect(not CombatGeometry.masked(muzzle,muzzle+Vector3.FORWARD*10,zero.boxes),"Frozen A6M cowl muzzle has unobstructed upper engine channel")
	var hellcat: Dictionary=config.data.unit_profiles.us_f6f5_1944
	expect(absf(float(hellcat.boxes[0].center_m[1]))<.001 and hellcat.sensor_height_m==0.,"F6F collision/sensor origin follows S04 flight offset instead of old ground-display height")
	finish("geometry")
