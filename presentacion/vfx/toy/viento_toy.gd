class_name VientoToy
extends EfectoToy

## VIENTO «TOY» (6/11/2026; docs/PLAN_VFX_ELEMENTOS.md §2.6, docs/HUMO_TOON_2026-11-06.md). Clase HERMANA de FuegoToy, AguaToy, HieloToy y RayoToy: misma API, mismas cinco figuras (BOLA, MURO,
## PILAR, BARRERA, HAZ), mismos ejes (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy) y los mismos diez mandos de EfectoToy (valen `velocidad`, `chispas` =
## cuántas hojas y jirones, `altura` y `ancho`; luz, halo, tono, brillo y blandura no hacen nada: el viento no brilla). La máquina de carga e impacto está copiada de HieloToy, no compartida.
## CARÁCTER: el viento «se ve por lo que mueve» (casi sin color, Vfx3D.COLOR["viento"] ≈ 0,75·0,97·0,85): JIRONES de humo toon muy pálidos y finos (humo_toy.gd + humo_toon.gdshader: dos tonos
## planos, borde duro, erosión al morir), alargados en la dirección del viento, más las CINTAS en espiral (`remolino` de Formas3D, la misma pieza que vfx_3d.gd usa en «remolino_viento») y HOJAS
## (`hoja` de Formas3D) arrastradas. Sin luz, sin aditivos, sin GPUParticles3D: todo son MultiMesh movidos por la CPU.
## FIGURAS: BOLA = ráfaga: núcleo casi invisible de jirones alargados con 2-3 cintas en espiral y hojas; en vuelo deja una estela corta de jirones que se erosionan. MURO = cortina de jirones
## ascendentes a lo largo de x. PILAR = torbellino (discos de remolino apilados que giran alternos + hojas en espiral, como vfx_3d.gd). BARRERA = anillo de jirones girando sobre la elipse del suelo.
## HAZ = chorro de jirones hacia -Z desde la mano.
## Ciclo de vida de un proyectil de viento, sobre UN SOLO nodo (igual que las hermanas):
##   empezar_carga(duracion, tam_final)  jirones y hojas que CONVERGEN en la mano mientras la ráfaga crece; dos cintas giran alrededor. NO hace falta `lanzar()`.
##   progreso_carga() -> float           0 → 1 (se queda en 1 al sostener y tras soltar)
##   soltar(dir)                         ESE MISMO nodo pasa a proyectil apuntando a `dir` (estela de jirones)
##   cancelar_carga()                    se deshace en T_CANCELAR s y se libera
##   impactar_en(pos, normal, escala)    ImpactoVientoToy GOLPE orientado por la normal: soplo radial de jirones a ras de la superficie + hojas, sin destello
##   rebotar(pos, normal) -> Vector3     soplo pequeño; la ráfaga SIGUE; devuelve la dirección reflejada
##   terminar_sin_choque()               se agota en el aire: los jirones se dispersan (variante FIN)
##   finalizar(motivo, pos, normal)      atajo para HechizoVivo._terminar(causa)

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const CorrientesViento = preload("res://presentacion/vfx/toy/viento_corrientes.gd")
static var prueba_corrientes: bool = OS.get_cmdline_user_args().has("viento-concepto") or bool(
	ProjectSettings.get_setting("magic_symbols/vfx_viento_revisado", true))

const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)

## Paleta del viento: la del elemento en vfx_3d.gd (0,75·0,97·0,85), aclarada para el tono claro y apagada para la sombra y el tono viejo.
const CLARO: Color = Color(0.90, 0.99, 0.94)
const SOMBRA: Color = Color(0.68, 0.87, 0.77)
const VIEJO: Color = Color(0.64, 0.80, 0.72)
const HOJA: Color = Color(0.62, 0.88, 0.5)            ## Vfx3D.COLOR_DE["hoja"]

## La ráfaga se dibuja más grande que su semieje (que sale del Hechizo y es pequeño: 0,12-0,23 m): sin esto era una raya al lado de la bola de agua o la de fuego. Solo es dibujo.
const RADIO_RAFAGA_MIN: float = 0.55
const ESCALA_RAFAGA: float = 1.3

const T_SOLTAR: float = 0.14
const T_APAGAR: float = 0.45
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const T_NACER: float = 0.35
const T_MORIR: float = 0.5
const HUMO_BOLA: int = 14                             ## bocanadas de cada reserva
const HUMO_ESTELA: int = 16
const HUMO_MURO: int = 20
const HUMO_PILAR: int = 14
const HUMO_BARRERA: int = 18
const HUMO_HAZ: int = 16
const HUMO_CARGA: int = 12
const HOJAS_FIG: int = 12

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28                                 ## hojas y jirones que convergen (tasa)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0                       ## sin uso (el viento no destella); existe para que los mandos del lab valgan para todos
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0                         ## sin uso
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0                          ## × el radio de la nube que converge
@export var carga_bola_visible: bool = true: set = _set_carga_bola_visible
@export_group("Impacto")
@export var area_al_impactar: bool = false
@export_group("Mundo")
@export var pies: Vector3 = Vector3(0, -0.7, 0.5)
@export var altura_suelo: float = 0.7

var _construido: bool = false
var _pendiente: bool = false
var _figura_anim: int = -1
var _silencio: bool = false
var _est: int = EstadoCarga.NINGUNA
var _c_t: float = 0.0
var _c_dur: float = 1.0
var _c_r: float = 0.4
var _c_prog: float = 0.0
var _c_escala: float = 1.0
var _c_desde: float = 1.0
var _c_nodo: Node3D = null
var _c_humo: Node3D = null
var _c_hojas: Node3D = null
var _c_cintas: Array = []
var _c_corrientes: CorrientesViento = null
var _c_acc: float = 0.0
var _pop: bool = false
var _humo: Node3D = null                ## reserva de jirones de la figura (local al Cuerpo)
var _estela: Node3D = null              ## BOLA en vuelo: jirones que se quedan en el mundo (top_level)
var _hojas: Node3D = null
var _cintas: Array = []                 ## remolinos (MeshInstance3D) con su velocidad de giro en meta
var _acc: float = 0.0
var _acc_h: float = 0.0
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _t_fig: float = 0.0
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
var _corrientes: CorrientesViento = null
var _bola_viento: MeshInstance3D = null
var _edad_rafaga: float = 0.0
## CAMPO DE VIENTO compartido (11/11, CampoViento; solo si `CampoViento.en_viento_toy`): hojas, jirones y puntos de las cintas siguen el MISMO campo (turbulencia sin divergencia + viento de la figura +
## rodeo de casillas, enemigos y bloques). Apagado, el toy es el de siempre.
var _campo: CampoViento = null
var _campo_sol_t: float = 0.0
var _campo_ult: Vector3 = Vector3.ZERO
var _campo_tiene_ult: bool = false


