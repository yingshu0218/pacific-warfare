extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
## Photo-oriented exterior game asset, with inert gallery display poses.
const GUN := preload("res://scripts/presentation/models/archive_gun_rig.gd")
@export var cruiser := true

var wood: StandardMaterial3D
var light: StandardMaterial3D
var gray: StandardMaterial3D
var cap: StandardMaterial3D

func _half_length() -> float:
	return 100.6 if cruiser else 67.1

func _draft() -> float:
	return 5.9 if cruiser else 3.7

func _stations() -> Array[Vector4]:
	var half: float = _half_length()
	var beam: float = 9.7 if cruiser else 5.8
	var freeboard: float = 6.5 if cruiser else 4.25
	var out: Array[Vector4] = []
	# Rounded stern, long forecastle and curved sheer are art contours.
	var contour: Array[Vector4] = [
		Vector4(-1.0,.004,1.41,.003), Vector4(-.988,.065,1.38,.031),
		Vector4(-.965,.17,1.34,.08), Vector4(-.913,.34,1.23,.21),
		Vector4(-.84,.53,1.13,.37), Vector4(-.75,.71,1.05,.57),
		Vector4(-.61,.89,1,.79), Vector4(-.46,.97,.985,.91),
		Vector4(-.25,1,.97,.972), Vector4(0.0,1,.96,.98),
		Vector4(.24,.965,.94,.92), Vector4(.43,.9,.89,.84),
		Vector4(.61,.79,.84,.70), Vector4(.76,.68,.83,.56),
		Vector4(.86,.54,.83,.39), Vector4(.92,.39,.84,.26),
		Vector4(.965,.225,.85,.14), Vector4(.992,.094,.86,.058),
		Vector4(1.0,.023,.86,.017)]
	for r: Vector4 in contour:
		var drop: float = (0.85 if not cruiser else 0.48) * smoothstep(.015,.17,r.x)
		out.append(Vector4(half*r.x,r.y*beam,r.z*freeboard-drop,r.w*beam))
	return out

func _section(row: Vector4, side: float) -> PackedVector3Array:
	return _draw_section(row,side,8.0 if cruiser else 5.0,4.5 if cruiser else 3.7)

func _ready() -> void:
	_hull_side = _paint("657174")
	_steel = _paint("697677")
	_upper = _paint("7e8b89")
	_deck = _paint("7c7462" if cruiser else "626c6c")
	_underbody = _paint("65474a")
	_dark = _paint("313a3e")
	wood = _paint("a8987f")
	light = _paint("8c9a97")
	gray = _paint("515f62")
	cap = _paint("3f494b")
	_group = _layer("Weather hull")
	_hull()
	_group = _layer("Fixed deck details")
	_edges()
	if cruiser:
		_build_tone()
	else:
		_build_akizuki()
	_marks()

func _edges() -> void:
	var rows := _stations()
	var sh := 1.13 if cruiser else .8
	for sig: float in [-1., 1.]:
		for idx: int in range(2,rows.size()-2):
			var a: Vector4 = rows[idx]
			var b: Vector4 = rows[idx+1]
			var aa := Vector3(sig*(a.y-.2),a.z,a.x)
			var bb := Vector3(sig*(b.y-.2),b.z,b.x)
			_spar("Deck-edge rail",aa+Vector3.UP*sh,bb+Vector3.UP*sh,.075 if cruiser else .055,gray)
			_spar("Deck-edge middle rail",aa+Vector3.UP*sh*.55,bb+Vector3.UP*sh*.55,.047 if cruiser else .036,gray)
			var div: int = maxi(1,ceili(aa.distance_to(bb)/4.2))
			for j: int in range(div):
				var p: Vector3 = aa.lerp(bb,float(j)/div)
				_spar("Rail stanchion",p,p+Vector3.UP*sh,.078,light)
		for j: int in range(11 if cruiser else 7):
			var z: float = -_half_length()*.55+float(j)*4.4
			var w: float = (9.7 if cruiser else 5.8)*.974
			_box("Dark inset detail",Vector3(sig*w,_deck_height(z)-1.78,z),Vector3(.10,.27,.35),gray)
	var half: float = _half_length()
	_spar("Bow jackstaff",Vector3(0,_deck_height(-half*.95),-half*.95),Vector3(0,_deck_height(-half*.95)+2.6,-half*.95),.105,light)
	_spar("Stern flagstaff",Vector3(0,_deck_height(half*.97),half*.97),Vector3(0,_deck_height(half*.97)+2.2,half*.97),.096,light)
	for end: float in [-.89,.84]:
		for side: float in [-1.,1.]:
			var pos := Vector3(side*(2.1 if cruiser else 1.3),_deck_height(half*end)+.32,half*end)
			_pipe("Deck bollard",pos,.63,.37,.43,1.,gray)
			_spar("Deck seam strip",pos+Vector3(0,-.24,-2),pos+Vector3(0,-.24,2),.12,cap)

