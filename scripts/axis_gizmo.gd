# axis_gizmo.gd (Godot 4.4.1)
extends Node3D

@export var axis_length: float = 0.6
@export var axis_thickness: float = 0.03
@export var head_length: float = 0.12
@export var head_radius: float = 0.06
@export var unshaded: bool = true

func _ready() -> void:
	_make_axis(Vector3(1, 0, 0), Color(1, 0, 0)) # X (red)
	_make_axis(Vector3(0, 1, 0), Color(0, 1, 0)) # Y (green)
	_make_axis(Vector3(0, 0, 1), Color(0, 0, 1)) # Z (blue)

func _make_axis(dir: Vector3, col: Color) -> void:
	# ---- shaft (cylinder) ----
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = axis_thickness
	cyl.bottom_radius = axis_thickness
	cyl.height = axis_length
	cyl.radial_segments = 12
	shaft.mesh = cyl
	shaft.material_override = _mat(col)

	if dir == Vector3(1, 0, 0): # X
		shaft.transform.basis = Basis(Vector3(0, 0, 1), -PI/2)
		shaft.position = Vector3(axis_length * 0.5, 0, 0)
	elif dir == Vector3(0, 1, 0): # Y (default orientation)
		shaft.position = Vector3(0, axis_length * 0.5, 0)
	else: # Z
		shaft.transform.basis = Basis(Vector3(1, 0, 0), PI/2)
		shaft.position = Vector3(0, 0, axis_length * 0.5)
	add_child(shaft)

	# ---- head (use CylinderMesh as a cone by setting top_radius=0) ----
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0                 # makes it a cone
	head_mesh.bottom_radius = head_radius
	head_mesh.height = head_length
	head_mesh.radial_segments = 12
	head.mesh = head_mesh
	head.material_override = _mat(col)

	if dir == Vector3(1, 0, 0): # X
		head.transform.basis = Basis(Vector3(0, 0, 1), -PI/2)
		head.position = Vector3(axis_length, 0, 0)
	elif dir == Vector3(0, 1, 0): # Y
		head.position = Vector3(0, axis_length, 0)
	else: # Z
		head.transform.basis = Basis(Vector3(1, 0, 0), PI/2)
		head.position = Vector3(0, 0, axis_length)
	add_child(head)

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_receive_shadows = true
	return m
