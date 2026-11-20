@tool
extends Node3D

const MAESTRE := preload("res://arte/modelos/marimanta.glb")
const ADULTO := preload("res://arte/modelos/goblin_warrior_chibi.glb")
const APRENDIZ := preload("res://arte/modelos/goblin_archer_chibi.glb")
const CACO := preload("res://arte/modelos/goblin_base.glb")
# 20/11: Doña Comba, diseño de Pablo para la tendera de Monte Sumicio; misma familia goblin y mismos clips.
const TENDERA := preload("res://arte/modelos/dona_comba.glb")
const ANCIANO := preload("res://arte/modelos/anciano_sumicio.glb")
const RECOLECTOR := preload("res://arte/modelos/wanderer_sumicio.glb")
const MIRA := preload("res://arte/modelos/mira_sumicio.glb")
const IRIA := preload("res://arte/modelos/iria_sumicio.glb")
const MOSSCAP := preload("res://arte/modelos/mosscap_sumicio.glb")
const GRUBWICK := preload("res://arte/modelos/grubwick_sumicio.glb")
const GRUMBLETWIG := preload("res://arte/modelos/grumbletwig_sumicio.glb")
const FOREST_WITCH := preload("res://arte/modelos/forest_witch_sumicio.glb")
const TINTE := preload("res://presentacion/ropa_sumiciu.gdshader")

const OFICIO_TENDERA := 4
const OFICIO_ANCIANO := 5
const OFICIO_RECOLECTOR := 6
const OFICIO_ESCRIBA := 7
const OFICIO_PANADERA := 8
const OFICIO_MOSSCAP := 9
const OFICIO_TEJEDOR := 10
const OFICIO_GRUMBLETWIG := 11
const OFICIO_FOREST_WITCH := 12

@export_enum("Vecino", "Aprendiz", "Gorro verde", "Maestre", "Tendera", "Anciano", "Recolector", "Escriba", "Panadera", "Aprendiz Mosscap", "Tejedor", "Aprendiz Grumbletwig", "Aprendiz Forest Witch") var oficio: int = 0:
	set(valor):
		oficio = valor
		_actualizar_en_editor()
@export_range(0.6, 1.4, 0.01) var estatura := 1.06:
	set(valor):
		estatura = valor
		_actualizar_en_editor()
@export var ropa := Color.WHITE:
	set(valor):
		ropa = valor
		_actualizar_en_editor()
@export var nombre_visible := ""

var _modelo: Node3D
var _animador: AnimationPlayer
var _reposo: StringName
var _rutina: StringName
var _espera_rutina := 0.0


func _ready() -> void:
	set_process(false)
	_montar()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _animador.assigned_animation != _reposo:
		return
	_espera_rutina -= delta
	if _espera_rutina <= 0.0:
		_animador.play(_rutina, 0.2)


func _actualizar_en_editor() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		_montar()


func _montar() -> void:
	if is_instance_valid(_modelo):
		_modelo.free()
	_montar_modelo()
	if not nombre_visible.is_empty() and not has_node("Nombre"):
		var rotulo := Label3D.new()
		rotulo.name = "Nombre"
		rotulo.text = nombre_visible
		rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rotulo.position.y = estatura + 0.34
		rotulo.pixel_size = 0.012
		add_child(rotulo)


