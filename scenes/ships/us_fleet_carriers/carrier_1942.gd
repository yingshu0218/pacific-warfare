extends "res://scenes/ships/us_carrier_1942_visual/carrier.gd"
## Static hand-shaped museum models. Coordinate dimensions are display envelopes.
@export_enum("Yorktown CV-5", "Lexington CV-2", "Wasp CV-7") var variant: int = 0
const YORKTOWN := 0
const LEXINGTON := 1
const WASP := 2

func _half_length() -> float:
	return [123.3678,135.3312,112.9792][variant]

func _draft() -> float:
	return [7.75,8.56,6.07][variant]

func _stations() -> Array[Vector4]:
	match variant:
		YORKTOWN:
			return [Vector4(-123.3678,.16,10.89,.11),Vector4(-120,1.67,10.47,.45),Vector4(-114,3.25,9.95,1.63),Vector4(-103,6.32,9.24,4.0),Vector4(-89,9.12,8.55,7.23),Vector4(-70,11.51,8.03,10.61),Vector4(-48,12.50,7.77,12.13),Vector4(-22,12.82,7.65,12.61),Vector4(21,12.82,7.61,12.65),Vector4(60,12.53,7.54,12.19),Vector4(83,11.85,7.45,10.82),Vector4(103,9.23,7.32,7.82),Vector4(114,6.11,7.23,3.92),Vector4(120,3.93,7.20,1.14),Vector4(123.3678,1.46,7.15,.10)]
		LEXINGTON:
			return [Vector4(-135.3312,.12,11.83,.12),Vector4(-132.5,1.59,11.41,.51),Vector4(-126,3.72,10.81,1.48),Vector4(-116,6.51,10.09,3.63),Vector4(-103,10.09,9.48,7.17),Vector4(-86,13.44,9.02,10.90),Vector4(-67,15.30,8.67,13.63),Vector4(-39,16.12,8.38,15.92),Vector4(-12,16.52,8.25,16.05),Vector4(31,16.40,8.23,16.02),Vector4(65,15.80,8.16,15.50),Vector4(94,14.25,8.05,12.95),Vector4(116,10.51,8.01,8.12),Vector4(126,7.27,7.94,4.57),Vector4(132,4.32,7.85,1.19),Vector4(135.3312,1.33,7.75,.17)]
		_:
			return [Vector4(-112.9792,.12,9.76,.11),Vector4(-109.5,1.40,9.48,.48),Vector4(-103,3.53,8.87,1.79),Vector4(-94,5.93,8.38,3.68),Vector4(-79,9.12,7.74,7.02),Vector4(-62,11.15,7.34,10.34),Vector4(-39,12.14,7.07,11.95),Vector4(-14,12.43,6.92,12.28),Vector4(29,12.44,6.90,12.30),Vector4(60,12.1,6.91,11.8),Vector4(78,10.98,7.0,10.52),Vector4(91,9.03,7.09,8.34),Vector4(103,6.88,7.16,5.47),Vector4(110.8,5.75,7.23,2.73),Vector4(112.9792,4.50,7.18,.28)]

func _deck_plan() -> Array[Vector2]:
	match variant:
		YORKTOWN:
			return [Vector2(-118.9,4.37),Vector2(-117,8.85),Vector2(-111.8,12.0),Vector2(-101,14.66),Vector2(-83.5,15.61),Vector2(-51.9,15.75),Vector2(-31,16.53),Vector2(27,16.53),Vector2(63,16.24),Vector2(95,15.85),Vector2(112,14.1),Vector2(120,12.10),Vector2(121.9,9.85)]
		LEXINGTON:
			return [Vector2(-128.1,6.30),Vector2(-126.6,10.53),Vector2(-120.1,14.52),Vector2(-107,17.3),Vector2(-85,18.65),Vector2(-45,19.03),Vector2(38,19.03),Vector2(68,18.97),Vector2(101,18.36),Vector2(119.8,16.30),Vector2(128.1,13.62),Vector2(131.7,10.50)]
		_:
			return [Vector2(-107,4.80),Vector2(-105.8,7.62),Vector2(-101.1,10.93),Vector2(-92,13.36),Vector2(-80,14.30),Vector2(-52,14.47),Vector2(-26,14.65),Vector2(23,14.65),Vector2(61,14.27),Vector2(87,14.00),Vector2(102,13.12),Vector2(110.6,10.33),Vector2(111.8,8.94)]

