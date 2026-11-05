class_name NubeVenenoVfx
extends Node3D

## EL DIBUJO DE LA NUBE DE VENENO (5/11/2026, naturaleza «toy»): gas tóxico a ras de suelo, blando y TRANSLÚCIDO (se ve a través la jugadora, los enemigos y las hojas).
## Lo monta `NubeVeneno3D` como hijo y lo mueve con `avanzar` (la lógica de la nube no depende de él). Son solo MultiMesh movidos por CPU (sin GPUParticles), con los shaders de naturaleza:
##   · BOCANADAS: manchas blandas de cartel (naturaleza_blob), verde oscuro / verde / verde claro, de opacidad muy baja, que se arremolinan despacio dentro del radio.
##   · MANCHA DEL SUELO: disco tenue de borde irregular (nube_veneno_suelo) que marca el radio exacto, que es lo que envenena.
##   · BURBUJAS: aros pequeños que suben y REVIENTAN (se ensanchan y se apagan) · MOTAS: espora que sube; al arder se vuelven chispas naranjas que acaban en ceniza.
## ESTADOS, todos derivados de lo que ya sabe la nube (no guarda lógica propia):
##   NACER (brota desde el centro, T_NACER s) · VIVIR (remolino y respiración; la permanente no parpadea) · VIENTO (la nube se mueve: las bocanadas se quedan ATRÁS según la velocidad, así que se estira
##   y se deshilacha sola) · FUEGO (se amarillea, se consume bocanada a bocanada soltando chispas) · DISIPARSE (en el último T_DESVANECE s sube, se ensancha y se apaga).
## Rendimiento: con `MAX_COMPLETOS` nubes dibujadas a la vez, las siguientes salen en versión LIGERA (menos bocanadas, sin burbujas ni motas). `estado()` lo leen las pruebas.

const N_BOCANADAS: int = 16
const N_BOCANADAS_LIGERO: int = 7
const N_BURBUJAS: int = 6
const N_MOTAS: int = 14
const N_MOTAS_VIVAS: int = 5                   ## las que se ven en reposo (el resto solo al arder)
const MAX_COMPLETOS: int = 6

const T_NACER: float = 0.8
const T_DESVANECE: float = 1.4
const V_VIENTO: float = 1.4                    ## u/s: velocidad con la que se considera «a pleno viento» (= NubeVeneno3D.DERIVA)
const ALFA_BOCANADA: float = 0.12
const ALFA_MAX: float = 0.22                   ## tope de la opacidad de UNA bocanada: la nube nunca es un polígono opaco

const VERDE_OSCURO: Color = Color(0.14, 0.46, 0.20)
const VERDE: Color = Color(0.45, 0.80, 0.27)
const VERDE_CLARO: Color = Color(0.62, 0.92, 0.34)
const VERDE_NUCLEO: Color = Color(0.86, 1.0, 0.68)         ## el centro de la bola de veneno
const AMARILLO_QUEMA: Color = Color(0.80, 0.86, 0.30)      ## la nube que arde se aclara hacia verde amarillento
const CHISPA: Color = Color(0.95, 0.42, 0.10)              ## naranja de fuego (el de las hojas que arden)
const CENIZA: Color = Color(0.30, 0.28, 0.20)

static var completos: int = 0

var radio_u: float = 2.3
var ligero: bool = false
var _contado: bool = false
var _t: float = 0.0
var _prev: Vector3 = Vector3.ZERO
var _tiene_prev: bool = false
var _vel: Vector3 = Vector3.ZERO
var _quema_ini: float = -1.0
var _quema_t: float = 0.0
var _bocanadas: Array = []
var _mm_boc: MultiMeshInstance3D = null
var _mm_bur: MultiMeshInstance3D = null
var _mm_mot: MultiMeshInstance3D = null
var _suelo: MeshInstance3D = null
var _mat_suelo: ShaderMaterial = null
## Lo último dibujado (las pruebas: en headless el MultiMesh no guarda datos)
var _alfas: PackedFloat32Array = PackedFloat32Array()
var _tams: PackedFloat32Array = PackedFloat32Array()
var _pos_boc: PackedVector3Array = PackedVector3Array()
var _col_boc: Array = []
var _est: Dictionary = {}


