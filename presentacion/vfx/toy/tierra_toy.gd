class_name TierraToy
extends EfectoToy

## TIERRA «TOY» (6/11/2026; docs/PLAN_VFX_ELEMENTOS.md §2.5, referencia Zelda: Echoes of Wisdom). Clase HERMANA de FuegoToy, AguaToy, HieloToy, RayoToy y VientoToy: misma API, mismas cinco
## figuras (BOLA, MURO, PILAR, BARRERA, HAZ), mismos ejes (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy) y los mismos diez mandos de EfectoToy
## (valen `altura`, `ancho`, `velocidad`, `brillo` y `chispas` = cuántos terrones y cuánto polvo; luz, halo, tono y blandura no hacen nada: la tierra no brilla). Máquina de carga e impacto copiada
## de HieloToy, no compartida.
## CARÁCTER: MACIZA, MATE, de SOMBRAS DURAS (tierra_roca.gdshader: tres tonos planos por cara con luz fija, opaca; Vfx3D.COLOR["tierra"] ≈ 0,85·0,66·0,40) y con PESO: los bloques
## SUBEN DEL SUELO con ANTICIPACIÓN (0,1 s de temblor y polvo en la base), SOBREPASO y ASENTAMIENTO (polvo radial bajo + 2-3 fragmentos que ruedan) y al morir se HUNDEN en el suelo con
## polvo (no se desvanecen). El polvo es humo toon PARDO de dos tonos (humo_toy.gd). Sin luz, sin aditivos, sin GPUParticles3D: MultiMesh movidos por la CPU.
## FIGURAS: BOLA = pedrusco facetado (icosfera de 80 caras con ruido de vértices) que gira al volar y suelta terrones y polvo. MURO = hilera de bloques facetados a lo largo de x. PILAR = un
## bloque alto con cuatro más bajos alrededor. BARRERA = corona de bloques inclinados hacia dentro sobre la elipse del suelo. HAZ = hilera de púas de piedra que brotan hacia -Z.
## Ciclo de vida de un proyectil de tierra, sobre UN SOLO nodo (igual que las hermanas):
##   empezar_carga(duracion, tam_final)  piedrecitas que CONVERGEN en la mano mientras la roca crece en ella. NO hace falta `lanzar()`.
##   progreso_carga() -> float · soltar(dir) · cancelar_carga() · impactar_en(pos, normal, escala) (ImpactoTierraToy GOLPE: piedrecitas con gravedad + nube de polvo pardo a ras de suelo)
##   rebotar(pos, normal) -> Vector3 · terminar_sin_choque() (la roca se deshace en terrones que caen, FIN) · finalizar(motivo, pos, normal)

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const SH_ROCA: String = "res://presentacion/vfx/toy/tierra_roca.gdshader"

const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)

## Polvo pardo: dos tonos tierra (claro = Vfx3D.COLOR["tierra"] aclarado; sombra = ocre oscuro) y un tono viejo más apagado.
const POLVO_CLARO: Color = Color(0.82, 0.70, 0.52)
const POLVO_SOMBRA: Color = Color(0.56, 0.43, 0.28)
const POLVO_VIEJO: Color = Color(0.50, 0.41, 0.31)

const T_SOLTAR: float = 0.14
const T_APAGAR: float = 0.4
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const GIRO_QUIETA: float = 0.5
const GIRO_VUELO: float = 5.0
const T_NACER: float = 0.55             ## muro, pilar, barrera: 0,1 s de anticipación + subida con sobrepaso + asentamiento
const T_NACER_HAZ: float = 0.5
const T_NACER_BOLA: float = 0.3
const T_MORIR: float = 0.6              ## se hunde
const T_MORIR_BOLA: float = 0.4
const ANTICIPO: float = 0.1 / T_NACER   ## fracción de `sube` que dura el temblor previo
const SOBREPASO: float = 0.1            ## cuánto se pasa de su sitio antes de asentarse (fracción del alto)
const MAX_BLOQUES: int = 24
const POLVO_FIG: int = 18
const PIEDRAS_FIG: int = 24


