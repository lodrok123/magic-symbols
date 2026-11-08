class_name EfectoToy
extends EfectoVfx3D

## EFECTO DE FUEGO «TOY» (prueba 3 de VFX, 1/11/2026, docs/PRUEBA3_VFX_TOY_2026-11-01.md). Extiende el contrato EfectoVfx3D (preparar / lanzar / morir) y
## reúne en el raíz los DIEZ MANDOS que más cambian el aspecto, con rango y en castellano, para tocarlos en el inspector sin abrir código:
##   altura · ancho · blandura · ondulacion · velocidad · brillo · halo · tono (0 fuego, 1 azul) · chispas (proporción) · luz (energía de la luz)
## Cada instancia duplica sus materiales al nacer, así que mover un mando en una no cambia las demás.
## Otros ajustes (no son de los diez): `vida` (s que dura el efecto cuando se lanza con vida ≤ 0 desde el inspector), `aparicion` (0 apagado, 1 pleno;
## lo anima el AnimationPlayer en «nacer» y «morir»; no hace falta tocarlo).

@export_group("Los diez mandos")
@export_range(0.3, 3.0, 0.05) var altura: float = 1.0: set = _set_altura
@export_range(0.0, 1.0, 0.05) var chisporroteo: float = 0.6: set = _set_chisporroteo
@export_range(0.05, 1.0, 0.01) var blandura: float = 0.22: set = _set_blandura
@export_range(0.0, 1.5, 0.05) var ondulacion: float = 0.6: set = _set_ondulacion
@export_range(0.1, 4.0, 0.05) var velocidad: float = 1.0: set = _set_velocidad
@export_range(0.3, 3.0, 0.05) var brillo: float = 1.0: set = _set_brillo
@export_range(0.0, 3.0, 0.05) var halo: float = 1.0: set = _set_halo
@export_range(0.0, 1.0, 0.05) var tono: float = 0.0: set = _set_tono
@export_range(0.0, 1.0, 0.05) var chispas: float = 1.0: set = _set_chispas
@export_range(0.0, 4.0, 0.05) var luz: float = 1.0: set = _set_luz
@export_group("Otros")
@export_range(0.3, 2.0, 0.05) var ancho: float = 1.0: set = _set_ancho
@export_range(0.0, 1.0, 0.01) var aparicion: float = 1.0: set = _set_aparicion
@export var vida: float = -1.0
## Modo proyectil (bola): suelta la estela corta mientras vuela.
@export var proyectil: bool = false: set = _set_proyectil
@export var titileo: float = 0.10

var _listo: bool = false
var _vuelo_part: Array = []
var _mats: Array[ShaderMaterial] = []
var _halos: Array[ShaderMaterial] = []
var _luz: OmniLight3D = null
var _luz_base: float = 1.0
var _cuerpo: Node3D = null
var _mats_ero: Array[ShaderMaterial] = []     ## los de _mats cuyo shader trae erosion (uniform ero_inicio): la muerte sin choque les mueve "vida" y nada mas
var _t: float = 0.0
var _fase: float = 0.0
## Cuánto se adelanta la cabeza de la bola en vuelo (m, por -Z). FuegoToy lo escala con el tamaño de la bola.
var _avance_cabeza: float = -0.12


func _ready() -> void:
	super._ready()
	_fase = randf() * 100.0
	_recoger()