func _montar_modelo() -> void:
	if oficio == 3 and not Engine.is_editor_hint():
		var maestre := Pj3D.new()
		maestre.name = "Modelo"
		add_child(maestre)
		if maestre.cargar("marimanta"):
			maestre.set_alto(estatura)
			_modelo = maestre
			return
		maestre.free()
	var fuentes := [ADULTO, APRENDIZ, CACO, MAESTRE, TENDERA, ANCIANO, RECOLECTOR, MIRA, IRIA, MOSSCAP, GRUBWICK, GRUMBLETWIG, FOREST_WITCH]
	var reposos := [&"Idle002", &"Idle002", &"idle", &"Idle_02", &"idle", &"idle", &"recolectar", &"escribir", &"amasar", &"idle", &"tejer", &"idle", &"idle_mixamo"]
	var alturas := [1.7, 1.7, 0.978089, 1.7, 0.950196, 0.950684, 0.952148, 0.95166, 0.95166, 0.95166, 0.951172, 0.952148, 0.950684]
	_modelo = fuentes[oficio].instantiate()
	_modelo.name = "Modelo"
	_modelo.scale = Vector3.ONE * estatura / alturas[oficio]
	add_child(_modelo)
	if oficio != 3 and (oficio in [1, 2] or ropa != Color.WHITE):
		_vestir()
	var editor := Engine.is_editor_hint()
	if editor and oficio not in [OFICIO_RECOLECTOR, OFICIO_ESCRIBA, OFICIO_PANADERA, OFICIO_TEJEDOR, OFICIO_GRUMBLETWIG, OFICIO_FOREST_WITCH]:
		return
	var reproductores := _modelo.find_children("*", "AnimationPlayer", true, false)
	if reproductores.is_empty():
		return
	_animador = reproductores[0] as AnimationPlayer
	_reposo = reposos[oficio]
	if oficio in [OFICIO_TENDERA, OFICIO_ANCIANO]:
		_rutina = &"atender_mostrador" if oficio == OFICIO_TENDERA else &"rezar"
		_espera_rutina = randf_range(5.0, 9.0)
		_animador.animation_finished.connect(_volver_al_reposo)
		set_process(_animador.has_animation(_rutina))
	elif oficio == OFICIO_PANADERA and not editor:
		_animador.animation_finished.connect(_volver_al_reposo)
	andar(false)
	_animador.advance(0.0)
	if editor:
		_animador.pause()
	elif oficio == OFICIO_ESCRIBA:
		_montar_pluma()


func _montar_pluma() -> void:
	var esqueleto := _modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mano := esqueleto.find_bone("mixamorig_RightHand")
	var indice := esqueleto.find_bone("mixamorig_RightHandIndex1")
	esqueleto.force_update_all_bone_transforms()
	var palma := esqueleto.get_bone_global_pose(mano)
	var nudillo := esqueleto.get_bone_global_pose(indice).origin
	var punta := palma.origin.lerp(nudillo, 0.95) + Vector3(0.0, -0.025, 0.031)
	var eje := Quaternion(Vector3.UP, Vector3(0.22, 1.0, 0.55).normalized())
	var agarre := BoneAttachment3D.new()
	agarre.bone_idx = mano
	esqueleto.add_child(agarre)
	var pluma := Equipo3D._pluma()
	agarre.add_child(pluma)
	pluma.transform = palma.affine_inverse() * Transform3D(Basis(eje), punta)


func andar(en_marcha: bool) -> void:
	if _animador == null:
		return
	var marcha := &"walk" if oficio in [OFICIO_TENDERA, OFICIO_ANCIANO, OFICIO_MOSSCAP] else &"Walking"
	var clip := marcha if en_marcha else _reposo
	if _animador.assigned_animation != clip and _animador.has_animation(clip):
		if _animador.assigned_animation == &"hablar":
			_animador.process_mode = Node.PROCESS_MODE_INHERIT
		_animador.play(clip, 0.14)


func hablar() -> void:
	if oficio not in [OFICIO_TENDERA, OFICIO_ANCIANO, OFICIO_PANADERA] or _animador == null:
		return
	if oficio == OFICIO_TENDERA:
		# El diálogo puede abrir la tienda, que pone el juego en pausa.
		_animador.process_mode = Node.PROCESS_MODE_ALWAYS
	_animador.play(&"hablar", 0.14)


func _volver_al_reposo(clip: StringName) -> void:
	if clip == &"hablar" or clip == _rutina:
		_espera_rutina = randf_range(12.0, 20.0)
		andar(false)


func _vestir() -> void:
	for malla: MeshInstance3D in _modelo.find_children("*", "MeshInstance3D", true, false):
		var base := malla.get_active_material(0) as StandardMaterial3D
		if base == null or base.albedo_texture == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = TINTE
		material.set_shader_parameter("tono_ropa", ropa)
		material.set_shader_parameter("textura", base.albedo_texture)
		material.set_shader_parameter("caja", Vector2(malla.mesh.get_aabb().position.y, malla.mesh.get_aabb().size.y))
		material.set_shader_parameter("normal_mapa", base.normal_texture)
		material.set_shader_parameter("usar_normal", base.normal_enabled and base.normal_texture != null)
		material.set_shader_parameter("gorro", Color("#b13845") if oficio == 1 else Color("#4c8b4e"))
		material.set_shader_parameter("tenir_gorro", oficio in [1, 2])
		malla.set_surface_override_material(0, material)