# ================================================================== PIEDRAS POR CPU ==================================================================
## Terrones, piedrecitas y fragmentos: un MultiMesh de pedruscos (tierra_roca.gdshader) que caen con gravedad, giran, rebotan una vez y se quedan en el suelo hasta encogerse. `mundo` = top_level.
class Piedras extends Node3D:
	var gravedad: float = 9.8
	var suelo_y: float = -1.0e9
	var _mi: MultiMeshInstance3D = null
	var _s: Array = []
	var _cursor: int = 0
	static var _malla: ArrayMesh = null

	static func malla_piedra() -> ArrayMesh:
		if _malla == null:
			_malla = HieloMallas.bloque(0.3, 4.0)
		return _malla

	func montar(n: int, mundo: bool) -> void:
		top_level = mundo
		if mundo:
			transform = Transform3D.IDENTITY
		_mi = TierraToy.crear_mm("Piedras", n, malla_piedra(), 0.3)
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

	func emitir(pos: Vector3, vel: Vector3, vida: float, tam: float, giro: Vector3 = Vector3.ZERO) -> int:
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
		var g: Vector3 = giro if giro.length() > 0.01 else Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam": tam, "giro": g, "tono": randf(),
			"rot": Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), "rebotes": 0, "quieta": false}
		return hueco

	func vaciar() -> void:
		for i in _s.size():
			_s[i] = {"vivo": false}
			if _mi != null:
				HieloMallas.ocultar(_mi.multimesh, i)

	func _process(delta: float) -> void:
		avanzar(delta)

	func avanzar(delta: float) -> void:
		if _mi == null:
			return
		var mm: MultiMesh = _mi.multimesh
		for i in _s.size():
			var d: Dictionary = _s[i]
			if not bool(d["vivo"]):
				continue
			d["edad"] = float(d["edad"]) + delta
			var u: float = float(d["edad"]) / float(d["vida"])
			if u >= 1.0:
				d["vivo"] = false
				HieloMallas.ocultar(mm, i)
				continue
			if not bool(d["quieta"]):
				var v: Vector3 = d["vel"]
				v.y -= gravedad * delta
				var p: Vector3 = (d["pos"] as Vector3) + v * delta
				if p.y < suelo_y:
					p.y = suelo_y
					if int(d["rebotes"]) < 1 and v.y < -1.0:
						v.y = -v.y * 0.22
						v.x *= 0.45
						v.z *= 0.45
						d["rebotes"] = int(d["rebotes"]) + 1
						d["giro"] = (d["giro"] as Vector3) * 0.4
					else:
						v = Vector3.ZERO
						d["quieta"] = true
				d["vel"] = v
				d["pos"] = p
				var g: Vector3 = d["giro"]
				if g.length() > 0.001:
					d["rot"] = (Basis(g.normalized(), g.length() * delta) * (d["rot"] as Basis)).orthonormalized()
			var s: float = float(d["tam"]) * (1.0 - smoothstep(0.75, 1.0, u))           # al final se hunde (encoge), no se desvanece
			mm.set_instance_transform(i, Transform3D((d["rot"] as Basis) * Basis.from_scale(Vector3.ONE * s), d["pos"]))
			mm.set_instance_custom_data(i, Color(float(d["tono"]), 1.0, 0.0, 0.0))

	func estados() -> Array:
		var r: Array = []
		for i in _s.size():
			var d: Dictionary = _s[i]
			if bool(d["vivo"]):
				r.append({"hueco": i, "pos": d["pos"], "vel": d["vel"], "u": float(d["edad"]) / float(d["vida"]), "edad": float(d["edad"]), "quieta": bool(d["quieta"]), "rebotes": int(d["rebotes"])})
		return r


## ShaderMaterial de la roca (opaco, sin luz) con `p` encima.
static func material_roca(p: Dictionary = {}) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_ROCA)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## MultiMesh de `n` rocas (`malla`) con el material de la roca para instancias.
static func crear_mm(nombre: String, n: int, malla: Mesh, oscurecer: float = 0.0) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = maxi(n, 1)
	for i in mm.instance_count:
		HieloMallas.ocultar(mm, i)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material_roca({"instancias": 1.0, "oscurecer": oscurecer})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return mi


