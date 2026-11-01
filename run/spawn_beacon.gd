class_name SpawnBeacon
extends Node3D
## Свечение места появления врага (№87): кольцо на полу и столб света, который разгорается к концу ожидания. Показывает игроку, где
## сейчас встанет враг, пока тот ещё скрыт. В момент появления вспыхивает и гаснет (burst). Рисуется кодом, ассетов нет.

const COLOR: Color = Color(1.0, 0.45, 0.12)
const RING_RADIUS: float = 0.9
const BEAM_WIDTH: float = 0.16
## Столб не ниже этой высоты (метры над полом), даже если враг стоит на земле.
const MIN_BEAM_HEIGHT: float = 1.8
const BURST_TIME: float = 0.3

var _duration: float = 1.0
var _age: float = 0.0
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _ring_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _bursting: bool = false


## Ставит свечение на пол в точке ground. height: на какой высоте над полом встанет враг (летающие), duration: сколько светится до
## появления.
static func spawn(parent: Node, ground: Vector3, height: float, duration: float) -> SpawnBeacon:
	var beacon: SpawnBeacon = SpawnBeacon.new()
	beacon._duration = maxf(duration, 0.05)
	parent.add_child(beacon)
	beacon.global_position = ground
	beacon._build(maxf(height, MIN_BEAM_HEIGHT))
	return beacon


func _build(beam_height: float) -> void:
	_ring_material = _glow_material(0.8)
	_beam_material = _glow_material(0.3)
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = RING_RADIUS
	ring_mesh.bottom_radius = RING_RADIUS
	ring_mesh.height = 0.06
	ring_mesh.material = _ring_material
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0.0, 0.05, 0.0)
	add_child(_ring)
	var beam_mesh: BoxMesh = BoxMesh.new()
	beam_mesh.size = Vector3(BEAM_WIDTH, beam_height, BEAM_WIDTH)
	beam_mesh.material = _beam_material
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.position = Vector3(0.0, beam_height * 0.5, 0.0)
	add_child(_beam)


# Светящийся (без освещения, со сложением цветов) полупрозрачный материал.
func _glow_material(alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, alpha)
	return material


func _process(delta: float) -> void:
	_age += delta
	if _bursting:
		var burst: float = clampf(_age / BURST_TIME, 0.0, 1.0)
		_ring.scale = Vector3.ONE * lerpf(1.0, 2.6, burst)
		_ring_material.albedo_color.a = lerpf(0.9, 0.0, burst)
		_beam_material.albedo_color.a = lerpf(0.8, 0.0, burst)
		_beam.scale = Vector3(lerpf(1.0, 3.0, burst), 1.0, lerpf(1.0, 3.0, burst))
		if burst >= 1.0:
			queue_free()
		return
	# К концу ожидания кольцо сжимается, мигает чаще, столб ярче: сигнал «сейчас появится».
	var phase: float = clampf(_age / _duration, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * lerpf(6.0, 20.0, phase))
	_ring.scale = Vector3.ONE * lerpf(1.35, 0.85, phase)
	_ring_material.albedo_color.a = lerpf(0.35, 0.95, phase) * lerpf(0.65, 1.0, pulse)
	_beam_material.albedo_color.a = lerpf(0.12, 0.6, phase) * lerpf(0.7, 1.0, pulse)


## Враг появился: свечение вспыхивает и гаснет само.
func burst() -> void:
	_bursting = true
	_age = 0.0
