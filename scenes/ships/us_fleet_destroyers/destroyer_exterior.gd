extends "res://scenes/ships/visual_study/ship_exterior_geometry.gd"
## Two static display assets from archival silhouettes. Not naval simulation geometry.
@export_enum("Sims 1942", "Sumner 1944") var variant: int = 0
const SIMS: Array[Vector4] = [
	Vector4(-53.061, .075, 5.8, .035), Vector4(-52, .5, 5.73, .045),
	Vector4(-49, 1.45, 5.55, .49), Vector4(-44, 2.64, 5.27, 1.53),
	Vector4(-39, 3.61, 4.99, 2.65), Vector4(-33, 4.51, 4.8, 3.69),
	Vector4(-24, 5.25, 4.68, 4.76), Vector4(-15, 5.385, 4.53, 5.27),
	Vector4(-3.1, 5.385, 4.47, 5.29), Vector4(-2.9, 5.385, 3.0, 5.29),
	Vector4(8, 5.35, 2.94, 5.22), Vector4(18, 5.18, 2.96, 4.99),
	Vector4(26, 4.8, 2.98, 4.57), Vector4(37, 3.97, 3.08, 3.45),
	Vector4(44, 3.31, 3.21, 2.7), Vector4(49, 2.59, 3.32, 1.97),
	Vector4(51.6, 1.72, 3.37, 1.03), Vector4(53.061, .36, 3.38, .19)]
const SUMNER: Array[Vector4] = [
	Vector4(-57.3786, .07, 5.18, .028), Vector4(-56.5, .41, 5.11, .08),
	Vector4(-54.3, 1.12, 4.99, .44), Vector4(-50, 2.34, 4.76, 1.35),
	Vector4(-45, 3.45, 4.45, 2.47), Vector4(-38, 4.52, 4.19, 3.72),
	Vector4(-30, 5.53, 4.02, 4.92), Vector4(-21, 6.05, 3.91, 5.86),
	Vector4(-11, 6.25, 3.84, 6.13), Vector4(1, 6.25, 3.8, 6.17),
	Vector4(15, 6.09, 3.81, 5.95), Vector4(28, 5.53, 3.83, 5.31),
	Vector4(40, 4.58, 3.94, 4.37), Vector4(49, 3.76, 4.1, 3.37),
	Vector4(54.4, 3.1, 4.17, 2.12), Vector4(56.8, 2.11, 4.18, .95),
	Vector4(57.3786, 1.11, 4.20, .25)]

func _stations() -> Array[Vector4]:
	return SIMS if variant == 0 else SUMNER

func _half_length() -> float:
	return 53.061 if variant == 0 else 57.3786

func _draft() -> float:
	return 3.0 if variant == 0 else 3.9

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var result: PackedVector3Array = super._section(row,side)
	# Keep the profile raked at the bow and rounded at the transom.
	var taper: float = smoothstep(_half_length() - 13.0,_half_length(),absf(row.x))
	var shift: float = (2.28 if variant == 0 else 2.85) if row.x < 0.0 else -1.38
	for i: int in range(result.size()-1):
		result[i].z += shift * taper * (1.0-float(i)/float(result.size()-1))
	return result

func _ready() -> void:
	_steel = _paint("667680" if variant == 0 else "606d76")
	_deck = _paint("505e67" if variant == 0 else "4a5763")
	_upper = _paint("83919a" if variant == 0 else "748591")
	_dark = _paint("2e3944")
	_hull_side = _paint("647787" if variant == 0 else "55636e")
	_underbody = _paint("654746")
	_group = _layer("Hull silhouette")
	_hull()
	if variant == 0:
		_sims()
	else:
		_sumner()
	_group = _layer("Deck fittings and rails")
	_rails()
	_deck_details()
	if variant == 0: _dress_sims()
	else: _dress_sumner()