## Parámetros del polvo pardo (humo toon de dos tonos tierra).
static func polvo_params(tam_ini: float, tam_fin: float, vida: float, deriva: Vector3, mundo: bool) -> Dictionary:
	return {"claro": POLVO_CLARO, "sombra": POLVO_SOMBRA, "viejo": POLVO_VIEJO, "tam_ini": tam_ini, "tam_fin": tam_fin, "vida": vida, "deriva": deriva, "erosion": 0.9, "estirado": 1.0,
		"umbral": 0.42, "ruido_borde": 0.22, "mundo": mundo, "giro_vel": 0.4, "curva": 0.5, "friccion": 1.6}


## Bloque facetado unidad: caja de ±0,5 en x z y alto 1 (base en y = 0) con las esquinas movidas y la tapa estrechada e inclinada: cada cara es plana (dos triángulos no coplanarios = facetas).
static func prisma(semilla: float = 1.0) -> ArrayMesh:
	var h: Callable = func(a: float) -> float: return fposmod(sin(a * 12.9898 + semilla * 7.1) * 43758.5453, 1.0) - 0.5
	var b: Array = []
	var t: Array = []
	for i in 4:
		var sx: float = -0.5 if (i == 0 or i == 3) else 0.5
		var sz: float = -0.5 if i < 2 else 0.5
		b.append(Vector3(sx * (1.0 + 0.12 * h.call(float(i) + 1.0)), 0.0, sz * (1.0 + 0.12 * h.call(float(i) + 2.0))))
		t.append(Vector3(sx * (0.86 + 0.14 * h.call(float(i) + 3.0)), 1.0 + 0.1 * h.call(float(i) + 4.0), sz * (0.86 + 0.14 * h.call(float(i) + 5.0))))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: Vector3 = Vector3(0, 0.5, 0)
	for i in 4:
		var j: int = (i + 1) % 4
		HieloMallas._tri(st, b[i], b[j], t[j], c, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], 0.0, 0.0, 1.0)
		HieloMallas._tri(st, b[i], t[j], t[i], c, [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)], 0.0, 1.0, 1.0)
	HieloMallas._tri(st, t[0], t[1], t[2], c, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 1)], 1.0, 1.0, 1.0)
	HieloMallas._tri(st, t[0], t[2], t[3], c, [Vector2(0, 1), Vector2(1, 1), Vector2(0, 1)], 1.0, 1.0, 1.0)
	return st.commit()


@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
## Los bloques SUBEN con `sube` (0 → 1: anticipación, subida con sobrepaso y asentamiento; lo anima «nacer») y se HUNDEN con `hunde` (0 → 1; lo anima «morir»).
@export_range(0.0, 1.0, 0.01) var sube: float = 1.0
@export_range(0.0, 1.0, 0.01) var hunde: float = 0.0
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28                                 ## piedrecitas que convergen (tasa)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0                       ## sin uso
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0                         ## sin uso
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0
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
var _c_piedras: Node3D = null
var _c_acc: float = 0.0
var _pop: bool = false
var _roca: MeshInstance3D = null        ## BOLA
var _inclinable: Node3D = null
var _bloques: Array = []                ## figuras de volumen: [{pos, rot, wx, h, wz, retraso, tono}]
var _bloques_mm: MultiMeshInstance3D = null
var _polvo: Node3D = null               ## HumoToy pardo (mundo)
var _piedras: Node3D = null             ## Piedras (mundo)
var _asentado: bool = false             ## ¿ya soltó el polvo y los fragmentos del asentamiento?
var _hundiendo: bool = false
var _acc: float = 0.0
var _acc_p: float = 0.0
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _giro_bola: float = 0.0
var _bola_rota: bool = false
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
var _y_act: Array = []                  ## (pruebas) desplazamiento vertical actual de cada bloque (m; < 0 = aún bajo tierra)


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)
	_montar_reservas()
	_avanzar_bloques(0.0)


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
	_montar_reservas()
	_avanzar_bloques(0.0)


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
	_pop = false
	_bola_rota = false
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
	_quitar_visual_carga()


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


