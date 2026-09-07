## TEMPLATE FILE ############################
# This file manages the passthrough of the project. You can simply set the enabled member on this class and
# the script will automatically switch the passthrough mode.
#############################################

extends Node
class_name XRPassthrough

# This is the high level trigger for passthrough. Set to true or false to enable/disable passthrough
# The block underneath is the setter attatched directly to the variable. Any changes to `enabled` will go
# through that code and dynamically toggle passthrough.
@export var enabled := false:
	set(value):
		enabled = value
		if _ready_to_apply:
			_apply(value)

# Assign your WorldEnviornment node here. This is so the code can modify it's proptorties.
@export_node_path("WorldEnvironment") var world_environment: NodePath

# Anything that would ruin the passthrough mode. Ex. walls, floors, etc is placed here
# and hidden during passthrough mode.
@export var hide_in_passthrough: Array[NodePath] = []

var _xr: XRInterface = null

var _environment: Environment = null
var _original_background := Environment.BG_SKY

# Cache the existing hidden objects so already hidden objects stay hidden.
var _hidden: Array[Node3D] = []
var _hidden_was_visible: Array[bool] = []

# A safety flag to ensure the xr interface isn't accessed before it exists.
var _ready_to_apply := false


func _ready() -> void:
	# Grab the xr interface
	_xr = XRServer.find_interface("OpenXR")
	if _xr == null: 
		push_error("XRPassthrough|FATAL: no OpenXR interface passthrough will NOT work")
		return

	# Process the applications's envornment
	var world: WorldEnvironment = get_node_or_null(world_environment)
	if world != null and world.environment != null:
		_environment = world.environment
		_original_background = _environment.background_mode
	else:
		push_warning("XRPassthrough|WARN: no WorldEnvironment assigned, or no enviornment within the 
		WorldEnviornment. You may have issues with the sky blocking passthrough")

	# For each object you request to be hidden in passthrough, we store the Node itself plus if it was hidden.
	# This is to prevent objects you specifically hide from being unhidden in testing.
	for path in hide_in_passthrough:
		var node := get_node_or_null(path) as Node3D
		_hidden.append(node)
		_hidden_was_visible.append(node.visible)

	# We will here link the function to the session_begun signal to flip the _ready_to_apply flag to true when
	# and only when the session is ready. Note: we never clear this flag. Implement this additional guard if you'd like
	# on things like session pause (headset put down). The purpose of this is because set_environment_blend_mode only 
	# does anything if the session is actually running.
	_xr.session_begun.connect(_on_session_begun)


func _on_session_begun() -> void:
	_ready_to_apply = true
	_apply(enabled)


## Apply the actual switch
func _apply(enable: bool) -> void:

	# ternary to define the mode based on enable
	var mode := (XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND if enable
		else XRInterface.XR_ENV_BLEND_MODE_OPAQUE)

	# Apply the selected mode
	_xr.set_environment_blend_mode(mode)
	get_viewport().transparent_bg = enable # note: disables ssr, subsurface scattering, depth of field, etc.

	# If an enviornment is present, toggle the current state to the proper one based on enable
	if _environment != null:
		if enable:
			_environment.background_mode = Environment.BG_COLOR
			_environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		else:
			_environment.background_mode = _original_background

	# Toggle the visibility of all relevant objects.
	for i in _hidden.size():
		_hidden[i].visible = _hidden_was_visible[i] and not enable

	print("XRPassthrough|INFO: passthrough %s" % ("on" if enable else "off"))
