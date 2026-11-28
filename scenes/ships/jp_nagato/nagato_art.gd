extends "res://scenes/ships/visual_study/archival_cruiser_art.gd"
## October 1944 archive exterior. Units are Godot art coordinates only.
const GUN := preload("res://scripts/presentation/models/archive_gun_rig.gd")
var gray: StandardMaterial3D
var wood: StandardMaterial3D
var light: StandardMaterial3D
var cap: StandardMaterial3D
var glass: StandardMaterial3D
var edge: StandardMaterial3D
var seam: StandardMaterial3D

func _half_length() -> float:
	return 112.5

func _draft() -> float:
	return 8.3

func _stations() -> Array[Vector4]:
	var contour: Array[Vector4] = [
		Vector4(-1.,.003,10.65,.001),Vector4(-.992,.039,10.53,.012),
		Vector4(-.978,.095,10.02,.03),
		Vector4(-.956,.19,9.44,.08),Vector4(-.91,.34,9.03,.18),
		Vector4(-.84,.52,8.55,.33),Vector4(-.74,.71,8.05,.53),
		Vector4(-.63,.875,7.65,.72),Vector4(-.48,.965,7.4,.89),
		Vector4(-.29,1.,7.2,.97),Vector4(-.11,1.,7.12,.99),
		Vector4(.15,.998,7.05,.99),Vector4(.34,.956,6.98,.92),
		Vector4(.485,.900,6.94,.84),Vector4(.535,.872,6.92,.80),
		Vector4(.551,.851,5.48,.79),Vector4(.60,.806,5.42,.74),
		Vector4(.72,.70,5.35,.60),Vector4(.84,.56,5.19,.44),
		Vector4(.92,.404,5.15,.32),Vector4(.978,.225,5.19,.14),
		Vector4(1.,.065,5.26,.035)]
	var out: Array[Vector4] = []
	for r: Vector4 in contour:
		out.append(Vector4(r.x*_half_length(),r.y*16.2,r.z,r.w*16.2))
	return out

func _section(row: Vector4, side: float) -> PackedVector3Array:
	var section := _draw_section(row,side,10.,6.6)
	for i: int in range(section.size()):
		var p: Vector3 = section[i]
		var shoulder: float = smoothstep(0.35,0.82,1.0-absf(row.x)/_half_length())
		if i==3 or i==4:
			p.x += side * shoulder * (0.92 if i==3 else 0.48)
		section[i] = p
	return section