# ================================================================== HOJAS POR CPU ==================================================================
## Hojas de Formas3D («hoja», la misma pieza que vfx_3d.gd) movidas por la CPU: revolotean, giran y caen despacio. `mundo` = top_level (se quedan en el mundo).
class Hojas extends Node3D:
	var gravedad: float = 1.6
	var _mi: MultiMeshInstance3D = null
	var _s: Array = []
	var _cursor: int = 0
	var _t: float = 0.0
	static var _malla: ArrayMesh = null

	static func malla_hoja() -> ArrayMesh:
		if _malla == null:
			_malla = (Formas3D.malla("hoja") as ArrayMesh).duplicate() as ArrayMesh
			_malla.surface_set_material(0, Formas3D.material_tinte(VientoToy.HOJA, false, "hoja"))
		return _malla

	func montar(n: int, mundo: bool) -> void:
		top_level = mundo
		if mundo:
			transform = Transform3D.IDENTITY
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malla_hoja()
		mm.instance_count = maxi(n, 1)
		for i in mm.instance_count:
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_mi = MultiMeshInstance3D.new()
		_mi.name = "Hojas"
		_mi.multimesh = mm
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
		add_child(_mi)
		_s.clear()
		for i in n:
			_s.append({"vivo": false})

	func capacidad() -> int:
		return _s.size()

	func vivas() -> int:
		var k: int = 0
		for d in _s:
			if bool(d["vivo"]):
				k += 1
		return k

	func emitir(pos: Vector3, vel: Vector3, vida: float, tam: float, giro: Vector3 = Vector3.ZERO, curva: float = 0.0) -> int:
		if _s.is_empty():
			return -1
		var hueco: int = -1
		for k in _s.size():
			var j: int = (_cursor + k) % _s.size()
			if not bool((_s[j] as Dictionary)["vivo"]):
				hueco = j
				break
		if hueco < 0:
			return -1
		_cursor = (hueco + 1) % _s.size()
		var g: Vector3 = giro if giro.length() > 0.01 else Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7))
		_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam": tam, "giro": g, "curva": curva, "fase": randf() * TAU,
			"rot": Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))}
		return hueco

	func vaciar() -> void:
		for i in _s.size():
			_s[i] = {"vivo": false}
			if _mi != null:
				_mi.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

	func _process(delta: float) -> void:
		avanzar(delta)

	func avanzar(delta: float) -> void:
		if _mi == null:
			return
		_t += delta
		var mm: MultiMesh = _mi.multimesh
		for i in _s.size():
			var d: Dictionary = _s[i]
			if not bool(d["vivo"]):
				continue
			d["edad"] = float(d["edad"]) + delta
			var u: float = float(d["edad"]) / float(d["vida"])
			if u >= 1.0:
				d["vivo"] = false
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				continue
			var v: Vector3 = d["vel"]
			v.y -= gravedad * delta
			v = v.rotated(Vector3.UP, float(d["curva"]) * delta)
			v *= maxf(1.0 - 0.6 * delta, 0.0)
			var p: Vector3 = (d["pos"] as Vector3) + v * delta
			p += Vector3(sin(_t * 9.0 + float(d["fase"])), 0.0, cos(_t * 7.0 + float(d["fase"])) ) * 0.35 * delta   # revoloteo
			d["vel"] = v
			d["pos"] = p
			var g: Vector3 = d["giro"]
			d["rot"] = (Basis(g.normalized(), g.length() * delta) * (d["rot"] as Basis)).orthonormalized()
			var s: float = float(d["tam"]) * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.8, 1.0, u))
			mm.set_instance_transform(i, Transform3D((d["rot"] as Basis) * Basis.from_scale(Vector3.ONE * s), p))

	func estados() -> Array:
		var r: Array = []
		for i in _s.size():
			var d: Dictionary = _s[i]
			if bool(d["vivo"]):
				r.append({"hueco": i, "pos": d["pos"], "vel": d["vel"], "u": float(d["edad"]) / float(d["vida"])})
		return r


## Parámetros de las reservas de jirones del viento (pálidos, finos, poca erosión visible porque son claros).
static func humo_params(tam_ini: float, tam_fin: float, vida: float, deriva: Vector3, mundo: bool, estirado: float = 0.55) -> Dictionary:
	return {"claro": CLARO, "sombra": SOMBRA, "viejo": VIEJO, "tam_ini": tam_ini, "tam_fin": tam_fin, "vida": vida, "deriva": deriva, "erosion": 0.85, "estirado": estirado,
		"umbral": 0.46, "ruido_borde": 0.26, "mundo": mundo, "giro_vel": 0.9, "curva": 1.2, "friccion": 0.9}


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)


# ------------------------------------------------------------------ interfaz ------------------------------------------------------------------

func _set_figura(v: Figura) -> void:
	figura = v
	_pedir()


func _set_x(v: float) -> void:
	semieje_x = maxf(v, 0.05)
	_pedir()


func _set_y(v: float) -> void:
	semieje_y = maxf(v, 0.05)
	_pedir()


func _set_z(v: float) -> void:
	semieje_z = maxf(v, 0.05)
	_pedir()


func _set_viaja(v: bool) -> void:
	viaja = v
	_pedir()


