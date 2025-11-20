extends Node

@export var agent_name : String = "Bob"
@export var attempts : int = 6
@export var delay_sec : float = 0.1

func _ready() -> void:
	for i in range(attempts):
		for a in get_tree().get_nodes_in_group("agents"):
			if a.name == agent_name:
				print("Helper (group): trovato", a.get_path())
				a.call_deferred("walk", "Cassa1", -1)
				queue_free()
				return
		await get_tree().create_timer(delay_sec).timeout
	print("Helper (group): non trovato", agent_name)
	queue_free()
