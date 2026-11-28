extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Archive-only silhouettes. +X starboard; -Z forward. All details are closed display meshes.
@export_enum("Ki-43-II Hayabusa","Ki-61-I Hien") var variant: int = 0

const HAYA_BODY := [
	[-4.08,.14,.427,.432,.411],[-4.00,.14,.516,.513,.508],[-3.81,.14,.565,.570,.553],
	[-3.53,.14,.569,.582,.564],[-3.22,.142,.549,.576,.550],[-2.93,.138,.524,.556,.53],
	[-2.52,.135,.512,.542,.525],[-2.00,.135,.501,.553,.549],[-1.53,.140,.49,.57,.550],
	[-1.01,.162,.478,.591,.529],[-.55,.180,.456,.575,.509],[-.10,.192,.419,.513,.467],
	[.48,.227,.366,.428,.410],[1.16,.265,.31,.347,.347],[1.83,.295,.252,.268,.281],
	[2.44,.315,.190,.195,.219],[3.04,.328,.14,.14,.161],[3.58,.342,.098,.103,.117],
	[4.04,.347,.059,.071,.078],[4.43,.352,.025,.042,.050],[4.61,.358,.013,.022,.023]]
const HIEN_BODY := [
	[-4.17,.154,.226,.225,.224],[-4.06,.16,.284,.271,.285],[-3.88,.164,.328,.301,.327],
	[-3.59,.164,.361,.340,.373],[-3.29,.171,.395,.378,.409],[-2.91,.182,.422,.418,.43],
	[-2.48,.195,.446,.461,.453],[-1.99,.207,.469,.494,.478],[-1.52,.224,.478,.516,.510],
	[-1.12,.235,.478,.531,.544],[-.66,.249,.475,.539,.571],[-.19,.257,.454,.537,.571],
	[.37,.274,.412,.500,.515],[.87,.298,.363,.441,.441],[1.40,.324,.321,.377,.380],
	[2.02,.346,.263,.307,.309],[2.56,.357,.207,.242,.252],[3.09,.368,.149,.177,.183],
	[3.60,.381,.100,.128,.131],[4.01,.388,.066,.088,.092],[4.31,.394,.032,.051,.056],
	[4.43,.397,.016,.030,.031]]
const HAYA_WING := [
	[.25,-1.42,2.56,.02,.138],[.55,-1.42,2.55,.022,.13],[.86,-1.36,2.44,.065,.132],
	[1.48,-1.29,2.32,.111,.128],[2.16,-1.21,2.18,.174,.12],[3.11,-1.10,1.991,.275,.107],
	[4.12,-.98,1.75,.375,.097],[4.82,-.866,1.52,.441,.08],[5.13,-.746,1.25,.470,.074],
	[5.31,-.550,.861,.488,.055],[5.40,-.344,.482,.496,.03],[5.42,-.155,.090,.503,.014]]
const HIEN_WING := [
	[.24,-1.48,2.67,.005,.146],[.60,-1.48,2.66,.018,.145],[1.03,-1.47,2.58,.055,.136],
	[1.64,-1.44,2.42,.105,.126],[2.45,-1.39,2.19,.185,.115],[3.52,-1.31,1.94,.29,.105],
	[4.61,-1.17,1.70,.399,.092],[5.35,-1.036,1.47,.474,.084],[5.66,-.923,1.28,.507,.073],
	[5.85,-.786,1.03,.526,.06],[5.95,-.606,.722,.536,.047],[5.99,-.459,.430,.539,.028],
	[6.00,-.34,.21,.54,.019]]
const HAYA_TAIL := [[.025,2.76,1.40,.371,.109],[.33,2.80,1.38,.38,.10],[.68,2.89,1.25,.389,.085],
	[1.14,3.06,1.06,.42,.078],[1.47,3.26,.80,.441,.064],[1.66,3.46,.53,.46,.044],[1.73,3.68,.18,.470,.02]]
const HIEN_TAIL := [[.025,2.65,1.49,.431,.103],[.35,2.71,1.46,.440,.097],[.72,2.83,1.31,.45,.085],
	[1.20,3.00,1.14,.48,.074],[1.59,3.18,.91,.506,.06],[1.86,3.39,.65,.524,.043],[1.98,3.55,.31,.535,.026],[2.00,3.65,.12,.537,.015]]
const HAYA_GLASS := [
	[-1.31,.653,.279,.044,.04],[-1.23,.650,.335,.158,.048],[-1.07,.647,.356,.389,.039],
	[-.89,.638,.363,.485,.047],[-.63,.632,.367,.495,.045],[-.32,.618,.354,.461,.048],
	[-.07,.593,.331,.376,.052],[.21,.550,.297,.251,.042],[.43,.526,.241,.14,.03],[.62,.516,.146,.062,.025]]