func _quitar_visual_carga() -> void:
	if _c_nodo != null and is_instance_valid(_c_nodo):
		var n: Node3D = _c_nodo
		_c_nodo = null
		_c_piedras = null
		if is_inside_tree():
			get_tree().create_timer(0.6).timeout.connect(n.queue_free)
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
				get_tree().create_timer(0.85).timeout.connect(queue_free)


## Piedrecitas que convergen en la mano (nodo «Carga», que no escala con la roca).
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	_c_piedras = Piedras.new()
	_c_piedras.name = "Convergencia"
	_c_piedras.gravedad = 0.0
	_c_nodo.add_child(_c_piedras)
	_c_piedras.call("montar", 24, false)
	_c_acc = 0.0


## Estado de la convergencia para las pruebas: piedrecitas vivas (local a la mano).
func estado_carga() -> Array:
	if _c_piedras == null or not is_instance_valid(_c_piedras):
		return []
	return _c_piedras.call("estados")


func _emitir_carga(delta: float, p: float) -> void:
	if _c_piedras == null or not is_instance_valid(_c_piedras):
		return
	var r0: float = _c_r * lerpf(3.0, 2.0, p) * carga_radio
	_c_acc += float(carga_chispas) * lerpf(0.4, 1.2, p) * delta
	var r_bola: float = _c_r * clampf(_c_escala, 0.05, 1.3) * 0.8
	while _c_acc >= 1.0:
		_c_acc -= 1.0
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.8, 0.6), randf_range(-1, 1)).normalized()
		var rr: float = r0 * randf_range(0.8, 1.2)
		_c_piedras.call("emitir", d * rr, -d * (rr - r_bola) / 0.4, 0.4, _c_r * randf_range(0.12, 0.2), Vector3.ZERO)


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoTierraToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoTierraToy = ImpactoTierraToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


## Los terrones y el polvo sueltos siguen cayendo aunque la roca desaparezca: pasan al padre y se liberan solos.
func _soltar_reservas() -> void:
	if get_parent() == null or not is_inside_tree():
		return
	var padre: Node = get_parent()
	for n in [_piedras, _polvo]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			padre.add_child(n)
			n.top_level = true
			n.transform = Transform3D.IDENTITY
			get_tree().create_timer(2.0).timeout.connect(n.queue_free)
	_piedras = null
	_polvo = null


func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	var imp: ImpactoTierraToy = ImpactoTierraToy.crear(ImpactoTierraToy.Variante.AREA, Vector3.UP, r)
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoTierraToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	_bola_rota = true
	_quitar_visual_carga()
	_soltar_reservas()
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoTierraToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
		_ult_pos = pos
	return nd


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	_crear_impacto(ImpactoTierraToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_bola_rota = true
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


## Las figuras de volumen nacen BAJO TIERRA: `sube` empieza en 0 (si no, el primer fotograma las vería ya asentadas y soltaría el polvo antes de tiempo).
func lanzar(v: float = -1.0) -> void:
	if figura != Figura.BOLA:
		sube = 0.0
		hunde = 0.0
		_asentado = false
		_avanzar_bloques(0.0)
		_brote_anticipo()
	super.lanzar(v)


## Brote inicial de polvo de la base de cada bloque al ordenar la subida (la anticipación se ve aunque el fotograma sea largo).
func _brote_anticipo() -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _bloques.is_empty() or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	var n: int = mini(_bloques.size() * 2, 12)
	for i in n:
		var b: Dictionary = _bloques[i % _bloques.size()]
		var loc: Vector3 = (b["pos"] as Vector3) + Vector3(randf_range(-0.5, 0.5) * float(b["wx"]) * ancho, 0.04, randf_range(-0.5, 0.5) * float(b["wz"]) * ancho)
		_polvo.call("emitir", tr * loc, tr.basis * Vector3(randf_range(-0.5, 0.5), 0.6, randf_range(-0.5, 0.5)), 0.8, 0.7)


## Una bola que muere sin impacto se deshace en terrones. Las demás figuras se hunden con `hunde`.
func morir() -> void:
	if figura == Figura.BOLA and not _bola_rota and _piedras != null and is_instance_valid(_piedras) and is_inside_tree():
		_bola_rota = true
		_romper_bola()
	super.morir()


func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "tierra") -> void:
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
	_roca = null
	_inclinable = null
	_bloques = []
	_bloques_mm = null
	_asentado = false
	_hundiendo = false
	_acc = 0.0
	_acc_p = 0.0
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
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
	_anim_si_hace_falta()