## Recoge los materiales, las partículas y la luz del árbol (al nacer; FuegoToy lo repite cuando reconstruye su geometría).
func _recoger() -> void:
	_listo = false
	_cuerpo = get_node_or_null("Cuerpo") as Node3D
	_mats.clear()
	_halos.clear()
	_mats_ero.clear()
	for n in find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = n
		var m: ShaderMaterial = g.material_override as ShaderMaterial
		if m == null:
			continue
		m = m.duplicate() as ShaderMaterial      # cada instancia lleva los suyos
		g.material_override = m
		var pasada: ShaderMaterial = m.next_pass as ShaderMaterial
		if pasada != null:
			m.next_pass = pasada.duplicate() as ShaderMaterial
		if m.shader != null and m.shader.resource_path.get_file() == "halo_toy.gdshader":
			_halos.append(m)
		else:
			_mats.append(m)
			if m.next_pass is ShaderMaterial:
				_mats.append(m.next_pass as ShaderMaterial)
	for m2 in _mats:
		if m2.shader != null:
			for u in m2.shader.get_shader_uniform_list():
				if u["name"] == "ero_inicio":
					_mats_ero.append(m2)
					break
	_vuelo_part.clear()
	for gp in find_children("*", "GPUParticles3D", true, false):
		if (gp as Node).is_in_group("vuelo"):
			var g3: GPUParticles3D = gp
			var mesh: QuadMesh = g3.draw_pass_1 as QuadMesh      # solo la primera pasada (no se lee draw_pass_2: con una sola pasada da error de índice)
			if mesh != null and mesh.material is ShaderMaterial:
				var dup: QuadMesh = mesh.duplicate() as QuadMesh
				dup.material = (mesh.material as ShaderMaterial).duplicate() as ShaderMaterial     # cada instancia, el suyo
				g3.draw_pass_1 = dup
			_vuelo_part.append(g3)
	_luz = find_child("Luz", true, false) as OmniLight3D
	if _luz != null:
		_luz_base = _luz.light_energy
	_listo = true
	_aplicar_todo()


func _process(delta: float) -> void:
	super._process(delta)
	if proyectil and _listo:
		for gp in _vuelo_part:
			for pase in [gp.draw_pass_1]:
				var sm: ShaderMaterial = (pase as QuadMesh).material as ShaderMaterial
				if sm != null:
					sm.set_shader_parameter("vel_dir", -global_transform.basis.z)
		for m in _mats:
			if m.shader != null and m.shader.resource_path.get_file() == "fuego_lelu_bola.gdshader":
				m.set_shader_parameter("vel_dir", -global_transform.basis.z)
	if _listo:
		var est: Node3D = get_node_or_null("Cuerpo/Frente/Estrella") as Node3D
		if est != null:
			var pe: float = 1.0 + 0.1 * chisporroteo * (sin(_t * 17.0 + _fase) * 0.6 + sin(_t * 26.0) * 0.4)
			est.scale = Vector3(pe, pe, pe)             # titileo leve del destello
	if _luz != null and _listo:
		_t += delta
		var f: float = 1.0 + titileo * (sin(_t * 6.1 + _fase) * 0.6 + sin(_t * 10.7 + _fase * 2.0) * 0.4)
		f += 0.12 * chisporroteo * (sin(_t * 58.0 + _fase * 3.0) * 0.6 + sin(_t * 87.0 + _fase) * 0.4)   # crepitar: 9-14 Hz, irregular
		_luz.light_energy = _luz_base * luz * f * aparicion


func lanzar(v: float = -1.0) -> void:
	super.lanzar(v if v > 0.0 or vida <= 0.0 else vida)


func _aplicar_todo() -> void:
	if not _listo:
		return
	_param_mats("altura", altura)
	_param_mats("ancho", ancho)
	_set_chisporroteo(chisporroteo)
	_param_mats("blandura", blandura)
	_param_mats("ondulacion", ondulacion)
	_param_mats("velocidad", velocidad)
	_param_mats("brillo", brillo)
	_param_mats("tono", tono)
	_set_halo(halo)
	for h in _halos:
		h.set_shader_parameter("tono", tono)
	_set_chispas(chispas)
	_set_aparicion(aparicion)
	var est0: Node3D = get_node_or_null("Cuerpo/Frente/Estrella") as Node3D
	if est0 != null:
		est0.visible = proyectil                             # en estática, sin destello de 4 puntas (ronda 8)


func _param_mats(nombre: String, v: float) -> void:
	if not _listo:
		return
	for m in _mats:
		m.set_shader_parameter(nombre, v)


func _set_altura(v: float) -> void:
	altura = v
	_param_mats("altura", v)


func _set_ancho(v: float) -> void:
	ancho = v
	_param_mats("ancho", v)


func _set_blandura(v: float) -> void:
	blandura = v
	_param_mats("blandura", v)


