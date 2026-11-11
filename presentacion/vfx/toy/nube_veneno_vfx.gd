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

## GAS PESADO (11/11, docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md top 5 nº 4; encendido de serie desde el 11/11, se apaga con el ajuste `magic_symbols/vfx_veneno_gas_pesado` o `-- veneno-pesado`):
## las bocanadas dejan de orbitar y siguen un CampoViento propio (turbulencia sin divergencia que, ceñida al SUELO, solo gira en horizontal; el viento es la deriva de la nube; rodean casillas,
## enemigos y bloques), con arrastre 0,7 (el de la demo: con viento se quedan atrás y se deshilachan solas), un muelle blando a su sitio y PESO (se quedan a ras de suelo). Mismos verdes y misma mancha.
static var gas_pesado: bool = OS.get_cmdline_user_args().has("veneno-pesado") or bool(ProjectSettings.get_setting("magic_symbols/vfx_veneno_gas_pesado", true))     # 11/11 (Pablo: «enciéndelas todas»): de serie
## HUMO AL ARDER (encendido de serie desde el 11/11; se apaga con `magic_symbols/vfx_veneno_humo` o `-- veneno-humo`): la nube que arde (`NubeVeneno3D.quemar`, la interacción veneno + fuego que ya había) suelta humo PARDO
## de HumoRegla (materia HUMO, sus colores): el gas que arde se frena y da hollín. Sigue a la nube y, al irse ella, lo ya soltado se acaba solo.
static var humo_al_arder: bool = OS.get_cmdline_user_args().has("veneno-humo") or bool(ProjectSettings.get_setting("magic_symbols/vfx_veneno_humo", true))     # 11/11 (Pablo: «enciéndelas todas»): de serie
const MUELLE: float = 1.4            ## 1/s²: tirón horizontal hacia el sitio de cada bocanada (sin él el viento se la llevaría entera)
const PESO: float = 3.0              ## 1/s²: tirón hacia su altura (gas pesado: no sube sola)
const AMORT_Y: float = 2.2           ## 1/s
const T_SOLIDOS: float = 0.4         ## s entre dos recogidas de sólidos

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
## Gas pesado: el campo que muestrean las bocanadas, su posición (local a la nube) y su velocidad (mundo).
var campo: CampoViento = null
var _gp_pos: PackedVector3Array = PackedVector3Array()
var _gp_vel: PackedVector3Array = PackedVector3Array()
var _gp_listo: bool = false
var _gp_sol_t: float = 0.0
var _gp_ult: Vector3 = Vector3.ZERO
var _humo: HumoRegla = null
var _humo_hecho: bool = false


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
	var gas: bool = gas_pesado
	if gas:
		_mover_gas(dt, p_mundo, nacer, consumo, disolver)
	else:
		_gp_listo = false
	if ardiendo and humo_al_arder:
		_humo_veneno(quema, consumo)
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
		var k_tam: float = 1.0 - 0.4 * viento * lag
		var k_alfa: float = 1.0 - 0.65 * viento * lag
		if gas:
			# gas pesado: la posición sale del campo (ver _mover_gas); lo que el viento ha sacado del radio se estira y se apaga (se deshilacha)
			var q: Vector3 = _gp_pos[i]
			x = q.x
			y = q.y
			z = q.z
			var fuera: float = smoothstep(1.0, 1.7, Vector2(x, z).length() / radio_u)
			k_tam = 1.0 - 0.3 * fuera
			k_alfa = 1.0 - fuera
		var tam: float = float(b["tam"]) * radio_u * (0.4 + 0.6 * nacer) * (1.0 + 0.3 * disolver) * k_tam * (1.0 - 0.3 * consumo)
		var orden: float = float(b["orden"])
		var vivo: float = 1.0 - smoothstep(orden * 0.7, orden * 0.7 + 0.3, consumo)
		var a: float = ALFA_BOCANADA * refuerzo * smoothstep(0.0, 0.6, edad / T_NACER) * desv * k_alfa * vivo
		if not permanente:
			a *= 1.0 + 0.1 * sin(_t * 1.3 + fase)               # (respira un poco; la permanente, quieta)
		a = clampf(a, 0.0, ALFA_MAX)
		var col: Color = (tonos[int(b["tono"])] as Color).lerp(AMARILLO_QUEMA, quema * (0.6 + 0.3 * float(int(b["tono"]) == 2)))
		_alfas[i] = a
		_tams[i] = tam
		_pos_boc[i] = Vector3(x, y, z)
		_col_boc[i] = col
	if gas:
		_limitar_opacidad()
	for i in _bocanadas.size():
		var col: Color = _col_boc[i]
		var a: float = _alfas[i]
		var tam: float = _tams[i]
		col.a = a
		_col_boc[i] = col
		amax = maxf(amax, a)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tam, tam, tam)), _pos_boc[i]))
		mm.set_instance_color(i, col.srgb_to_linear())
	# --- mancha del suelo ---
	var col_s: Color = VERDE.lerp(AMARILLO_QUEMA, quema * 0.7)
	_mat_suelo.set_shader_parameter("color", col_s)
	var aro: Color = VERDE_OSCURO.lerp(CENIZA, consumo * 0.8)
	_mat_suelo.set_shader_parameter("color_aro", aro)
	_mat_suelo.set_shader_parameter("alfa", smoothstep(0.0, 0.5, edad / T_NACER) * desv * (1.0 - consumo * 0.85))
	_mat_suelo.set_shader_parameter("crece", maxf(nacer, 0.02))
	_mat_suelo.set_shader_parameter("tiempo", _t)
	_mat_suelo.set_shader_parameter("remolino", 1.0 if gas else 0.0)
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
	_est = {"nacer": nacer, "desv": desv, "consumo": consumo, "quema": quema, "viento": viento, "alfa_max": amax, "burbujas": burb_vivas, "motas": mota_vivas, "vel": _vel,
		"gas_pesado": gas, "muestras": campo.muestras if campo != null else 0, "solidos": campo.solidos() if campo != null else 0,
		"humo": _humo if _humo != null and is_instance_valid(_humo) else null, "humo_emitidas": _humo.emitidas if _humo != null and is_instance_valid(_humo) else 0}