func _sims() -> void:
	_group = _layer("Rounded pilothouse and one funnel")
	_octagon("Fore deckhouse", Vector3(0,5.97,-19.2), 7.55,2.55,16.0,1.32,_steel)
	_round("Forward round pilothouse",Vector3(0,8.69,-18.9),2.85,2.95,1.13,_upper)
	_round("Wraparound bridge cap",Vector3(0,10.29,-18.9),3.49,.28,1.08,_upper)
	_bridge_windows(-18.9,9.74,2.86,1.11)
	for side: float in [-1.0,1.0]:
		_box("Bridge wing",Vector3(side*3.32,9.99,-18.30),Vector3(1.26,.48,2.4),_upper)
	_octagon("Open bridge hood",Vector3(0,10.95,-18),3.5,1.07,3.25,.66,_steel)
	_round("Bridge-top optic",Vector3(0,12.06,-18.6),.99,.77,1.0,_upper)
	_mast(-13.35,7.28,22.63,4.28,true)
	_octagon("Uptake deckhouse",Vector3(0,5.30,-5.85),5.93,1.85,8.18,.94,_steel)
	_stack(-5.4,6.0,13.95,1.66,1.31,1.74)
	_octagon("Lower afterhouse",Vector3(0,4.08,23.5),6.72,2.26,18.7,1.12,_steel)
	_octagon("After deck platform",Vector3(0,5.78,17.95),6.31,.47,8.2,.85,_upper)
	_round("After raised theatre",Vector3(0,6.08,22.6),1.67,1.43,1.10,_upper)
	_mast(28.9,5.2,12.16,2.3,false)
	_boats(-3.0,5.03,4.03)
	_octagon("Central deck gear cover",Vector3(0,3.65,7.3),3.5,1.34,4.35,.40,_steel)
	for side: float in [-1.,1.]:
		_round("Semi-round after deck wing",Vector3(side*2.31,5.82,16.77),1.69,.72,1.0,_steel)
		_round("Small platform interior tone",Vector3(side*2.31,6.20,16.77),1.45,.045,1.0,_deck)
		_spar("After walking ladder edge",Vector3(side*2.97,3.1,14.15),Vector3(side*2.97,5.84,16.7),.10,_upper)
	_group = _layer("Four single-barrel display housings")
	_display_housing(-34.1,_deck_height(-34.1),false,1)
	_display_housing(-26.05,6.62,false,1)
	_display_housing(29.35,5.59,true,1)
	_display_housing(38.25,_deck_height(38.25),true,1)
	_hull_number("409",-42.3,3.30,1.46)
	_early_ports()

func _sumner() -> void:
	_group = _layer("Broad bridge and paired funnels")
	_octagon("Fore deckhouse",Vector3(0,5.52,-23.3),8.05,3.14,17.5,1.43,_steel)
	_octagon("Squared pilothouse",Vector3(0,8.4,-20.9),6.17,2.45,8.40,.95,_upper)
	_octagon("Pilothouse cap",Vector3(0,9.72,-20.9),6.49,.24,8.61,.95,_upper)
	for i: int in range(-2,3):
		_box("Facing window",Vector3(i*.91,9.09,-25.12),Vector3(.65,.48,.075),_dark)
	for side: float in [-1.0,1.0]:
		_box("Bridge flank glazing",Vector3(side*3.10,9.10,-20.78),Vector3(.058,.42,3.21),_dark)
		_octagon("Bridge wing",Vector3(side*3.77,7.45,-19.1),2.45,.58,5.3,.57,_upper)
	_round("Rounded director base",Vector3(0,10.21,-20.4),1.24,.98,1.13,_steel)
	_octagon("Angular optic shelter",Vector3(0,11.49,-20.21),2.55,1.33,2.49,.47,_upper)
	_spar("Visible short optic arm",Vector3(-1.8,12.13,-20.61),Vector3(1.8,12.13,-20.61),.21,_dark)
	_mast(-14.3,7.09,22.04,5.30,true)
	_octagon("Midship island deckhouse",Vector3(0,4.87,-.65),7.17,2.09,28.16,.92,_steel)
	_stack(-9.42,5.90,13.87,1.67,1.26,.58)
	_stack(4.78,5.90,13.20,1.52,1.16,.46)
	_octagon("After deckhouse",Vector3(0,4.90,30.08),6.32,2.32,15.04,1.24,_steel)
	_octagon("First after walking tier",Vector3(0,6.19,25.05),6.76,.30,6.15,1.04,_upper)
	_octagon("Stepped after service cabin",Vector3(0,6.28,30.44),4.55,1.09,5.5,.85,_steel)
	_octagon("After walking tier deck cap",Vector3(0,6.07,34.23),5.84,.18,3.19,.83,_upper)
	_boats(-7.52,5.36,4.59)
	_boats(12.8,4.84,4.49)
	for z: float in [-2.8,12.3]:
		_octagon("Central deck gear cover",Vector3(0,5.63,z),3.03,1.12,3.98,.5,_steel)
	_round("Stern ring",Vector3(0,4.61,49.15),2.2,1.16,1.02,_steel)
	_round("Stern ring interior tone",Vector3(0,5.20,49.15),1.98,.035,1.02,_deck)
	for side: float in [-1.,1.]:
		_round("Midship raised outboard platform",Vector3(side*3.2,6.13,17.87),1.81,.85,1.09,_steel)
		_round("Dark platform interior",Vector3(side*3.2,6.57,17.87),1.62,.04,1.09,_deck)
		_round("Open platform furniture",Vector3(side*3.13,6.83,17.47),.49,.53,1.03,_steel)
		_spar("Platform ladder edge",Vector3(side*4.36,3.94,15.16),Vector3(side*4.36,6.09,17.12),.106,_upper)
	_group = _layer("Three twin-barrel display housings")
	_display_housing(-36.82,_deck_height(-36.82),false,2)
	_display_housing(-26.98,7.08,false,2)
	_display_housing(39.0,_deck_height(39.0),true,2)
	_hull_number("692",-46.0,2.51,.91)

