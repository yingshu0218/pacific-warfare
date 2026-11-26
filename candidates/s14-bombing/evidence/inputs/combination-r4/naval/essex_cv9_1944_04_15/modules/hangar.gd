extends Node3D
const H: Script = preload("res://naval/essex_cv9_1944_04_15/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")
func _ready() -> void:
	set_meta("host_id","hangar")
	var p: Dictionary = H.palette()
	# Open-side hangar silhouette: continuous gallery fascia, dark recesses and real pillars.
	# Hull owns the common hangar-floor surface at 7.926m. Build only the
	# actual outer overhang, subtracting the hull footprint instead of offsetting
	# two coincident floors or disabling shadows.
	var hull_outline: PackedVector2Array = []
	var hull_stations: Array = H.hull_stations()
	for station: Array in hull_stations:
		hull_outline.append(Vector2(float(station[1])*1.035,float(station[0])))
	hull_stations.reverse()
	for station: Array in hull_stations:
		hull_outline.append(Vector2(-float(station[1])*1.035,float(station[0])))
	var floor_outline: PackedVector2Array = PackedVector2Array(G.beveled_rect(25.6,214.0))
	for overhang: PackedVector2Array in Geometry2D.clip_polygons(floor_outline,hull_outline):
		H.triangulated_slab(self,"HangarFloorOverhang",overhang,7.55,7.926,p.gray)
	# Gallery spaces are peripheral. Leave real elevator wells open through all levels.
	for side: float in [-1,1]:
		G.box(self,"GallerySide",Vector3(2.2,2.25,222),Vector3(side*13.0,14.335,0),p.gray)
	for side: float in [-1.0,1.0]:
		for range_z: Vector2 in [Vector2(-104,-75),Vector2(-69,-40),Vector2(-33,-1),Vector2(7,35),Vector2(41,68),Vector2(75,103)]:
			var z: float = (range_z.x+range_z.y)*.5
			G.box(self,"OpenHangarDark",Vector3(.16,5.284,range_z.y-range_z.x),Vector3(side*12.45,10.568,z),p.dark)
		for z: float in [-106,-73,-37,3,38,71,105]:
			G.box(self,"HangarPillar",Vector3(1.0,5.284,2.0),Vector3(side*12.8,10.568,z),p.gray)
		# Broad gallery-level gun/catwalk support is an actual hull-gallery feature.
		for span: Vector2 in ([Vector2(-105.5,-29.2),Vector2(-10.8,105.5)] if side<0 else [Vector2(-105.5,105.5)]):
			G.box(self,"GalleryEdgeBeam",Vector3(.45,.8,span.y-span.x),Vector3(side*14.1,15.05,(span.x+span.y)*.5),p.steel)
	for z: float in [-107,107]:
		G.box(self,"HangarEnd",Vector3(24,5.284,.5),Vector3(0,10.568,z),p.gray)
	H.batch_static(self)
