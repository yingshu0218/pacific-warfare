extends Node3D
const H: Script = preload("res://naval/shokaku_1941_08_23/geometry.gd")
const G: Script = preload("res://scripts/naval/destroyers/mesh_tools.gd")

func _ready() -> void:
	set_meta("host_id","hangar")
	var p: Dictionary = H.palette()
	# Continuous closed hangar sides. End radii are source-backed large forms;
	# no open US-style hangar gallery, no interior rooms or working machinery.
	var outline: PackedVector2Array = H.polygon([[-8.1,-102.0],[8.1,-102.0],[10.7,-98.0],
		[11.6,-86.0],[11.6,99.0],[9.8,108.0],[7.4,112.0],[-7.4,112.0],[-9.8,108.0],
		[-11.6,99.0],[-11.6,-86.0],[-10.7,-98.0]])
	# Side walls, not a solid slab spanning elevator holes.
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var mid: Vector2 = (a+b)*.5
		var wall: MeshInstance3D = G.box(self,"EnclosedHangarWall",Vector3(.30,6.55,a.distance_to(b)),Vector3(mid.x,10.525,mid.y),p.gray)
		wall.rotation.y = atan2(b.x-a.x,b.y-a.y)
	# Real longitudinal boat/catwalk decks below flight deck overhang.
	for side: float in [-1,1]:
		G.box(self,"BoatGallery",Vector3(2.2,.28,111),Vector3(side*12.2,8.83,2.5),p.gray)
		G.box(self,"GalleryEdge",Vector3(.12,.52,111),Vector3(side*13.24,9.21,2.5),p.gray)
	# Fore/aft deck support columns are at the real open ends, below the deck.
	# These do not carry or artificially reconnect outboard weapon platforms.
	for z: float in [-113.0,-103.5]:
		var base_y: float=H.station_at(z).y
		var x_width: float=5.4 if z< -110 else 7.7
		for x: float in [-x_width,x_width]:
			G.box(self,"ForeFlightDeckStanchion",Vector3(.48,13.2-base_y,.55),Vector3(x,(13.2+base_y)*.5,z),p.gray)
			_support_marker(Vector3(x,base_y,z))
		G.box(self,"ForeDeckTransverseBeam",Vector3(24.3,.6,.65),Vector3(0,13.5,z),p.gray)
	for z: float in [114.0,122.2]:
		var base_y: float=H.station_at(z).y
		var x_width: float=7.2 if z<120 else 5.2
		for x: float in [-x_width,x_width]:
			G.box(self,"AftFlightDeckStanchion",Vector3(.43,13.245-base_y,.52),Vector3(x,(13.245+base_y)*.5,z),p.gray)
			_support_marker(Vector3(x,base_y,z))
		G.box(self,"AftDeckTransverseBeam",Vector3(23.5,.55,.6),Vector3(0,13.52,z),p.gray)
	H.batch_static(self)

func _support_marker(at: Vector3) -> void:
	var marker: Marker3D=Marker3D.new()
	marker.name="UnderdeckSupportBase_%02d"%get_child_count()
	marker.position=at; marker.set_meta("kind","underdeck_support_base"); marker.set_meta("host_id","hull")
	add_child(marker)
