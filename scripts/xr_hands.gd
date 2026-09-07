## TEMPLATE FILE ############################
# Similar to xr_visuals.gd, this script enables a hand tracking preview for
# when controllers are asleep/not tracked. Generates a mesh on the fly from
# primitives.
#
# This script is by far the most complicated out of the starter scripts, so don't
# fret if it doesn't immediately make sense. Most of it boils down to generating
# and updating the primitives used in the preview. It *is* however beneficial to
# evnetually understand this file, as it contains useful examples of how to handle
# and manipulate instantiated primitives.
#############################################
extends Node3D
class_name XRHandVisuals

# OpenXR names for both hand "trackers" to find them ion the tracker registry
const HAND_TRACKERS: Array[StringName] = [
	&"/user/hand_tracker/left",
	&"/user/hand_tracker/right"
]

# What each raw index means, if you're interested:
# https://docs.godotengine.org/en/stable/classes/class_xrhandtracker.html
const WRIST := 1

const TRACKER_INDICES := [
	[2, 3, 4, 5],          # Thumb chain
	[6, 7, 8, 9, 10],      # Index chain
	[11, 12, 13, 14, 15],  # Middle chain
	[16, 17, 18, 19, 20],  # Ring chain
	[21, 22, 23, 24, 25],  # Pinky chain
]

# Below is the same table as above, but with the enum names instead of indexes
# this is useful for learning, but really long and clunky. Good to reference though, for other
# hand tracking purposes. Personally spent a good couple evenings learning hand anatomy lmao.
#const TRACKER_INDICES := [
#	[
#		XRHandTracker.HAND_JOINT_THUMB_METACARPAL,
#		XRHandTracker.HAND_JOINT_THUMB_PHALANX_PROXIMAL,
#		XRHandTracker.HAND_JOINT_THUMB_PHALANX_DISTAL,
#		XRHandTracker.HAND_JOINT_THUMB_TIP,
#	],
#	[
#		XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL,
#		XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL,
#		XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_INTERMEDIATE,
#		XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL,
#		XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP,
#	],
#	[
#		XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL,
#		XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL,
#		XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_INTERMEDIATE,
#		XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_DISTAL,
#		XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP,
#	],
#	[
#		XRHandTracker.HAND_JOINT_RING_FINGER_METACARPAL,
#		XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL,
#		XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_INTERMEDIATE,
#		XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_DISTAL,
#		XRHandTracker.HAND_JOINT_RING_FINGER_TIP,
#	],
#	[
#		XRHandTracker.HAND_JOINT_PINKY_FINGER_METACARPAL,
#		XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL,
#		XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_INTERMEDIATE,
#		XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_DISTAL,
#		XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP,
#	],
#]


## On for controller/hand, false for only controller.
@export var enabled := true:
	set = _set_enabled

@export_group("Hand appearance")
@export var FINGER_THICKNESS := 0.7 ## Thickness of the fingers. 0.7 default
@export var hand_color := Color(0.55, 0.78, 1.0, 0.35) ## keep alpha <1

## Add any offset needed for the hands here. Keep it zero likely
@export var hand_offset := Vector3.ZERO

var joint_scale := 1.0

var _hands: Array[Node3D] = []
var _spheres: Array = []
var _cylinders: Array = []


func _ready() -> void:
	# Prepare two hands
	for hand in HAND_TRACKERS.size():
		_build_hand()

	# Set status. If false, the node will not call its own _process function every frame.
	set_process(enabled)


func _process(_delta: float) -> void:
	# For each hand, we will update the hand's position if it is visible.
	for hand in _hands.size():
		var tracker := _find_tracker(hand)
		var root: Node3D = _hands[hand]

		# We will only show the hands if it is genuine hand tracking and not paused,
		# emulated, or otherwise not true optical hand tracking.
		root.visible = _actually_tracking(tracker)
		if root.visible:
			_update_hand(hand, tracker)


func _actually_tracking(tracker: XRHandTracker) -> bool:
	# If the tracker doesnt even exist or doesn't have current data, no hands.
	if tracker == null or not tracker.get_has_tracking_data():
		return false

	# Some headsets will return that they are hand tracking, when it is simply an emulation from controller
	# inputs. This prevents that and only allows true optical hand tracking like on the Q3.
	var source := tracker.get_hand_tracking_source()
	return (source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
		and source != XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED)