func definir(fig: int, x: float, y: float, z: float, vuela: bool = false) -> void:
	_silencio = true
	figura = fig as Figura
	semieje_x = maxf(x, 0.05)
	semieje_y = maxf(y, 0.05)
	semieje_z = maxf(z, 0.05)
	viaja = vuela
	_silencio = false
	if _construido:
		reconstruir()


func _pedir() -> void:
	if _silencio:
		return
	if _construido and is_inside_tree() and not _pendiente:
		_pendiente = true
		call_deferred("reconstruir")


func reconstruir() -> void:
	_pendiente = false
	if not is_inside_tree() or not _construido:
		return
	_listo = false
	_construir()
	proyectil = viaja
	_recoger()
	_set_proyectil(viaja)


func semiejes() -> Vector3:
	return Vector3(semieje_x, semieje_y, semieje_z)


func esta_cargando() -> bool:
	return _est == EstadoCarga.CARGANDO


func progreso_carga() -> float:
	return _c_prog


func escala_carga() -> float:
	return _c_escala


# ------------------------------------------------------------------ carga, suelta e impacto ------------------------------------------------------------------

func empezar_carga(duracion: float, tam_final: Variant = null) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	if tam_final is Vector3:
		r = maxf((tam_final as Vector3).x, (tam_final as Vector3).z)
	elif tam_final is float or tam_final is int:
		r = float(tam_final)
	r = maxf(r, 0.05)
	_c_r = r
	definir(Figura.BOLA, r, r, r, false)
	proyectil = false
	aparicion = 1.0
	if _ap != null:
		_ap.stop()
	_c_dur = maxf(duracion, 0.05)
	_c_t = 0.0
	_c_prog = 0.0
	_c_escala = carga_tam_inicial
	_est = EstadoCarga.CARGANDO
	_aplicar_vuelo(false)
	_pop = false
	if _cuerpo != null:
		_cuerpo.visible = carga_bola_visible
	_montar_carga()
	_aplicar_escala_carga()


