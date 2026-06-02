extends Node
class_name StateMachine
## 通用有限状态机。把若干 State 作为子节点挂上即可。
## 当前状态名可读 current_name（调试 overlay 会显示）。

signal state_changed(name: String)

@export var initial_state: NodePath

var current: State
var current_name := ""
var _states := {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			_states[child.name.to_lower()] = child
			child.state_machine = self
	var start: State = get_node_or_null(initial_state) as State
	if start == null and _states.size() > 0:
		start = _states.values()[0]
	if start != null:
		current = start
		current_name = start.name
		current.enter()

func _process(delta: float) -> void:
	if current:
		current.update(delta)

func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current:
		current.handle_input(event)

func transition_to(name: String, msg: Dictionary = {}) -> void:
	var key := name.to_lower()
	if not _states.has(key) or _states[key] == current:
		return
	if current:
		current.exit()
	current = _states[key]
	current_name = current.name
	current.enter(msg)
	state_changed.emit(current_name)
