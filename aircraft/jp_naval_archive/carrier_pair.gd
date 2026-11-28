extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Museum-style outer art. No flight, munitions or operation interfaces.
@export_enum("D3A1", "B5N2") var model: int = 0
const VAL_BODY := [
 [-4.83,.01,.30,.35,.34],[-4.73,.015,.53,.54,.53],[-4.54,.025,.66,.64,.62],[-4.20,.035,.68,.66,.65],
 [-3.80,.048,.68,.66,.65],[-3.38,.085,.64,.65,.65],[-2.90,.105,.62,.66,.66],[-2.38,.135,.62,.69,.67],
 [-1.65,.145,.64,.72,.69],[-.82,.16,.64,.69,.68],[.00,.17,.60,.65,.67],[.70,.18,.54,.62,.62],
 [1.40,.20,.44,.53,.55],[2.11,.23,.35,.46,.49],[2.97,.255,.255,.37,.37],[3.71,.28,.166,.27,.27],
 [4.32,.32,.102,.17,.18],[4.86,.34,.056,.10,.10],[5.08,.35,.018,.045,.040]]
const KATE_BODY := [
 [-4.90,.018,.35,.35,.35],[-4.73,.024,.55,.55,.55],[-4.49,.04,.635,.62,.62],[-4.12,.045,.64,.625,.625],
 [-3.75,.055,.62,.625,.63],[-3.20,.08,.55,.61,.62],[-2.60,.10,.55,.675,.64],[-1.80,.12,.57,.71,.68],
 [-.85,.13,.61,.73,.72],[.0,.145,.60,.72,.73],[.78,.155,.57,.68,.68],[1.59,.165,.515,.60,.62],
 [2.39,.18,.421,.48,.52],[3.10,.20,.325,.36,.41],[3.79,.225,.22,.26,.30],[4.39,.25,.133,.19,.201],
 [4.86,.28,.072,.12,.13],[5.09,.30,.019,.038,.037]]
const VAL_WING := [
 [.15,-1.91,3.41,-.28,.195],[.66,-1.98,3.57,-.26,.181],[1.40,-2.01,3.55,-.18,.162],
 [2.30,-1.98,3.40,-.09,.149],[3.25,-1.90,3.20,.00,.136],[4.24,-1.76,2.93,.10,.115],
 [5.22,-1.56,2.60,.20,.098],[6.04,-1.31,2.23,.29,.076],[6.67,-1.02,1.86,.36,.056],
 [7.02,-.76,1.43,.408,.040],[7.13,-.58,1.05,.424,.024],[7.18,-.37,.58,.434,.009]]
const KATE_WING := [
 [.15,-1.93,3.53,-.25,.195],[.67,-1.95,3.58,-.238,.183],[1.70,-1.93,3.29,-.17,.169],
 [2.65,-1.84,3.04,-.10,.148],[3.53,-1.58,2.72,.01,.131],[4.56,-1.33,2.36,.135,.113],
 [5.60,-1.08,1.98,.26,.099],[6.50,-.84,1.66,.37,.077],[7.19,-.66,1.39,.45,.060],
 [7.53,-.53,1.18,.49,.046],[7.68,-.40,.98,.504,.031],[7.75,-.13,.46,.513,.013]]
const VAL_TAIL := [
 [.02,3.04,1.91,.365,.092],[.32,3.04,1.94,.38,.090],[.87,3.15,1.82,.44,.078],
 [1.42,3.27,1.65,.494,.065],[1.93,3.45,1.36,.54,.055],[2.32,3.65,.97,.577,.039],
 [2.57,3.86,.58,.61,.027],[2.64,4.04,.22,.62,.012]]
const KATE_TAIL := [
 [.03,3.29,1.81,.31,.099],[.46,3.34,1.76,.32,.087],[1.05,3.48,1.56,.36,.076],
 [1.60,3.66,1.34,.40,.066],[2.03,3.82,1.10,.43,.057],[2.42,4.02,.81,.465,.040],
 [2.55,4.18,.48,.481,.024],[2.60,4.34,.20,.486,.011]]
const VAL_FIN := [
 [.38,2.65,5.00,.14],[.59,3.00,5.07,.135],[1.32,3.47,5.10,.105],
 [1.84,3.71,5.12,.085],[2.18,3.96,5.08,.068],[2.40,4.15,4.95,.048],
 [2.50,4.32,4.76,.028],[2.525,4.46,4.60,.012]]
const KATE_FIN := [
 [.38,2.37,5.04,.146],[.60,2.86,5.10,.139],[1.15,3.44,5.10,.113],
 [1.74,3.68,5.10,.085],[2.19,3.85,5.03,.073],[2.50,4.00,4.91,.049],
 [2.67,4.17,4.75,.034],[2.71,4.32,4.49,.010]]
