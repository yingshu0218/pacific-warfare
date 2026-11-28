extends Control
const BOARD := preload("res://scripts/command/coordination/deck_board.gd")
const FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var board := BOARD.new()
var status := Label.new()
var trail := RichTextLabel.new()
var readouts := {}
var playing := false
var elapsed := 0.0

func _ready() -> void:
	var skin := Theme.new()
	skin.default_font = FONT
	skin.default_font_size = 17
	theme = skin
	var blue := ColorRect.new()
	blue.color = Color("172833")
	add_child(blue)
	blue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := MarginContainer.new()
	add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: pad.add_theme_constant_override("margin_"+side,27)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	pad.add_child(body)
	var title := Label.new()
	title.text = "双舰指挥链 · 调度演练"
	title.add_theme_font_size_override("font_size",30)
	body.add_child(title)
	var tagline := Label.new()
	tagline.text = "舰队签发  →  航空岗位分配  →  各舰调度官签收   /   独立游戏原型"
	body.add_child(tagline)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	_button(actions,"签发演练任务",func(): board.fleet_task())
	_button(actions,"推进一步",func(): board.advance())
	_button(actions,"自动观战 开/暂停",func(): playing = not playing)
	_button(actions,"重置",func(): board = BOARD.new())
	body.add_child(status)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation",18)
	body.add_child(pair)
	for id: String in ["A","B"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("223944");style.set_corner_radius_all(7);style.set_content_margin_all(13)
		panel.add_theme_stylebox_override("panel",style)
		pair.add_child(panel)
		var shelf := VBoxContainer.new()
		shelf.add_theme_constant_override("separation",6)
		panel.add_child(shelf)
		var label := Label.new()
		label.add_theme_font_size_override("font_size",20)
		shelf.add_child(label)
		readouts[id] = label
		var row := HBoxContainer.new()
		shelf.add_child(row)
		_button(row,"普通回收",func(): board.request_return(id,false))
		_button(row,"优先回收",func(): board.request_return(id,true))
		_button(row,"舰长 开/停",func(): board.captain_open(id,not board.decks[id].open))
		var row2 := HBoxContainer.new()
		shelf.add_child(row2)
		_button(row2,"玩家接管／交还",func(): board.takeover(id,BOARD.AUTO if board.decks[id].controller==BOARD.USER else BOARD.USER))
		_button(row2,"玩家放行下一项",func(): board.start(id,BOARD.USER,board.decks[id].generation))
	var header := Label.new()
	header.text = "命令与回报"
	body.add_child(header)
	trail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trail.scroll_following = true
	body.add_child(trail)
	refresh()

func _button(row: Control,title: String,action: Callable) -> void:
	var btn := Button.new()
	btn.text = title
	row.add_child(btn)
	btn.pressed.connect(func(): action.call();refresh())

func _process(delta: float) -> void:
	if not playing: return
	elapsed += delta
	if elapsed >= .9:
		elapsed -= .9
		board.advance()
		refresh()

func refresh() -> void:
	status.text = "第 %d 步  ·  %s  ·  舰队任务：%s" % [board.clock,"自动推进" if playing else "暂停推进",board.task.get("status","未签发")]
	for id: String in readouts:
		var deck: Dictionary = board.decks[id]
		readouts[id].text = "%s 舰   ·   %s调度   ·   甲板%s\n进行中：%s   /   等待：%d 项" % [id,deck.controller,"开放" if deck.open else "暂停",deck.now.get("title","空闲"),deck.line.size()]
	trail.text = "\n".join(board.log.slice(maxi(0,board.log.size()-80)))
