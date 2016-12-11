
extends Label

# member variables here, example:
# var a=2
# var b="textvar"

onready var player = get_tree().get_root().get_node("Test/Player")

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	set_process(true)
	
func _process(delta):
	var output = ""
	output = output + state_string()
	output = output + velocity_string()
	set_text(output)

func state_string():
	var stat_name = player.movement.get_state_name()
	return "State: " + stat_name + "\n"

func velocity_string():
	return "Velocity: " + str(player.movement.state.velocity)