class_name BlastEffect
extends Node3D
## Вспышка взрыва (№91): расширяющаяся светящаяся сфера цвета бочки, гаснет и удаляется сама. Только оформление.

const DURATION: float = 0.45
const START_SCALE: float = 0.15

var _radius: float = 1.0
var _color: Color = Color.WHITE


static func spawn(parent: Node, at: Vector3, radius: float, color: Color) -> BlastEffect:
	if parent == null or not parent.is_inside_tree():
		return null
	var effect: BlastEffect = BlastEffect.new()
	effect._radius = radius
	effect._color = color
	parent.add_child(effect)
	effect.global_position = at
	return effect


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(_color.r, _color.g, _color.b, 0.7)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.material = material
	var sphere: MeshInstance3D = MeshInstance3D.new()
	sphere.mesh = mesh
	sphere.scale = Vector3.ONE * _radius * START_SCALE
	add_child(sphere)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 3.0
	light.omni_range = _radius * 1.5
	light.shadow_enabled = false
	add_child(light)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(sphere, "scale", Vector3.ONE * _radius, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(material, "albedo_color:a", 0.0, DURATION)
	tween.tween_property(light, "light_energy", 0.0, DURATION)
	tween.chain().tween_callback(queue_free)
