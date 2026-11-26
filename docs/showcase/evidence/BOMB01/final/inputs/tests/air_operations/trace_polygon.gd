extends SceneTree
func _initialize() -> void:
	var deck: CarrierDeckGeometry = CarrierDeckGeometry.new()
	for x: float in [-3.0,-2.99999952316284,-2.999, -3.001]:
		for z: float in [-47.0342864990234,-47.03,-47.0,-46.99]:
			print("POLY ",Vector2(x,z)," ",deck.surface(Vector2(x,z))," direct=",Geometry2D.is_point_in_polygon(Vector2(x,z),deck.polygon(deck.data.flight_deck.boundary_xz_m)))
	quit()
