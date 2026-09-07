## TEMPLATE FILE ############################
# Picking things up!
#############################################

extends Area3D
class_name XRGrabber


## Which controller action grabs. Choose an openxr action map bind.
@export var grab_action := "grip_click"

## If set, only bodies in this specific group can be picked up. Useful if you don't
## want ALL rigidbodies to be pickable.
@export var required_group := ""

## Multiplies how hard objects are thrown. Sometimes it can feel more satisfying to
## bump this up to ~1.2 ish
@export_range(0.0, 3.0) var throw_strength := 1.0

## If you want a satisfying little haptip blip when you grab something :)
@export var haptics := true

var _controller: XRController3D = null
var _held: RigidBody3D = null

# So we can store where the object was when you grabbed it, so it doesn't snap to the
# middle of your palm
var _grab_offset := Transform3D.IDENTITY

# Hand velocity/pos storage to throw
var _last_position := Vector3.ZERO
var _velocity := Vector3.ZERO


func _ready() -> void:
	# Ensure the script is a child of an XRController3D. If not, disable it
	_controller = get_parent() as XRController3D
	if _controller == null:
		push_error("XRGrabber|FATAL: this node must be a child of an XRController3D")
		set_physics_process(false)
		return

	_controller.button_pressed.connect(_on_button_pressed)
	_controller.button_released.connect(_on_button_released)


func _on_button_pressed(action: String) -> void:
	if action == grab_action:
		_grab()


func _on_button_released(action: String) -> void:
	if action == grab_action:
		_release()


func _physics_process(delta: float) -> void:
	# Universal kilswitch for when no object is held
	if _held == null:
		return

	# Check to see if object was deleted since. Stops the hand from staying grabbed to a "ghost" object.
	if not is_instance_valid(_held):
		_held = null
		return

	# Move the held object to the grab point.
	_held.global_transform = global_transform * _grab_offset

	# Measure the velocity and start moving the target throw velocity to the current one.
	# Feel free to adjust the 0.4 to see how differnt values feel.
	var frame_velocity := (_held.global_position - _last_position) / delta
	_velocity = _velocity.lerp(frame_velocity, 0.4)
	_last_position = _held.global_position


func _grab() -> void:
	if _held != null:
		return

	var body := _nearest_body()
	if body == null:
		return

	_held = body

	# Freeze the body kinematically. Can still push others around but cannot experience gravity or similar.
	_held.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_held.freeze = true

	_grab_offset = global_transform.affine_inverse() * _held.global_transform
	_last_position = _held.global_position
	_velocity = Vector3.ZERO

	if haptics:
		_controller.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.1, 0.0)


func _release() -> void:
	if _held == null:
		return

	# Set the objects velocity to throw. Also unfreeze physics
	if is_instance_valid(_held):
		_held.freeze = false
		_held.linear_velocity = _velocity * throw_strength

	# Reset members for next grab
	_held = null
	_velocity = Vector3.ZERO


## Closest grabbable body currently inside the grab volume, or null.
func _nearest_body() -> RigidBody3D:
	var best: RigidBody3D = null
	var best_distance := INF

	for body in get_overlapping_bodies():
		var rigid := body as RigidBody3D

		# Skip anything that is not a loose physics object, and anything already
		# frozen -- that is almost always something your other hand is holding.
		if rigid == null or rigid.freeze:
			continue
		if required_group != "" and not rigid.is_in_group(required_group):
			continue

		# Compute if the given body is closer. distance_squared_to is faster and an acceptable
		# metric for this.
		var distance := global_position.distance_squared_to(rigid.global_position)
		if distance < best_distance:
			best_distance = distance
			best = rigid

	return best
