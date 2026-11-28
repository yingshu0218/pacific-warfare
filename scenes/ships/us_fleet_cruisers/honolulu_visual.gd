extends "res://scenes/ships/us_fleet_cruisers/us_cruiser_detail.gd"
## CL-48 static outer silhouette, Mare Island, 24–26 October 1942.
const HALF: float = 92.71
const PROFILE: Array[Vector4] = [
	Vector4(-HALF,.031,8.51,.017),Vector4(-91.7,.43,8.45,.10),Vector4(-89.2,1.44,8.25,.51),
	Vector4(-85.8,2.49,7.95,1.41),Vector4(-80.9,3.79,7.61,2.67),Vector4(-75.0,5.10,7.22,3.94),
	Vector4(-67.1,6.38,6.84,5.30),Vector4(-58.0,7.49,6.48,6.60),Vector4(-48.0,8.26,6.29,7.53),
	Vector4(-35.8,8.90,6.14,8.26),Vector4(-20.0,9.29,6.08,8.70),Vector4(-3.1,9.4107,6.05,8.92),
	Vector4(13.6,9.4107,6.05,8.97),Vector4(29.0,9.30,6.07,8.76),Vector4(43.4,8.98,6.10,8.31),
	Vector4(56.2,8.55,6.16,7.81),Vector4(67.4,7.92,6.24,7.08),Vector4(77.0,7.21,6.38,6.23),
	Vector4(84.4,6.52,6.51,5.21),Vector4(89.8,5.76,6.61,4.30),Vector4(HALF,4.52,6.67,3.21),
]

func _stations() -> Array[Vector4]: return PROFILE
func _half_length() -> float: return HALF
func _draft() -> float: return 5.92
func _section(row: Vector4, side: float) -> PackedVector3Array:
	return _draw_section(row,side,5.15,5.23)

func _ready() -> void:
	_colors("697883","83939c","4e5e65","566977")
	_group = _layer("Hull and weather deck")
	_hull()
	_group = _layer("Rounded stepped bridge and high after house")
	_bridge()
	_group = _layer("Unequal stacks and separate mast profiles")
	_upperworks()
	_group = _layer("Three forward and two aft still casings")
	for i: int in range(5):
		var z: float = [-59.8,-48.4,-35.8,42.0,53.1][i]
		_photo_case(z,0,_deck_height(z),6.27,6.55,2.20,[.70,3.28,.60,3.31,.69][i],3,Vector3.FORWARD if i<2 else Vector3.BACK)
	_group = _layer("Long aft work deck and deck relief")
	_detail()
	_group = _layer("Submerged art")
	_underbody_shapes(PackedVector3Array([Vector3(-2.96,-3.45,81.2),Vector3(2.96,-3.45,81.2)]),85.7,1.06)

func _bridge() -> void:
	_octagon("Forward main deckhouse",Vector3(0,7.64,-21.11),12.85,3.30,20.72,1.85,_steel,.96)
	_gallery("Forward curved middle terrace",Vector3(0,9.72,-23.14),13.91,.87,11.36,_upper)
	_octagon("Lower enclosed forward tower",Vector3(0,11.16,-23.54),9.91,2.13,9.31,1.47,_steel)
	_gallery("Bridge lower wraparound wing",Vector3(0,12.53,-22.92),12.64,.64,10.14,_upper)
	_octagon("Rounded side shaded pilothouse",Vector3(0,13.84,-23.37),8.36,1.94,7.51,1.26,_steel)
	_windows_face(Vector3(0,14.05,-27.15),7,.85,.58,.49)
	_gallery("Rounded pilothouse canopy",Vector3(0,15.13,-23.31),9.10,.54,8.65,_upper)
	_octagon("Stepped bridge upper platform",Vector3(0,16.54,-22.46),6.64,2.84,5.93,1.06,_steel,.94)
	_watch(-23.55,18.12,.88)
	_pipe("Forward upper watch silhouette",Vector3(0,20.87,-22.85),1.53,1.14,.93,1.10,_steel)
	_lattice(Vector3(0,22.02,-22.96),2.62,1.06)
	_octagon("Main low central belt of houses",Vector3(0,7.16,2.71),12.10,2.24,38.53,1.97,_steel)
	_octagon("Medium after body",Vector3(0,8.04,27.05),12.59,3.72,16.12,1.88,_steel,.93)
	_gallery("After skirt",Vector3(0,10.19,28.8),9.23,.73,9.8,_upper)
	_octagon("After raised lookouts",Vector3(0,11.59,28.20),6.68,2.70,7.35,.72,_steel,.92)
	_watch(28.9,13.49,1.06)
	_gallery("Stern upper watch overhanging cap",Vector3(0,15.82,28.85),4.61,.36,4.34,_upper)
	_pipe("After cantilever housing",Vector3(0,16.68,28.81),1.59,1.07,.98,1.21,_steel)
	_octagon("Central stepped service base",Vector3(0,9.44,-2.05),5.06,2.53,4.84,.59,_steel,.85)
	_watch(-2.03,10.78,.78)
	_lattice(Vector3(0,13.04,-2.0),2.22,.95)
	for side: float in [-1.0,1.0]:
		_bridge_side(side,4.19,14.02,-25.90,6)
		_gallery("Bridge wing curved footprint",Vector3(side*5.2,13.08,-22.12),3.31,.49,5.28,_upper)
		_spar("Wing lower outline brace",Vector3(side*3.8,10.3,-21.81),Vector3(side*6.39,12.83,-22.10),.18,_steel)
		_spar("Bridge outer handrail",Vector3(side*5.95,13.04,-25.17),Vector3(side*5.95,13.04,-19.97),.078,_upper)
		for z: float in [-25.17,-23.48,-21.77,-19.97]:
			_spar("Bridge rim support",Vector3(side*5.95,12.63,z),Vector3(side*5.95,13.04,z),.073,_steel)
		for z: float in [-13.9,-5.5,7.25,18.3,33.7]:
			_work_platform(Vector3(side*6.82,8.05,z),3.05,3.42)
		for z: float in [-6.71,1.2,8.9,16.2,21.5]:
			_box("Midships gallery door in relief",Vector3(side*6.06,7.12,z),Vector3(.049,.79,.65),_dark)

