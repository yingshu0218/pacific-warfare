extends "res://scenes/ships/us_fleet_cruisers/us_cruiser_detail.gd"
## CA-38 static 1942 outer silhouette, before damage. Bow -Z, game waterline Y=0.

const HALF: float = 89.6366
const PROFILE: Array[Vector4] = [
	Vector4(-HALF,.033,8.17,.017),Vector4(-88.8,.42,8.12,.11),Vector4(-86.6,1.28,7.95,.55),
	Vector4(-83.0,2.51,7.67,1.56),Vector4(-78.5,3.78,7.39,2.71),Vector4(-72.5,5.02,7.11,4.07),
	Vector4(-65.0,6.12,6.89,5.26),Vector4(-56.1,7.15,6.68,6.42),Vector4(-47.1,7.95,6.55,7.36),
	Vector4(-37.0,8.65,6.45,8.12),Vector4(-27.0,9.20,6.41,8.76),Vector4(-14.0,9.56,6.37,9.13),
	Vector4(-2.6,9.56,6.35,9.12),Vector4(6.2,9.54,6.30,9.09),Vector4(9.8,9.52,5.11,9.07),
	Vector4(22.0,9.40,4.95,8.91),Vector4(35.8,9.06,4.87,8.56),Vector4(49.5,8.38,4.89,7.77),
	Vector4(61.0,7.47,4.95,6.73),Vector4(71.4,6.39,5.05,5.58),Vector4(80.0,5.38,5.16,4.37),
	Vector4(86.1,4.48,5.21,3.28),Vector4(HALF,3.64,5.24,2.58),
]

func _stations() -> Array[Vector4]: return PROFILE
func _half_length() -> float: return HALF
func _draft() -> float: return 5.92
func _section(row: Vector4, side: float) -> PackedVector3Array:
	return _draw_section(row,side,4.82,5.11)

func _ready() -> void:
	_colors("6e7a83","86959c","465863","5d6d79")
	_group = _layer("Hull and weather deck")
	_hull()
	_group = _layer("Distinct blocky forward tower")
	_bridge()
	_group = _layer("Two separated stacks and mast shapes")
	_upperworks()
	_group = _layer("Still external housings")
	for i: int in range(3):
		var z: float = [-58.7,-45.6,54.8][i]
		_photo_case(z,0,_deck_height(z),[7.66,7.59,7.46][i],7.34,2.72,[.83,3.37,.79][i],3,Vector3.FORWARD if i<2 else Vector3.BACK)
	_group = _layer("Deck detail and amidships aviation silhouettes")
	_detail()
	_group = _layer("Submerged art")
	_underbody_shapes(PackedVector3Array([Vector3(-3.08,-3.6,75.9),Vector3(3.08,-3.6,75.9)]),81.8,1.05)

func _bridge() -> void:
	_octagon("Long main raised forehouse",Vector3(0,8.19,-26.60),14.35,3.84,24.5,1.77,_steel,.96)
	_octagon("Blocky bridge second tier",Vector3(0,11.59,-29.53),12.72,2.99,14.65,1.87,_steel)
	_octagon("Box bridge skirt",Vector3(0,13.28,-29.48),14.34,.56,13.38,1.53,_upper)
	_octagon("Lower bridge enclosed cabin",Vector3(0,14.76,-29.57),11.25,2.45,10.53,1.02,_steel)
	_octagon("Wide primary bridge visor",Vector3(0,16.29,-29.65),13.39,.58,10.01,1.11,_upper)
	_windows_face(Vector3(0,15.18,-34.87),9,1.02,.73,.56)
	_octagon("Upper box level",Vector3(0,17.79,-28.67),8.64,2.54,8.54,1.02,_steel)
	_octagon("Second stepped bridge balcony",Vector3(0,19.12,-28.87),9.97,.43,8.51,1.22,_upper)
	_windows_face(Vector3(0,18.21,-32.97),6,1.01,.65,.54)
	_octagon("Small angular forward crown",Vector3(0,20.31,-28.88),5.78,2.21,5.86,.68,_steel,.90)
	_watch(-28.67,21.57,.84)
	_gallery("Small forward upper balcony",Vector3(0,23.31,-28.69),4.32,.35,3.86,_upper)
	_pipe("Upper silhouette break",Vector3(0,24.35,-28.64),1.97,1.23,1.02,.91,_steel)
	_lattice(Vector3(0,25.80,-28.65),2.82,1.02)
	_octagon("Compact aft stack walkway",Vector3(0,6.65,18.0),12.06,3.46,20.20,1.48,_steel,.93)
	_octagon("After raised block",Vector3(0,7.32,42.20),11.40,4.48,13.13,1.84,_steel,.92)
	_octagon("After lookout block",Vector3(0,10.51,43.15),7.67,2.71,7.56,1.04,_steel,.88)
	_watch(43.22,12.19,1.31)
	_octagon("Raised after roof service box",Vector3(0,15.46,44.50),2.36,.96,2.1,.29,_steel,.94)
	_gallery("After lookout rim",Vector3(0,15.99,44.50),2.71,.22,2.37,_upper)
	_octagon("Midships raised service trunk",Vector3(0,11.10,-6.07),5.45,4.68,6.33,.67,_steel,.84)
	_watch(-6.07,13.21,.64)
	_lattice(Vector3(0,15.41,-6.29),2.18,.87)
	_octagon("Flight deck side casing",Vector3(0,7.21,30.55),9.42,4.60,7.11,1.27,_steel,.94)
	_gallery("Symmetric after deck overhanging shelf",Vector3(0,10.11,42.65),12.31,.45,8.82,_upper)
	for side: float in [-1.0,1.0]:
		_bridge_side(side,5.64,15.16,-32.75,7)
		_bridge_side(side,4.34,18.22,-31.22,5)
		_octagon("Bridge wing ledge",Vector3(side*6.40,13.59,-29.71),3.12,.39,5.70,.46,_upper)
		_spar("Visible visor diagonal",Vector3(side*4.8,11.79,-29.2),Vector3(side*7.62,13.46,-30.62),.19,_steel)
		_spar("Bridge level railing",Vector3(side*5.84,17.20,-32.30),Vector3(side*5.84,17.20,-26.80),.091,_upper)
		for z: float in [-32.30,-30.45,-28.60,-26.80]:
			_spar("Bridge railing upright",Vector3(side*5.84,16.43,z),Vector3(side*5.84,17.20,z),.073,_steel)
		for z: float in [-17.3,-3.8,9.8,23.4]:
			_work_platform(Vector3(side*6.9,_deck_height(z)+1.83,z),3.28,3.43)
			_pipe("Open-work platform support",Vector3(side*6.9,_deck_height(z)+.63,z),1.26,.79,.93,1.0,_steel)

