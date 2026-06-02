extends Node
class_name State
## 状态基类。继承它实现每个状态（idle/run/jump/attack/hurt…）。
## 在 enter/exit/update/physics_update/handle_input 里写逻辑，
## 调用 state_machine.transition_to("名字") 切换状态。

var state_machine: StateMachine

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