## GAS PESADO: un paso de las bocanadas por el campo. Viento = la deriva de la nube (lo que la lógica la mueve); sólidos = los de alrededor y el suelo.
func _mover_gas(dt: float, p_mundo: Vector3, nacer: float, consumo: float, disolver: float) -> void:
	var n: int = _bocanadas.size()
	if campo == null:
		campo = CampoViento.new(4211 + int(radio_u * 10.0))
		campo.escala = maxf(radio_u * 2.2, 2.0)
		campo.turbulencia = 0.5
		campo.alcance = 0.8                  # a ras de suelo el remolino solo gira en horizontal (la rampa de Bridson con el suelo)
		campo.piel = 0.3
		campo.usar_suelo = true
		campo.un_sentido = false
		campo.empuje = 0.0                   # sin empuje: con viento se quedan atrás por el arrastre (0,7) y se deshilachan
		_gp_sol_t = 0.0
	var vv: Vector3 = Vector3(_vel.x, 0.0, _vel.z)
	var hay_viento: bool = vv.length() > 0.05
	campo.y_suelo = p_mundo.y
	campo.dir = vv.normalized() if hay_viento else Vector3.ZERO
	campo.fuerza = vv.length() if hay_viento else 0.0
	campo.avanzar(dt)
	_gp_sol_t -= dt
	if _gp_sol_t <= 0.0 and is_inside_tree():
		_gp_sol_t = T_SOLIDOS
		campo.recoger_de(self, p_mundo, radio_u + 1.5, p_mundo.y)
	if not _gp_listo or _gp_pos.size() != n:
		_gp_pos.resize(n)
		_gp_vel.resize(n)
		for i in n:
			_gp_pos[i] = _ancla(i, nacer, consumo, disolver)
			_gp_vel[i] = vv
		_gp_listo = true
		_gp_ult = p_mundo
	var salto: Vector3 = p_mundo - _gp_ult           # lo que la lógica movió la nube: las bocanadas NO se mueven con ella (las lleva el aire)
	_gp_ult = p_mundo
	if salto.length() > radio_u * 2.0:
		salto = Vector3.ZERO                         # un teletransporte (recrear, cargar partida): se van con ella
	var muelle: float = MUELLE * (1.0 - 0.6 * clampf(vv.length() / V_VIENTO, 0.0, 1.0))     # con viento el muelle cede: se deshilacha
	for i in n:
		var anc: Vector3 = _ancla(i, nacer, consumo, disolver)
		var q: Vector3 = _gp_pos[i] - salto
		var pw: Vector3 = p_mundo + q
		# cada bocanada tiene su inercia (su `lag`): unas siguen el viento antes que otras y la nube se estira en jirones
		var k_arr: float = lerpf(2.0, 0.3, clampf((float(_bocanadas[i]["lag"]) - 0.2) / 1.4, 0.0, 1.0))
		var v: Vector3 = campo.arrastrar(pw, _gp_vel[i], dt, k_arr)
		var dq: Vector3 = anc - q
		v.x += dq.x * muelle * dt
		v.z += dq.z * muelle * dt
		v.y += (dq.y * PESO - v.y * AMORT_Y) * dt
		pw = campo.contener(pw + v * dt, 0.1)
		_gp_pos[i] = pw - p_mundo
		_gp_vel[i] = v