func _round(label: String,p: Vector3,r: float,h: float,depth: float,mat: Material) -> void:
	var form: CylinderMesh = CylinderMesh.new()
	form.height = h
	form.bottom_radius = r
	form.top_radius = r
	form.radial_segments = 28
	_instance(label,form,mat,p).scale.z = depth

func _display_housing(z: float, base: float, aft: bool, barrel_count: int) -> void:
	var w: float = 2.75 if barrel_count == 1 else 4.52
	var d: float = 3.39 if barrel_count == 1 else 4.12
	var f: float = 1.0 if aft else -1.0
	_round("Visible seating ring",Vector3(0,base+.18,z),w*.42,.34,1.0,_dark)
	_octagon("Fixed faceted housing",Vector3(0,base+1.16,z),w,1.92,d,.45,_steel,.91)
	_octagon("Shelter roof",Vector3(0,base+2.14,z),w*.91,.18,d*.91,.39,_upper)
	for x: float in ([0.] if barrel_count == 1 else [-.79,.79]):
		_spar("Display barrel root",Vector3(x,base+1.38,z+f*d*.43),Vector3(x,base+1.44,z+f*(d*.5+.55)),.35,_dark)
		_spar("Neutral barrel silhouette",Vector3(x,base+1.43,z+f*(d*.50+.43)),Vector3(x,base+1.73,z+f*(d*.5+3.04)),.20,_steel)

func _stack(z: float, base: float, tip: float, radius: float, elongation: float, rake: float) -> void:
	var p: Vector3 = Vector3(0,(base+tip)*.5,z+rake*.5)
	var body: MeshInstance3D = _pipe("Oval sloped funnel shell",p,tip-base,radius,radius*.85,elongation,_steel)
	body.rotation.x = atan2(rake,tip-base)
	_pipe("Funnel cap band",Vector3(0,tip-.19,z+rake),.56,radius*.93,radius*.96,elongation,_dark)
	_pipe("Dark funnel shadow top",Vector3(0,tip+.105,z+rake),.045,radius*.83,radius*.83,elongation,_dark)