func _ready() -> void:
	flight_y = [14.07,14.49,12.53][variant]
	_steel = _paint(["74858d","74828a","758790"][variant])
	_hull_side = _paint(["526577","687984","637985"][variant])
	_underbody = _paint("704944")
	_upper = _paint("98a5a9")
	_deck = _paint("626c70")
	_dark = _paint("36434c")
	_edge = _paint("4f6169")
	_wood = _paint(["64818d","718893","72919b"][variant])
	_glass = _paint("32434b")
	_mark = _paint("84939a")
	_group = _layer("CurvedWaterlineHull")
	_hull()
	_group = _layer("HangarAndGallery")
	_carrier_bays()
	_group = _layer("FlightDeckAndFlushElevators")
	_carrier_flight_deck()
	_group = _layer("StarboardIsland")
	match variant:
		YORKTOWN: _yorktown()
		LEXINGTON: _lexington()
		WASP: _wasp()
	_group = _layer("VisibleExteriorFittings")
	_outboard()
	if variant == WASP: _wasp_tones()

func _carrier_flight_deck() -> void:
	var top := _surface()
	var belt := _surface()
	var field := _deck_plan()
	var y := flight_y
	var bottom := y-.77
	for i in range(field.size()-1):
		var a := field[i]
		var b := field[i+1]
		_quad(top,Vector3(-a.y,y,a.x),Vector3(a.y,y,a.x),Vector3(b.y,y,b.x),Vector3(-b.y,y,b.x),Vector3.UP)
		_quad(belt,Vector3(-a.y+.18,bottom,a.x),Vector3(-b.y+.18,bottom,b.x),Vector3(b.y-.18,bottom,b.x),Vector3(a.y-.18,bottom,a.x),Vector3.DOWN)
		for side: float in [-1.0,1.0]:
			_quad(belt,Vector3(side*a.y,y,a.x),Vector3(side*b.y,y,b.x),Vector3(side*(b.y-.18),bottom,b.x),Vector3(side*(a.y-.18),bottom,a.x),Vector3(side,0,0))
	for i: int in [0,field.size()-1]:
		var e := field[i]
		_quad(belt,Vector3(-e.y,y,e.x),Vector3(e.y,y,e.x),Vector3(e.y-.18,bottom,e.x),Vector3(-e.y+.18,bottom,e.x),Vector3.FORWARD if i == 0 else Vector3.BACK)
	_commit("Continuous fore-aft timber deck",top,_wood)
	_commit("Rounded deck fascia and soffit",belt,_edge)
	# Broad low-contrast boards read at typical archive zoom; small dark joints stay subtle.
	var seams := _surface()
	var bands := _surface()
	for x: int in range(-18,19):
		var a: float = 0.0
		var b: float = 0.0
		for z: int in range(ceili(field[0].x)+1,floori(field[-1].x)):
			if _deck_half(float(z))-.28 > absf(x):
				if is_zero_approx(a): a = float(z)
				b = float(z)
		if b <= a: continue
		if x%3 == 1:
			_quad(bands,Vector3(x-.33,y+.009,a),Vector3(x+.29,y+.009,a),Vector3(x+.29,y+.009,b),Vector3(x-.33,y+.009,b),Vector3.UP)
		_quad(seams,Vector3(x-.039,y+.016,a),Vector3(x+.039,y+.016,a),Vector3(x+.039,y+.016,b),Vector3(x-.039,y+.016,b),Vector3.UP)
		var z := a+3.7+float(posmod(x,5))*1.35
		while z < b-1.0:
			_quad(seams,Vector3(x+.04,y+.016,z-.037),Vector3(x+.94,y+.016,z-.037),Vector3(x+.94,y+.016,z+.037),Vector3(x+.04,y+.016,z+.037),Vector3.UP)
			z += 11.7
	_commit("Low-contrast staggered timber joints",seams,_paint(["435d68","4d6470","4b6875"][variant]))
	_commit("Alternating stained timber strips",bands,_paint(["607b87","6a818d","668891"][variant]))
	for side: float in [-1.,1.]:
		for i in range(field.size()-1):
			if i in [0,field.size()-2]: continue
			var a := field[i]
			var b := field[i+1]
			_spar("Inset exterior deck-edge rail band",Vector3(side*(a.y-.31),y+.013,a.x),Vector3(side*(b.y-.31),y+.013,b.x),.090,_mark)
	match variant:
		YORKTOWN:
			for z: float in [-75.6,-4.1,77.3]: _display_lift("Yorktown",z,13.3,14.6)
		LEXINGTON:
			_display_lift("Lexington forward",-84.3,10.8,17.2)
			_display_lift("Lexington after",80.7,11.6,13.5)
		WASP:
			_display_lift("Wasp forward",-66.1,12.6,14.1)
			_display_lift("Wasp after",68.4,12.7,14.3)
			_octagon("Port deck-edge elevator fixed flush",Vector3(-14.95,y-.29,-11.2),4.44,.54,12.40,1.03,_steel)
			_octagon("Port elevator T-shaped outboard tongue",Vector3(-17.62,y-.29,-11.2),2.11,.51,3.72,.41,_steel)
			_spar("Elevator outer edge",Vector3(-17.12,y-.08,-16.22),Vector3(-17.12,y-.08,-6.18),.16,_edge)
			for z: float in [-16.0,-6.3]:
				_spar("Display-only lattice under port platform",Vector3(-10.9,y-3.90,z),Vector3(-16.97,y-.51,z),.31,_steel)