static func _b(pos: Vector3, rot: Basis, wx: float, h: float, wz: float, retraso: float, rng: RandomNumberGenerator) -> Dictionary:
	return {"pos": pos, "rot": rot, "wx": wx, "h": h, "wz": wz, "retraso": retraso, "tono": rng.randf()}


func _montar_bloques(c: Node3D, capa: Array, malla: Mesh) -> void:
	if capa.size() > MAX_BLOQUES:
		capa = capa.slice(0, MAX_BLOQUES)
	_bloques = capa
	_bloques_mm = crear_mm("Bloques", _bloques.size(), malla)
	c.add_child(_bloques_mm)


## BOLA: pedrusco facetado que gira (quieto despacio, en vuelo deprisa sobre el eje del vuelo).
func _bola(c: Node3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	_inclinable = Node3D.new()
	_inclinable.name = "Inclinable"
	c.add_child(_inclinable)
	_roca = MeshInstance3D.new()
	_roca.name = "Roca"
	_roca.mesh = HieloMallas.bloque(0.2, 1.0 + randf() * 5.0)
	_roca.material_override = material_roca()
	_roca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_roca.scale = Vector3(r, r * semieje_y / maxf(r, 0.001), r)
	_inclinable.add_child(_roca)


## MURO: hilera de bloques facetados a lo largo de x (más altos hacia el centro), cada uno con su pequeño retraso al subir.
func _muro(c: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23 + int(semieje_x * 100.0)
	var n: int = clampi(int(round(2.0 * semieje_x / 0.62)), 3, MAX_BLOQUES)
	var w: float = 2.0 * semieje_x / float(n)
	var capa: Array = []
	for i in n:
		var x: float = -semieje_x + w * (float(i) + 0.5)
		var env: float = 1.0 - 0.28 * pow(absf(x) / maxf(semieje_x, 0.01), 2.5)
		var hh: float = semieje_y * rng.randf_range(0.8, 1.0) * env
		capa.append(_b(Vector3(x, 0.0, rng.randf_range(-0.2, 0.2) * semieje_z), Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)), w * 1.02, hh, maxf(2.0 * semieje_z, 0.25), absf(x) / maxf(semieje_x, 0.01) * 0.25, rng))
	_montar_bloques(c, capa, prisma(2.0))