func _mast(z: float, foot: float, tip: float, wing: float, fore: bool) -> void:
	var bottom := Vector3(0,foot,z)
	var top := Vector3(0,tip,z+.65)
	_spar("Mast pole",bottom,top,.25 if fore else .16,_steel)
	_spar("Horizontal yard",Vector3(-wing*.5,tip-2.1,z+.55),Vector3(wing*.5,tip-2.1,z+.55),.115,_upper)
	_spar("Signal stay",top-Vector3(0,.4,0),Vector3(0,_deck_height(-47)+.4,-47) if fore else Vector3(0,_deck_height(44)+.37,44),.022,_dark)
	if fore:
		_spar("Outrigger brace",Vector3(2.16,foot,z+4.37),Vector3(0,tip-7.,z+.39),.087,_steel)
		_spar("Outrigger brace",Vector3(-2.16,foot,z+4.37),Vector3(0,tip-7.,z+.39),.087,_steel)
		var extent: float = .95 if variant == 0 else 1.78
		_spar("Aerial edge",Vector3(-extent,tip-.64,z+.69),Vector3(extent,tip-.64,z+.69),.08,_upper)
		if variant == 1:
			for i: int in range(-3,4):
				_spar("Open aerial ribs",Vector3(i*.46,tip-.69,z+.69),Vector3(i*.46,tip-.18,z+.69),.053,_upper)

func _bridge_windows(z: float, y: float, r: float, depth: float) -> void:
	for i: int in range(-5,6):
		var angle: float = float(i)*.185
		var p := Vector3(r*sin(angle),y,z-r*depth*cos(angle))
		var n: MeshInstance3D = _box("Curved pilothouse windows",p,Vector3(.31,.42,.115),_dark)
		n.rotation.y = -angle

func _boats(z: float, y: float, x: float) -> void:
	for side: float in [-1.0,1.0]:
		_octagon("Open boat exterior",Vector3(side*x,y,z),1.28,.78,4.88,.57,_upper,.85)
		_octagon("Boat seat shadow",Vector3(side*x,y+.39,z),.86,.075,3.68,.36,_dark)
		for dz: float in [-1.54,1.58]:
			var a := Vector3(side*(x-.71),y-1.06,z+dz+.33)
			var b := Vector3(side*(x-.67),y+.85,z+dz+.22)
			_spar("Visible boat davit",a,b,.145,_steel)
			_spar("Davit curved end",b,Vector3(side*x,y+.66,z+dz),.12,_upper)

func _rails() -> void:
	var rails: Array[Vector4] = _stations()
	for side: float in [-1.0,1.0]:
		for i: int in range(1,rails.size()-2):
			var a: Vector4 = rails[i]
			var b: Vector4 = rails[i+1]
			if absf(a.z-b.z)>1.0:
				continue
			var start := Vector3(side*(a.y-.12),a.z+.78,a.x)
			var end := Vector3(side*(b.y-.12),b.z+.78,b.x)
			_spar("Thin deck rail",start,end,.045,_upper)
			_spar("Lower deck rail",start-Vector3.UP*.35,end-Vector3.UP*.35,.031,_steel)
			var count: int = maxi(1,ceili(start.distance_to(end)/2.5))
			for index: int in range(count):
				var top: Vector3 = start.lerp(end,float(index)/float(count))
				_spar("Railing post",top,top-Vector3.UP*.78,.060,_steel)

func _hull_number(mark: String, z: float, y: float, scale_hint: float) -> void:
	var low: Vector4 = _stations()[0]
	var high: Vector4 = _stations()[1]
	for index: int in range(1,_stations().size()):
		high = _stations()[index]
		if z <= high.x:
			low = _stations()[index-1]
			break
	var row: Vector4 = low.lerp(high,inverse_lerp(low.x,high.x,z))
	var section: PackedVector3Array = _section(row,1.0)
	var mid_fraction: float = inverse_lerp(section[4].y,section[5].y,y)
	var slope: float = (high.y-low.y)/(high.x-low.x)
	var side_x: float = lerpf(section[4].x,section[5].x,mid_fraction)
	for side: float in [-1.,1.]:
		var badge := Label3D.new()
		badge.name = "Hull number"
		badge.text = mark
		badge.font_size = 64
		badge.pixel_size = scale_hint/47.
		badge.outline_size = 0
		badge.modulate = Color("c3d1d7") if variant == 0 else Color("9cacb4")
		badge.rotation.y = side*(PI*.5+atan(slope))
		badge.position = Vector3(side*(side_x+.18),y,z)
		_group.add_child(badge,true)