func _build_tone() -> void:
	var pieces: Array[Vector3] = [Vector3(-66,0,1.05),Vector3(-49,0,4.15),Vector3(-30.5,0,1.28),Vector3(-14,0,1.24)]
	for i: int in range(pieces.size()):
		var r: Vector3 = pieces[i]
		_display_mount("ForeGallery%02d" % (i+1),"main",Vector3(0,_deck_height(r.x),r.x),Vector3(8.4,2.65,7.5),r.z,Vector3.FORWARD if i < 2 else Vector3.BACK,2)
	_group = _layer("Tower Bridge and Funnel")
	_octagon("Raised deckhouse",Vector3(0,8.35,7.2),14.7,4.28,34.3,2.2,_steel)
	_octagon("Forward tower shoulder",Vector3(0,11.5,1.85),11.8,3.1,17.8,2.2,_upper)
	_octagon("Tall bridge taper",Vector3(0,15.32,1.15),8.05,4.64,14.1,1.96,_steel,.85)
	_octagon("Pilot deck overhang",Vector3(0,18.05,-.8),9.6,.65,11.4,2.1,_upper)
	_octagon("Wheelhouse",Vector3(0,19.31,-.7),7.15,1.78,8.1,1.56,_steel)
	_windows_face(Vector3(0,19.55,-4.69),7,.66,.47,.46)
	_octagon("Wheelhouse visor",Vector3(0,20.42,-.8),7.64,.41,8.68,1.70,_upper)
	_octagon("Watch tier",Vector3(0,21.73,-.3),5.75,1.5,5.4,1.25,gray)
	_gallery("Upper watch lip",Vector3(0,22.59,-.42),6.36,.36,5.8,light)
	_pipe("Rounded observation hood",Vector3(0,23.32,-1.1),1.25,1.26,1.04,1.,_upper)
	_octagon("Funnel weather casing",Vector3(0,10.66,21.25),10.7,5.35,15.2,2.17,_steel,.88)
	_gallery("Funnel collar",Vector3(0,13.12,21.25),10.3,.55,14.5,light)
	_funnel(21.2,13.39,4.15,8.8,1.82)
	_spar("Funnel housing stair rail",Vector3(4.37,10.87,16.1),Vector3(4.04,13.35,20.85),.086,light)
	_octagon("Aft socket tower",Vector3(0,9.45,44.6),7.2,4,10.,1.48,gray)
	_octagon("Aft observation platform",Vector3(0,11.75,44.6),8.32,.52,9.6,1.32,_upper)
	_signal_mast(3.1,19.4,32.7,3.9,2.2)
	_signal_mast(45.1,10.2,24.8,3.85,2.1)
	_spar("Dark main aerial line",Vector3(0,31.9,3.78),Vector3(0,23.8,45.8),.037,gray)
	for sig: float in [-1.,1.]:
		for i: int in range(2):
			var z := 23.5 + float(i)*10.1
			_display_mount("WingGallery%d_%d" % [1 if sig>0 else 2,i+1],"secondary",Vector3(sig*7.15,9.7,z),Vector3(3.6,1.56,3.54),.8,Vector3(sig,0,0),2)
		_display_mount("BridgeDisplay%d" % (1 if sig>0 else 2),"dedicated_aa",Vector3(sig*4.75,13.2,8.8),Vector3(1.75,.94,1.58),.35,Vector3(sig,0,0),2)
	_group = _layer("Low Aft Aviation Deck")
	_octagon("Aft aviation surface",Vector3(0,6.08,68.5),12.5,.88,39.8,2.5,gray)
	for sig: float in [-1.,1.]:
		_box("Deck handling tracks",Vector3(sig*2.1,6.6,69.3),Vector3(.18,.19,34.3),light)
		_box("Inset handling strips",Vector3(sig*4.85,6.66,68.6),Vector3(.22,.23,24.),light)
		var inner := Vector3(sig*2.18,7.17,54.5)
		_spar("Aircraft handling display beam",inner,inner+Vector3(sig*6.59,0,5.4),1.03,gray)
		_boat(Vector3(sig*5.22,9.93,16.2),2.23,6.81)
		_boat(Vector3(sig*5.48,7.84,42.1),2.05,5.96)
	_spar("Simple slender stern derrick",Vector3(-3.2,6.74,78.2),Vector3(-3.2,15.5,78.2),.66,_steel)
	_spar("Stern derrick boom",Vector3(-3.2,14.8,78.2),Vector3(1.65,16.16,73.3),.59,gray)
	_spar("Derrick suspension",Vector3(1.65,16.16,73.3),Vector3(1.65,8.1,73.3),.069,gray)