func _display_lift(label: String,z: float,w: float,d: float) -> void:
	var y := flight_y
	var groove := _paint("354e58")
	var lift_tone := _paint(["78909a","7a919b","7c9ba5"][variant])
	_box(label+" flush outer outline",Vector3(0,y+.025,z),Vector3(w+.16,.035,d+.16),groove)
	_box(label+" flush inset timber",Vector3(0,y+.045,z),Vector3(w-.50,.034,d-.50),lift_tone)
	for i: int in range(1,int(floorf(w))-1):
		var x := -w*.5+.38+float(i)
		_box("Inset elevator timber joint",Vector3(x,y+.066,z),Vector3(.067,.013,d-.61),_edge)


func _carrier_bays() -> void:
	var y := flight_y-.77
	var core_length: float = [194.,216.,173.][variant]
	var core_width: float = [18.4,25.5,17.3][variant]
	var floor_y: float = [7.45,7.91,6.79][variant]
	_octagon("Dark hangar backing",Vector3(0,(y+floor_y)*.5,0),core_width,y-floor_y,core_length,2.6,_edge)
	for side: float in [-1.,1.]:
		var n: int = [19,22,17][variant]
		var step := core_length/n
		for j: int in range(n):
			var shift := .75*sin(j*1.6+side)
			var z := (j-(n-1)*.5)*step+shift
			var wx := minf(_deck_half(z)-1.43,core_width*.5+2.15)
			var yy := _deck_height(z)
			var open_side := false
			match variant:
				YORKTOWN: open_side = j in [0,2,3,7,8,9,13,15,17,18]
				LEXINGTON: open_side = j in [1,2,6,10,14,18,20,21]
				WASP: open_side = j in [0,2,5,6,7,10,12,13,15]
			var x := side*wx
			var gap := step*(.73+.17*sin(j*2.03+side)) if open_side else step-.74
			var recess := .84 if variant == LEXINGTON else 1.17
			_box("Recessed shadow beneath the flight deck",Vector3(x-side*recess,(y+yy)*.5,z),Vector3(.29,y-yy,gap),_dark if open_side else _hull_side)
			if open_side and (j%2 == 0 or variant == WASP):
				_box("Offset hangar mullion",Vector3(x-side*.35,(yy+y)*.5,z+gap*.20),Vector3(.40,y-yy,.46),_steel)
				_box("Flanking shutter leaf",Vector3(x-side*.55,(yy+y)*.5,z-gap*.35),Vector3(.23,y-yy,step*.27),_hull_side)
			if variant != LEXINGTON and j%3 != 0:
				_octagon("Folding scaffold side silhouette",Vector3(side*(_deck_half(z)-.73),y-.63,z+step*.17),2.42,.24,step*.52,.66,_steel)
			_box("Hangar side pier",Vector3(x,(y+yy)*.5,z-step*.46),Vector3(.65,y-yy,.78),_steel)
			_box("Underdeck edge beam",Vector3(x,y-.19,z),Vector3(1.16,.41,step),_steel)
			_box("Gallery sill",Vector3(x,yy+.31,z),Vector3(1.78,.30,step-.17),_steel)
			if open_side:
				_spar("Underdeck knee",Vector3(x-side*.4,yy+.38,z-step*.43),Vector3(side*(_deck_half(z)-.42),y-.04,z-step*.43),.28,_steel)
			else:
				for k in range(3):
					_box("Shutter shade band",Vector3(x-side*.39,lerpf(yy,y,(k+1)*.23),z),Vector3(.09,.056,step-.96),_edge)
			if j > 1 and j < n-2 and not (variant == WASP and side < 0 and z >= -25 and z <= 1):
				var gallery := side*(_deck_half(z)-.46)
				_box("Outer flight-deck catwalk",Vector3(gallery,y-.58,z),Vector3(.98,.20,step-.58),_steel)
				_rail(Vector3(gallery+side*.43,y-.48,z-step*.43),Vector3(gallery+side*.43,y-.48,z+step*.43),3)
		for sw: float in [-1.,1.]:
			for j in range(3):
				var z := sw*(core_length*.5+1.6+j*5.)
				if z <= _deck_plan()[0].x+1.0 or z >= _deck_plan()[-1].x-1.0: continue
				var hx := minf(_deck_half(z)-1.18,_side_at(z,_deck_height(z))-.35)
				var yy := _deck_height(z)
				_box("Cantilever stanchion",Vector3(side*hx,(yy+y)*.5,z),Vector3(.52,y-yy,.61),_steel)
				_spar("Deck end web",Vector3(side*hx,yy,z),Vector3(side*(_deck_half(z)-.53),y,z),.38,_steel)
				if side > 0.0: _box("Exposed end crossbeam",Vector3(0,y-.21,z),Vector3(_deck_half(z)*1.95,.42,.52),_steel)