func _ready() -> void:
	_hull_side = _paint("66717a")
	_steel = _paint("737d85")
	_upper = _paint("8c959b")
	_deck = _paint("897d67")
	_underbody = _paint("65474a")
	_dark = _paint("313a3e")
	wood = _paint("a8987f")
	light = _paint("8c9a97")
	gray = _paint("515f62")
	cap = _paint("30383f")
	glass = _paint("263139")
	edge = _paint("89939a")
	seam = _paint("746957")
	_group = _layer("Weather hull")
	_hull()
	_group = _layer("Weather deck fittings")
	_fixed_edges()
	_deck_seams()
	_foredeck()
	_build_pagoda()
	_build_waist()
	_build_casemates()
	_build_aft()
	var major: Array[Vector3] = [Vector3(-65,0,1.15),Vector3(-45,0,4.03),Vector3(48,0,4.15),Vector3(70,0,1.20)]
	for i: int in range(major.size()):
		var p: Vector3 = major[i]
		_display_mount("CenterGallery%02d" % (i+1),"main",Vector3(0,_deck_height(p.x),p.x),Vector3(11.5,3.15,10.05),p.z,Vector3.FORWARD if i<2 else Vector3.BACK,2)
	for sign: float in [-1.,1.]:
		for j: int in range(3):
			var p := Vector3(sign*(12.05 if j==0 else 12.45),11.16,(-18.5 + 16.0*j))
			_display_mount("WaistGallery%s%d" % [("S" if sign>0 else "P"),j+1],"dedicated_aa",p,Vector3(2.4,.95,1.86),.3,Vector3(sign,0.,0.),2)
	set_meta("visual_reference","Kure Maritime Museum / NHHC NH 73090")
	set_meta("art_only",true)
	set_meta("exterior_revision",3)

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
		for z: float in [-90.,-86.,-81.,-76.,-71.,-66.,-61.,-56.,-52.,-47.,-41.,-35.,-30.,-23.,-17.,-11.,-5.,5.,11.,17.,26.,31.,37.,45.,58.,65.,75.,84.,90.,96.]:
			var section: Vector3 = _side_surface(z,.76,side)
			_disc("Recessed hull scuttle",section,.19,.043,Vector3(side,0.0,0.0),glass)
		for z: float in [-102.6,-97.4]:
			var hub: Vector3 = _side_surface(z,.69,side)
			_disc("Hawse recess rim",hub,.67,.16,Vector3(side,.06,-.34),_upper)
			_disc("Hawse relief inset",hub+Vector3(side*.13,0.,-.03),.43,.075,Vector3(side,.06,-.34),cap)
		var c: Vector3 = _side_surface(-99.8,.60,side)
		_spar("Flush stowed anchor stock",c+Vector3(side*.08,-.68,0.1),c+Vector3(side*.08,.55,0.1),.19,gray)
		for tip: float in [-1.,1.]:
			_spar("Anchor relief arm",c+Vector3(side*.11,-.66,.10),c+Vector3(side*.11,-.24,.10+tip*.56),.15,gray)
		for z: float in [-105.,-96.,93.,103.]:
			var p := Vector3(side*1.64,_deck_height(z)+.15,z)
			_pipe("Deck bollard",p,.55,.47,.48,1.,gray)
		for j: int in range(12):
			_box("Foredeck chain relief",Vector3(side*(3.13-j*.16),_deck_height(-100+j*1.22)+.055,-100+j*1.22),Vector3(.17,.19,.75),cap)
	_spar("Bow staff",Vector3(0,10.1,-111),Vector3(0,13.3,-111),.106,light)
	_spar("Stern staff",Vector3(0,5.23,111),Vector3(0,8.35,111),.11,light)

func _side_surface(z: float, level: float, side: float) -> Vector3:
	var rows: Array[Vector4] = _stations()
	for i: int in range(rows.size()-1):
		if z <= rows[i+1].x:
			var a: PackedVector3Array = _section(rows[i],side)
			var b: PackedVector3Array = _section(rows[i+1],side)
			var f: float = inverse_lerp(rows[i].x,rows[i+1].x,z)
			var q: Vector3 = a[4].lerp(b[4],f).lerp(a[5].lerp(b[5],f),level)
			return q + Vector3(side*.047,0,0)
	return Vector3.ZERO

func _disc(label: String,p: Vector3,radius: float,depth: float,axis: Vector3,mat: Material) -> void:
	var part := _pipe(label,p,depth,radius,radius,1.,mat)
	part.quaternion = Quaternion(Vector3.UP,axis.normalized())

func _foredeck() -> void:
	_group = _layer("Foredeck equipment")
	for sign_dir: float in [-1.0,1.0]:
		for z: float in [-93.,-89.3]:
			var p := Vector3(sign_dir*2.65,_deck_height(z)+.39,z)
			_pipe("Capstan foot",p,.68,.76,.63,1.,gray)
			_pipe("Capstan head",p+Vector3.UP*.36,.24,.69,.63,1.,_upper)
		for z: float in [-85.,-79.8,-73.5]:
			var p := Vector3(sign_dir*4.7,_deck_height(z)+.19,z)
			_octagon("Foredeck hatch rim",p,1.28,.34,1.75,.23,gray)
			_octagon("Foredeck hatch cover",p+Vector3.UP*.19,1.16,.21,1.62,.22,_steel,.92)
		for z: float in [-101.,-79.,-62.]:
			var y: float = _deck_height(z)
			var p := Vector3(sign_dir*(3.0 if z < -90. else 8.7),y+.11,z)
			_box("Mooring fitting sole",p,1.22*Vector3(1.,.18,1.65),gray)
			for d: float in [-.47,.47]:
				_pipe("Mooring horn",p+Vector3(0,.28,d),.58,.21,.31,1.,_steel)