## GAS PESADO · SE VE A TRAVÉS (11/11, al encenderlo de serie): sin órbita, el campo (que a ras de suelo solo gira en horizontal) junta bocanadas y donde se apilan la opacidad
## ACUMULADA llegaba a ~0,9 (la regla de la nube es ≤ 0,55, prueba_nube_veneno_vfx 1.4). Aquí se mide, con la forma blanda del shader, la opacidad 1 - Π(1 - alfa·forma) en el centro
## de cada bocanada y, donde pasa de OPACIDAD_GAS, se rebajan SOLO las bocanadas que la tapan: su alfa × ln(1 - tope) / ln(1 - opacidad) (por Bernoulli, el punto queda ≤ tope).
## Donde no se apilan, el gas pesado se dibuja igual (mismos verdes, misma mancha, mismas bocanadas). 16 bocanadas: 256 parejas por paso.
const OPACIDAD_GAS: float = 0.42     ## en los centros; entre centros sale algo más (prueba 1.4: ~0,5 con 0,45)
func _limitar_opacidad() -> void:
	var n: int = _bocanadas.size()
	var k_min: PackedFloat32Array = PackedFloat32Array()
	k_min.resize(n)
	k_min.fill(1.0)
	var ln_tope: float = log(1.0 - OPACIDAD_GAS)
	for i in n:
		var c: Vector2 = Vector2(_pos_boc[i].x, _pos_boc[i].z)
		var libre: float = 1.0
		for j in n:
			libre *= 1.0 - _alfas[j] * _forma(c, j)
		if 1.0 - libre <= OPACIDAD_GAS or libre <= 0.0:
			continue
		var s: float = ln_tope / log(libre)
		for j in n:
			if _forma(c, j) > 0.0:
				k_min[j] = minf(k_min[j], s)
	for j in n:
		_alfas[j] *= k_min[j]


## La forma blanda de la bocanada `j` en el punto `c` (plano XZ local): 1 en el centro, borde suave desde la mitad del radio (la del shader).
func _forma(c: Vector2, j: int) -> float:
	var d: float = Vector2(_pos_boc[j].x, _pos_boc[j].z).distance_to(c) / maxf(_tams[j] * 0.5, 0.001)
	return 1.0 - smoothstep(0.45, 1.0, d)


## El sitio de la bocanada `i` (local): en su anillo, sin girar, más bajo que la nube de siempre (pesa).
func _ancla(i: int, nacer: float, consumo: float, disolver: float) -> Vector3:
	var b: Dictionary = _bocanadas[i]
	var ang: float = float(b["ang0"])
	var rr: float = float(b["rad"]) * radio_u * nacer * (1.0 - 0.18 * consumo) * (1.0 + 0.12 * disolver)
	return Vector3(cos(ang) * rr, float(b["h0"]) * 0.7 + disolver * 0.45 + consumo * 0.3, sin(ang) * rr)


## HUMO AL ARDER: crea (una vez) el emisor de HumoRegla HUMO que sigue a la nube y le pasa el ritmo (cuánto arde) y el viento.
var _humo_k: float = 0.0
func _humo_veneno(quema: float, consumo: float) -> void:
	_humo_k = quema * (1.0 - 0.5 * consumo)
	if _humo != null and is_instance_valid(_humo):
		_humo.viento = Vector3(_vel.x, 0.0, _vel.z) * 0.8
		return
	if _humo_hecho or not is_inside_tree():
		return
	_humo_hecho = true
	var nube: Node = get_parent()
	var padre: Node = nube.get_parent() if nube != null and nube.get_parent() != null else nube
	if padre == null:
		return
	var k: float = clampf(radio_u / 2.3, 0.7, 1.5)
	_humo = HumoRegla.crear(HumoRegla.Materia.HUMO, padre, global_position, {"n": 48, "escala": k, "arrastre": 1.1, "vida": 2.4})
	if _humo == null:
		return
	_humo.name = "HumoVeneno"
	_humo.sigue = self
	var ref: WeakRef = weakref(self)
	var ritmo: Callable = func() -> float:
		var o: Object = ref.get_ref()
		return float(o.get("_humo_k")) if o != null else 0.0
	_humo.anadir_fuente({"local": Vector3(0, 0.35, 0), "caja": Vector3(radio_u * 0.55, 0.12, radio_u * 0.55), "dir": Vector3.UP, "v": Vector2(0.3, 0.8), "abanico": 20.0,
		"ritmo": 10.0 * k, "temp": HumoRegla.T_SALIDA, "tam_k": 0.9, "escala_fn": ritmo})


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