func _island_base(x: float,z: float,b: float,w: float,d: float,h: float,cut: float) -> void:
	_octagon("Tapered hangar-top island footprint",Vector3(x,b+h*.5,z),w,h,d,cut,_steel,.94)
	for j: int in range(5):
		_box("Island side recess",Vector3(x+w*.48,b+.70,z+(j-2)*d*.121),Vector3(.11,.44,.68),_edge)

func _bridge_tiers(x: float,y: float,z: float,w: float,d: float,h: float) -> void:
	_octagon("Rounded chart-house",Vector3(x,y+h*.36,z),w,h*.72,d,w*.25,_upper,.96)
	_octagon("Overhanging bridge apron",Vector3(x,y+h*.67,z-.35),w+2.05,.31,d+1.6,w*.28,_steel)
	_octagon("Wheelhouse",Vector3(x,y+h*.86,z-.52),w-.38,h*.40,d*.78,w*.21,_upper,.98)
	_panes(x,y+h*.89,z-.52,w-.38,d*.78,6)
	_octagon("Fore bridge shade cap",Vector3(x,y+h*1.07,z-.52),w+.28,.28,d*.83,w*.23,_steel)
	var a := Vector3(x-w*.42,y+h*1.15+.12,z-d*.38-1.1)
	var b := Vector3(x+w*.42,y+h*1.15+.12,z-d*.38-1.1)
	_box("Open bridge upper deck",Vector3(x,y+h*1.15,z-1.2),Vector3(w*.86,.24,d*.77),_steel)
	_rail(a,b,6)

