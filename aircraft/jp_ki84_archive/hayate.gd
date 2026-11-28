extends "res://aircraft/us_archive/batch_airframe_finish.gd"
## Closed static exhibit. +X starboard and -Z forward; scale is for game presentation.

const BODY := [
	[-4.45,.155,.399,.467,.438],[-4.39,.147,.508,.555,.538],[-4.23,.14,.574,.615,.600],
	[-3.93,.137,.603,.637,.626],[-3.54,.135,.599,.632,.619],[-3.19,.143,.575,.611,.593],
	[-2.83,.154,.553,.596,.593],[-2.38,.158,.537,.592,.614],[-1.89,.176,.529,.595,.647],
	[-1.42,.19,.526,.634,.661],[-.96,.215,.518,.674,.670],[-.51,.244,.502,.649,.648],
	[-.05,.262,.482,.600,.601],[.49,.278,.451,.536,.565],[.97,.293,.402,.467,.503],
	[1.53,.318,.349,.407,.422],[2.11,.342,.288,.335,.341],[2.66,.362,.233,.272,.272],
	[3.16,.384,.179,.214,.217],[3.64,.399,.125,.145,.154],[4.04,.41,.085,.100,.107],
	[4.34,.419,.062,.075,.079],[4.54,.424,.026,.050,.055],[4.59,.424,.013,.030,.033]]
const WING := [
	[.24,-1.63,2.84,.01,.172],[.52,-1.62,2.82,.01,.169],[.85,-1.57,2.68,.039,.151],
	[1.36,-1.49,2.52,.087,.139],[2.18,-1.37,2.32,.178,.127],[3.08,-1.24,2.10,.275,.116],
	[4.03,-1.085,1.87,.376,.102],[4.75,-.962,1.67,.454,.084],[5.13,-.829,1.39,.495,.068],
	[5.40,-.653,1.02,.516,.052],[5.54,-.435,.646,.528,.038],[5.60,-.245,.333,.537,.023],
	[5.62,-.129,.125,.541,.015]]
const TAIL := [[.026,2.65,1.56,.465,.115],[.35,2.72,1.52,.47,.109],[.69,2.83,1.38,.49,.10],
	[1.11,2.99,1.19,.52,.087],[1.49,3.17,.992,.554,.075],[1.78,3.37,.76,.574,.056],
	[1.97,3.56,.55,.59,.041],[2.05,3.72,.29,.596,.028],[2.07,3.81,.12,.6,.013]]
const GLASS := [[-1.48,.738,.272,.082,.035],[-1.36,.737,.345,.170,.042],[-1.20,.739,.371,.355,.048],
	[-.982,.741,.387,.486,.048],[-.79,.740,.39,.510,.041],[-.49,.734,.387,.502,.043],
	[-.21,.723,.368,.465,.042],[.07,.701,.339,.389,.040],[.32,.683,.308,.257,.036],
	[.51,.666,.257,.151,.035],[.67,.647,.198,.080,.031],[.80,.632,.160,.041,.030]]
const FIN := [[.41,2.55,4.57,.112],[.55,2.72,4.59,.113],[.85,3.02,4.58,.108],[1.12,3.23,4.57,.096],
	[1.41,3.405,4.55,.079],[1.66,3.545,4.52,.065],[1.87,3.659,4.47,.051],
	[2.035,3.785,4.4,.042],[2.15,3.91,4.285,.029],[2.19,4.02,4.17,.014],[2.20,4.080,4.122,.008]]

func _ready() -> void:
	_set_batch_paint(Color("657154"),Color("bdc3b4"))
	paint.radial = GEO.material(Color("3a3c32"))
	paint.spinner = GEO.material(Color("923f36"))
	paint.rubber = GEO.material(Color("2b2e2c"))
	paint.oxide = GEO.material(Color("514e42"))
	var visual: Node3D = GEO.group(self,"DisplayGeometry")
	visual.scale.z = 1.0533
	var airframe: Node3D = GEO.group(visual,"Airframe")
	var wing_root: Node3D = GEO.group(visual,"AeroSurfaces")
	var paintwork: Node3D = GEO.group(visual,"Paintwork")
	_body(airframe,"DeepHeavyweightRadialBody",BODY)
	_cowl(GEO.group(visual,"ClosedCowlingExterior"))
	_canopy(GEO.group(visual,"RaisedCanopy"),GLASS)
	_fin(wing_root,"TallRoundShoulderedFin",FIN)
	_chin_housing(airframe)
	for side: float in [-1.,1.]:
		GEO.part(wing_root,"TaperedLowWing_"+("Port" if side<0. else "Starboard"),
			GEO.wing(WING,side,WING[0][0],WING[-1][0],0.,1.,Vector3.ZERO,paint.top.albedo_color,paint.bottom.albedo_color,true),paint.skin)
		_wing(wing_root,"Tailplane",TAIL,side)
		_wing_hinge_line(wing_root,WING,side,2.85,5.31,.77,.012)
		_wing_hinge_line(wing_root,TAIL,side,.44,1.95,.68,.008)
		_wing_seam(wing_root,WING,side,2.61)
		_wing_seam(wing_root,WING,side,4.15)
		_roundel(paintwork,"body",BODY,Vector2(1.24,.327),.325,side,.008)
		for surface: float in [-1.,1.]:
			_roundel(paintwork,"wing",WING,Vector2(side*3.94,-.262),.544,surface,.014)
		var tip: Vector3 = GEO.wing_point(WING,5.49,.42,true)
		tip.x *= side
		_ellipsoid(wing_root,"WingtipPositionLight",Vector3(.038,.022,.050),tip,paint.red if side<0. else paint.nav_green)
		_gear(visual,side)
	var hub := Vector3(0,-.37,3.83)
	GEO.rod(visual,"TailLeg",Vector3(0,.30,3.72),hub,.050,paint.metal)
	_ellipsoid(visual,"TailWheel",Vector3(.079,.150,.15),hub,paint.rubber)
	GEO.rod(visual,"RakedAntenna",Vector3(0,.765,.88),Vector3(0,1.482,.965),.019,paint.frame)

