extends Area3D
class_name DepthZone

# We no longer use a depth value or a bottom node.
# The bottom comes from the first CollisionShape3D child (Box/Cylinder).
# Assumption: zone is upright (no tilt), so its local +Y is world up.

# Optional: if you still want to override via a node later, keep this flag.
@export var allow_bottom_override: bool = false
@export var bottom_node_path: NodePath = NodePath("")

func get_bottom_y(surface_y: float) -> float:
	# 1) Optional override by node (kept for flexibility)
	if allow_bottom_override:
		var n: Node3D = get_node_or_null(bottom_node_path) as Node3D
		if n != null:
			var by: float = n.global_position.y
			if by > surface_y:
				by = surface_y
			return by

	# 2) Read from the first CollisionShape3D child
	var cs: CollisionShape3D = _find_first_collision_shape()
	if cs == null:
		# fallback: do not change anything, return surface_y (shallow)
		return surface_y

	var by: float = _compute_shape_bottom_y(cs)
	# safety: never above the water surface
	if by > surface_y:
		by = surface_y
	return by


# --- helpers ---

func _find_first_collision_shape() -> CollisionShape3D:
	var i: int = 0
	var n: int = get_child_count()
	while i < n:
		var c: Node = get_child(i)
		if c is CollisionShape3D:
			return c as CollisionShape3D
		i += 1
	return null

func _compute_shape_bottom_y(cs: CollisionShape3D) -> float:
	# Assumptions:
	# - zone is upright (no tilt), so "down" is along -Y in world.
	# - we support BoxShape3D and CylinderShape3D (most common).
	# - if scaled, we read the node's world scale to compute half-height.

	var gt: Transform3D = cs.global_transform
	var world_scale: Vector3 = gt.basis.get_scale()
	var center_y: float = gt.origin.y

	var shape := cs.shape
	if shape == null:
		return center_y

	# BOX
	if shape is BoxShape3D:
		var s: Vector3 = (shape as BoxShape3D).size
		# size is full extents in local space; half-height in local Y is s.y * 0.5
		var half_h: float = absf(world_scale.y) * s.y * 0.5
		return center_y - half_h

	# CYLINDER
	if shape is CylinderShape3D:
		var h: float = (shape as CylinderShape3D).height
		var half_h2: float = absf(world_scale.y) * h * 0.5
		return center_y - half_h2

	# Unknown shape: best-effort fallback (treat like a 2m half-height)
	return center_y - 1.0