func _update_hand(hand: int, tracker: XRHandTracker) -> void:
	var joints: Array = _spheres[hand]

	# Ensure coordinates are in the right space.
	var reference := XRServer.get_reference_frame()
	var world_scale := XRServer.world_scale
	var offset := hand_offset

	# Every joint gets a sphere sat right on top of it. The runtime tells us how thick
	# each joint is, so big hands and small hands both come out looking correct.
	for joint in XRHandTracker.HAND_JOINT_MAX:
		var sphere: MeshInstance3D = joints[joint]
		sphere.position = reference * (tracker.get_hand_joint_transform(joint).origin * world_scale) + offset
		sphere.scale = Vector3.ONE * tracker.get_hand_joint_radius(joint) * world_scale * joint_scale

	# Now the cylinders that bridge the gaps between those spheres. Each entry we
	# built earlier is [the cylinder, the joint it starts at, the joint it ends at].
	for bone in _cylinders[hand]:
		var cylinder: MeshInstance3D = bone[0]
		var from: Vector3 = reference * (tracker.get_hand_joint_transform(bone[1]).origin * world_scale) + offset
		var to: Vector3 = reference * (tracker.get_hand_joint_transform(bone[2]).origin * world_scale) + offset

		# The vector running from one joint to the other tells us everything we need.
		var along := to - from
		var length := along.length()

		# Division by zero protection
		cylinder.visible = length > 0.0001
		if not cylinder.visible:
			continue

		# We take the thickness from the far joint, which is what makes the fingers
		# taper as they go out towards the tips.
		var radius := tracker.get_hand_joint_radius(bone[2]) * world_scale * joint_scale * FINGER_THICKNESS

		# Place the cylinder in the middle/average position. They extend out on both ends.
		cylinder.position = from + along * 0.5

		# Rotate the cylinder off UP and onto a normalized version of our bone.
		# Quaterions are complicated. irritably so. Good to learn about them though,
		cylinder.quaternion = Quaternion(Vector3.UP, along / length)

		# Both meshes were built one unit big back in _build_hand, so here the scale
		# simply *is* the size we want.
		cylinder.scale = Vector3(radius, length, radius) # y is the length, x and z the width


func _find_tracker(hand_idx: int) -> XRHandTracker:
	return XRServer.get_tracker(HAND_TRACKERS[hand_idx]) as XRHandTracker


func _build_hand() -> void:
	# We'll start by building the material we use for hands.
	var material := StandardMaterial3D.new()
	material.albedo_color = hand_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.5

	# Mesh for all spheres in the hand.
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	sphere_mesh.radial_segments = 8 # resolution of the mesh
	sphere_mesh.rings = 4			# also resolution of the mesh
	sphere_mesh.material = material

	# Mesh for all cylinders in the hand.
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = 1.0
	cylinder_mesh.bottom_radius = 1.0
	cylinder_mesh.height = 1.0
	cylinder_mesh.radial_segments = 6
	cylinder_mesh.rings = 0
	cylinder_mesh.material = material

	var root := Node3D.new()
	root.name = "Hand%d" % _hands.size() # first hand will be hand0, and second hand1
	root.visible = false
	add_child(root) # add the generated node as a child of self (XRHands)

	# First we create all of the joints (spheres)
	var spheres: Array = []
	for joint in XRHandTracker.HAND_JOINT_MAX:
		spheres.append(_add_mesh(root, sphere_mesh))

	# Here we add all the cylinders between joints.
	var cylinders: Array = []
	for chain in TRACKER_INDICES:
		cylinders.append([_add_mesh(root, cylinder_mesh), WRIST, chain[0]])
		for link in chain.size() - 1:
			cylinders.append([_add_mesh(root, cylinder_mesh), chain[link], chain[link + 1]])

	# Finally, add everything generated to the class's members.
	_hands.append(root)
	_spheres.append(spheres)
	_cylinders.append(cylinders)


func _add_mesh(root: Node3D, mesh: Mesh) -> MeshInstance3D:
	# Instantiate a new MeshInstance3D node
	var instance := MeshInstance3D.new()

	# We assign the desired mesh here, and turn off shadows. (We don't want the hand to
	# cast shadows)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Finally, add the mesh as a child to root, and return the created instance.
	root.add_child(instance)
	return instance


func _set_enabled(value: bool) -> void:
	enabled = value
	set_process(value and not _hands.is_empty())

	if not value:
		for hand: Node3D in _hands:
			hand.visible = false