func _deck_details() -> void:
	var tip: float = _half_length()
	for side: float in [-1.,1.]:
		var z: float = -tip+10.7
		var rail_x: float = 2.5 if variant == 0 else 2.44
		_box("Anchor hawse",Vector3(side*rail_x,_deck_height(z)-.8,z),Vector3(.23,.63,1.03),_dark)
		_spar("Foredeck chain path",Vector3(side*.53,_deck_height(z)+.07,z-.79),Vector3(side*.81,_deck_height(z+4.2)+.07,z+4.2),.104,_dark)
		_round("Fore deck mooring bitts",Vector3(side*1.43,_deck_height(z+4.7)+.34,z+4.7),.20,.68,1,_steel)
		_round("Stern mooring bollard",Vector3(side*1.64,_deck_height(tip-5)+.27,tip-5),.19,.54,1,_steel)
	for z: float in [-44.0,16.65,46.30]:
		_octagon("Deck service hatch",Vector3(0,_deck_height(z)+.22,z),1.18,.44,1.22,.23,_upper)
	_spar("Jackstaff",Vector3(0,_deck_height(-tip+1.1),-tip+1.1),Vector3(0,_deck_height(-tip+1.1)+1.34,-tip+1.1),.068,_steel)
	_spar("Stern staff",Vector3(0,_deck_height(tip-1.9),tip-1.9),Vector3(0,_deck_height(tip-1.9)+1.64,tip-1.9),.085,_steel)

func _early_ports() -> void:
	var rim := _paint("485b65")
	for i: int in range(16):
		var z: float = -37.4 + float(i)*2.0
		var a: Vector4 = SIMS[0]
		var b: Vector4 = SIMS[1]
		for j: int in range(1,SIMS.size()):
			b = SIMS[j]
			if z <= b.x:
				a = SIMS[j-1]
				break
		var row: Vector4 = a.lerp(b,inverse_lerp(a.x,b.x,z))
		var sec: PackedVector3Array = _section(row,1.0)
		for side: float in [-1.0,1.0]:
			var y: float = row.z-.64
			var side_x: float = lerpf(sec[4].x,sec[5].x,inverse_lerp(sec[4].y,sec[5].y,y))
			var port := _pipe("Small visible hull scuttle",Vector3(side*(side_x+.026),y,z),.045,.123,.123,1.,rim)
			port.rotation.z = PI*.5

func _dress_sims() -> void:
	_group = _layer("Sims light fittings and visible deck transitions")
	for side: float in [-1.,1.]:
		_spar("Bridge support strut",Vector3(side*2.20,7.17,-21.26),Vector3(side*3.66,9.36,-20.16),.132,_steel)
		_spar("Bridge support strut",Vector3(side*2.37,7.17,-17.84),Vector3(side*3.70,9.36,-18.91),.132,_steel)
		_box("Bridge face break",Vector3(side*2.10,10.35,-21.69),Vector3(.83,.36,.24),_dark)
		_spar("Bridge glacis hand rail",Vector3(side*3.04,10.47,-20.43),Vector3(side*3.59,10.47,-17.70),.08,_upper)
		_box("Hull-side hose housing",Vector3(side*4.31,4.11,24.97),Vector3(.64,1.59,2.1),_steel)
		_surface_ladder(Vector3(side*3.68,4.34,-12.45),Vector3(side*3.68,6.68,-14.06),.29)
		_surface_ladder(Vector3(side*2.98,3.14,13.74),Vector3(side*2.98,5.88,16.44),.29)
		_ring_mark(Vector3(side*3.79,5.18,-19.0),.39,side)
		_ring_mark(Vector3(side*3.35,4.69,19.55),.41,side)
		_round("Stern deck fairlead bell",Vector3(side*1.38,3.62,45.9),.34,.79,1.03,_steel)
		_round("Raised aft gallery stanchion",Vector3(side*1.88,6.16,23.14),.24,.88,1.,_steel)
		_box("Aft ventilator throat",Vector3(side*2.72,5.39,27.65),Vector3(.53,.40,.65),_dark)
	for z: float in [-5.4,1.77,10.34,20.24,35.17]:
		_deck_piece(z,.86)
	_box("Foremast cabinet",Vector3(0,13.24,-13.04),Vector3(.48,.61,.58),_upper)
	_spar("Foremast fork antenna",Vector3(-.84,21.32,-12.73),Vector3(.84,21.32,-12.73),.073,_dark)
	_round("After circular control hood",Vector3(0,7.13,22.6),1.03,.34,.98,_dark)
	_spar("Thin stern yardarm port",Vector3(-1.21,10.21,29.55),Vector3(0,11.17,29.55),.063,_steel)
	_spar("Thin stern yardarm starboard",Vector3(1.21,10.21,29.55),Vector3(0,11.17,29.55),.063,_steel)