func soltar(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length() > 0.001 and is_inside_tree():
		var d: Vector3 = dir.normalized()
		look_at(global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	_silencio = true
	viaja = true
	_silencio = false
	proyectil = true
	_aplicar_vuelo(true)
	if _cuerpo != null and not _cuerpo.visible:
		_cuerpo.visible = true
		_pop = true
		_c_desde = 0.5
		_c_escala = 0.5
		_aplicar_escala_carga()
	else:
		_pop = false
		_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.SOLTANDO
	_quitar_visual_carga(-global_basis.z)


func cancelar_carga() -> void:
	if _est == EstadoCarga.CANCELANDO:
		return
	_quitar_visual_carga()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.CANCELANDO


func _set_carga_bola_visible(v: bool) -> void:
	carga_bola_visible = v
	if _est == EstadoCarga.CARGANDO and _cuerpo != null:
		_cuerpo.visible = v


## La convergencia deja de emitir; lo emitido se erosiona solo y el nodo «Carga» se libera al cabo de 0,8 s.
func _quitar_visual_carga(direccion: Vector3 = Vector3.ZERO) -> void:
	if _c_nodo != null and is_instance_valid(_c_nodo):
		var n: Node3D = _c_nodo
		_c_nodo = null
		if is_instance_valid(_c_corrientes):
			var trazo: CorrientesViento = _c_corrientes
			_c_corrientes = null
			var dispara: bool = direccion.length_squared() > 0.001
			if dispara:
				var d: Vector3 = direccion.normalized()
				n.look_at(n.global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
			var figura_salida: StringName = &"SALIDA" if dispara else &"CARGA"
			var radio := Vector3.ONE * _c_r * carga_radio
			var tiempo: float = _c_t * velocidad
			var progreso: float = _c_prog
			var grosor: float = ancho
			var fundido := n.create_tween()
			fundido.tween_method(func(u: float) -> void:
				var alfa: float = 1.0 if dispara else 1.0 - u
				trazo.dibujar(figura_salida, radio, tiempo + u * 0.18, alfa, grosor, u if dispara else progreso),
				0.0, 1.0, 0.22 if dispara else 0.14)
			fundido.tween_callback(n.queue_free)
			return
		_c_humo = null
		_c_hojas = null
		_c_cintas = []
		for c in n.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
		if is_inside_tree():
			get_tree().create_timer(0.8).timeout.connect(n.queue_free)
		else:
			n.queue_free()


func _escala_de_carga(p: float) -> float:
	var g: float = smoothstep(0.0, 1.0, pow(clampf(p, 0.0, 1.0), carga_curva))
	return lerpf(carga_tam_inicial, 1.0, g)


func _aplicar_escala_carga() -> void:
	if _cuerpo != null:
		var v: float = aparicion
		_cuerpo.scale = Vector3(lerpf(0.65, 1.0, v), lerpf(0.15, 1.0, v), lerpf(0.65, 1.0, v)) * _c_escala


func _avanzar_carga(delta: float) -> void:
	match _est:
		EstadoCarga.CARGANDO:
			_c_t += delta
			var p: float = clampf(_c_t / _c_dur, 0.0, 1.0)
			_c_prog = p
			var g: float = _escala_de_carga(p)
			var env: float = smoothstep(0.55, 1.0, p)
			var resp: float = sin(_c_t * TAU * RESPIRO_HZ)
			_c_escala = g * (1.0 + carga_respiro * env * resp)
			_aplicar_escala_carga()
			if is_instance_valid(_c_corrientes):
				_c_nodo.global_transform = global_transform
				_c_corrientes.dibujar(&"CARGA", Vector3.ONE * _c_r * carga_radio, _c_t * velocidad,
					smoothstep(0.0, 0.075, _c_t), ancho, p)
			else:
				_emitir_carga(delta, p)
		EstadoCarga.SOLTANDO:
			_c_t += delta
			var u: float = clampf(_c_t / T_SOLTAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 1.0, smoothstep(0.0, 1.0, u)) + (0.07 * sin(u * PI) if _pop else 0.0)
			_aplicar_escala_carga()
			if u >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 1.0
				_aplicar_escala_carga()
		EstadoCarga.CANCELANDO:
			_c_t += delta
			var u2: float = clampf(_c_t / T_CANCELAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u2 * u2)
			_aplicar_escala_carga()
			if u2 >= 1.0:
				_est = EstadoCarga.NINGUNA
				queue_free()
		EstadoCarga.APAGANDO:
			_c_t += delta
			var u3: float = clampf(_c_t / T_APAGAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u3 * u3)
			_aplicar_escala_carga()
			if u3 >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 0.001
				_aplicar_escala_carga()
				_soltar_estela()
				get_tree().create_timer(0.3).timeout.connect(queue_free)


## Jirones y hojas que convergen en la mano (nodo «Carga», que no escala con la ráfaga), y dos cintas que giran alrededor.
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	if prueba_corrientes:
		_c_nodo.top_level = true
		_c_nodo.global_transform = global_transform
		_c_corrientes = CorrientesViento.new()
		_c_nodo.add_child(_c_corrientes)
		return
	_c_humo = HumoToy.new()
	_c_humo.name = "Convergencia"
	_c_nodo.add_child(_c_humo)
	_c_humo.call("montar", HUMO_CARGA, humo_params(_c_r * 0.35, _c_r * 0.8, 0.5, Vector3.ZERO, false, 0.5))
	_c_hojas = Hojas.new()
	_c_hojas.name = "HojasCarga"
	_c_hojas.gravedad = 0.0
	_c_nodo.add_child(_c_hojas)
	_c_hojas.call("montar", 10, false)
	_c_cintas = []
	for j in 2:
		var c: MeshInstance3D = Formas3D.instancia("remolino", Color.WHITE, _c_r * 1.1)
		c.name = "CintaCarga%d" % j
		c.position = Vector3(0, -_c_r * 0.55, 0)
		c.set_meta("giro", 3.5 if j == 0 else -2.6)
		c.set_meta("fase", float(j) * PI)
		_c_nodo.add_child(c)
		_c_cintas.append(c)
	_c_acc = 0.0


## Estado de la convergencia para las pruebas: bocanadas y hojas vivas con su posición y velocidad (local a la mano).
func estado_carga() -> Array:
	if _c_humo == null or not is_instance_valid(_c_humo):
		return []
	var r: Array = _c_humo.call("estados")
	if _c_hojas != null and is_instance_valid(_c_hojas):
		r.append_array(_c_hojas.call("estados"))
	return r


func _emitir_carga(delta: float, p: float) -> void:
	if _c_humo == null or not is_instance_valid(_c_humo):
		return
	var r0: float = _c_r * lerpf(3.0, 2.0, p) * carga_radio
	var tasa: float = float(carga_chispas) * lerpf(0.4, 1.3, p)
	_c_acc += tasa * delta
	var r_bola: float = _c_r * clampf(_c_escala, 0.05, 1.3)
	while _c_acc >= 1.0:
		_c_acc -= 1.0
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized()
		var rr: float = r0 * randf_range(0.8, 1.2)
		var vel: Vector3 = -d * (rr - r_bola) / 0.45                      # llega al borde de la ráfaga en ~0,45 s
		if randf() < 0.55:
			_c_humo.call("emitir", d * rr, vel, 1.0, randf_range(0.7, 1.1), -1.0, 1.8)
		elif _c_hojas != null:
			_c_hojas.call("emitir", d * rr, vel * 0.9, 0.5, _c_r * randf_range(0.25, 0.4), Vector3.ZERO, 1.5)
	for c in _c_cintas:
		var mi: MeshInstance3D = c
		mi.rotation.y += float(mi.get_meta("giro")) * delta
		var sc: float = lerpf(0.4, 1.0, p) * (0.85 + 0.15 * sin(_c_t * 5.0 + float(mi.get_meta("fase"))))
		mi.scale = Vector3.ONE * _c_r * 1.1 * sc


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoVientoToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoVientoToy = ImpactoVientoToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


## La estela de jirones sigue erosionándose aunque la ráfaga desaparezca: pasa al padre y se libera sola.
func _soltar_estela() -> void:
	if _estela == null or not is_instance_valid(_estela) or get_parent() == null or not is_inside_tree():
		return
	var padre: Node = get_parent()
	_estela.get_parent().remove_child(_estela)
	padre.add_child(_estela)
	_estela.top_level = true
	_estela.transform = Transform3D.IDENTITY
	get_tree().create_timer(1.5).timeout.connect(_estela.queue_free)
	_estela = null


func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	var imp: ImpactoVientoToy = ImpactoVientoToy.crear(ImpactoVientoToy.Variante.AREA, Vector3.UP, r)
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoVientoToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	_quitar_visual_carga()
	_soltar_estela()
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoVientoToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
		_ult_pos = pos
	return nd


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	_crear_impacto(ImpactoVientoToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_quitar_visual_carga()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.APAGANDO


func finalizar(motivo: String, pos: Vector3 = Vector3.INF, normal: Vector3 = Vector3.UP) -> void:
	var p: Vector3 = global_position if pos == Vector3.INF else pos
	match motivo:
		"golpe", "muro", "suelo":
			impactar_en(p, normal)
		"retorno":
			cancelar_carga()
		_:
			terminar_sin_choque()


func impactar() -> void:
	var n: Vector3 = global_transform.basis.z.normalized() if proyectil else Vector3.UP
	if global_position.y < 0.3:
		n = Vector3.UP
	impactar_en(global_position, n)


func morir() -> void:
	_soltar_estela()
	super.morir()


func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "viento") -> void:
	semieje_x = maxf(float(volumen.get("x", 0.5)) * casilla, 0.05)
	semieje_y = maxf(float(volumen.get("y", 0.5)) * casilla, 0.05)
	semieje_z = maxf(float(volumen.get("z", 0.5)) * casilla, 0.05)
	var plano: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if plano.length() > 0.01 and is_inside_tree():
		look_at(global_position + plano, Vector3.UP)
	if _construido:
		reconstruir()


func desde_hechizo(h: Hechizo) -> void:
	var d: Dictionary = describir(h, casilla)
	definir(int(d["figura"]), d["x"], d["y"], d["z"], d["viaja"])
	rotation.y = float(d["giro_y"])
	area_al_impactar = int(d["figura"]) == Figura.BOLA and not bool(d["viaja"])


static func describir(h: Hechizo, casilla_m: float = 2.3) -> Dictionary:
	return FuegoToy.describir(h, casilla_m)


func extension() -> float:
	return FuegoToy._extension(int(figura) as FuegoToy.Figura, semieje_x, semieje_y, semieje_z)


static func _extension_ref(fig: int) -> float:
	return FuegoToy._extension_ref(fig as FuegoToy.Figura)


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	var cuerpo: Node3D = get_node_or_null("Cuerpo") as Node3D
	if cuerpo == null:
		cuerpo = Node3D.new()
		cuerpo.name = "Cuerpo"
		add_child(cuerpo)
	for h in cuerpo.get_children():
		cuerpo.remove_child(h)
		h.free()
	_humo = null
	_estela = null
	_hojas = null
	_corrientes = null
	_bola_viento = null
	_cintas = []
	_acc = 0.0
	_acc_h = 0.0
	_t_fig = 0.0
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
	if not prueba_corrientes or figura == Figura.BOLA:
		match figura:
			Figura.BOLA:
				_bola(cuerpo)
			Figura.HAZ:
				_haz(cuerpo)
			Figura.PILAR:
				_pilar(cuerpo)
			Figura.MURO:
				_muro(cuerpo)
			_:
				_barrera(cuerpo)
	if prueba_corrientes:
		_corrientes = CorrientesViento.new()
		_corrientes.name = "CorrientesViento"
		cuerpo.add_child(_corrientes)
		if figura == Figura.BOLA:
			var esfera := SphereMesh.new()
			esfera.radial_segments = 24
			esfera.rings = 12
			var material := ShaderMaterial.new()
			material.shader = preload("res://presentacion/vfx/toy/viento_bola.gdshader")
			material.render_priority = 1
			_bola_viento = MeshInstance3D.new()
			_bola_viento.name = "BolaDeViento"
			_bola_viento.mesh = esfera
			_bola_viento.material_override = material
			_bola_viento.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_bola_viento.hide()
			cuerpo.add_child(_bola_viento)
		elif figura == Figura.PILAR:
			_hojas = _hojas_de(cuerpo, HOJAS_FIG, false, -0.5)
		elif figura == Figura.MURO:
			_hojas = _hojas_de(cuerpo, HOJAS_FIG, false, -0.5)    # suben con la cortina
		elif figura == Figura.HAZ:
			_hojas = _hojas_de(cuerpo, HOJAS_FIG, false, 0.2)     # arrastradas hacia delante
	_anim_si_hace_falta()


func _humo_local(c: Node3D, nombre: String, n: int, q: Dictionary) -> Node3D:
	var h: Node3D = HumoToy.new()
	h.name = nombre
	c.add_child(h)
	h.call("montar", n, q)
	return h


func _hojas_de(c: Node3D, n: int, mundo: bool, gravedad: float = 1.6) -> Node3D:
	var h: Hojas = Hojas.new()
	h.name = "Hojas"
	h.gravedad = gravedad
	c.add_child(h)
	h.montar(n, mundo)
	return h


func _cinta(c: Node3D, nombre: String, tam: float, pos: Vector3, giro: float) -> MeshInstance3D:
	var mi: MeshInstance3D = Formas3D.instancia("remolino", Color.WHITE, tam)
	mi.name = nombre
	mi.position = pos
	mi.rotation.y = randf() * TAU
	mi.set_meta("giro", giro)
	mi.set_meta("tam", tam)
	c.add_child(mi)
	_cintas.append(mi)
	return mi


## BOLA = RÁFAGA: núcleo de jirones alargados por -Z (local al cuerpo), dos cintas en espiral que giran en sentidos opuestos, hojas; en vuelo, estela de jirones que se quedan en el mundo.
func _bola(c: Node3D) -> void:
	var r: float = _radio_rafaga()
	# NÚCLEO BLANDO: pocos jirones anchos y muy transparentes (opacidad) que van DETRÁS de las cintas y les dan cuerpo; prioridad baja para que las cintas se pinten encima.
	var q: Dictionary = humo_params(r * 1.8, r * 3.0, 0.6, Vector3.ZERO, false, 0.8)
	q.merge({"opacidad": 0.6, "prioridad": -2, "erosion": 0.5, "friccion": 2.0}, true)
	_humo = _humo_local(c, "Nucleo", HUMO_BOLA, q)
	_cinta(c, "Cinta0", r * 1.7, Vector3(0, -r * 0.8, 0), 4.0)
	_cinta(c, "Cinta1", r * 1.3, Vector3(0, -r * 0.5, 0), -3.1)
	_hojas = _hojas_de(c, 8, false, 0.0)
	_estela = _humo_local(c, "Estela", HUMO_ESTELA, humo_params(r * 0.6, r * 1.5, 0.55, Vector3(0, 0.25, 0), true, 0.5))
	_estela.visible = false


## MURO = CORTINA: jirones que nacen a lo largo de x en el pie y suben, con hojas que suben a la deriva.
func _muro(c: Node3D) -> void:
	_humo = _humo_local(c, "Cortina", HUMO_MURO, humo_params(0.35, 0.9, 0.9, Vector3(0, 1.4, 0), false, 0.6))
	_hojas = _hojas_de(c, HOJAS_FIG, false, -0.6)


## PILAR = TORBELLINO: discos de remolino apilados que giran alternos, jirones que suben girando, hojas en espiral.
func _pilar(c: Node3D) -> void:
	var w: float = maxf(semieje_x, semieje_z)
	var pisos: int = clampi(int(round(semieje_y / 0.9)), 2, 6)
	for i in pisos:
		var f: float = float(i) / float(maxi(pisos - 1, 1))
		_cinta(c, "Disco%d" % i, w * (1.2 + 0.8 * f), Vector3(0, semieje_y * (0.05 + 0.75 * f), 0), (4.5 if i % 2 == 0 else -3.6))
	_humo = _humo_local(c, "Torbellino", HUMO_PILAR, humo_params(w * 0.5, w * 1.3, 1.0, Vector3(0, 1.8, 0), false, 0.5))
	_hojas = _hojas_de(c, HOJAS_FIG, false, -1.2)


## BARRERA = ANILLO: jirones que giran sobre la elipse del suelo (colocados por fórmula), tres cintas repartidas y hojas que orbitan.
func _barrera(c: Node3D) -> void:
	_humo = _humo_local(c, "Anillo", HUMO_BARRERA, humo_params(0.4, 0.95, 1.0, Vector3.ZERO, false, 0.55))
	for j in 3:
		var a: float = TAU * float(j) / 3.0
		_cinta(c, "Cinta%d" % j, semieje_y * 0.7, Vector3(cos(a) * semieje_x * 0.85, 0.0, sin(a) * semieje_z * 0.85), 3.2)
	_hojas = _hojas_de(c, HOJAS_FIG, false, 0.0)


## HAZ = CHORRO: jirones que salen de la mano hacia -Z y se alargan, con hojas arrastradas.
func _haz(c: Node3D) -> void:
	_haz_largo = semieje_x * 2.0
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	_humo = _humo_local(c, "Chorro", HUMO_HAZ, humo_params(_haz_r * 0.9, _haz_r * 2.2, 0.55, Vector3.ZERO, false, 0.4))
	_hojas = _hojas_de(c, 8, false, 0.3)


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	if ap != null and _figura_anim == int(figura):
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:aparicion"))
		match nom:
			"nacer":
				an.length = T_NACER
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, T_NACER, 1.0)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 1.0)
			"morir":
				an.length = T_MORIR
				an.track_insert_key(pista, 0.0, 1.0)
				an.track_insert_key(pista, T_MORIR, 0.0)
		an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = T_MORIR


# ------------------------------------------------------------------ vuelo y emisión ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v
	_aplicar_vuelo(v)


func _aplicar_vuelo(v: bool) -> void:
	_edad_rafaga = 0.0
	if _estela != null and is_instance_valid(_estela):
		_estela.visible = v and _corrientes == null
	if _corrientes != null and figura == Figura.BOLA:
		# La ráfaga (quieta o en vuelo) es la envoltura + las cintas orbitales de CorrientesViento; las cintas planas de `remolino` y los jirones se ven
		# como un folio, así que no se enseñan. Las HOJAS sí: son lo único verde del viento.
		_humo.visible = _est != EstadoCarga.CARGANDO      # el núcleo blando: jirones de humo_toy muy transparentes detrás de las cintas
		_hojas.visible = _est != EstadoCarga.CARGANDO
		for cinta: MeshInstance3D in _cintas:
			cinta.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	_t_fig += delta
	_campo_paso(delta)
	if _bola_viento != null:
		var en_carga: bool = _est == EstadoCarga.CARGANDO or _est == EstadoCarga.CANCELANDO
		var radio: float = _radio_rafaga()
		_bola_viento.visible = true     # también quieta: con la envoltura la ráfaga tiene silueta de esfera desde cualquier ángulo
		_bola_viento.scale = Vector3.ONE * radio * 1.45     # la malla mide 1 m de diámetro: la envoltura tiene radio 0,72 · semieje, y las cintas orbitales la rodean un poco por fuera
		_bola_viento.position.z = -radio * 0.68 * smoothstep(0.0, 0.10, _edad_rafaga) if proyectil else 0.0
		if en_carga:
			return
	if _corrientes != null:
		_actualizar_corrientes(delta)
		if figura == Figura.BOLA:
			_emitir_figura(delta)   # solo cuentan las hojas (los jirones no se ven)
		return
	_girar_cintas(delta)
	_emitir_figura(delta)


func _radio_rafaga() -> float:
	return maxf(RADIO_RAFAGA_MIN, maxf(semieje_x, semieje_z) * ESCALA_RAFAGA)


## El campo de viento de esta figura (null si el interruptor está apagado). Lo pueden muestrear otros (CampoViento.velocidad en mundo).
func campo() -> CampoViento:
	return _campo


## Un paso del CAMPO DE VIENTO: lo configura con la figura (en mundo), recoge los sólidos cercanos cada 0,3 s y arrastra con él hojas y jirones; las cintas lo leen al dibujarse.
func _campo_paso(delta: float) -> void:
	if not CampoViento.en_viento_toy or not is_inside_tree() or delta <= 0.0:
		if _campo != null:
			_campo = null
			if _corrientes != null and is_instance_valid(_corrientes):
				_corrientes.campo = null
		return
	if _campo == null:
		_campo = CampoViento.new(int(figura) * 31 + 7)
		_campo_sol_t = 0.0
		_campo_tiene_ult = false
	var tr: Transform3D = global_transform
	var v_marco: Vector3 = (tr.origin - _campo_ult) / delta if _campo_tiene_ult else Vector3.ZERO
	_campo_ult = tr.origin
	_campo_tiene_ult = true
	_configurar_campo(tr, v_marco)
	_campo.avanzar(delta)
	_campo_sol_t -= delta
	if _campo_sol_t <= 0.0:
		_campo_sol_t = 0.3
		_campo.recoger_de(self, tr.origin, extension() + 1.5, tr.origin.y - (altura_suelo if figura == Figura.BOLA else 0.0))
	if _corrientes != null and is_instance_valid(_corrientes):
		_corrientes.campo = _campo
	for h in [_humo, _hojas, _estela]:
		if h == null or not is_instance_valid(h) or not (h as Node3D).is_visible_in_tree():
			continue
		var lista: Variant = h.get("_s")
		if not (lista is Array):
			continue
		var mundo: bool = (h as Node3D).top_level
		_campo.arrastrar_lista(lista, Transform3D.IDENTITY if mundo else (h as Node3D).global_transform, Vector3.ZERO if mundo else v_marco, delta)


## El viento dirigido de cada figura (lo que ya dibujan sus cintas): BOLA = el aire que lleva la ráfaga; HAZ = chorro hacia delante; MURO = cortina que sube y se inclina; PILAR y BARRERA = remolino.
func _configurar_campo(tr: Transform3D, v_marco: Vector3) -> void:
	var c: CampoViento = _campo
	var b: Basis = tr.basis.orthonormalized()
	var frente: Vector3 = Vector3(-b.z.x, 0.0, -b.z.z)
	frente = frente.normalized() if frente.length() > 0.01 else Vector3.FORWARD
	c.dir = Vector3.ZERO
	c.fuerza = 0.0
	c.sube = 0.0
	c.remolino = 0.0
	c.centro_remolino = tr.origin
	c.eje_remolino = Vector3.UP
	var w: float = maxf(semieje_x, semieje_z)
	match figura:
		Figura.BOLA:
			var r: float = _radio_rafaga()
			c.escala = maxf(r * 4.0, 1.5)
			c.turbulencia = 0.5
			if v_marco.length() > 0.3:
				c.dir = v_marco.normalized()
				c.fuerza = v_marco.length()
		Figura.HAZ:
			c.escala = maxf(semieje_z * FuegoToy.HAZ_ABRE * 4.0, 1.5)
			c.turbulencia = 0.9
			c.dir = frente
			c.fuerza = semieje_x * 2.0 / 0.6 * velocidad
		Figura.MURO:
			c.escala = maxf(semieje_y * 1.5, 1.5)
			c.turbulencia = 0.7
			c.dir = -frente
			c.fuerza = 0.6 * velocidad
			c.sube = semieje_y * 1.1 * altura
		Figura.PILAR:
			c.escala = maxf(semieje_y * 0.8, 1.5)
			c.turbulencia = 0.6
			c.remolino = w * 3.0 * velocidad
			c.radio_remolino = w * 1.2
			c.sube = semieje_y * 0.5 * altura
		_:
			c.escala = maxf(w * 1.5, 1.5)
			c.turbulencia = 0.5
			c.remolino = w * 1.6 * velocidad
			c.radio_remolino = w
	c.un_sentido = c.fuerza > 0.0


func _actualizar_corrientes(delta: float) -> void:
	var ejes := Vector3(semieje_x, semieje_y * altura, semieje_z)
	if figura == Figura.BOLA:
		ejes = Vector3.ONE * _radio_rafaga()
	if figura == Figura.HAZ:
		ejes = Vector3(semieje_x * 2.0, maxf(semieje_y, 0.4), semieje_z * FuegoToy.HAZ_ABRE)
	elif figura == Figura.BARRERA:
		ejes.y = maxf(ejes.y, minf(ejes.x, ejes.z) * 0.63)
	var opacidad: float = aparicion * clampf(_c_escala, 0.0, 1.0)
	var estela: float = 1.0
	if figura == Figura.BOLA:
		_edad_rafaga += delta
		estela = smoothstep(0.02, 0.22, _edad_rafaga) if proyectil else 0.0   # quieta no deja cola
	_corrientes.dibujar(StringName(Figura.keys()[figura]), ejes, _t_fig * velocidad, opacidad, ancho, estela)
	if figura == Figura.BOLA or figura == Figura.BARRERA or _hojas == null or opacidad < 0.10:
		return
	# Las HOJAS son lo único verde del viento: el aire en sí es blanco frío (ver viento_corriente.gdshader). Cada figura las arrastra a su manera.
	_acc_h += delta * (10.0 if figura == Figura.PILAR else 7.0) * clampf(chispas, 0.0, 1.0)
	while _acc_h >= 1.0:
		_acc_h -= 1.0
		match figura:
			Figura.PILAR:
				var a: float = randf() * TAU
				var pie := Vector3(cos(a) * ejes.x * 0.46, 0.08, sin(a) * ejes.z * 0.46)
				var empuje := Vector3(-sin(a) * ejes.x * 2.0, ejes.y * 0.68, cos(a) * ejes.z * 2.0)
				_hojas.emitir(pie, empuje, 0.7, 0.16, Vector3.ZERO, 4.0)
			Figura.MURO:
				var x: float = randf_range(-0.9, 0.9) * ejes.x
				_hojas.emitir(Vector3(x, 0.1, 0.1), Vector3(randf_range(-0.5, 0.5), ejes.y * randf_range(0.5, 0.9), randf_range(-0.2, 0.3)), 1.1, 0.16, Vector3.ZERO, 2.0)
			Figura.HAZ:
				var u: float = randf_range(0.0, 0.5)
				var radio: float = ejes.z * 0.4
				var vel_z: float = -ejes.x / 0.6 * randf_range(0.8, 1.1)
				_hojas.emitir(Vector3(randf_range(-1.0, 1.0) * radio, ejes.y + randf_range(-1.0, 1.0) * radio, -u * ejes.x),
					Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), vel_z), 0.65, 0.14, Vector3.ZERO, 3.0)