func _signal_beam(x: float,y: float,z: float,width: float) -> void:
	_yard(x,y,z,width)
	var a := Vector3(x,y+2.15,z)
	for s: float in [-1.,1.]:
		_spar("Mast-top signal halyard",a,Vector3(x+s*width*.89,y-.02,z),.086,_edge)

func _bridge_wings(x: float,y: float,z: float,width: float,depth: float) -> void:
	for s: float in [-1.,1.]:
		var xx := x+s*(width*.5-1.27)
		_octagon("Projecting open signal wing",Vector3(xx,y,z),2.42,.32,depth,1.00,_steel)
		_rail(Vector3(xx+s*.98,y+.17,z-depth*.33),Vector3(xx+s*.98,y+.17,z+depth*.33),3)
		_spar("Bridge wing exterior bracket",Vector3(x+s*(width*.37-1.19),y-2.40,z+.4),Vector3(xx+s*.78,y-.15,z+.4),.32,_steel)

func _yorktown() -> void:
	var y := flight_y
	var x := 12.15
	_island_base(x,0.2,y,8.06,41.4,2.2,1.38)
	_octagon("Forward tapered island apron",Vector3(x-.53,y+1.02,-23.6),6.53,2.04,10.5,1.34,_steel,.89)
	_bridge_tiers(x-.31,y+1.38,-11.19,7.55,15.20,6.05)
	_bridge_wings(x-.31,y+4.46,-12.8,10.20,7.40)
	_bridge_wings(x-.12,y+6.96,-9.35,10.72,9.41)
	_octagon("Rounded fore observation cupola",Vector3(x-.42,y+8.9,-17.63),3.24,1.91,3.89,1.18,_upper,.94)
	_funnel(x+.43,9.33,y+2.45,9.05,6.16,16.57,1.61)
	_octagon("Lower casing aft of the bridge",Vector3(x+.31,y+2.62,14.46),7.95,4.40,12.10,1.63,_steel,.96)
	_octagon("Raised aft platform immediately behind funnel",Vector3(x+.34,y+5.57,20.06),7.48,.46,6.88,1.60,_steel)
	_pipe("Foremast main spar",Vector3(x-.61,y+15.17,-7.13),17.3,.36,.15,1.,_steel)
	for s: float in [-1.,1.]:
		_spar("Open tripod bracing silhouette",Vector3(x+s*3.02,y+3.68,-.18),Vector3(x-.61,y+16.72,-7.13),.58,_steel)
		_spar("Slender antenna stays",Vector3(x-.61,y+20.4,-7.13),Vector3(x+s*4.34,y+7.4,-11.22),.079,_edge)
	_octagon("Wide tripod observation top",Vector3(x-.61,y+13.98,-7.13),5.49,.83,5.12,1.31,_upper)
	_octagon("Upper tripod lookout",Vector3(x-.61,y+15.04,-7.13),4.38,.80,4.18,1.01,_dark)
	_signal_beam(x-.61,y+17.25,-7.13,5.75)
	_screen(x-.61,y+21.56,-7.13,5.78,2.05)
	_pipe("Slim, separate aft signal mast",Vector3(x+.60,y+12.7,19.87),16.45,.25,.12,1.,_steel)
	_signal_beam(x+.60,y+17.6,19.87,2.91)
	_spar("Continuous aerial between distinct poles",Vector3(x-.61,y+21.7,-7.13),Vector3(x+.60,y+20.9,19.87),.066,_edge)
	_crane(15.22,43.0)