func montar(p_radio_u: float) -> void:
	radio_u = maxf(p_radio_u, 0.1)
	ligero = NubeVenenoVfx.completos >= MAX_COMPLETOS
	if not _contado:
		_contado = true
		NubeVenenoVfx.completos += 1
	var n: int = N_BOCANADAS_LIGERO if ligero else N_BOCANADAS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + int(radio_u * 100.0)
	_bocanadas.clear()
	for i in n:
		var f: float = (float(i) + 0.5) / float(n)
		_bocanadas.append({
			"ang0": float(i) * 2.399963 + rng.randf() * 0.4,
			"rad": 0.12 + 0.62 * sqrt(f) + rng.randf_range(-0.04, 0.04),
			"h0": rng.randf_range(0.18, 0.75),
			"tam": rng.randf_range(0.34, 0.8),
			"fase": rng.randf() * TAU,
			"lag": rng.randf_range(0.2, 1.6),
			"tono": i % 3,
			"orden": rng.randf(),
			"sentido": 1.0 if i % 4 != 3 else -0.6,
		})
	_mm_boc = NaturalezaManchas.crear_mm("Bocanadas", n, 0.0, 0.42)
	((_mm_boc.material_override as ShaderMaterial)).set_shader_parameter("color_nucleo", VERDE_NUCLEO)
	add_child(_mm_boc)
	_alfas.resize(n)
	_tams.resize(n)
	_pos_boc.resize(n)
	_col_boc.resize(n)
	if not ligero:
		_mm_bur = NaturalezaManchas.crear_mm("Burbujas", N_BURBUJAS, 0.0, 0.3)
		((_mm_bur.material_override as ShaderMaterial)).set_shader_parameter("anillo", 1.0)
		add_child(_mm_bur)
		_mm_mot = NaturalezaManchas.crear_mm("Motas", N_MOTAS, 0.0, 0.5)
		add_child(_mm_mot)
	var q := QuadMesh.new()
	q.size = Vector2(radio_u * 2.0, radio_u * 2.0)
	_mat_suelo = ShaderMaterial.new()
	_mat_suelo.shader = load("res://presentacion/vfx/toy/nube_veneno_suelo.gdshader") as Shader
	_suelo = MeshInstance3D.new()
	_suelo.name = "Suelo"
	_suelo.mesh = q
	_suelo.material_override = _mat_suelo
	_suelo.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_suelo.position = Vector3(0.0, 0.05, 0.0)
	_suelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_suelo)


func _exit_tree() -> void:
	if _contado:
		_contado = false
		NubeVenenoVfx.completos = maxi(NubeVenenoVfx.completos - 1, 0)


func _enter_tree() -> void:
	if not _contado and not _bocanadas.is_empty():
		_contado = true
		NubeVenenoVfx.completos += 1


