extends RefCounted
## Fictional coordination board. A completed ticket is only a board event;
## this code cannot command a vehicle, route, weapon, or physical deck.
const AUTO := "自动"
const USER := "玩家"
var decks := {}
var task := {}
var log: Array[String] = []
var clock := 0
var serial := 0

func _init() -> void:
	for id: String in ["A","B"]:
		decks[id] = {"controller":AUTO,"generation":0,"open":true,"now":{},"line":[]}
	_note("舰队指挥官","建立双舰协调板")

func _note(role: String, detail: String) -> void:
	log.append("%02d  %s · %s" % [clock,role,detail])
	if log.size() > 120:
		log.pop_front()

func fleet_task() -> bool:
	if not task.is_empty():
		return false
	task = {"id":"演练-01","status":"待航空岗分配","deadline":clock+12}
	_note("舰队指挥官","签发演练任务，交航空指挥官分配")
	return true

func _assign() -> void:
	if task.get("status","") != "待航空岗分配":
		return
	if clock >= int(task.deadline):
		task.status = "已过期"
		_note("航空指挥官","任务过期，停止分配")
		return
	for id: String in ["A","B"]:
		var deck: Dictionary = decks[id]
		if not deck.open or not deck.now.is_empty() or not deck.line.is_empty():
			continue
		task.status = "已签收"
		task.carrier = id
		var ticket := _ticket("离舰演练","普通",task.id)
		deck.line.append(ticket)
		_note("航空指挥官","演练任务交 %s 舰，票据 #%s" % [id,ticket.id])
		return

func _review_assignment() -> void:
	if task.get("status","") != "已签收":
		return
	var from: String = task.carrier
	var source: Dictionary = decks[from]
	if source.open:
		return
	var pending: int = source.line.find_custom(func(v:Dictionary)->bool: return v.parent == task.id)
	if pending < 0:
		return # Already running or closed out; never transfer an active ticket.
	var other := "B" if from == "A" else "A"
	var dest: Dictionary = decks[other]
	if not dest.open or not dest.now.is_empty() or not dest.line.is_empty():
		return
	var ticket: Dictionary = source.line.pop_at(pending)
	dest.line.append(ticket)
	task.carrier = other
	_note("航空指挥官","%s 舰甲板暂停，待执行票据 #%d 改交 %s 舰" % [from,ticket.id,other])

func _ticket(title: String, priority: String, parent: String = "") -> Dictionary:
	serial += 1
	return {"id":serial,"title":title,"priority":priority,"parent":parent,"end":clock+12}

func request_return(id: String, priority: bool) -> bool:
	if not decks.has(id):
		return false
	var fleet: Dictionary = decks[id]
	var ticket := _ticket("回收演练","优先" if priority else "普通")
	fleet.line.append(ticket)
	_note("编队长","%s 舰请求%s回收 #%d" % [id,"优先" if priority else "",ticket.id])
	if not fleet.open or not fleet.now.is_empty():
		_note(id+" 舰调度官","票据 #%d 等待：%s" % [ticket.id,"甲板暂停" if not fleet.open else "上一项还未结束"])
	return true

func captain_open(id: String, available: bool) -> bool:
	if not decks.has(id) or decks[id].open == available:
		return false
	decks[id].open = available
	_note(id+" 舰舰长","开放甲板" if available else "暂停新作业；当前作业不被调度中断")
	return true

func takeover(id: String, controller: String) -> int:
	if not decks.has(id) or controller not in [AUTO,USER]:
		return -1
	var deck: Dictionary = decks[id]
	if deck.controller == controller:
		return deck.generation
	deck.controller = controller
	deck.generation += 1
	_note(id+" 舰调度官","%s接管：原票据、队列与进行中操作保留" % controller)
	return deck.generation

func start(id: String, controller: String, generation: int, requested: int = -1) -> bool:
	if not decks.has(id):
		return false
	var deck: Dictionary = decks[id]
	if controller != deck.controller or generation != deck.generation:
		return false
	if not deck.open or not deck.now.is_empty() or deck.line.is_empty():
		return false
	var selection := 0
	if requested >= 0:
		selection = deck.line.find_custom(func(v:Dictionary)->bool: return v.id == requested)
		if selection < 0:
			return false
	else:
		selection = deck.line.find_custom(func(v:Dictionary)->bool: return v.priority == "优先")
		selection = maxi(0,selection)
	var ticket: Dictionary = deck.line[selection]
	if ticket.end <= clock:
		return false
	deck.line.remove_at(selection)
	deck.now = ticket
	deck.now.complete_at = clock+2
	_note(id+" 舰调度官","%s开始 %s #%d" % [controller,ticket.title,ticket.id])
	return true

func advance() -> void:
	clock += 1
	for id: String in ["A","B"]:
		var deck: Dictionary = decks[id]
		if not deck.now.is_empty() and deck.now.complete_at <= clock:
			var ticket: Dictionary = deck.now
			deck.now = {}
			_note(id+" 舰调度官","完成 %s #%d" % [ticket.title,ticket.id])
			if not task.is_empty() and ticket.parent == task.id:
				task.status = "已完成"
		for i: int in range(deck.line.size()-1,-1,-1):
			var entry: Dictionary = deck.line[i]
			if entry.end <= clock:
				deck.line.remove_at(i)
				_note(id+" 舰调度官","票据 #%d 过期，已回报" % entry.id)
				if not task.is_empty() and entry.parent == task.id:
					task.status = "已过期"
	_review_assignment()
	_assign()
	for id: String in ["A","B"]:
		if decks[id].controller == AUTO:
			start(id,AUTO,decks[id].generation)