func _lexington() -> void:
	var y := flight_y
	var x := 14.81
	_island_base(x,1.4,y,8.36,53.5,2.40,1.45)
	_bridge_tiers(x-.08,y+1.5,-17.19,7.31,12.14,7.28)
	_bridge_wings(x-.11,y+4.85,-16.0,10.06,9.62)
	_octagon("Fore tapered navigating top",Vector3(x-.39,y+11.8,-15.15),4.02,1.53,4.68,1.02,_upper,.94)
	# Narrow separation above the base between the bridge tower and massive separate slab.
	_octagon("Funnel lower casing",Vector3(x+.40,y+3.83,9.21),8.23,7.46,27.65,1.48,_steel,.99)
	_funnel(x+.53,11.28,y+3.63,14.05,7.72,29.92,1.68)
	for z: float in [0.5,4.6,8.8,13.0,17.2,21.4]:
		for s: float in [-1.,1.]:
			_oval_recess(x+.53+s*3.88,y+7.69,z,1.71,1.56,s)
	for q: float in [9.2,15.8,24.9]:
		_spar("Fine exterior vertical division along the slab",Vector3(x+4.42,y+8.78,q),Vector3(x+4.42,y+16.82,q),.11,_edge)
	_pipe("Slender independent foremast",Vector3(x-.38,y+15.6,-15.25),17.1,.32,.13,1.,_steel)
	_octagon("Mast observation platform",Vector3(x-.38,y+14.91,-15.25),3.80,.76,4.43,.89,_steel)
	_signal_beam(x-.38,y+18.60,-15.25,4.33)
	_spar("Light aft standing mast stays",Vector3(x+.68,y+6.44,30.33),Vector3(x+.78,y+16.1,30.33),.24,_steel)
	_screen(x-.38,y+21.19,-15.25,4.39,1.16)
	_crane(16.54,60.8)

func _wasp() -> void:
	var y := flight_y
	var x := 10.91
	_island_base(x,-.28,y,6.91,37.12,1.88,1.22)
	_octagon("Low stepped bow-facing island cheek",Vector3(x-.25,y+1.36,-19.56),7.09,2.73,11.2,1.21,_steel,.92)
	_bridge_tiers(x-.23,y+1.80,-8.90,5.97,10.76,5.09)
	_bridge_wings(x-.23,y+4.30,-10.04,8.92,6.64)
	_bridge_wings(x+.09,y+7.15,-7.10,8.10,7.57)
	_funnel(x+.46,7.98,y+2.22,11.38,5.71,12.80,1.20)
	_box("Sheet shoulder under the funnel",Vector3(x+.03,y+2.53,8.17),Vector3(6.33,4.98,15.00),_steel)
	_octagon("Foremast waist platform",Vector3(x-.62,y+10.83,-5.37),4.25,.40,4.13,1.03,_upper)
	_octagon("Foremast raised instrument deck",Vector3(x-.62,y+13.62,-5.37),4.99,.54,4.39,.98,_steel)
	_pipe("Foremast pole",Vector3(x-.64,y+12.83,-5.42),15.91,.31,.13,1.,_steel)
	_spar("Fine raking backstay",Vector3(x+1.61,y+4.34,1.41),Vector3(x-.64,y+14.04,-5.42),.23,_steel)
	_signal_beam(x-.64,y+15.01,-5.42,4.48)
	_screen(x-.64,y+18.64,-5.42,4.19,2.05)
	_octagon("Stepped after observation casing",Vector3(x+.35,y+3.55,16.11),5.95,3.7,6.13,1.05,_steel,.94)
	_octagon("Aft stack-side lookout",Vector3(x+.41,y+6.19,16.66),5.29,2.00,5.24,.99,_upper,.88)
	_octagon("Aft stack-side projecting platform",Vector3(x+.41,y+7.27,17.21),5.71,.34,4.83,.96,_steel)
	_pipe("Distinct high second aft mast",Vector3(x+.33,y+12.3,19.21),15.1,.22,.10,1.,_steel)
	_signal_beam(x+.33,y+16.16,19.21,3.13)
	_spar("Fine aft-to-fore static wire",Vector3(x+.33,y+19.66,19.21),Vector3(x-.64,y+20.36,-5.42),.065,_edge)
	_crane(12.06,43.5)

