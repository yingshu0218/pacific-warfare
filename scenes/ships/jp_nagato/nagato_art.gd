extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
## October 1944 archive exterior. Units are Godot art coordinates only.
const GUN := preload("res://scripts/presentation/models/archive_gun_rig.gd")
var gray: StandardMaterial3D
var wood: StandardMaterial3D
var light: StandardMaterial3D
var cap: StandardMaterial3D

func _half_length() -> float:
	return 112.5

func _draft() -> float:
	return 8.3

func _stations() -> Array[Vector4]:
	var contour: Array[Vector4] = [
		Vector4(-1.,.012,10.2,.005),Vector4(-.985,.072,9.8,.018),
		Vector4(-.956,.19,9.44,.08),Vector4(-.91,.34,9.03,.18),
		Vector4(-.84,.52,8.55,.33),Vector4(-.74,.71,8.05,.53),
		Vector4(-.63,.875,7.65,.72),Vector4(-.48,.965,7.4,.89),
		Vector4(-.29,1.,7.2,.97),Vector4(-.11,1.,7.12,.99),
		Vector4(.15,.998,7.05,.99),Vector4(.34,.956,6.98,.92),
		Vector4(.49,.896,6.92,.84),Vector4(.57,.825,6.12,.76),
		Vector4(.72,.70,5.35,.60),Vector4(.84,.56,5.19,.44),
		Vector4(.92,.404,5.15,.32),Vector4(.978,.225,5.19,.14),
		Vector4(1.,.065,5.26,.035)]
	var out: Array[Vector4] = []
	for r: Vector4 in contour:
		out.append(Vector4(r.x*_half_length(),r.y*16.2,r.z,r.w*16.2))
	return out

func _section(row: Vector4, side: float) -> PackedVector3Array:
	return _draw_section(row,side,10.,6.6)

func _ready() -> void:
	_hull_side = _paint("657174")
	_steel = _paint("697677")
	_upper = _paint("7e8b89")
	_deck = _paint("827965")
	_underbody = _paint("65474a")
	_dark = _paint("313a3e")
	wood = _paint("a8987f")
	light = _paint("8c9a97")
	gray = _paint("515f62")
	cap = _paint("3f494b")
	_group = _layer("Weather hull")
	_hull()
	_group = _layer("Weather deck fittings")
	_fixed_edges()
	_build_pagoda()
	_build_waist()
	_build_aft()
	var major: Array[Vector3] = [Vector3(-65,0,1.15),Vector3(-45,0,4.38),Vector3(48,0,4.50),Vector3(70,0,1.20)]
	for i: int in range(major.size()):
		var p: Vector3 = major[i]
		_display_mount("CenterGallery%02d" % (i+1),"main",Vector3(0,_deck_height(p.x),p.x),Vector3(11.1,3.58,9.7),p.z,Vector3.FORWARD if i<2 else Vector3.BACK,2)
	for sign: float in [-1.,1.]:
		for j: int in range(3):
			var p := Vector3(sign*(12.05 if j==0 else 12.45),11.16,(-18.5 + 16.0*j))
			_display_mount("WaistGallery%s%d" % [("S" if sign>0 else "P"),j+1],"dedicated_aa",p,Vector3(2.4,.95,1.86),.3,Vector3(sign,0.,0.),2)
	set_meta("visual_reference","Kure Maritime Museum / NHHC NH 73090")
	set_meta("art_only",true)

func _fixed_edges() -> void:
	var rows := _stations()
	for side: float in [-1.,1.]:
		for idx: int in range(1,rows.size()-2):
			var a: Vector4 = rows[idx]
			var b: Vector4 = rows[idx+1]
			var first := Vector3(side*(a.y-.2),a.z+.02,a.x)
			var next := Vector3(side*(b.y-.2),b.z+.02,b.x)
			_spar("Upper rail",first+Vector3.UP,next+Vector3.UP,.072,gray)
			_spar("Lower rail",first+Vector3.UP*.49,next+Vector3.UP*.49,.052,gray)
			var div: int = maxi(1,ceili(first.distance_to(next)/4.4))
			for j: int in range(div):
				var pin := first.lerp(next,float(j)/div)
				_spar("Rail upright",pin,pin+Vector3.UP,.07,light)
		for j: int in range(11):
			var z: float = -36. + float(j)*6.2
			var x := side*(15.54-.007*z*z/50.)
			_box("Dark hull port",Vector3(x,_deck_height(z)-.91,z),Vector3(.07,.33,.47),gray)
		for z: float in [-105.,-96.,93.,103.]:
			var p := Vector3(side*1.64,_deck_height(z)+.15,z)
			_pipe("Deck bollard",p,.55,.47,.48,1.,gray)
		var eye := Vector3(side*3.86,9.7,-102.)
		_pipe("Closed bow chain plate",eye,.44,.58,.58,1.,gray).rotation.z = PI*.39
		for j: int in range(12):
			_box("Foredeck chain relief",Vector3(side*(3.13-j*.16),_deck_height(-100+j*1.22)+.055,-100+j*1.22),Vector3(.17,.19,.75),cap)
	_spar("Bow staff",Vector3(0,10.1,-111),Vector3(0,13.3,-111),.106,light)
	_spar("Stern staff",Vector3(0,5.23,111),Vector3(0,8.35,111),.11,light)