func _build_pagoda() -> void:
	_group = _layer("Pagoda silhouette")
	# Distinct bridge bodies and platforms, following the October photo.
	_octagon("Raised center deckhouse",Vector3(0,8.78,0.2),25.7,3.45,64.8,5.1,_steel)
	_octagon("Rounded forward deckhouse",Vector3(0,12.46,-20.7),17.9,4.20,23.1,4.9,_steel,.94)
	_gallery("Lower curved bridge body",Vector3(0,15.79,-24.1),14.15,3.10,14.8,_steel)
	_gallery("Lower tier enclosed curve",Vector3(0,18.04,-25.48),10.29,1.61,11.0,gray)
	for side: float in [-1.,1.]:
		var p := Vector3(side*7.82,12.73,-24.76)
		_octagon("Forward extension access block",p,3.18,3.06,6.8,.69,_steel,.92)
		var d := Vector3(side*9.40,12.13,-25.47)
		_box("Dark lower gallery doorway",d,Vector3(.11,1.48,.81),glass)
		_spar("Enclosure lip",d+Vector3(0,.8,-.57),d+Vector3(0,.8,.57),.12,_upper)
		_gallery("Forward low rounded bay",Vector3(side*5.85,16.05,-29.85),3.51,1.36,4.12,_steel)
	_octagon("Offset communications trunk",Vector3(0,24.9,-19.9),5.9,18.8,8.9,1.35,_steel,.87)
	_pipe("Tapered external forward trunk",Vector3(0,25.6,-24.8),14.0,2.35,1.82,.78,_steel).rotation.x = -.06
	# y, width, forward reach, aft reach. The outline of each gallery is different.
	var decks: Array[Vector4] = [
		Vector4(16.7,18.2,-32.6,-15.1), Vector4(19.8,13.5,-31.4,-15.8),
		Vector4(23.2,15.3,-29.1,-12.0), Vector4(27.4,18.1,-32.6,-13.8),
		Vector4(31.5,16.2,-30.0,-13.7), Vector4(34.7,13.6,-34.5,-17.6),
		Vector4(37.0,11.2,-28.7,-17.8), Vector4(40.6,8.0,-26.5,-19.6)]
	for i: int in range(decks.size()):
		var d: Vector4 = decks[i]
		_bridge_level(d,i)
	# Rounded bridge ends break away from the identical polygon floors.
	_gallery("Lower forward navigation enclosure",Vector3(0,16.06,-29.05),10.38,1.57,6.92,_steel)
	_gallery("Upper compact optical hood",Vector3(0,37.87,-24.55),7.8,1.44,5.24,_steel)
	for sg: float in [-1.,1.]:
		var p := Vector3(sg*5.5,27.62,-30.54)
		_gallery("Offset shoulder lookout",p,3.38,1.09,2.78,_steel)
		_gallery("Thin offset lookout roof",p+Vector3.UP*.62,3.63,.17,3.04,gray)
	_octagon("Crowned director house",Vector3(0,42.08,-22.5),5.83,2.15,5.28,1.39,_steel,.86)
	_gallery("Rounded top roof",Vector3(0,43.25,-22.34),5.28,.43,5.08,gray)
	_spar("Peak aerial staff",Vector3(0,42.1,-21.5),Vector3(0,47.05,-21.5),.19,_steel)
	_open_grid(Vector3(0,45.42,-21.42),5.0,2.20,true)
	for side: float in [-1.,1.]:
		_spar("Heavy sloping frame leg",Vector3(side*7.02,11.46,-14.1),Vector3(side*1.7,33.7,-19.65),.52,_steel)
		_spar("Front housing strut",Vector3(side*4.23,13.8,-26.6),Vector3(side*1.74,32.5,-25.45),.33,_steel)
		_spar("External bridge ladder",Vector3(side*3.6,20.1,-21.7),Vector3(side*3.3,34.5,-21.7),.13,gray)
		for r: int in range(8):
			var y: float = 20.6 + r*.69
			_spar("Bridge ladder rung",Vector3(side*3.46,y,-22.03),Vector3(side*3.46,y,-21.38),.045,edge)
		_spar("Wide signal yard",Vector3(0,32.18,-18.1),Vector3(side*11.4,32.18,-17.9),.14,gray)
		_spar("Upper signal yard",Vector3(0,40.17,-22.64),Vector3(side*8.5,40.17,-22.61),.11,gray)
		for z: float in [-10.9,-13.0]:
			var p := Vector3(side*5.8,12.20,z)
			_spar("Bridge to stack walkway",p,p+Vector3(0,0,6.56),.44,_steel)
			_spar("Walkway handrail",p+Vector3.UP*.85,p+Vector3(0,.85,6.56),.09,gray)