## Un paso del dibujo. `p_mundo` es la posición de la nube; el resto es su estado (edad en s, vida que le queda, si es permanente, si arde).
func avanzar(dt: float, p_mundo: Vector3, edad: float, vida: float, vida_max: float, permanente: bool, ardiendo: bool) -> void:
	if _mm_boc == null:
		return
	_t += dt
	if _tiene_prev and dt > 0.0001:
		var v: Vector3 = (p_mundo - _prev) / dt
		v.y = 0.0
		_vel = _vel.lerp(v, 1.0 - exp(-dt / 0.3))
	elif dt > 0.0001:
		_vel = _vel.lerp(Vector3.ZERO, 0.5)
	_prev = p_mundo
	_tiene_prev = true
	var nacer: float = smoothstep(0.0, 1.0, edad / T_NACER)
	var desv: float = 1.0 if permanente else smoothstep(0.0, 1.0, vida / minf(T_DESVANECE, maxf(vida_max * 0.5, 0.2)))
	var consumo: float = 0.0
	var quema: float = 0.0
	if ardiendo:
		if _quema_ini < 0.0:
			_quema_ini = maxf(vida, 0.2)
		_quema_t += dt
		consumo = clampf(1.0 - vida / _quema_ini, 0.0, 1.0)
		quema = smoothstep(0.0, 1.0, _quema_t / 0.5)
	var viento: float = clampf(_vel.length() / V_VIENTO, 0.0, 1.0)
	var disolver: float = 1.0 - desv
	var refuerzo: float = 1.5 if ligero else 1.0
	# --- bocanadas ---
	var mm: MultiMesh = _mm_boc.multimesh
	var tonos: Array = [VERDE_OSCURO, VERDE, VERDE_CLARO]
	var amax: float = 0.0
	for i in _bocanadas.size():
		var b: Dictionary = _bocanadas[i]
		var rad: float = float(b["rad"])
		var ang: float = float(b["ang0"]) + float(b["sentido"]) * _t * (0.38 / (0.45 + rad))
		var fase: float = float(b["fase"])
		var lag: float = float(b["lag"])
		var rr: float = rad * radio_u * nacer * (1.0 - 0.18 * consumo) * (1.0 + 0.12 * disolver)
		var x: float = cos(ang) * rr + 0.05 * radio_u * sin(_t * 0.7 + fase) - _vel.x * lag
		var z: float = sin(ang) * rr + 0.05 * radio_u * cos(_t * 0.6 + fase) - _vel.z * lag
		var y: float = float(b["h0"]) + 0.07 * sin(_t * 0.9 + fase) + disolver * 0.45 + consumo * 0.3 + (1.0 - nacer) * -0.1
		var tam: float = float(b["tam"]) * radio_u * (0.4 + 0.6 * nacer) * (1.0 + 0.3 * disolver) * (1.0 - 0.4 * viento * lag) * (1.0 - 0.3 * consumo)
		var orden: float = float(b["orden"])
		var vivo: float = 1.0 - smoothstep(orden * 0.7, orden * 0.7 + 0.3, consumo)
		var a: float = ALFA_BOCANADA * refuerzo * smoothstep(0.0, 0.6, edad / T_NACER) * desv * (1.0 - 0.65 * viento * lag) * vivo
		if not permanente:
			a *= 1.0 + 0.1 * sin(_t * 1.3 + fase)               # (respira un poco; la permanente, quieta)
		a = clampf(a, 0.0, ALFA_MAX)
		var col: Color = (tonos[int(b["tono"])] as Color).lerp(AMARILLO_QUEMA, quema * (0.6 + 0.3 * float(int(b["tono"]) == 2)))
		col.a = a
		_alfas[i] = a
		_tams[i] = tam
		_pos_boc[i] = Vector3(x, y, z)
		_col_boc[i] = col
		amax = maxf(amax, a)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tam, tam, tam)), Vector3(x, y, z)))
		mm.set_instance_color(i, col.srgb_to_linear())
	# --- mancha del suelo ---
	var col_s: Color = VERDE.lerp(AMARILLO_QUEMA, quema * 0.7)
	_mat_suelo.set_shader_parameter("color", col_s)
	var aro: Color = VERDE_OSCURO.lerp(CENIZA, consumo * 0.8)
	_mat_suelo.set_shader_parameter("color_aro", aro)
	_mat_suelo.set_shader_parameter("alfa", smoothstep(0.0, 0.5, edad / T_NACER) * desv * (1.0 - consumo * 0.85))
	_mat_suelo.set_shader_parameter("crece", maxf(nacer, 0.02))
	_mat_suelo.set_shader_parameter("tiempo", _t)
	# --- burbujas y motas ---
	var gen: float = nacer * desv
	var burb_vivas: int = 0
	var mota_vivas: int = 0
	if _mm_bur != null:
		var mb: MultiMesh = _mm_bur.multimesh
		for k in N_BURBUJAS:
			var T: float = 1.7 + 0.23 * float(k)
			var u: float = (_t + float(k) * 0.61) / T
			var c: float = floorf(u)
			u -= c
			var px: float = _azar(k, c, 1.0) * 2.0 - 1.0
			var pz: float = _azar(k, c, 2.0) * 2.0 - 1.0
			var d: float = sqrt(px * px + pz * pz)
			if d > 1.0:
				px /= d
				pz /= d
			var bx: float = px * 0.7 * radio_u * nacer
			var bz: float = pz * 0.7 * radio_u * nacer
			var sube: float = minf(u / 0.82, 1.0)
			var tam_b: float = 0.07 + 0.09 * sube
			var al_b: float = 0.55
			if u > 0.82:
				var v: float = (u - 0.82) / 0.18                    # revienta: se ensancha y se apaga
				tam_b = 0.16 + 0.16 * v
				al_b = 0.55 * (1.0 - v)
			al_b *= gen * (1.0 - consumo) * (1.0 - quema * 0.5)
			if al_b > 0.02:
				burb_vivas += 1
			mb.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(tam_b, tam_b, tam_b)), Vector3(bx - _vel.x * 0.4, 0.1 + 0.75 * sube, bz - _vel.z * 0.4)))
			var cb: Color = VERDE_CLARO.lerp(AMARILLO_QUEMA, quema)
			cb.a = al_b
			mb.set_instance_color(k, cb.srgb_to_linear())
		var mo: MultiMesh = _mm_mot.multimesh
		for k in N_MOTAS:
			var chispa: bool = k >= N_MOTAS_VIVAS
			var T2: float = (0.9 + 0.17 * float(k % 5)) if chispa else (2.4 + 0.3 * float(k))
			var u2: float = (_t * (1.5 if chispa else 1.0) + float(k) * 0.37) / T2
			var c2: float = floorf(u2)
			u2 -= c2
			var qx: float = _azar(k + 20, c2, 1.0) * 2.0 - 1.0
			var qz: float = _azar(k + 20, c2, 2.0) * 2.0 - 1.0
			var dd: float = sqrt(qx * qx + qz * qz)
			if dd > 1.0:
				qx /= dd
				qz /= dd
			var mx: float = qx * 0.8 * radio_u * nacer * (1.0 - 0.25 * consumo) + 0.08 * sin(_t * 2.0 + float(k))
			var mz: float = qz * 0.8 * radio_u * nacer * (1.0 - 0.25 * consumo) + 0.08 * cos(_t * 1.7 + float(k))
			var my: float = 0.1 + u2 * (1.3 if chispa else 1.0)
			var cm: Color = VERDE_CLARO
			var amota: float = (0.9 if k >= N_MOTAS_VIVAS else 0.5) * sin(PI * u2) * gen
			var tam_m: float = 0.06
			if chispa:
				# solo al arder, y más cuanto más se consume: naranja al nacer, ceniza al subir
				amota *= quema * clampf(0.35 + consumo * 1.2, 0.0, 1.0)
				cm = CHISPA.lerp(CENIZA, smoothstep(0.45, 1.0, u2))
				tam_m = 0.09
			else:
				amota *= 1.0 - quema
			if amota > 0.02:
				mota_vivas += 1
			mo.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(tam_m, tam_m, tam_m)), Vector3(mx - _vel.x * 0.3, my, mz - _vel.z * 0.3)))
			cm.a = amota
			mo.set_instance_color(k, cm.srgb_to_linear())
	_est = {"nacer": nacer, "desv": desv, "consumo": consumo, "quema": quema, "viento": viento, "alfa_max": amax, "burbujas": burb_vivas, "motas": mota_vivas, "vel": _vel}


## Para las pruebas: lo último dibujado.
func estado() -> Dictionary:
	var e: Dictionary = _est.duplicate()
	e["ligero"] = ligero
	e["bocanadas"] = _bocanadas.size()
	e["instancias"] = _bocanadas.size() + (N_BURBUJAS + N_MOTAS if _mm_bur != null else 0)
	e["alfas"] = _alfas
	e["tams"] = _tams
	e["pos"] = _pos_boc
	e["colores"] = _col_boc
	e["radio_u"] = radio_u
	return e


## Un número pseudoaleatorio estable en [0, 1) para (a, b, c): las burbujas y motas no guardan estado, cada ciclo sale en un sitio distinto.
static func _azar(a: int, b: float, c: float) -> float:
	return fposmod(sin(float(a) * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453, 1.0)