func _build_pagoda() -> void:
	_group = _layer("Pagoda silhouette")
	_octagon("Raised center deckhouse",Vector3(0,8.8,0.),25.9,3.55,65.,4.5,_steel)
	_octagon("Low bridge apron",Vector3(0,12.78,-19.),13.8,4.6,26.7,3.6,_steel)
	_octagon("Tiered bridge core",Vector3(0,26.21,-22.),7.4,26.3,11.8,2.34,_steel,.81)
	var tiers: Array[Vector4] = [Vector4(15.5,17.9,13.5,-22.6),Vector4(19.9,13.2,10.9,-23.2),Vector4(24.1,11.9,10.1,-21.5),Vector4(28.3,12.8,10.7,-22.4),Vector4(32.6,10.8,9.3,-22.1),Vector4(35.7,9.5,9.8,-21.9),Vector4(39.5,6.7,8.1,-22.6)]
	for r: Vector4 in tiers:
		_octagon("Cantilevered observation deck",Vector3(0,r.x,r.w),r.y,.62,r.z,r.y*.235,_upper)
		_octagon("Shaded bridge band",Vector3(0,r.x-.64,r.w),r.y*.91,.65,r.z*.89,r.y*.215,gray,.95)
		for side: float in [-1.,1.]:
			_octagon("Side viewing pod",Vector3(side*r.y*.42,r.x+.72,r.w+r.z*.16),r.y*.18,1.,r.z*.37,r.y*.035,_steel)
			for i: int in range(6):
				var win := Vector3(side*r.y*.347+(i-2.5)*r.y*.037,r.x+.56,r.w-r.z*.340)
				_box("Bridge window shadow",win,Vector3(r.y*.029,.26,.09),cap)
			_spar("Tier side trim",Vector3(side*r.y*.426,r.x+.39,r.w-r.z*.28),Vector3(side*r.y*.426,r.x+.39,r.w+r.z*.28),.079,light)
	_octagon("Bridge roof house",Vector3(0,41.0,-22.3),5.18,2.5,5.1,1.5,_upper,.91)
	for side: float in [-1.,1.]:
		_spar("Pagoda tripod brace",Vector3(side*6.83,12.4,-13.3),Vector3(side*2.62,34.6,-20.9),.32,_steel)
		_spar("Pagoda fore tripod brace",Vector3(side*5.61,13.2,-29.8),Vector3(side*2.19,31.9,-24.8),.22,gray)
	_spar("Bridge peak mast",Vector3(0,39.,-22.2),Vector3(0,47.9,-22.2),.21,gray)
	for side: float in [-1.,1.]:
		_spar("Bridge stiffener",Vector3(side*4.,16.12,-28.8),Vector3(side*4.15,35.7,-26.0),.135,gray)
		_spar("Mid bridge yard",Vector3(0,34.6,-19.5),Vector3(side*10.1,34.6,-19.5),.084,gray)
		for i: int in range(4):
			var m := Vector3(side*(2.2+i*1.54),44.88,-22.2)
			_spar("Display aerial post",m,m+Vector3.UP*(.59 if i<2 else .39),.05,gray)
	_spar("Wide bridge signal yard",Vector3(-8.6,42.4,-22.2),Vector3(8.6,42.4,-22.2),.095,gray)
	_spar("Small bridge signal yard",Vector3(-4.7,44.7,-22.2),Vector3(4.7,44.7,-22.2),.089,gray)