const HIEN_GLASS := [
	[-1.12,.750,.297,.044,.05],[-1.02,.753,.326,.154,.050],[-.86,.756,.354,.330,.049],
	[-.69,.762,.369,.408,.046],[-.48,.768,.377,.432,.046],[-.24,.761,.371,.417,.039],
	[.01,.745,.349,.384,.041],[.25,.720,.332,.327,.050],[.49,.691,.303,.234,.047],[.66,.651,.260,.15,.036],[.81,.619,.214,.04,.024]]

func _ready() -> void:
	var hayabusa: bool = variant == 0
	var body: Array = HAYA_BODY if hayabusa else HIEN_BODY
	var wing: Array = HAYA_WING if hayabusa else HIEN_WING
	var tail: Array = HAYA_TAIL if hayabusa else HIEN_TAIL
	_set_batch_paint(Color("a9aa9c") if hayabusa else Color("b9bbaf"), Color("a1a79e") if hayabusa else Color("aeb3ab"))
	paint.rubber = GEO.material(Color("262a29"))
	paint.radial = GEO.material(Color("353d37"))
	paint.olive = GEO.material(Color("656b4e"))
	paint.mottle = GEO.material(Color("747960"))
	paint.red = GEO.material(Color("9e3930"))
	paint.warm_dark = GEO.material(Color("493c33"))
	var frame: Node3D = GEO.group(self,"Fuselage")
	var aero: Node3D = GEO.group(self,"WingsAndTail")
	var nose: Node3D = GEO.group(self,"EngineExterior")
	var insignia: Node3D = GEO.group(self,"AppliedMarkings")
	_body(frame,"ClosedFuselageLoft",body)
	_canopy(GEO.group(self,"Canopy"),HAYA_GLASS if hayabusa else HIEN_GLASS)
	if hayabusa:
		_fin(aero,"RoundedTallTail",[[.36,2.43,4.585,.116],[.60,2.87,4.59,.114],[.95,3.10,4.58,.096],[1.25,3.29,4.54,.081],
			[1.53,3.43,4.46,.066],[1.78,3.54,4.37,.051],[1.91,3.66,4.24,.036],[1.96,3.81,4.03,.018],[1.96,3.88,3.91,.009]])
		_radial_cowl(nose,body)
	else:
		_fin(aero,"SweptDorsalFin",[[.44,2.30,4.425,.112],[.61,2.70,4.432,.104],[.81,2.96,4.423,.102],[1.16,3.24,4.41,.084],
			[1.50,3.56,4.40,.066],[1.77,3.74,4.40,.050],[1.94,3.88,4.38,.038],[2.04,4.02,4.33,.021],[2.09,4.12,4.25,.009]])
		_inline_forms(nose,body)
		_radiator(GEO.group(self,"DeepVentralRadiator"))
	for side: float in [-1.0,1.0]:
		_wing(aero,"Mainplane",wing,side)
		_wing(aero,"Tailplane",tail,side)
		_wing_hinge_line(aero,wing,side,2.81 if hayabusa else 3.09,5.04 if hayabusa else 5.65,.76,.009)
		_wing_hinge_line(aero,tail,side,.52,1.58 if hayabusa else 1.87,.73,.008)
		_wing_seam(aero,wing,side,2.54)
		_wing_seam(aero,wing,side,4.3)
		var tip: Vector3 = GEO.wing_point(wing,5.29 if hayabusa else 5.87,.36,true)
		tip.x *= side
		_ellipsoid(aero,"TipGlazing",Vector3(.041,.022,.065),tip,paint.red if side<0.0 else paint.nav_green)
		_gear(side,hayabusa)
		_disc(insignia,"FuselageRoundel","body",body,Vector2(1.14 if hayabusa else 1.27,.305),.278 if hayabusa else .354,side)
		for surface: float in [-1.0,1.0]:
			var center := Vector2(side*(3.49 if hayabusa else 4.03),-.291)
			_disc(insignia,"WingRoundel","wing",wing,center,.486 if hayabusa else .475,surface)
		if hayabusa:
			_rear_band(insignia,body,side)
			_spray_patches(insignia,body,wing,side)
	var hub := Vector3(0,-.426,3.8 if hayabusa else 3.71)
	GEO.rod(self,"TailLeg",Vector3(0,.190,3.54),hub,.047,paint.frame)
	_ellipsoid(self,"TailWheel",Vector3(.074,.151,.151),hub,paint.rubber)
	GEO.rod(self,"ShortAntenna",Vector3(0,.580,.68),Vector3(0,1.42,.80),.019,paint.frame)

func _radial_cowl(host: Node3D,body: Array) -> void:
	GEO.arch(host,"CowlRearSheetLine",body,-3.11,.022,paint.radial)
	_ellipsoid(host,"ClosedDarkRadialFace",Vector3(.409,.412,.047),Vector3(0,.142,-4.091),paint.radial)
	for slot: int in 14:
		var a: float = TAU*slot/14.0
		var radial := Vector3(sin(a),cos(a),0)
		GEO.rod(host,"ClosedRecessFacet",Vector3(0,.142,-4.09)+radial*.132,Vector3(0,.142,-4.097)+radial*.370,.028,paint.frame)
	_prop(host,Vector3(0,.145,-4.105),1.462,Vector3(.157,.156,.150),.42,1.0,paint.metal)
	for side: float in [-1.,1.]:
		var fairing := Vector3(side*.446,-.186,-3.29)
		_ellipsoid(host,"ClosedCollectorFairing",Vector3(.096,.063,.189),fairing,paint.warm_dark)