func _upperworks() -> void:
	_funnel(-16.48,8.15,20.71,2.96,1.06,1.0)
	_funnel(2.72,8.21,19.38,3.16,1.01,1.0)
	_mast_silhouette(-25.30,18.61,36.92,5.45,2.35)
	_aft_mast(44.11,12.61,36.93,3.83)
	_spar("Fine fore-and-aft aerial",Vector3(0,31.80,-24.72),Vector3(0,32.20,44.61),.033,_dark)
	_small_halyards(-24.66,15.40,31.71,5.37)
	_small_halyards(44.65,13.30,32.30,3.66)
	for s: float in [-1,1]:
		_spar("Offset after deck upright",Vector3(s*4.4,7.58,29.3),Vector3(s*4.4,19.43,28.65),.38,_steel)
		_spar("Small mid deck crane boom",Vector3(s*4.4,15.61,28.91),Vector3(s*8.2,16.88,26.43),.23,_steel)

func _detail() -> void:
	_weather_rails(.93,3.12)
	_hull_relief([-73.3,-71.2,-67.4,-63.9,-60.6,-43.1,-35.8,-26.7,-18.7,
		10.1,11.8,14.0,17.7,20.1,55.9,58.9,61.9,66.4,70.1,76.3,80.2],false)
	_hawse_relief(-78.5,3.41,5.53,.94)
	_number("38",-76.2,4.10,1.07)
	_gallery("Foredeck cable cover",Vector3(0,_deck_height(-77.4)+.31,-77.4),4.19,.57,3.02,_steel)
	for side: float in [-1.0,1.0]:
		_spar("Subtle bow chain",Vector3(side*.82,_deck_height(-75.70)+.10,-75.70),Vector3(side*.81,_deck_height(-84.70)+.10,-84.70),.114,_dark)
		_duty_boat(Vector3(side*5.95,7.09,-9.22),side,.96)
		for z: float in [11.7,16.2,21.2]:
			_octagon("Small boat storage case",Vector3(side*6.1,_deck_height(z)+.65,z),2.23,1.19,2.82,.43,_upper,.94)
			_spar("Storage deck side rim",Vector3(side*7.10,_deck_height(z)+1.35,z-1.25),Vector3(side*7.10,_deck_height(z)+1.35,z+1.25),.119,_steel)
		for z: float in [-83.9,-76.7,-69.8,-63.3,57.2,61.3,67.4,72.3,79.1,83.3]:
			var x: float = 2.41 if absf(z)<79.5 else 1.07
			_deck_service(Vector3(side*x,_deck_height(z),z),.87)
		_octagon("Open central deck lattice base",Vector3(side*3.98,7.37,31.5),2.9,1.1,8.80,.40,_steel)
		_rail_track(Vector3(side*3.72,8.33,28.13),Vector3(side*.98,0,.17).normalized(),4.71)
		for z: float in [12.0,14.0,16.0,19.8,21.8,37.4]:
			_box("After house inset",Vector3(side*(6.0 if z<30 else 5.1),7.12,z),Vector3(.094,.54,.76),_dark)
		for z: float in [11.7,21.4]:
			_spar("Side gallery tier brace",Vector3(side*5.92,_deck_height(z)+.18,z),Vector3(side*7.07,_deck_height(z)+1.36,z+.24),.137,_steel)
		_gallery("Small stern covered position",Vector3(side*2.92,5.46,73.0),2.82,.59,3.79,_upper)
	for z: float in [-71.8,-67.2,61.1,73.5,80.5]:
		_deck_edges(z,2.2)
	_spar("Bow flag staff",Vector3(0,_deck_height(-87.80),-87.80),Vector3(0,10.11,-87.80),.085,_steel)
	_spar("Stern flag staff",Vector3(0,_deck_height(87.81),87.81),Vector3(0,8.82,87.81),.09,_steel)