func _build_waist() -> void:
	_group = _layer("Stack and ship boats")
	_octagon("Raised stack foot",Vector3(0,12.1,3.4),10.0,3.22,15.2,2.4,_upper)
	_pipe("Unified oval funnel",Vector3(0,19.7,4.0),12.9,3.8,3.38,1.31,_steel).rotation.x = .034
	_pipe("Dark oval stack crown",Vector3(0,26.09,4.34),1.43,3.55,3.45,1.34,cap)
	for side: float in [-1.,1.]:
		_spar("Funnel narrow exhaust relief",Vector3(side*2.15,13.5,9.8),Vector3(side*2.06,25.9,9.21),.21,gray)
		_boat(Vector3(side*9.3,13.55,7.0),3.05,8.8)
		_boat(Vector3(side*9.1,12.93,16.4),2.34,7.3)
		for z: float in [3.7,10.7,13.,19.2]:
			_spar("Boat davit base",Vector3(side*7.9,10.61,z),Vector3(side*8.63,15.1,z),.13,_steel)
			_spar("Boat davit bent arm",Vector3(side*8.63,15.1,z),Vector3(side*10.0,15.75,z),.118,gray)
		_octagon("Side gallery landing",Vector3(side*12.3,10.93,-2.6),3.5,.45,8.8,.61,_steel)
		for j: int in range(5):
			var z := -28.4+float(j)*8.6
			_octagon("Recessed broadside gallery",Vector3(side*12.94,8.15,z),3.25,2.62,4.4,.87,_steel)
			_box("Shadowed gallery face",Vector3(side*14.59,8.01,z),Vector3(.065,1.21,2.62),gray)

func _build_aft() -> void:
	_group = _layer("Aft mast and deck handling detail")
	_octagon("Low aft superstructure",Vector3(0,10.63,27.0),13.6,4.25,16.7,3.4,_steel)
	_octagon("Aft signal office",Vector3(0,14.06,27.1),7.6,3.6,7.38,1.32,_upper)
	_signal_mast(28.,15.1,40.2,8.6,4.3)
	_octagon("Stern handling deck",Vector3(0,6.18,90.),10.4,.52,19.3,2.0,_upper)
	for side: float in [-1.,1.]:
		_spar("Aft deck track",Vector3(side*.92,6.48,78.),Vector3(side*.92,6.48,100.),.15,gray)
		var q := Vector3(side*3.8,6.17,99.)
		_spar("Aft boom upright",q,q+Vector3.UP*10.3,.27,_steel)
		_spar("Aft boom diagonal",q+Vector3.UP*10.3,q+Vector3(0,14.6,-6.9),.21,_steel)
		_spar("Aft boom wire",q+Vector3.UP*9.4,q+Vector3(0,14.6,-6.9),.042,gray)
func _signal_mast(z: float,foot: float,top: float,yard: float,spread: float) -> void:
	var tip := Vector3(0,top,z+.65)
	_spar("Tapered signal mast",Vector3(0,foot,z),tip,.19,_steel)
	for side: float in [-1.,1.]:
		_spar("Signal mast sloped support",Vector3(side*spread,foot,z+1.65),Vector3(0,top-(top-foot)*.21,z+.52),.12,_steel)
		var a := Vector3(side*yard,lerpf(foot,top,.64),z+.46)
		_spar("Lower crossyard",Vector3(0,a.y,a.z),a,.084,gray)
		_spar("Fine signal line",a,Vector3(side*spread*.87,foot+.39,z-1.1),.032,gray)
		_spar("Small upper yard",Vector3(0,top-2.5,z+.58),Vector3(side*yard*.52,top-2.5,z+.58),.074,gray)

func _boat(p: Vector3,w: float,len: float) -> void:
	_octagon("Boat hull outer",p,w,.95,len,w*.41,wood,.72)
	_octagon("Boat interior cover",p+Vector3.UP*.38,w*.83,.28,len*.87,w*.31,gray,.97)
	for z: float in [-.23,0.,.23]:
		_box("Light boat thwart",p+Vector3(0,.58,z*len),Vector3(w*.65,.14,.21),wood)

func _display_mount(id: String,role: String,p: Vector3,size: Vector3,rise: float,front: Vector3,count: int) -> void:
	_group = _layer(id + " stationary collar")
	if size.x < 4.:
		_pipe("Waist gallery ledge",p+Vector3.DOWN*.14,.24,1.39,1.39,1.,_upper)
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