func _inline_forms(host: Node3D,body: Array) -> void:
	_prop(host,Vector3(0,.151,-4.177),1.48,Vector3(.211,.211,.112),.43,1.,paint.metal)
	GEO.arch(host,"SlimCowlingSheetLine",body,-2.38,.020,paint.frame)
	for side: float in [-1.,1.]:
		for i: int in 6:
			var z: float = -3.57+i*.143
			var row: Array = GEO.sample(body,z)
			_ellipsoid(host,"ClosedExhaustShadow",Vector3(.039,.033,.096),Vector3(side*(row[2]-.001),.105+i*.009,z),paint.warm_dark)

func _radiator(host: Node3D) -> void:
	var rows: Array = [[-.03,-.269,.18,.120,.12],[.14,-.328,.301,.145,.17],[.32,-.368,.34,.154,.255],
		[.64,-.351,.328,.143,.218],[.99,-.316,.262,.137,.158],[1.28,-.278,.161,.11,.094],[1.44,-.239,.048,.052,.055]]
	_body(host,"ClosedRoundedRadiatorHousing",rows)
	_ellipsoid(host,"RecessedRadiatorFace",Vector3(.243,.112,.069),Vector3(0,-.398,.162),paint.radial)

func _gear(side: float,hayabusa: bool) -> void:
	var g: Node3D = GEO.group(self,"PortLandingGear" if side<0. else "StarboardLandingGear")
	var mount := Vector3(side*(1.81 if hayabusa else 1.77),-.066,-.79)
	var hub := Vector3(side*(1.93 if hayabusa else 1.96),-1.069,-1.01 if hayabusa else -.968)
	GEO.rod(g,"OleoLeg",mount,hub,.064,paint.metal)
	GEO.rod(g,"Brace",mount+Vector3(side*-.27,.02,.49),hub+Vector3.UP*.19,.033,paint.frame)
	_ellipsoid(g,"Tyre",Vector3(.124,.281,.281),hub,paint.rubber)
	_ellipsoid(g,"HubCover",Vector3(.023,.128,.128),hub+Vector3.RIGHT*side*.107,paint.metal)
	_ellipsoid(g,"UpperGearSkin",Vector3(.066,.393,.224),mount.lerp(hub,.37)+Vector3.RIGHT*side*.102,paint.top)

func _disc(host: Node3D,id: String,kind: String,profile: Array,c: Vector2,r: float,side: float) -> void:
	var pts: Array[Vector2] = []
	for i: int in 30:
		var theta: float = TAU*i/30.0
		pts.append(c+Vector2(cos(theta),sin(theta))*r)
	_decal(host,id,kind,profile,pts,side,.018,paint.red)

func _rear_band(host: Node3D,body: Array,side: float) -> void:
	var pts: Array[Vector2] = [Vector2(2.42,.123),Vector2(2.58,.117),Vector2(2.58,.502),Vector2(2.42,.523)]
	_decal(host,"RearFuselageWhiteBand","body",body,pts,side,.016,paint.white)

func _spray_patches(host: Node3D,body: Array,wing: Array,side: float) -> void:
	for i: int in 14:
		var z: float = -2.92 + i*.4
		var row: Array = GEO.sample(body,z)
		var c := Vector2(z,row[1]+row[3]*(.50+.22*sin(i*4.96+side)))
		_olive_island(host,"body",body,c,Vector2(.13+.066*sin(i*4.22),.042+.014*cos(i*3.3)),side,i)
	for ix: int in 12:
		var sx: float = side*(.85+.322*ix)
		var row: Array = GEO.sample(wing,absf(sx))
		for j: int in 3:
			var z: float = row[1]+row[2]*(.19+j*.29+.07*sin(ix*3.9+j))
			var c := Vector2(sx+.04*sin(j*2.6+ix),z)
			_olive_island(host,"wing",wing,c,Vector2(.115+.046*sin(ix*4.75+j),.14+.07*cos(ix*2.55+j)),1.0,ix*4+j)

func _olive_island(host: Node3D,kind: String,profile: Array,c: Vector2,sz: Vector2,side: float,n: int) -> void:
	var pts: Array[Vector2] = []
	for i: int in 8:
		var a: float = TAU*i/8.0
		var spread: float = .87+.15*sin(i*3.7+n*2.4)
		pts.append(c+Vector2(cos(a)*sz.x,sin(a)*sz.y)*spread)
	_decal(host,"AgeSoftenedFieldMottle",kind,profile,pts,side,.008,paint.olive if n%3==0 else paint.mottle)