func _bridge_level(d: Vector4,i: int) -> void:
	var y: float = d.x
	var w: float = d.y*.5
	var front: float = d.z
	var aft: float = d.w
	var mid: float = (front+aft)*.5
	var len: float = aft-front
	var path := PackedVector2Array([Vector2(-w*.55,front),Vector2(w*.55,front),Vector2(w,front+len*.25),
		Vector2(w*.97,aft-len*.24),Vector2(w*.61,aft),Vector2(-w*.61,aft),Vector2(-w*.97,aft-len*.24),Vector2(-w,front+len*.25)])
	var contrast: Material = gray if i in [2,4,5] else _steel
	_platform_shape("Shaped bridge balcony %d" % i,path,y,.58,contrast)
	# A solid, recessed, narrower body produces the photographed deep shadow breaks.
	var cabin_z: float = mid + (1.25 if i in [2,3,4] else -.75)
	_octagon("Separate enclosed bridge floor %d" % i,Vector3(0,y-1.02,cabin_z),w*(1.47 if i in [0,1,6] else 1.08),1.95,len*.66,w*.31,contrast,.92)
	for j: int in range(path.size()):
		var p: Vector2 = path[j]
		var q: Vector2 = path[(j+1)%path.size()]
		var up := Vector3(p.x,y+.48,p.y)
		var to := Vector3(q.x,y+.48,q.y)
		_spar("Balcony rim",up,to,.15,_upper)
		if i!=2:
			_spar("Balcony stanchion",up,up-Vector3.UP*.46,.096,gray)
			if up.distance_to(to) > 3.2:
				var post: Vector3 = up.lerp(to,.50)
				_spar("Intermediate balcony stanchion",post,post-Vector3.UP*.46,.087,gray)
		if j in [1,3,5,7]:
			var k: Vector3 = up.lerp(to,.52)
			_spar("Balcony gusset",Vector3(k.x*.67,y-1.65,lerpf(mid,k.z,.70)),k-Vector3.UP*.37,.19,_steel)
	var window_z: float = cabin_z-len*.33*.956-.08
	var window_w: float = w*(1.13 if i in [0,1,6] else .83)
	if i in [0,1,3,4,6,7]:
		for j: int in range(8):
			var x: float = window_w*(float(j)-3.5)/8.4
			_box("Recessed bridge glazing",Vector3(x,y-.69,window_z),Vector3(window_w*.081,.40,.12),glass)
	if i in [0,2,3,4,6]:
		for side: float in [-1.,1.]:
			var pod_z: float = front + len*(.29 if i in [2,4] else .61)
			_gallery("Rounded lookout pocket",Vector3(side*w*.71,y+.62,pod_z),w*.45,1.09,len*.29,_steel)
			_gallery("Lookout shade lip",Vector3(side*w*.71,y+1.20,pod_z),w*.5,.17,len*.30,cap)
	for sign_dir: float in [-1.,1.]:
		if i in [0,1,3,4,6]:
			var x: float = sign_dir*w*(.58 if i in [0,1,6] else .43)
			var y_strip: float = y-.66
			for j: int in range(4):
				var z: float = lerpf(cabin_z-len*.18,cabin_z+len*.16,float(j)/3.)
				_box("Side bridge glazing",Vector3(x,y_strip,z),Vector3(.14,.35,.41),glass)
		if i in [1,3,5]:
			var z: float = lerpf(front,aft,.17)
			var p := Vector3(sign_dir*w*.53,y+.48,z)
			_octagon("Bridge access hood",p,1.23,1.01,1.37,.27,_steel)
	if i==5:
		_disc("Wide crosswise optical bridge silhouette",Vector3(0,y+.88,front+1.2),.43,w*2.16,Vector3.RIGHT,gray)