## PILAR: un bloque alto en el centro y cuatro más bajos pegados, ligeramente inclinados hacia fuera.
func _pilar(c: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 37
	var capa: Array = []
	capa.append(_b(Vector3.ZERO, Basis(Vector3.UP, rng.randf() * TAU), semieje_x * 1.4, semieje_y, semieje_z * 1.4, 0.0, rng))
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + rng.randf_range(-0.3, 0.3)
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		capa.append(_b(Vector3(d.x * semieje_x * 1.1, 0.0, d.z * semieje_z * 1.1), HieloMallas._inclinar(d, rng.randf_range(0.08, 0.18), a), semieje_x * 0.9, semieje_y * rng.randf_range(0.28, 0.5), semieje_z * 0.9, 0.12 + 0.05 * float(k), rng))
	_montar_bloques(c, capa, prisma(3.0))


## BARRERA: corona de bloques inclinados hacia dentro sobre la elipse del suelo.
func _barrera(c: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	var perim: float = FuegoToyMallas.perimetro_elipse(semieje_x, semieje_z)
	var n: int = clampi(int(round(perim / 0.7)), 6, MAX_BLOQUES)
	var capa: Array = []
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var w: float = perim / float(n) * 0.9
		capa.append(_b(Vector3(d.x * semieje_x * 0.92, 0.0, d.z * semieje_z * 0.92), HieloMallas._inclinar(-d, rng.randf_range(0.25, 0.42), atan2(-d.x, -d.z)), w, semieje_y * rng.randf_range(0.75, 1.0), w * 0.6, rng.randf_range(0.0, 0.2), rng))
	_montar_bloques(c, capa, prisma(4.0))


## HAZ: hilera de púas de piedra que BROTAN del suelo hacia -Z (cada una sale después de la anterior), cada vez más bajas.
func _haz(c: Node3D) -> void:
	_haz_largo = semieje_x * 2.0
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 53
	var n: int = clampi(int(round(_haz_largo / 0.3)), 4, MAX_BLOQUES)
	var capa: Array = []
	for i in n:
		var f: float = (float(i) + 0.5) / float(n)
		var w: float = clampf(_haz_r * rng.randf_range(0.35, 0.55), 0.06, 0.5)
		var lado: Vector3 = Vector3(rng.randf_range(-0.6, 0.6), 0.0, 0.0) * _haz_r
		capa.append(_b(Vector3(lado.x, 0.0, -f * _haz_largo), HieloMallas._inclinar(Vector3(0, 0, -1), rng.randf_range(0.15, 0.35), 0.0), w, _haz_alt * 2.0 * rng.randf_range(0.8, 1.2) * (1.15 - 0.5 * f), w, f * 0.6, rng))
	_montar_bloques(c, capa, HieloMallas.cristal(5, 7.0))


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	if ap != null and _figura_anim == int(figura):
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	var es_vol: bool = figura != Figura.BOLA
	var nacer: float = T_NACER_BOLA
	var morir_s: float = T_MORIR_BOLA
	if figura == Figura.HAZ:
		nacer = T_NACER_HAZ
		morir_s = T_MORIR
	elif es_vol:
		nacer = T_NACER
		morir_s = T_MORIR
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:sube" if (es_vol and nom == "nacer") else (".:hunde" if es_vol else ".:aparicion")))
		match nom:
			"nacer":
				an.length = nacer
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, nacer, 1.0)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
				an.track_insert_key(pista, morir_s, 1.0 if es_vol else 0.0)
		an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s


# ------------------------------------------------------------------ subir, asentarse y hundirse ------------------------------------------------------------------

## Desplazamiento vertical (fracción del alto, 0 = en su sitio, −1 = bajo tierra) de un bloque con `s` (0..1 tras su anticipación): sube deprisa, se pasa SOBREPASO y se asienta.
static func subida(s: float) -> float:
	var u: float = clampf(s, 0.0, 1.0)
	if u < 0.62:
		return -1.0 + (1.0 + SOBREPASO) * smoothstep(0.0, 1.0, u / 0.62)
	return SOBREPASO * (1.0 - smoothstep(0.0, 1.0, (u - 0.62) / 0.38))


## (pruebas) desplazamiento vertical actual (m) de cada bloque.
func alturas_actuales() -> Array:
	return _y_act


## Pone cada bloque según `sube` (anticipación → subida con sobrepaso → asentamiento) y `hunde` (temblor y bajada bajo tierra). Suelta el polvo y los fragmentos en su momento.
func _avanzar_bloques(delta: float) -> void:
	if _bloques_mm == null or not is_instance_valid(_bloques_mm) or _bloques.is_empty():
		return
	var mm: MultiMesh = _bloques_mm.multimesh
	var sb: float = clampf(sube, 0.0, 1.0)
	var hd: float = clampf(hunde, 0.0, 1.0)
	var tt: float = Time.get_ticks_msec() * 0.001
	_y_act = []
	var k_ant: float = ANTICIPO if figura != Figura.HAZ else 0.05
	var asentados: int = 0
	for j in _bloques.size():
		var b: Dictionary = _bloques[j]
		var ret: float = float(b["retraso"])
		var h: float = float(b["h"]) * altura
		var s: float = clampf((sb - k_ant - ret * (1.0 - k_ant)) / maxf(1.0 - k_ant - ret * (1.0 - k_ant), 0.01), 0.0, 1.0)
		var y: float = subida(s) * h
		if s >= 0.95:
			asentados += 1
		var pos: Vector3 = b["pos"]
		if sb < k_ant + ret or (hd > 0.0 and hd < 0.3):                              # anticipación: temblor antes de salir; al morir, tiembla antes de hundirse
			pos += Vector3(sin(tt * 61.0 + float(j) * 1.7), 0.0, cos(tt * 53.0 + float(j))) * 0.015
		if hd > 0.0:
			y -= h * 1.05 * smoothstep(0.25, 1.0, hd)
		_y_act.append(y)
		var visible: bool = y > -h * 0.999
		HieloMallas.poner(mm, j, pos + Vector3(0, y, 0), b["rot"], float(b["wx"]) * ancho, h if visible else 0.0, float(b["wz"]) * ancho, float(b["tono"]), 1.0, 0.0)
	if delta > 0.0 and is_inside_tree():
		_polvo_de_bloques(delta, sb, hd, k_ant, asentados)


## El polvo de la construcción: en la anticipación sale de la base; al asentarse, polvo radial bajo + fragmentos que ruedan (una vez); al hundirse, polvo mientras baja.
func _polvo_de_bloques(delta: float, sb: float, hd: float, k_ant: float, asentados: int) -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _piedras == null or not is_instance_valid(_piedras):
		return
	var tr: Transform3D = global_transform
	var k: float = clampf(chispas, 0.0, 1.0)
	_piedras.set("suelo_y", global_position.y + 0.01)
	if sb < k_ant + 0.2 and sb > 0.0 and asentados == 0:                               # anticipación (y los bloques que aún esperan su retraso): polvo que brota de la base
		_acc += 40.0 * k * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var b: Dictionary = _bloques[randi() % _bloques.size()]
			var loc: Vector3 = (b["pos"] as Vector3) + Vector3(randf_range(-0.5, 0.5) * float(b["wx"]), 0.05, randf_range(-0.5, 0.5) * float(b["wz"]))
			_polvo.call("emitir", tr * loc, tr.basis * Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4)), 0.7, 0.6)
	elif asentados > 0 and not _asentado and hd <= 0.0:
		_asentado = true
		for b2 in _bloques:
			var w: float = float(b2["wx"]) * ancho
			var p0: Vector3 = b2["pos"]
			for q in 3:
				var a: float = randf() * TAU
				var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
				_polvo.call("emitir", tr * (p0 + d * w * 0.5 + Vector3(0, 0.05, 0)), tr.basis * (d * randf_range(1.2, 2.2) + Vector3(0, 0.3, 0)), 1.0, randf_range(0.8, 1.3) * sqrt(maxf(w, 0.3)))
			if randf() < 0.75 * k:
				var a2: float = randf() * TAU
				var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
				_piedras.call("emitir", tr * (p0 + Vector3(0, 0.1, 0) + d2 * w * 0.5), tr.basis * (d2 * randf_range(1.0, 2.2) + Vector3(0, randf_range(1.0, 2.0), 0)), randf_range(1.0, 1.6), randf_range(0.05, 0.1) * sqrt(maxf(w, 0.3)))
	elif hd > 0.25 and hd < 0.95:
		_acc += 22.0 * k * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var b3: Dictionary = _bloques[randi() % _bloques.size()]
			var a3: float = randf() * TAU
			var d3: Vector3 = Vector3(cos(a3), 0.0, sin(a3))
			_polvo.call("emitir", tr * ((b3["pos"] as Vector3) + d3 * float(b3["wx"]) * 0.5 + Vector3(0, 0.05, 0)), tr.basis * (d3 * randf_range(0.6, 1.4) + Vector3(0, 0.4, 0)), 0.8, 0.8)
	if hd >= 0.98:
		_soltar_reservas()