func _set_ondulacion(v: float) -> void:
	ondulacion = v
	_param_mats("ondulacion", v)


func _set_velocidad(v: float) -> void:
	velocidad = v
	_param_mats("velocidad", v)


func _set_brillo(v: float) -> void:
	brillo = v
	_param_mats("brillo", v)


func _set_tono(v: float) -> void:
	tono = v
	_param_mats("tono", v)
	if _listo:
		for h in _halos:
			h.set_shader_parameter("tono", v)


func _set_halo(v: float) -> void:
	halo = v
	if _listo:
		for h in _halos:
			var base: float = float(h.get_meta("brillo_base", -1.0))
			if base < 0.0:
				base = float(h.get_shader_parameter("brillo"))
				h.set_meta("brillo_base", base)
			h.set_shader_parameter("brillo", base * v)


func _set_chispas(v: float) -> void:
	chispas = v
	if _listo:
		for gp in find_children("*", "GPUParticles3D", true, false):
			(gp as GPUParticles3D).amount_ratio = clampf(v, 0.0, 1.0)


func _set_chisporroteo(v: float) -> void:
	chisporroteo = v
	_param_mats("chisporroteo", v)
	if _listo:
		for gp in find_children("*", "GPUParticles3D", true, false):
			if (gp as Node).is_in_group("trocitos"):
				(gp as GPUParticles3D).amount_ratio = clampf(v, 0.0, 1.0)
				(gp as GPUParticles3D).emitting = v > 0.01


func _set_luz(v: float) -> void:
	luz = v


## Mueve SOLO "vida" de los materiales con erosion (1 = entero, 0 = comido), sin tocar "aparicion" ni la escala del cuerpo: lo usa la muerte sin choque (APAGANDO), que ya encoge la bola por su cuenta con _c_escala.
## Con la erosion global apagada no hace nada (en esos shaders "vida" bajaria el alfa y cambiaria la silueta).
func _vida_erosion(v: float) -> void:
	if not _listo or not VfxKit3D.usar_erosion:
		return
	for m in _mats_ero:
		m.set_shader_parameter("vida", v)


func _set_aparicion(v: float) -> void:
	aparicion = v
	if not _listo:
		return
	_param_mats("vida", v)
	for h in _halos:
		h.set_shader_parameter("vida", v)
	if _cuerpo != null:
		_cuerpo.scale = Vector3(lerpf(0.65, 1.0, v), lerpf(0.15, 1.0, v), lerpf(0.65, 1.0, v))


func _set_proyectil(v: bool) -> void:
	proyectil = v
	if _listo:
		for gp in find_children("*", "GPUParticles3D", true, false):
			if (gp as Node).is_in_group("vuelo"):
				(gp as GPUParticles3D).emitting = v          # jirones y chispas con estela: solo en vuelo
		for gp in find_children("*", "GPUParticles3D", true, false):
			if (gp as Node).is_in_group("estela"):
				(gp as GPUParticles3D).emitting = v
		for mi in find_children("*", "MeshInstance3D", true, false):
			if (mi as Node).is_in_group("estela_malla"):
				(mi as Node3D).visible = v                       # estela corta de la ronda 3 (malla con la textura de lenguas)
		for m in _mats:
			if m.shader != null and m.shader.resource_path.get_file() == "fuego_lelu_bola.gdshader":
				m.set_shader_parameter("inclin", 1.0 if v else 0.0)       # billboard de la bola: el eje de la llama sigue a la velocidad
		var fre: Node3D = get_node_or_null("Cuerpo/Frente") as Node3D
		if fre != null:
			fre.position.z = _avance_cabeza if v else 0.0             # la cabeza va delante en vuelo (poco: la cola tiene que arrancar dentro de ella)
		var est: Node3D = get_node_or_null("Cuerpo/Frente/Estrella") as Node3D
		if est != null:
			est.visible = v                                  # destello de 4 puntas solo en vuelo
		var inc: Node3D = get_node_or_null("Cuerpo/Inclinable") as Node3D
		if inc != null:
			inc.rotation_degrees.x = 55.0 if v else 0.0       # en vuelo, la llama se inclina hacia atrás