func _platform_shape(label: String, outline: PackedVector2Array, y: float, thickness: float, mat: Material) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	var centroid := Vector2.ZERO
	for p: Vector2 in outline:
		centroid += p / float(outline.size())
	var middle := Vector3(centroid.x,y,centroid.y)
	for i: int in range(outline.size()):
		var a := Vector3(outline[i].x,y,outline[i].y)
		var next: Vector2 = outline[(i+1)%outline.size()]
		var b := Vector3(next.x,y,next.y)
		var down: Vector3 = Vector3.DOWN*thickness
		_tri(mesh,middle,a,b,Vector3.UP)
		_quad(mesh,a,a+down,b+down,b,(a+b)*.5-middle)
		_tri(mesh,middle+down,a+down,b+down,Vector3.DOWN)
	_commit(label,mesh,mat)

func _open_grid(p: Vector3,w: float,h: float,across: bool) -> void:
	var a: Vector3 = Vector3.RIGHT if across else Vector3.BACK
	for j: int in range(3):
		var q: Vector3 = p+Vector3.UP*h*(float(j)*.5-.5)
		_spar("Open aerial horizontal",q-a*w*.5,q+a*w*.5,.092,gray)
	for j: int in range(7):
		var q: Vector3 = p+a*w*(float(j)/6.-.5)
		_spar("Open aerial upright",q-Vector3.UP*h*.5,q+Vector3.UP*h*.5,.089,gray)

func _build_waist() -> void:
	_group = _layer("Stack and ship boats")
	_octagon("Raised stack foot",Vector3(0,12.1,3.4),10.0,3.22,15.2,2.4,_upper)
	_funnel()
	for sign_dir: float in [-1.0,1.0]:
		var p := Vector3(sign_dir*6.6,15.24,2.1)
		_gallery("Waist service blister",p,3.22,2.46,5.2,_steel)
		_spar("Stack service pipe",p+Vector3(0,-2.8,3.5),Vector3(sign_dir*3.46,24.02,6.3),.29,gray)
	for side: float in [-1.,1.]:
		_spar("Funnel narrow exhaust relief",Vector3(side*2.15,13.5,9.8),Vector3(side*2.06,25.9,9.21),.21,gray)
		_boat(Vector3(side*9.3,13.55,7.0),3.05,8.8)
		_boat(Vector3(side*9.1,12.93,16.4),2.34,7.3)
		for z: float in [3.7,10.7,13.,19.2]:
			_spar("Boat davit base",Vector3(side*7.9,10.61,z),Vector3(side*8.63,15.1,z),.13,_steel)
			_spar("Boat davit bent arm",Vector3(side*8.63,15.1,z),Vector3(side*10.0,15.75,z),.118,gray)
		_octagon("Side gallery landing",Vector3(side*12.3,10.93,-2.6),3.5,.45,8.8,.61,_steel)
		for z: float in [-25.0,-15.6,-4.5,6.1,16.8,24.3]:
			var p := Vector3(side*12.1,11.00,z)
			_spar("Waist safety rail",p+Vector3(0,.87,-1.7),p+Vector3(0,.87,1.5),.09,gray)
			for q: float in [-1.7,-.15,1.5]:
				_spar("Waist safety upright",p+Vector3(0,0,q),p+Vector3(0,.87,q),.081,_steel)
		for z: float in [-21.9,-11.5,1.2,12.0,23.0]:
			var p := Vector3(side*11.6,10.67,z)
			_octagon("Deck service drum",p+Vector3.UP*.29,1.52,.66,1.23,.31,gray)
			_spar("Side footway rim",p+Vector3(side*.4,.62,-1.3),p+Vector3(side*.4,.62,1.3),.105,edge)

