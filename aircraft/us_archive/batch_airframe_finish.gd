extends "res://aircraft/us_archive/visual_parts.gd"
## Shared visual language for this four-airframe batch only.
## Natural aluminum is represented by base colour under the same satin finish,
## not a separate reflective rendering style.

func _set_batch_paint(top: Color, underside: Color) -> void:
	_set_paint(top, underside)
	for key: String in ["skin","top","bottom","frame","metal","dark","seam"]:
		_airframe_matte(paint[key])
	paint.glass.albedo_color = Color("355267")
	paint.glass.roughness = .29
	paint.glass.metallic = .06
	paint.glass.metallic_specular = .32
	paint.glass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	paint.frame.albedo_color = top.lerp(Color("676d72"),.28)
	paint.seam.albedo_color = top.lerp(Color("39464e"),.24)
	paint.metal.albedo_color = top.lightened(.18).lerp(Color("8b969b"),.44)
	paint.panel = GEO.material(top.lerp(Color("56636b"),.27))
	_airframe_matte(paint.panel)
	paint.silver = GEO.material(top.lightened(.16))
	_airframe_matte(paint.silver)

func _airframe_matte(material: StandardMaterial3D) -> void:
	material.roughness = .76
	material.metallic = .10
	material.metallic_specular = .34

func _wing_hinge_line(host: Node3D, profile: Array, side: float, span_a: float, span_b: float, chord_t: float, radius: float) -> void:
	var steps: int = maxi(5,roundi((span_b-span_a)*2.0))
	for index: int in steps:
		var a: Vector3 = GEO.wing_point(profile,lerpf(span_a,span_b,float(index)/steps),chord_t,true)
		var b: Vector3 = GEO.wing_point(profile,lerpf(span_a,span_b,float(index+1)/steps),chord_t,true)
		a.x *= side
		b.x *= side
		var lift: Vector3 = Vector3.UP * radius*.62
		GEO.rod(host,"SubtleControlJoin",a+lift,b+lift,radius,paint.seam)