const VAL_CANOPY := [
 [-2.78,.77,.15,.09,.034],[-2.60,.77,.27,.215,.044],[-2.29,.79,.36,.44,.05],
 [-2.04,.80,.393,.515,.051],[-1.55,.829,.398,.528,.050],[-.92,.840,.387,.455,.051],
 [-.34,.843,.38,.434,.046],[.24,.811,.362,.39,.045],[.87,.779,.308,.317,.041],
 [1.29,.743,.243,.188,.036],[1.53,.714,.175,.076,.024],[1.61,.696,.087,.035,.018]]
const KATE_CANOPY := [
 [-2.86,.765,.12,.056,.025],[-2.69,.779,.225,.176,.041],[-2.43,.804,.303,.361,.046],
 [-2.20,.821,.354,.44,.051],[-1.87,.829,.375,.47,.05],[-1.46,.842,.385,.474,.054],
 [-.93,.853,.389,.475,.052],[-.37,.858,.389,.474,.053],[.19,.855,.387,.472,.051],
 [.72,.837,.373,.435,.049],[1.17,.806,.342,.392,.047],[1.64,.754,.291,.318,.042],
 [2.01,.703,.237,.213,.037],[2.31,.650,.162,.112,.027],[2.55,.604,.070,.045,.018]]

func _ready() -> void:
	var val: bool = model == 0
	var body: Array = VAL_BODY if val else KATE_BODY
	var wing: Array = VAL_WING if val else KATE_WING
	var tail: Array = VAL_TAIL if val else KATE_TAIL
	_set_batch_paint(Color("b9b2a0") if val else Color("606d53"),Color("aaa391") if val else Color("b9b4a1"))
	paint.rubber = GEO.material(Color("292e2f"))
	var cowl: Node3D = GEO.group(self,"RadialNose")
	var top: Node3D = GEO.group(self,"Airframe")
	var plane: Node3D = GEO.group(self,"MainWing")
	var rear: Node3D = GEO.group(self,"Empennage")
	var glass: Node3D = GEO.group(self,"GlazedCanopy")
	var markings: Node3D = GEO.group(self,"ExteriorMarkings")
	var cowl_join: float = -3.65 if val else -3.69
	GEO.part(top,"AirframeSkin",GEO.loft(body,cowl_join,body[-1][0],paint.top.albedo_color,paint.bottom.albedo_color,Vector4.ZERO,true),paint.skin)
	_canopy(glass,VAL_CANOPY if val else KATE_CANOPY)
	_canopy_spines(glass,VAL_CANOPY if val else KATE_CANOPY)
	_fin(rear,"VerticalTail",VAL_FIN if val else KATE_FIN)
	for side: float in [-1.,1.]:
		_wing(plane,"EllipticalWing" if val else "TaperedWing",wing,side)
		_wing(rear,"Tailplane",tail,side)
		_wing_hinge_line(plane,wing,side,2.8 if val else 3.1,6.32 if val else 6.99,.78,.008)
		_wing_hinge_line(rear,tail,side,.39,2.22,.72,.007)
		if not val: _wing_seam(plane,wing,side,4.62)
		_roundel(markings,"wing",wing,Vector2(side*(5.02 if val else 5.56),.23),.63,1.)
		_roundel(markings,"wing",wing,Vector2(side*(5.02 if val else 5.56),.23),.63,-1.)
		_roundel(markings,"body",body,Vector2(1.98 if val else 2.95,.28),.295,side)
		_wing_tip(plane,wing,side,7.05 if val else 7.52)
		if val:
			_gear_spat(plane,side)
			_val_flap(plane,side)
		else:
			_kate_gear_doors(plane,side)
		_exhaust(top,side,val)
	_cowling(cowl,val)
	_tailwheel(rear,val)
	var mast_z: float = 1.65 if val else 2.36
	GEO.rod(top,"RadioMast",Vector3(0,.69,mast_z),Vector3(0,1.36,mast_z+.15),.023,paint.frame)
	_rudder_join(rear,VAL_FIN if val else KATE_FIN)

func _cowling(host: Node3D,val: bool) -> void:
	var dark: Material = GEO.material(Color("343a38") if val else Color("454b45"))
	var rim: Material = GEO.material(Color("484c45"))
	var rows: Array = VAL_BODY if val else KATE_BODY
	var nose: float = rows[0][0]
	var join: float = -3.65 if val else -3.69
	GEO.part(host,"ContrastingCowlSkin",GEO.loft(rows,nose,join,Color.WHITE,Color.WHITE),dark)
	_ellipsoid(host,"DeepNoseFace",Vector3(.43,.43,.062),Vector3(0,.025,nose-.047),paint.dark)
	GEO.arch(host,"CowlRim",rows,-4.66 if val else -4.72,.020,rim)
	for i: int in 9:
		var radial: Vector3 = Vector3(sin(TAU*i/9.),cos(TAU*i/9.),0)
		GEO.rod(host,"NoseBaffle",Vector3(0,.025,nose-.118)+radial*.13,Vector3(0,.025,nose-.058)+radial*.35,.024,rim)
	_prop(host,Vector3(0,.025,nose-.14),1.54 if val else 1.58,Vector3(.11,.11,.22 if val else .25),.32,1.,paint.metal)