func _build_casemates() -> void:
	# Closed silhouette-only miniatures; no mechanics or firing.
	_group = _layer("Broadside casemate exhibit row")
	for side: float in [-1.,1.]:
		for i: int in range(8):
			var z: float = -33.6 + float(i)*8.78
			var p := Vector3(side*12.82,_deck_height(z)+1.02,z)
			var front := Vector3(side,0,0)
			_octagon("Fixed casemate surround",p,3.12,2.40,3.82,.74,_hull_side)
			_box("Recessed casemate aperture",p+front*1.42,Vector3(.15,1.55,2.48),glass)
			_spar("Casemate brow",p+Vector3(side*1.54,.88,-1.23),p+Vector3(side*1.54,.88,1.23),.18,_steel)
			_box("Embedded gallery shelf",p+Vector3(side*.70,-.89,0),Vector3(1.76,.39,3.35),_steel)
			var pivot: Vector3 = p+front*1.40
			var start: int = _group.get_child_count()
			_disc("Inset curved decorative shield",pivot,.64,.39,front,gray)
			var moving: Array = _group.get_children().slice(start)
			start = _group.get_child_count()
			_disc("Closed broadside silhouette",pivot+front*1.53,.14,3.16,front,_steel)
			var outline: Array = _group.get_children().slice(start)
			GUN.attach(self,"Casemate%s%02d" % ["S" if side>0 else "P",i+1],
				"secondary",pivot,pivot,front,moving,outline)

func _funnel() -> void:
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip := SurfaceTool.new()
	lip.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside := SurfaceTool.new()
	inside.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 36
	for i: int in range(n):
		var a: float = TAU*float(i)/n
		var b: float = TAU*float(i+1)/n
		var one := Vector3(cos(a),0,sin(a))
		var two := Vector3(cos(b),0,sin(b))
		var base := Vector3(0,13.3,3.45)
		var shoulder := Vector3(0,24.85,4.08)
		var top := Vector3(0,26.10,4.16)
		var low := Vector3(3.79,0,5.38)
		var high := Vector3(3.31,0,4.68)
		var outer := Vector3(3.59,0,4.96)
		var inner := Vector3(2.78,0,4.12)
		_quad(shell,base+one*low,base+two*low,shoulder+two*high,shoulder+one*high,one+two)
		_quad(lip,shoulder+one*high,shoulder+two*high,top+two*outer,top+one*outer,one+two)
		_quad(lip,top+one*outer,top+two*outer,top+two*inner,top+one*inner,Vector3.UP)
		_quad(inside,top+one*inner,top+two*inner,top+two*inner-Vector3.UP*1.60,top+one*inner-Vector3.UP*1.60,-one-two)
		_tri(inside,top-Vector3.UP*1.60,top+one*inner-Vector3.UP*1.60,top+two*inner-Vector3.UP*1.60,Vector3.UP)
	_commit("Shaped single funnel shell",shell,_steel)
	_commit("Rolled funnel rim",lip,cap)
	_commit("Recessed dark funnel opening",inside,glass)
	for x: float in [-1.65,0.,1.65]:
		_spar("Recessed stack grille",Vector3(x,25.71,.51),Vector3(x,25.71,7.73),.11,gray)

