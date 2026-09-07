## TEMPLATE FILE ############################
# This file enables the visible controller models you can see when
# you are actively using and the headset is tracking controllers.
#############################################

extends Node3D
class_name XRControllerVisuals


const EXPECTED_POSE := &"grip"

# Define the two fields for controllers. They must be of type XRController3D
# A carat (^) before a string represents a path
@export_node_path("XRController3D") var left_controller: NodePath
@export_node_path("XRController3D") var right_controller: NodePath

# Here we define the two models as scenes the user will select
@export var left_model: PackedScene
@export var right_model: PackedScene

# Any offsets or rotations that need to be applied due to controller quirks
# Should be fine at zero. Adjust as needed.
@export_group("Offsets")
@export var model_offset := Vector3.ZERO
@export var model_rotation := Vector3.ZERO


func _ready() -> void:
	_attach(left_controller, left_model)
	_attach(right_controller, right_model)


func _attach(controller_path: NodePath, model: PackedScene) -> void:
	# Retrieve the proper node. `as XRController3D` simply tells the interpreter the type.
	var controller := get_node(controller_path) as XRController3D
	
	# Instantiate the scene of the given controller. This spawns the actual scene into the runtime
	var instance := model.instantiate() as Node3D

	# Here we simply change some things to identify the scene, apply any needed offsets, and attach the model.
	instance.name = "ControllerModel"
	instance.position = model_offset
	instance.rotation_degrees = model_rotation
	controller.add_child(instance)