func _build_akizuki() -> void:
	for i: int in range(4):
		var z: float = [-47.,-32.4,35.,49.][i]
		_display_mount("TwinHouse%02d" % (i+1),"main",Vector3(0,_deck_height(z),z),Vector3(5.35,1.70,4.8),3.10 if i == 1 or i == 2 else .64,Vector3.FORWARD if i < 2 else Vector3.BACK,2)
	_group = _layer("Low wheelhouse and single stack")
	_octagon("Foredeck step",Vector3(0,5.78,-13.3),9.65,3.72,18.2,1.55,_steel)
	_octagon("Rounded bridge lower",Vector3(0,8.84,-17.4),7.82,2.48,8.3,1.53,_steel)
	_octagon("Bridge wing screen",Vector3(0,10.44,-18.7),8.9,.56,6.3,1.37,_upper)
	_gallery("Pilot enclosure",Vector3(0,11.49,-18.97),6.86,1.76,5.6,_steel)
	_windows_face(Vector3(0,11.76,-21.62),6,.68,.52,.52)
	_gallery("Bridge crown lip",Vector3(0,12.42,-18.96),7.11,.41,5.95,light)
	_octagon("Short weather closure",Vector3(0,13.45,-17.10),3.2,1.43,3.4,.50,gray)
	_octagon("Raised stack trunk",Vector3(0,5.61,-1.7),6.23,3.18,10.17,1.31,_steel,.89)
	_gallery("Stack plinth",Vector3(0,7.30,-1.7),6.49,.57,8.67,_upper)
	_funnel(-1.9,7.59,2.65,7.3,1.29)
	_octagon("Long rear deckhouse",Vector3(0,5.48,19.3),7.64,2.68,17.,1.19,_steel)
	_octagon("Rear small platform",Vector3(0,7.28,21.7),6.8,.54,7.5,1.11,_upper)
	_signal_mast(-11.45,10.1,23.9,2.75,1.98)
	_signal_mast(24.9,7.02,16.71,2.01,1.35)
	_spar("Slender signal line",Vector3(0,22.8,-10.7),Vector3(0,16,25.6),.031,cap)
	for sig: float in [-1.,1.]:
		_display_mount("WaistDisplay%d" % (1 if sig>0 else 2),"dedicated_aa",Vector3(sig*3.71,6.1,7.3),Vector3(1.58,.82,1.58),.34,Vector3(sig,0,0),2)
	_group = _layer("Work boats and central weather cover")
	_octagon("Midship low closed box",Vector3(0,5.21,10.5),4.23,1.52,3.61,.85,gray)
	for sig: float in [-1.,1.]:
		_boat(Vector3(sig*4.25,7.90,-2.9),1.68,5.42)
		_spar("Boat davit",Vector3(sig*4.65,5.5,-5),Vector3(sig*5.11,9.,-5),.21,_steel)
		_spar("Boat davit",Vector3(sig*4.65,5.5,-.82),Vector3(sig*5.11,9.,-.82),.21,_steel)