func _build_aft() -> void:
	_group = _layer("Aft mast and deck handling detail")
	_octagon("Low aft superstructure",Vector3(0,10.63,27.0),13.6,4.25,16.7,3.4,_steel)
	_octagon("Aft signal office",Vector3(0,14.06,27.1),7.6,3.6,7.38,1.32,_upper)
	_signal_mast(28.,15.1,40.2,8.6,4.3)
	_octagon("Stern handling deck",Vector3(0,5.57,91.),11.75,.30,23.16,2.5,_steel)
	for side: float in [-1.,1.]:
		_spar("Aft embedded handling track",Vector3(side*1.09,5.77,80.),Vector3(side*1.09,5.77,101.),.15,gray)
		for z: float in [80.,87.,90.,102.]:
			var p := Vector3(side*3.75,_deck_height(z)+.17,z)
			_octagon("Stern locker",p,1.47,.41,1.11,.31,_steel)
	for j: int in range(10):
		var z: float = 84.+j*1.85
		_spar("Stern handling cross tie",Vector3(-1.3,5.73,z),Vector3(1.3,5.73,z),.11,gray)
	var foot := Vector3(3.35,5.58,101.)
	_pipe("Single offset crane ring",foot+Vector3.UP*.37,.81,1.16,1.02,1.,gray)
	var neck := foot+Vector3.UP*6.8
	var tip := neck+Vector3(-1.75,7.65,-10.6)
	var top := neck+Vector3(0,3.30,.08)
	_spar("Stern crane upright",foot+Vector3.UP*.40,top,.53,_steel)
	for x: float in [-.41,.41]:
		_spar("Crane upper chord",neck+Vector3(x,.34,0),tip+Vector3(x,.13,0),.20,_steel)
		_spar("Crane lower chord",neck+Vector3(x,-.52,0),tip+Vector3(x,-.12,0),.18,gray)
		for j: int in range(6):
			var a: Vector3 = neck.lerp(tip,float(j)/6.)
			var b: Vector3 = neck.lerp(tip,float(j+1)/6.)
			_spar("Crane diagonal lattice",a+Vector3(x,-.49,0),b+Vector3(x,.21,0),.12,_steel)
	_spar("Crane support line",top,tip,.075,gray)
	_spar("Crane hanging line",tip,tip-Vector3.UP*4.13,.052,gray)

func _signal_mast(z: float,foot: float,top: float,yard: float,spread: float) -> void:
	var tip := Vector3(0,top,z+.65)
	_spar("Lower signal mast trunk",Vector3(0,foot,z),Vector3(0,top-8.5,z+.50),.44,_steel)
	_spar("Upper signal mast spar",Vector3(0,top-9.0,z+.49),tip,.20,gray)
	_gallery("Aft mast lookout nest",Vector3(0,foot+8.82,z+.48),4.75,.62,3.42,_steel)
	_open_grid(Vector3(0,foot+9.8,z+1.2),9.12,4.28,true)
	for side: float in [-1.,1.]:
		_spar("Signal mast sloped support",Vector3(side*spread,foot,z+1.65),Vector3(0,top-(top-foot)*.21,z+.52),.35,_steel)
		var a := Vector3(side*yard,lerpf(foot,top,.64),z+.46)
		_spar("Lower crossyard",Vector3(0,a.y,a.z),a,.13,gray)
		_spar("Lower crossyard brace",Vector3(0,a.y-3.17,a.z),a,.076,gray)
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
	if size.x > 4.:
		_showcase_main_case(c)
	else:
		_case_shape(c)
	var side := Vector3(front.z,0,-front.x)
	if size.x > 4.:
		for j: float in [-1.,1.]:
			_box("Low roof hatch",c.center+Vector3(j*size.x*.21,size.y*.508,size.z*.17),
				Vector3(size.x*.115,.09,size.z*.15),_steel)
	var body: Array = _group.get_children().slice(shape_start)
	var barrel_start: int = _group.get_child_count()
	var pivot := c.center + front*size.z*.24
	for i: int in range(count):
		var shift: float = (float(i)-float(count-1)*.5)*size.x*.32
		var a := pivot + side*shift
		var b := a + front*size.z*(1.27 if size.x>4. else .92) + Vector3.UP*size.y*.24
		var profile := _pipe("Tapered closed exhibit profile",a.lerp(b,.50),a.distance_to(b),
			maxf(.086,size.x*.056),maxf(.071,size.x*.039),1.,_steel)
		profile.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
		_disc("Rounded exhibit mantlet",a+front*size.z*.23,maxf(.13,size.x*.071),size.z*.21,b-a,gray)
		_disc("Closed dark end face",b+front*.04,maxf(.074,size.x*.040),.11,b-a,cap)
	var barrel: Array = _group.get_children().slice(barrel_start)
	GUN.attach(self,id,role,p+Vector3.UP*rise,pivot,front,body,barrel)

