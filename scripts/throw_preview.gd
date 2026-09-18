extends Node3D


@onready var arc: MeshInstance3D = $Arc
@onready var landing_ring: MeshInstance3D = $LandingRing

@export var arc_color: Color = Color(1.0, 1.0, 1.0, 0.8)

var _arc_mesh := ImmediateMesh.new()
var _arc_material := StandardMaterial3D.new()


func _ready() -> void:
	arc.mesh = _arc_mesh

	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_material.albedo_color = arc_color

	hide_preview()


func show_preview(points: PackedVector3Array) -> void:
	if points.size() < 2:
		hide_preview()
		return

	visible = true
	arc.visible = true
	landing_ring.visible = true

	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(
		Mesh.PRIMITIVE_LINE_STRIP,
		_arc_material
	)

	for point in points:
		_arc_mesh.surface_add_vertex(
			arc.to_local(point)
		)

	_arc_mesh.surface_end()

	landing_ring.global_position = points[points.size() - 1]


func hide_preview() -> void:
	_arc_mesh.clear_surfaces()

	arc.visible = false
	landing_ring.visible = false
	visible = false