func _upperworks() -> void:
	_funnel(-9.11,8.23,20.27,2.39,1.16,0.0)
	_funnel(4.85,8.12,18.18,2.31,1.15,0.0)
	_honolulu_forepole(-18.83,14.65,33.96)
	_small_halyards(-18.3,13.91,28.73,4.70)
	_small_halyards(24.49,9.61,26.48,3.53)
	_aft_mast(23.95,8.25,31.1,3.60)
	_spar("Fine deck-to-mast halyard",Vector3(0,29.0,-18.24),Vector3(0,26.4,24.51),.034,_dark)

func _honolulu_forepole(z: float, base_y: float, top_y: float) -> void:
	_spar("Single light forward pole",Vector3(0,base_y,z),Vector3(0,top_y,z+.72),.24,_steel)
	_spar("Crossed fore signal yard",Vector3(-4.87,top_y-5.23,z+.56),Vector3(4.87,top_y-5.23,z+.56),.101,_steel)
	_spar("Small high cross yard",Vector3(-1.91,top_y-2.68,z+.63),Vector3(1.91,top_y-2.68,z+.63),.095,_steel)
	for s: float in [-1.0,1.0]:
		_spar("Distinct exposed tripod stay",Vector3(s*2.28,base_y,z+2.12),Vector3(0,top_y-8.96,z+.515),.157,_steel)
		_spar("Static upper antenna grille frame",Vector3(s*1.22,top_y-1.60,z+.83),Vector3(s*.94,top_y-.24,z+.73),.063,_steel)
	_lattice(Vector3(0,top_y-.97,z+.76),2.35,1.25)
	_gallery("Fore pole maintenance step",Vector3(0,top_y-6.20,z+.52),2.40,.17,1.89,_steel)

func _detail() -> void:
	_weather_rails(.94,3.03)
	_hull_relief([-78.30,-75.50,-72.11,-69.53,-65.32,-61.63,-58.20,-34.35,-29.14,-23.12,-18.02,
		22.34,29.45,33.82,50.92,58.36,62.09,70.95,74.01,78.56,82.01],true)
	_hawse_relief(-82.2,3.10,5.98,.95)
	_number("48",-80.3,4.81,1.01)
	_gallery("Low broad foredeck winch shelter",Vector3(0,_deck_height(-78.21)+.26,-78.21),4.82,.46,3.58,_steel)
	_octagon("Long clear aviation work deck",Vector3(0,6.47,73.37),10.58,.42,24.54,1.35,_steel)
	_octagon("Flush inset aft deck panel",Vector3(0,6.71,74.25),7.01,.11,7.75,.69,_deck)
	for side: float in [-1.0,1.0]:
		_spar("Foredeck chain visual",Vector3(side*1.08,_deck_height(-79.78)+.08,-79.78),Vector3(side*.81,_deck_height(-88.05)+.11,-88.05),.10,_dark)
		_duty_boat(Vector3(side*5.65,8.04,11.29),side,.94)
		_gallery("After low support ring",Vector3(side*3.84,6.88,65.36),3.26,.62,3.36,_steel)
		_rail_track(Vector3(side*4.05,7.31,64.07),Vector3(0,0,1),12.2)
		for z: float in [62.9,70.51,76.6,81.1,85.6,-62.6,-67.7,-74.1,-81.24,-85.1]:
			_deck_service(Vector3(side*(2.85 if absf(z)<80.0 else 1.06),_deck_height(z),z),.80)
		_gallery("Aft side covered tool coaming",Vector3(side*4.92,6.93,81.51),2.59,.58,2.78,_steel)
		for z: float in [61.4,72.8,84.4]:
			_spar("Aft outside gallery support",Vector3(side*5.31,6.20,z),Vector3(side*5.28,7.16,z),.15,_steel)
	for z: float in [-85.1,-76.7,-69.1,69.0,82.2,89.0]:
		_deck_edges(z,2.24)
	_boat_crane(Vector3(-5.11,8.40,26.9),Vector3(-6.37,19.55,15.77),.88)
	_boat_crane(Vector3(4.27,6.87,86.7),Vector3(4.14,14.72,80.59),.88)
	_spar("Recessed hatch side line",Vector3(-3.49,6.83,70.4),Vector3(-3.49,6.83,78.12),.108,_dark)
	_spar("Recessed hatch side line",Vector3(3.49,6.83,70.4),Vector3(3.49,6.83,78.12),.108,_dark)
	_spar("Recessed hatch rear line",Vector3(-3.11,6.83,78.12),Vector3(3.11,6.83,78.12),.108,_dark)
	_spar("Stern flag staff",Vector3(0,_deck_height(91.42),91.42),Vector3(0,8.91,91.42),.097,_steel)
	_spar("Bow flag staff",Vector3(0,_deck_height(-91.05),-91.05),Vector3(0,10.75,-91.05),.087,_steel)