## La bola que muere sin impacto: terrones de su superficie que caen, y polvo.
func _romper_bola() -> void:
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	var tr: Transform3D = global_transform
	_piedras.set("suelo_y", global_position.y - altura_suelo)
	for k in 14:
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_piedras.call("emitir", tr * (d * r * randf_range(0.3, 0.9)), tr.basis * (d * randf_range(0.6, 2.0)) + _vel_mundo * 0.3, randf_range(0.8, 1.3), randf_range(0.06, 0.14) * sqrt(maxf(r / 0.4, 0.4)))
	if _polvo != null and is_instance_valid(_polvo):
		for q in 6:
			var d2: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)).normalized()
			_polvo.call("emitir", tr * (d2 * r * 0.5), tr.basis * d2 * 1.2, 1.0, 1.0)


# ------------------------------------------------------------------ vuelo y reservas ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v


## Reservas de polvo (humo toon pardo, en el mundo) y de piedras (terrones y fragmentos, en el mundo).
func _montar_reservas() -> void:
	if _polvo != null and is_instance_valid(_polvo) and _piedras != null and is_instance_valid(_piedras):
		return
	for n in [_polvo, _piedras]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	var r: float = maxf(semieje_x, semieje_z) if figura == Figura.BOLA else 0.4
	_polvo = HumoToy.new()
	_polvo.name = "Polvo"
	add_child(_polvo)
	_polvo.call("montar", POLVO_FIG, polvo_params(0.28 * sqrt(maxf(r / 0.4, 0.4)), 0.7 * sqrt(maxf(r / 0.4, 0.4)), 1.0, Vector3(0, 0.35, 0), true))
	_piedras = Piedras.new()
	_piedras.name = "Terrones"
	add_child(_piedras)
	_piedras.call("montar", PIEDRAS_FIG, true)


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	_avanzar_bola(delta)
	_avanzar_bloques(delta)
	_emitir_bola(delta)