func _gear_spat(host: Node3D,side: float) -> void:
	var p := Vector3(side*2.43,-1.49,-.49)
	var fairing: Node3D = GEO.group(host,"FixedWheelFairing",p)
	fairing.rotation.z = side*.105
	_ellipsoid(fairing,"LongTaperedUpperFairing",Vector3(.18,.72,.27),Vector3(-side*.09,.75,.13),paint.bottom)
	_ellipsoid(fairing,"WheelSpat",Vector3(.245,.53,.54),Vector3.ZERO,paint.top)
	_ellipsoid(fairing,"TrailingSpatTaper",Vector3(.175,.29,.48),Vector3(0,.105,.39),paint.top)
	_ellipsoid(fairing,"VisibleTyre",Vector3(.117,.315,.316),Vector3(0,-.31,-.055),paint.rubber)
	GEO.rod(fairing,"CurvedSpatPanelLine",Vector3(side*.234,-.02,-.27),Vector3(side*.22,.03,.322),.009,paint.seam)

func _val_flap(host: Node3D,side: float) -> void:
	var flap: Node3D = GEO.group(host,"ClosedFlushFlap")
	for i: int in 8:
		var s0: float = 1.42+i*.35
		var s1: float = s0+.31
		var a: Vector3 = GEO.wing_point(VAL_WING,s0,.72,false)*Vector3(side,1,1)
		var b: Vector3 = GEO.wing_point(VAL_WING,s1,.72,false)*Vector3(side,1,1)
		GEO.rod(flap,"UnderwingFlushJoin",a-Vector3.UP*.012,b-Vector3.UP*.012,.008,paint.seam)

func _kate_gear_doors(host: Node3D,side: float) -> void:
	var outline: Array[Vector2] = [
		Vector2(side*1.53,-1.23),Vector2(side*2.33,-1.17),Vector2(side*2.38,-.61),Vector2(side*1.54,-.56)]
	_decal(host,"ClosedMainGearDoor","wing",KATE_WING,outline,-1.,.008,paint.panel)

func _tailwheel(host: Node3D,val: bool) -> void:
	var z: float = 4.17 if val else 4.23
	GEO.rod(host,"TailwheelSupport",Vector3(0,.10,z-.11),Vector3(0,-.235,z+.06),.036,paint.frame)
	_ellipsoid(host,"Tailwheel",Vector3(.072,.164,.161),Vector3(0,-.245,z+.08),paint.rubber)

func _wing_tip(host: Node3D,profile: Array,side: float,x: float) -> void:
	var p: Vector3 = GEO.wing_point(profile,x,.46,true)*Vector3(side,1,1)
	_ellipsoid(host,"NavigationLens",Vector3(.029,.027,.070),p,paint.red if side < 0. else paint.nav_green)

func _exhaust(host: Node3D,side: float,val: bool) -> void:
	var at: Vector3 = Vector3(side*(.647 if val else .609),-.21,-3.77)
	GEO.rod(host,"ExhaustFairing",at,at+Vector3(side*.011,-.015,.18),.039,paint.dark)

func _roundel(host: Node3D,kind: String,profile: Array,center: Vector2,radius: float,side: float) -> void:
	var disc: Array[Vector2] = []
	for i: int in 32:
		var a: float = TAU*i/32.
		disc.append(center+Vector2(cos(a),sin(a))*radius)
	_decal(host,"Hinomaru",kind,profile,disc,side,.010 if kind=="wing" else .015,paint.red)

func _canopy_spines(host: Node3D,profile: Array) -> void:
	for side: float in [-1.,1.]:
		for i: int in range(profile.size()-1):
			var a: Vector3 = GEO.shell_point(profile,profile[i][0],side*.56)
			var b: Vector3 = GEO.shell_point(profile,profile[i+1][0],side*.56)
			GEO.rod(host,"CanopyLongeron",a,b,.012,paint.frame)

func _rudder_join(host: Node3D,rows: Array) -> void:
	for side: float in [-1.,1.]:
		for i: int in range(1,rows.size()-1):
			var a: Array = rows[i]
			var b: Array = rows[i+1]
			GEO.rod(host,"RudderPanelJoin",Vector3(side*a[3]*.84,a[0],lerpf(a[1],a[2],.74)),Vector3(side*b[3]*.84,b[0],lerpf(b[1],b[2],.74)),.007,paint.seam)