func _dress_sumner() -> void:
	_group = _layer("Sumner stepped lockers and bridge fittings")
	for side: float in [-1.,1.]:
		_box("Service shelter flank",Vector3(side*2.72,5.62,22.52),Vector3(1.63,1.38,3.06),_steel)
		_box("Service shelter fascia",Vector3(side*3.53,5.95,22.52),Vector3(.08,.62,2.77),_upper)
		_box("Small dark shelter face",Vector3(side*3.57,5.94,22.63),Vector3(.08,.31,1.87),_dark)
		_box("Forward after-deck locker",Vector3(side*2.58,6.74,27.40),Vector3(1.36,1.04,2.63),_steel)
		_box("Offset aft utility pedestal",Vector3(side*2.87,6.71,32.81),Vector3(1.09,1.52,1.9),_steel)
		_round("Round rim on layered afterdeck",Vector3(side*2.6,7.17,25.13),.89,.59,1.12,_upper)
		_round("Shadow inside after deck rim",Vector3(side*2.6,7.48,25.13),.73,.035,1.12,_dark)
		_round("Funnel flank cowl",Vector3(side*2.51,6.37,4.34),.63,1.29,1.15,_steel)
		_round("Low fore platform rim",Vector3(side*4.12,7.14,-14.26),1.09,.57,1.13,_steel)
		_round("Low fore platform shadow",Vector3(side*4.12,7.44,-14.26),.91,.04,1.13,_deck)
		_spar("Raised bridge wing corner",Vector3(side*3.95,7.24,-22),Vector3(side*4.44,7.52,-16.5),.11,_upper)
		_box("Bridge wing view slit",Vector3(side*4.91,7.45,-18.8),Vector3(.066,.23,1.21),_dark)
		_surface_ladder(Vector3(side*3.58,3.88,32.92),Vector3(side*3.58,6.14,34.53),.30)
		_surface_ladder(Vector3(side*3.21,4.2,-26.77),Vector3(side*3.21,7.1,-25.1),.31)
		_ring_mark(Vector3(side*4.95,5.5,-11.31),.385,side)
		_ring_mark(Vector3(side*4.53,5.16,8.71),.385,side)
	for z: float in [-13.77,-3.85,1.44,10.57,18.89,44.33,49.12]:
		_deck_piece(z,1.18)
	_box("Mast square dark lamp",Vector3(0,16.19,-13.79),Vector3(.58,.59,.64),_dark)
	_round("High mast masthead band",Vector3(0,20.16,-13.74),.36,.54,1.1,_steel)
	_spar("Top aerial diagonal",Vector3(-1.38,21.48,-13.61),Vector3(1.38,21.91,-13.61),.069,_steel)

func _deck_piece(z: float, shift_x: float) -> void:
	var base: float = _deck_height(z)
	for side: float in [-1.,1.]:
		_box("Visible coaming locker",Vector3(side*shift_x,base+.32,z),Vector3(.86,.64,1.69),_steel)
		_box("Narrow locker cap",Vector3(side*shift_x,base+.66,z),Vector3(.91,.09,1.78),_upper)
		_round("Nearby deck cowl",Vector3(side*(shift_x+1.19),base+.36,z+.87),.25,.72,1.22,_steel)

func _ring_mark(center: Vector3, radius: float, side: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius*.74
	ring.outer_radius = radius
	ring.rings = 14
	ring.ring_segments = 5
	_instance("External lifebuoy rim",ring,_upper,center).rotation.z = side*PI*.5

func _surface_ladder(low: Vector3, high: Vector3, spread: float) -> void:
	var d := Vector3(spread,0,0)
	_spar("External ladder rail",low-d,high-d,.075,_steel)
	_spar("External ladder rail",low+d,high+d,.075,_steel)
	for i: int in range(1,7):
		var rung: Vector3 = low.lerp(high,float(i)/7.0)
		_spar("External ladder rung",rung-d,rung+d,.050,_upper)