func _signal_mast(z: float,foot: float,top: float,yard: float,spread: float) -> void:
	var tip := Vector3(0,top,z+.65)
	_spar("Tapered signal mast",Vector3(0,foot,z),tip,.19 if cruiser else .13,_steel)
	for side: float in [-1.,1.]:
		_spar("Signal mast sloped support",Vector3(side*spread,foot,z+1.65),Vector3(0,top-(top-foot)*.21,z+.52),.12,_steel)
		var a := Vector3(side*yard,lerpf(foot,top,.64),z+.46)
		_spar("Lower crossyard",Vector3(0,a.y,a.z),a,.084,gray)
		_spar("Fine signal line",a,Vector3(side*spread*.87,foot+.39,z-1.1),.032,gray)
		_spar("Small upper yard",Vector3(0,top-2.5,z+.58),Vector3(side*yard*.52,top-2.5,z+.58),.074,gray)

func _funnel(z: float,foot: float,r: float,h: float,stretch: float) -> void:
	_pipe("Leaning funnel convex sides",Vector3(0,foot+h*.46,z),h*.95,r,r*.79,stretch,_steel).rotation.x = .093
	_pipe("Painted stack crown",Vector3(0,foot+h*.94,z+h*.048),h*.16,r*.81,r*.82,stretch,cap).rotation.x = .093
	for x: float in [-1.,1.]:
		_spar("Small stack side relief",Vector3(x*r*.72,foot+.3,z-r*stretch*.48),
			Vector3(x*r*.67,foot+h*.79,z-r*stretch*.55),r*.064,gray)

func _boat(p: Vector3,w: float,len: float) -> void:
	_octagon("Boat hull outer",p,w,.95,len,w*.41,wood,.72)
	_octagon("Boat interior cover",p+Vector3.UP*.38,w*.83,.28,len*.87,w*.31,gray,.97)
	for z: float in [-.23,0.,.23]:
		_box("Light boat thwart",p+Vector3(0,.58,z*len),Vector3(w*.65,.14,.21),wood)

func _display_mount(id: String,role: String,p: Vector3,size: Vector3,rise: float,front: Vector3,count: int) -> void:
	_group = _layer(id + " stationary collar")
	_pipe("Stationary collar",p+Vector3.UP*rise*.5,rise,size.x*.42,size.x*.40,1.,gray)
	var shape_start: int = _group.get_child_count()
	var c := GCase.new()
	c.center = p+Vector3.UP*(rise+size.y*.5)
	c.width = size.x
	c.height = size.y
	c.length = size.z
	c.front = front
	_case_shape(c)
	var side := Vector3(front.z,0,-front.x)
	_box("Top inspection panel",c.center+Vector3.UP*size.y*.54,Vector3(size.x*.28,.13,size.z*.28),gray)
	var body: Array = _group.get_children().slice(shape_start)
	var barrel_start: int = _group.get_child_count()
	var pivot := c.center + front*size.z*.24
	for i: int in range(count):
		var shift: float = (float(i)-float(count-1)*.5)*size.x*.32
		var a := pivot + side*shift
		var b := a + front*size.z*.92 + Vector3.UP*size.y*.08
		_spar("Closed display spar",a,b,maxf(.12,size.x*.054),gray)
		_spar("Shaded display collar",a,a+front*size.z*.33,maxf(.18,size.x*.085),cap)
	var barrel: Array = _group.get_children().slice(barrel_start)
	GUN.attach(self,id,role,p+Vector3.UP*rise,pivot,front,body,barrel)

func _marks() -> void:
	set_meta("visual_reference","NHHC 80-G-88024 / NH 111736" if cruiser else "Kure Maritime Museum, Akizuki trials, May 1942")
	set_meta("art_only",true)