func _showcase_main_case(c: GCase) -> void:
	var side := Vector3(c.front.z,0,-c.front.x)
	var shell := SurfaceTool.new()
	var top := SurfaceTool.new()
	for surface: SurfaceTool in [shell,top]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
	var lower := PackedVector2Array([Vector2(-.38,-.52),Vector2(.38,-.52),Vector2(.50,-.37),
		Vector2(.50,.32),Vector2(.37,.52),Vector2(-.37,.52),Vector2(-.50,.32),Vector2(-.50,-.37)])
	var upper := PackedVector2Array([Vector2(-.35,-.49),Vector2(.35,-.49),Vector2(.43,-.34),
		Vector2(.45,.09),Vector2(.32,.26),Vector2(-.32,.26),Vector2(-.45,.09),Vector2(-.43,-.34)])
	for i: int in range(lower.size()):
		var j: int = (i+1)%lower.size()
		var a: Vector3 = c.center+side*lower[i].x*c.width+c.front*lower[i].y*c.length-Vector3.UP*c.height*.50
		var b: Vector3 = c.center+side*lower[j].x*c.width+c.front*lower[j].y*c.length-Vector3.UP*c.height*.50
		var d: Vector3 = c.center+side*upper[i].x*c.width+c.front*upper[i].y*c.length+Vector3.UP*c.height*.50
		var e: Vector3 = c.center+side*upper[j].x*c.width+c.front*upper[j].y*c.length+Vector3.UP*c.height*.50
		_quad(shell,a,b,e,d,(a+b)*.5-c.center)
		_tri(top,c.center+Vector3.UP*c.height*.5,d,e,Vector3.UP)
		_tri(shell,c.center-Vector3.UP*c.height*.5,a,b,Vector3.DOWN)
	_commit("Faceted major display enclosure",shell,_steel)
	_commit("Flat major display roof",top,_steel)
	for sign_dir: float in [-1.,1.]:
		var p: Vector3 = c.center+side*sign_dir*c.width*.447+Vector3.UP*c.height*.22
		_box("Low side sight recess",p-c.front*c.length*.10,Vector3(.12,.25,.82),glass)
		_box("Side sight rain rim",p-c.front*c.length*.10+Vector3.UP*.19,Vector3(.17,.13,.96),_upper)
		_spar("Casing lower edge",p-Vector3.UP*c.height*.61+c.front*c.length*.23,
			p-Vector3.UP*c.height*.61-c.front*c.length*.36,.14,gray)

func _deck_seams() -> void:
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := _stations()
	for i: int in range(rows.size()-1):
		var a: Vector4 = rows[i]
		var b: Vector4 = rows[i+1]
		var width: float = minf(a.y,b.y)-.31
		for lane: int in range(-18,19):
			var x: float = lane*.80
			var start: Vector4 = a
			var end: Vector4 = b
			if absf(x)>width:
				if absf(x) > maxf(a.y,b.y)-.31:
					continue
				var ratio: float = inverse_lerp(a.y,b.y,absf(x)+.31)
				if a.y < b.y:
					start = a.lerp(b,ratio)
				else:
					end = a.lerp(b,ratio)
			var side: float = .023
			_quad(seams,Vector3(x-side,start.z+.018,start.x),Vector3(x+side,start.z+.018,start.x),
				Vector3(x+side,end.z+.018,end.x),Vector3(x-side,end.z+.018,end.x),Vector3.UP)
	_commit("Restrained longitudinal plank seams",seams,seam)