func _outboard() -> void:
	var scuttles := _surface()
	for side: float in [-1.,1.]:
		var positions: Array = [[-82.,-49.,-24.,54.,86.],[-96.,-61.,-35.,60.,103.],[-77.,-46.,25.,51.,84.]][variant]
		for j: int in range(positions.size()):
			var z: float = positions[j]
			var x := side*(_deck_half(z)-1.43)
			var y: float = flight_y-[2.05,2.56,1.99][variant]-.42*(j%2)
			var gallery_len: float = [[8.7,6.26,11.1,6.01,7.73],[8.7,7.09,7.7,6.94,9.32],[6.18,9.2,8.41,4.7,7.01]][variant][j]
			_octagon("Unoccupied static exterior gallery",Vector3(x,y,z),3.93,.68,gallery_len,1.37,_steel)
			for zz: float in [-gallery_len*.23,gallery_len*.23]:
				_spar("Gallery visible support",Vector3(x-side*2.5,y-2.61,z+zz),Vector3(x,y-.29,z+zz),.44,_steel)
			_rail(Vector3(x+side*1.82,y+.24,z-gallery_len*.35),Vector3(x+side*1.82,y+.24,z+gallery_len*.35),4)
		for j in range(16):
			var z := (-.72+.087*float(j))*_half_length()
			if (j+variant)%5 == 3: continue
			var yy := _deck_height(z)-1.24
			var sw := _side_at(z,yy)
			var p := Vector3(side*(sw+.082),yy,z)
			for i in range(9):
				var a := TAU*i/9.
				var b := TAU*(i+1)/9.
				_tri(scuttles,p,p+Vector3(0.,.20*cos(a),.30*sin(a)),p+Vector3(0.,.20*cos(b),.30*sin(b)),Vector3(side,0.,0.))
		var az := -_half_length()+14.59
		var ay := _deck_height(az)-1.82
		var ax := side*(_side_at(az,ay)+.14)
		_oval_recess(ax,ay,az,2.15,1.06,side)
		_spar("Exterior mooring silhouette shadow",Vector3(ax+side*.13,ay-.21,az),Vector3(ax+side*.25,ay-1.26,az+.65),.23,_dark)
		for j in range(4):
			var z := (j-1.7)*6.28
			var xx := side*(_deck_half(z)-2.61)
			var y := flight_y-2.81
			if variant == WASP and side<0 and z<1.0: continue
			_box("Catwalk storage tonal block",Vector3(xx,y,z),Vector3(1.95,1.29,3.72),_upper)
		for z: float in [-.81*_half_length(),.79*_half_length()]:
			var y := _deck_height(z)
			var w := minf(_deck_half(z)-2.14,_side_at(z,y)-1.67)
			_octagon("Davit boat exterior",Vector3(side*w,y+.37,z),1.84,.76,5.82,.65,_upper,.91)
			_spar("Fixed small davit",Vector3(side*(w-1.1),y,z-1.37),Vector3(side*(w+.71),y+2.12,z-.92),.27,_steel)
		for z: float in [-_half_length()+7.,_half_length()-7.]:
			var y := _deck_height(z)
			var w := minf(1.45,_side_at(z,y)-.19)
			_pipe("Rounded mooring silhouette",Vector3(side*w,y+.27,z),.54,.31,.27,1.,_dark)

	_commit("Batched shaded service scuttles",scuttles,_dark)

func _wasp_tones() -> void:
	# Painted tonal breakup is a display interpretation; not an August paint chart.
	var stains := _surface()
	var rows := _stations()
	var dark_patch := _paint("526a77")
	for side: float in [-1.,1.]:
		for i: int in [3,4,7,8,10,11]:
			var a: PackedVector3Array = _section(rows[i],side)
			var b: PackedVector3Array = _section(rows[i+1],side)
			var outward := Vector3(side,0,0)
			var lift := outward*.048
			var low_a := a[3].lerp(a[4],.33 if i%4 == 0 else .71)
			var low_b := b[3].lerp(b[4],.75 if i%3 == 1 else .32)
			var high_a := a[4].lerp(a[5],.83 if i%3 == 0 else .27)
			var high_b := b[4].lerp(b[5],.31 if i%4 == 0 else .80)
			_quad(stains,low_a+lift,low_b+lift,b[4]+lift,a[4]+lift,outward)
			_quad(stains,a[4]+lift,b[4]+lift,high_b+lift,high_a+lift,outward)
	_commit("Interpretive 1942 low-contrast tonal fields",stains,dark_patch)