func _avanzar_bola(delta: float) -> void:
	if _inclinable == null or not is_instance_valid(_inclinable):
		return
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO
	_giro_bola += (GIRO_VUELO if vuela else GIRO_QUIETA) * velocidad * delta
	if vuela:
		_inclinable.rotation = Vector3(_giro_bola, 0.3, 0.0)                  # rueda sobre el eje X: gira «hacia delante» al volar
	else:
		_inclinable.rotation = Vector3(0.2, _giro_bola, 0.1)


## La bola en vuelo suelta terrones que caen y polvo que se queda atrás.
func _emitir_bola(delta: float) -> void:
	if figura != Figura.BOLA or _piedras == null or not is_instance_valid(_piedras) or not _listo or delta <= 0.0 or not is_inside_tree():
		return
	var pos: Vector3 = global_position
	if _tiene_ult:
		_vel_mundo = (pos - _ult_pos) / delta
	_ult_pos = pos
	_tiene_ult = true
	if _cuerpo == null or not _cuerpo.visible or _est == EstadoCarga.CANCELANDO or _est == EstadoCarga.APAGANDO or not proyectil:
		return
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	var k: float = clampf(chispas, 0.0, 1.0) * clampf(_c_escala, 0.0, 1.0)
	_piedras.set("suelo_y", pos.y - altura_suelo)
	_acc_p += 9.0 * k * delta
	var tr: Transform3D = global_transform
	while _acc_p >= 1.0:
		_acc_p -= 1.0
		var loc: Vector3 = Vector3(randf_range(-0.5, 0.5) * r, randf_range(-0.5, 0.3) * r, r * randf_range(0.5, 1.2))
		_piedras.call("emitir", tr * loc, _vel_mundo * 0.25 + tr.basis * Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), 0.3), randf_range(0.7, 1.1), randf_range(0.04, 0.09) * sqrt(maxf(r / 0.4, 0.3)))
	if _polvo != null and is_instance_valid(_polvo):
		_acc += 7.0 * k * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var loc2: Vector3 = Vector3(randf_range(-0.4, 0.4) * r, randf_range(-0.3, 0.3) * r, r * randf_range(0.8, 1.3))
			_polvo.call("emitir", tr * loc2, _vel_mundo * 0.15 + tr.basis * Vector3(randf_range(-0.4, 0.4), 0.2, 0.2), 0.8, 0.8)