func _girar_cintas(delta: float) -> void:
	for c in _cintas:
		var mi: MeshInstance3D = c
		if not is_instance_valid(mi):
			continue
		mi.rotation.y += float(mi.get_meta("giro")) * velocidad * delta
		var tam: float = float(mi.get_meta("tam"))
		mi.scale = Vector3.ONE * tam * (0.9 + 0.1 * sin(_t_fig * 4.0 + mi.rotation.y)) * ancho


## Lo que emite cada figura mientras vive: una tasa × `chispas` × `aparicion`, menos al morir.
func _emitir_figura(delta: float) -> void:
	if _humo == null or not is_instance_valid(_humo) or not _listo or delta <= 0.0 or not is_inside_tree():
		return
	if _cuerpo == null or not _cuerpo.visible or _est == EstadoCarga.CANCELANDO or _est == EstadoCarga.APAGANDO:
		return
	var pos: Vector3 = global_position
	if _tiene_ult:
		_vel_mundo = (pos - _ult_pos) / delta
	_ult_pos = pos
	_tiene_ult = true
	var k: float = clampf(chispas, 0.0, 1.0) * clampf(aparicion, 0.0, 1.0) * clampf(_c_escala, 0.1, 1.0)
	if k <= 0.001:
		return
	var tr: Transform3D = global_transform
	match figura:
		Figura.BOLA:
			var r: float = _radio_rafaga() * clampf(_c_escala, 0.1, 1.5)
			_acc += 22.0 * k * delta
			while _acc >= 1.0:
				_acc -= 1.0
				var loc: Vector3 = Vector3(randf_range(-0.4, 0.4) * r, randf_range(-0.35, 0.35) * r, randf_range(-0.7, 0.1) * r)
				_humo.call("emitir", loc, Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), 1.2) * r * 2.0, 1.0, 1.0, PI * 0.5, 2.2)
			_acc_h += 5.0 * k * delta
			while _acc_h >= 1.0 and _hojas != null:
				_acc_h -= 1.0
				var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				_hojas.call("emitir", d * r * 0.9, Vector3(-d.z, 0.2, d.x) * r * 3.0, 0.6, r * 0.35, Vector3.ZERO, 5.0)
			if proyectil and _estela != null and _estela.visible:
				var ne: float = 16.0 * k * delta
				var cuenta: int = int(floor(ne + randf()))
				for q in cuenta:
					var locb: Vector3 = Vector3(randf_range(-0.5, 0.5) * r, randf_range(-0.4, 0.3) * r, r * randf_range(0.6, 1.4))
					var lat: Vector3 = tr.basis * Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.8), randf_range(0.2, 0.8)) * 0.5
					_estela.call("emitir", tr * locb, _vel_mundo * 0.2 + lat, randf_range(0.8, 1.2), randf_range(0.8, 1.2), -1.0, 1.6)
		Figura.MURO:
			_acc += 18.0 * k * (1.0 + semieje_x * 0.3) * delta
			while _acc >= 1.0:
				_acc -= 1.0
				var x: float = randf_range(-semieje_x, semieje_x) * 0.95
				_humo.call("emitir", Vector3(x, 0.1, randf_range(-semieje_z, semieje_z)), Vector3(randf_range(-0.3, 0.3), semieje_y * 1.1 * altura, 0.0), randf_range(0.8, 1.2), randf_range(0.8, 1.3), 0.0, 1.9)
			_acc_h += 6.0 * k * delta
			while _acc_h >= 1.0 and _hojas != null:
				_acc_h -= 1.0
				_hojas.call("emitir", Vector3(randf_range(-semieje_x, semieje_x), 0.05, 0.0), Vector3(randf_range(-0.5, 0.5), semieje_y * 0.8, randf_range(-0.3, 0.3)), 1.0, 0.16, Vector3.ZERO, 2.0)
		Figura.PILAR:
			var w: float = maxf(semieje_x, semieje_z)
			_acc += 10.0 * k * delta
			while _acc >= 1.0:
				_acc -= 1.0
				var a: float = randf() * TAU
				_humo.call("emitir", Vector3(cos(a) * w * 1.2, 0.05, sin(a) * w * 1.2), Vector3(-sin(a), 0.0, cos(a)) * w * 3.0 + Vector3(0, semieje_y * 0.5 * altura, 0), 1.0, 1.0, a, 2.0)
			_acc_h += 9.0 * k * delta
			while _acc_h >= 1.0 and _hojas != null:
				_acc_h -= 1.0
				var a2: float = randf() * TAU
				_hojas.call("emitir", Vector3(cos(a2) * w * 1.6, 0.05, sin(a2) * w * 1.6), Vector3(-sin(a2), 0.0, cos(a2)) * w * 4.0 + Vector3(0, semieje_y * 0.45, 0), 1.3, 0.17, Vector3.ZERO, 3.0)
		Figura.BARRERA:
			_colocar_anillo()
			_acc_h += 6.0 * k * delta
			while _acc_h >= 1.0 and _hojas != null:
				_acc_h -= 1.0
				var a3: float = randf() * TAU
				var p3: Vector3 = Vector3(cos(a3) * semieje_x, randf_range(0.1, 0.6) * semieje_y, sin(a3) * semieje_z)
				_hojas.call("emitir", p3, Vector3(-sin(a3) * semieje_x, 0.3, cos(a3) * semieje_z) * 1.6, 1.2, 0.17, Vector3.ZERO, 1.8)
		Figura.HAZ:
			_acc += 24.0 * k * delta
			var vel_z: float = -_haz_largo / 0.5 * velocidad
			while _acc >= 1.0:
				_acc -= 1.0
				_humo.call("emitir", Vector3(randf_range(-0.3, 0.3) * _haz_r, _haz_alt + randf_range(-0.3, 0.3) * _haz_r, 0.0), Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.4), vel_z), 1.0, 1.0, PI * 0.5, 2.4)
			_acc_h += 7.0 * k * delta
			while _acc_h >= 1.0 and _hojas != null:
				_acc_h -= 1.0
				_hojas.call("emitir", Vector3(randf_range(-0.5, 0.5) * _haz_r, _haz_alt + randf_range(-0.5, 0.5) * _haz_r, 0.0), Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.6), vel_z * 0.9), 0.7, 0.15, Vector3.ZERO, 3.0)


## BARRERA: las bocanadas del anillo se colocan por fórmula (giran sobre la elipse, cada una con su edad cíclica: nacen, se hinchan, se erosionan y renacen en otro sitio).
func _colocar_anillo() -> void:
	var mm: MultiMesh = _humo.call("multimesh")
	if mm == null:
		return
	var n: int = mm.instance_count
	var k: float = clampf(aparicion, 0.0, 1.0)
	for i in n:
		var fase: float = float(i) / float(n)
		var ciclo: float = 1.1
		var u: float = fposmod(_t_fig / ciclo + fase * 2.37, 1.0)
		var a: float = TAU * fase + _t_fig * 1.5 * velocidad + floorf(_t_fig / ciclo + fase * 2.37) * 1.7
		var y: float = semieje_y * (0.15 + 0.5 * fposmod(fase * 3.1, 1.0)) * altura
		var pos: Vector3 = Vector3(cos(a) * semieje_x, y, sin(a) * semieje_z)
		var tam: float = float(_humo.call("tamano", u, 1.0)) * ancho * k
		HumoToy.poner(mm, i, pos, tam * 1.5, tam * 0.75, a + PI * 0.5, u, fase, 1.0 if k > 0.05 else 0.0)