func _cowl(host: Node3D) -> void:
	_ellipsoid(host,"ClosedBroadRadialFace",Vector3(.414,.473,.038),Vector3(0,.157,-4.466),paint.radial)
	for slot: int in 16:
		var a: float = TAU*slot/16.
		var ray := Vector3(sin(a),cos(a)*1.14,0)
		GEO.rod(host,"ClosedRecessFacet",Vector3(0,.155,-4.497)+ray*.184,Vector3(0,.155,-4.484)+ray*.384,.029,paint.frame)
	GEO.arch(host,"CowlingRearBand",BODY,-3.25,.023,paint.seam)
	for side: float in [-1.,1.]:
		for i: int in 4:
			_ellipsoid(host,"ClosedExhaustRelief",Vector3(.053,.034,.133),Vector3(.575*side,-.102+i*.103,-3.28+i*.071),paint.oxide)
	var prop: Node3D = GEO.group(host,"FourBladeDisplayPropeller",Vector3(0,.156,-4.53))
	_ellipsoid(prop,"RoundedSpinner",Vector3(.218,.218,.23),Vector3(0,0,-.07),paint.spinner)
	var radius: float = 1.56
	for i: int in 4:
		var socket: Node3D = GEO.group(prop,"StaticBlade_%d"%i)
		socket.rotation.z = .66+PI*.5*i
		var plate: Node3D = GEO.group(socket,"BladeProfile")
		plate.rotation.y = PI*.5
		_plate(plate,"BladeSkin",[[.19,-.054],[.38,-.108],[.69,-.155],[1.10,-.167],[1.41,-.115],[1.53,-.060],[radius,.006],
			[1.535,.056],[1.40,.084],[1.10,.115],[.66,.103],[.39,.082],[.19,.057]],.048,paint.dark)
		_plate(plate,"RoundedYellowTip",[[1.447,-.104],[1.53,-.061],[radius,.006],[1.535,.056],[1.447,.075]],.050,paint.yellow)

func _chin_housing(host: Node3D) -> void:
	var chin := [[-4.05,-.388,.142,.068,.124],[-3.98,-.42,.2,.101,.148],[-3.78,-.45,.232,.112,.198],
		[-3.52,-.444,.227,.094,.188],[-3.26,-.411,.171,.088,.153],[-3.09,-.388,.099,.065,.096],
		[-2.96,-.379,.034,.036,.041]]
	_body(host,"ClosedShortChinFairing",chin)
	_ellipsoid(host,"DarkClosedChinContour",Vector3(.149,.093,.052),Vector3(0,-.455,-4.028),paint.radial)

func _gear(visual: Node3D,side: float) -> void:
	var chain: Node3D = GEO.group(visual,"PortDisplayGear" if side<0.0 else "StarboardDisplayGear")
	var top := Vector3(side*1.84,.012,-.846)
	var hub := Vector3(side*1.997,-.927,-1.044)
	GEO.rod(chain,"StaticMainStrut",top,hub,.064,paint.metal)
	GEO.rod(chain,"StaticBrace",top+Vector3(-side*.25,.017,.32),hub+Vector3.UP*.264,.034,paint.frame)
	_ellipsoid(chain,"MainTyre",Vector3(.133,.305,.306),hub,paint.rubber)
	_ellipsoid(chain,"MainHub",Vector3(.026,.146,.147),hub+Vector3.RIGHT*side*.119,paint.metal)
	_ellipsoid(chain,"UpperGearDoor",Vector3(.067,.381,.209),top.lerp(hub,.40)+Vector3.RIGHT*side*.086,paint.bottom)
	_ellipsoid(chain,"LowerDoorLip",Vector3(.033,.274,.221),hub+Vector3(side*.139,.128,.033),paint.bottom)

func _roundel(host: Node3D,kind: String,profile: Array,c: Vector2,r: float,side: float,lift: float) -> void:
	for layer: int in 2:
		var shape: Array[Vector2] = []
		for i: int in 30:
			var theta: float = TAU*i/30.
			shape.append(c+Vector2(cos(theta),sin(theta))*r*(1. if layer==0 else .88))
		_decal(host,"RoundelBorder" if layer==0 else "RedRoundel",kind,profile,shape,side,lift+.006*layer,paint.white if layer==0 else paint.red)
