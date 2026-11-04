class_name MarchaCuadrupedo3D
extends SkeletonModifier3D

## MARCHA DE LOS ANIMALES (4/11, encargo de Pablo: «el canouro con el movimiento de una HIENA y el loberno con el de un LOBO»; docs/ANIMALES_MOVIMIENTO_2026-11-04.md).
## Capa sobre el esqueleto «Wolf» de 51 huesos (loberno = emberheart.glb, canouro = canouro.glb). Va DESPUÉS del AnimationTree (es un SkeletonModifier3D, hijo del Skeleton3D) y no toca los
## clips. Se cuelga del Pj3D del animal con `MarchaCuadrupedo3D.para(pj)` (Combate3D lo hace en `_ready`). Interruptor: `MARCHA_ANIMAL = false` y todo vuelve a lo de antes.
##
## Hace cuatro cosas, todas por datos (PERFILES / TIPOS):
##  1. POSTURA sobre los huesos: pendiente del lomo (el delantero sube y, si hace falta, las patas delanteras se alargan lo justo para llegar al suelo), cabeza y cuello (más bajos y
##     adelantados), vaivén lateral de cabeza y hombros sincronizado con la zancada (hiena), cabeza estabilizada (lobo), cabeza que mira a la presa (con límite de giro) y agachado.
##  2. VELOCIDADES y CLIPS: qué clip y a qué velocidad de reproducción para que el pie no patine con el avance real (`elegir`), y la velocidad de cada estado (`v_base`).
##  3. GIRO con velocidad angular máxima (`paso_suave`, `actualizar`): el animal describe arcos en vez de girar en seco.
##  4. CONDUCTA (`conducta`): lobo = acecho agachado y embestida corta; hiena = zigzag, parada, retroceso, arrancada y retirada tras morder.
## Ejes: «delante» y «lateral» se miden del propio esqueleto en reposo (de la grupa a la cabeza); giro `+` sobre el lateral = morro hacia abajo.

static var MARCHA_ANIMAL: bool = true

## Parámetros por tipo de animal. Ángulos en grados.
const TIPOS: Dictionary = {
	"lobo": {
		"lomo": 7.0,                   # cuánto sube la parte delantera del lomo (el loberno viene con la grupa 6-7° más alta que la cruz: queda nivelado)
		"cabeza_parado": 4.0,          # grados de morro abajo (reparto sobre cuello y cabeza) quieto
		"cabeza_marcha": 26.0,         # ídem andando: «a la altura de la espalda o algo por debajo cuando trota»
		"cabeza_agachado": 16.0,       # de más en el acecho
		"estabilizar": 0.7,            # fracción del cabeceo del lomo que se le quita a la cabeza (poco cabeceo)
		"estabilizar_lateral": 0.8,    # ídem del desvío lateral que trae el clip
		"cabeza_base": 0.0,            # fracción del morro abajo que se da también a la base del cuello (Torso3)
		"vaiven_cabeza": 2.0,          # giro lateral de la cabeza (± grados) por zancada
		"vaiven_lomo": 0.0,
		"balanceo_hombros": 0.0,
		"limite_mirada": 70.0,         # lo que puede girar la cabeza respecto al cuerpo para seguir a la presa
		"escala_pata_max": 1.12,
		"omega": 6.5,                  # velocidad angular máxima del cuerpo (rad/s): cierra en arco
		"omega_parado": 7.0,
		"giro_lento": 0.35,            # la velocidad cae a esta fracción con un giro de 180°
	},
	"hiena": {
		"lomo": 13.0,
		"cabeza_parado": 20.0,
		"cabeza_marcha": 46.0,         # cabeza baja y adelantada (por debajo de la cruz)
		"cabeza_agachado": 6.0,
		"estabilizar": 0.0,            # sin estabilizar: cabecea
		"estabilizar_lateral": 0.0,
		"cabeza_base": 0.55,
		"vaiven_cabeza": 22.0,         # mucho vaivén lateral de la cabeza...
		"vaiven_lomo": 6.0,            # ...y del lomo (en contrafase)
		"balanceo_hombros": 7.0,       # ...y balanceo de los hombros
		"limite_mirada": 55.0,
		"escala_pata_max": 1.28,
		"omega": 3.6,                  # gira más torpe
		"omega_parado": 3.8,
		"giro_lento": 0.5,
	},
}

## Por modelo: tipo, altura con la que se midió, clips (nombre en el GLB) y velocidad a la que NO patinan a reproducción ×1 (u/s medidas con `herramientas/medir_animales.gd` a `alto_ref`),
## velocidades de cada estado (u/s) y conducta. `v_cambio`: por encima de esa velocidad se usa el clip de correr.
const PERFILES: Dictionary = {
	"loberno": {
		"tipo": "lobo", "alto_ref": 0.75,
		"clip_trote": "Run_Alt", "clip_correr": "Gallop", "clip_acecho": "Creep",
		"v_clip": {"Run_Alt": 1.40, "Gallop": 2.0, "Creep": 0.19, "Walk": 0.45},
		"v_patrulla": 1.15, "v_perseguir": 2.5, "v_acecho": 0.32, "v_cambio": 1.8,
		"vel_min": 0.45, "vel_max": 2.0,
		"conducta": {"acecho": {"d_ini": 2.9, "d_fin": 1.9, "pausa": 0.3, "embestida_v": 1.25, "embestida_t": 0.7, "enfriar": 6.0, "max_t": 3.0}},
	},
	"canouro": {
		"tipo": "hiena", "alto_ref": 0.55,
		"clip_trote": "Walk", "clip_correr": "Gallop", "clip_acecho": "Walk",
		"v_clip": {"Walk": 0.45, "Gallop": 1.55},
		"v_patrulla": 0.6, "v_perseguir": 2.2, "v_acecho": 0.4, "v_cambio": 1.4,
		"vel_min": 0.45, "vel_max": 2.2,
		"conducta": {"tanteo": {"d_max": 4.6, "d_min": 2.6, "para": 0.4, "atras": 0.55, "v_atras": 0.45, "tanteos": 1},
			"zigzag": {"grados": 24.0, "periodo": 0.9, "d_min": 1.8},
			"arrancada": {"mult": 1.4, "t": 0.9, "d_ini": 3.0},
			"retirada": {"t": 0.6, "v": 0.5}},
	},
}

# --- estado pedido por Combate3D (se escribe cada fotograma) ---
var velocidad: float = 0.0               ## u/s a los que se mueve de verdad (para el vaivén y la cabeza)
var agachado: float = 0.0                ## 0..1: bajar cuerpo y cabeza (acecho)
var mirar_yaw: float = 0.0               ## giro deseado de la cabeza respecto al cuerpo (rad, + = a su izquierda)
var pj: Pj3D = null
var id: String = ""
var perfil: Dictionary = {}
var tipo: Dictionary = {}
var rumbo: float = 0.0                   ## hacia dónde apunta el cuerpo (yaw, atan2(x, z)), con velocidad angular máxima

# --- esqueleto ---
var _sk: Skeleton3D = null
var _h: Dictionary = {}                  ## nombre lógico -> índice de hueso
var _fw: Vector3 = Vector3.BACK
var _lat: Vector3 = Vector3.RIGHT
var _listo: bool = false
var _escala_pata: float = 1.0
var _desv_pie: Dictionary = {}
var _fw_cabeza: Vector3 = Vector3.BACK         ## «delante» expresado en el marco del hueso de la cabeza en reposo
var medir: bool = false                  ## true: guarda en `ult` la pose final de cada fotograma
var ult: Dictionary = {}
var llamadas: int = 0                    ## cuántas veces ha corrido la capa (para las pruebas)
var _eje_pata: Dictionary = {}           ## índice de hueso de pata delantera -> Vector3 de escala
var _ag_s: float = 0.0                   ## agachado suavizado
var _mir_s: float = 0.0
var _mov_s: float = 0.0                  ## 0..1 «en marcha» suavizado
var _cab_media: float = 0.0              ## pitch medio del lomo (para estabilizar)
var _cab_ini: bool = false
var _fase: float = 0.0
var _clip_len: float = 1.0
var _clip_vel: float = 1.0
var _etiqueta: String = ""

# --- conducta ---
var _est: String = ""
var _t_est: float = 0.0
var _enfriar: float = 0.0
var _t_sin_llamar: float = 99.0
var _signo_zig: float = 1.0
var _t_zig: float = 0.0
var _tanteos: int = 0
var _t_persigue: float = 0.0
var retirada: float = 0.0
var _t_vuelta: float = 9.0
var _retirada_pendiente: bool = false
var _giro_hecho: bool = false

const NOMBRES: Dictionary = {
	"cuerpo": "Body", "espalda": "Back", "torso": "Torso", "torso2": "Torso2", "torso3": "Torso3",
	"cuello1": "Neck1", "cuello2": "Neck2", "cuello3": "Neck3", "cabeza": "Head",
	"hombro_i": "FrontShoulder.L", "hombro_d": "FrontShoulder.R", "cadera_i": "BackShoulder.L", "cadera_d": "BackShoulder.R",
	"brazo_i": "FrontUpperLeg.L", "brazo_d": "FrontUpperLeg.R", "mano_i": "FrontLowerLeg.L", "mano_d": "FrontLowerLeg.R",
	"pie_i": "FF.L", "pie_d": "FF.R", "cola1": "Tail1",
}


static func tiene_perfil(p_id: String) -> bool:
	return PERFILES.has(p_id)


## Crea (o devuelve) la capa del animal `p`. Null si el modelo no tiene perfil o no tiene esqueleto «Wolf».
static func para(p: Pj3D) -> MarchaCuadrupedo3D:
	if p == null or not PERFILES.has(p.id):
		return null
	if p.has_meta("marcha_cuadrupedo"):
		var m0: Variant = p.get_meta("marcha_cuadrupedo")
		if is_instance_valid(m0):
			return m0 as MarchaCuadrupedo3D
	var sk: Skeleton3D = p._esqueleto()
	if sk == null:
		return null
	var m := MarchaCuadrupedo3D.new()
	m.name = "MarchaCuadrupedo"
	sk.add_child(m)
	if not m.preparar(p):
		m.queue_free()
		return null
	p.set_meta("marcha_cuadrupedo", m)
	return m


func preparar(p: Pj3D) -> bool:
	pj = p
	id = p.id
	perfil = PERFILES[id]
	tipo = TIPOS[String(perfil["tipo"])]
	_sk = get_parent() as Skeleton3D
	if _sk == null:
		return false
	for k in NOMBRES:
		var i: int = _sk.find_bone(String(NOMBRES[k]))
		if i < 0:
			push_warning("MarchaCuadrupedo3D[%s]: falta el hueso %s" % [id, NOMBRES[k]])
			return false
		_h[k] = i
	# Ejes del cuerpo en el espacio del esqueleto: delante = de la grupa a la cabeza (horizontal), lateral = arriba × delante.
	var d: Vector3 = _rest(_h["cabeza"]).origin - _rest(_h["cuerpo"]).origin
	d.y = 0.0
	_fw = d.normalized()
	_lat = Vector3.UP.cross(_fw).normalized()
	rumbo = p.rotation.y
	_fw_cabeza = (_rest(_h["cabeza"]).basis.orthonormalized().inverse() * _fw)
	_calcular_patas()
	_listo = true
	return true


func _rest(i: int) -> Transform3D:
	return _sk.get_bone_global_rest(i)


## Cuánto hay que alargar las patas delanteras para que lleguen al suelo con el lomo inclinado (el delantero sube `Δy` en los hombros), repartido en las dos articulaciones.
func _calcular_patas() -> void:
	var ang: float = deg_to_rad(float(tipo["lomo"]))
	var o_torso: Vector3 = _rest(_h["torso"]).origin
	var r: Vector3 = _rest(_h["brazo_i"]).origin - o_torso
	var r2: Vector3 = Quaternion(_lat, -ang) * r
	var dy: float = r2.y - r.y
	var largo: float = _rest(_h["brazo_i"]).origin.y - _rest(_h["pie_i"]).origin.y
	if largo < 0.01:
		largo = 0.2
	_escala_pata = clampf(1.0 + dy / largo, 1.0, float(tipo["escala_pata_max"]))
	# Eje a lo largo del hueso en su marco local: el desplazamiento del hijo (la mano) respecto al brazo en reposo. Solo se escala el brazo: la mano y el pie cuelgan de él y heredan el alargado.
	for par in [["brazo_i", "mano_i"], ["brazo_d", "mano_d"]]:
		var b: int = _h[par[0]]
		var off: Vector3 = _sk.get_bone_rest(_h[par[1]]).origin
		var a: Vector3 = off.abs()
		var eje: Vector3 = Vector3(1, 1, 1)
		if a.x >= a.y and a.x >= a.z:
			eje.x = _escala_pata
		elif a.y >= a.z:
			eje.y = _escala_pata
		else:
			eje.z = _escala_pata
		_eje_pata[b] = eje

## Altura de la cruz sobre el suelo y pendiente del lomo (grados, + = delante alto) en el estado actual del esqueleto. Para las pruebas.
func pendiente_lomo() -> float:
	var c: Vector3 = (_pos(_h["hombro_i"]) + _pos(_h["hombro_d"])) * 0.5
	var g: Vector3 = (_pos(_h["cadera_i"]) + _pos(_h["cadera_d"])) * 0.5
	var v: Vector3 = c - g
	return rad_to_deg(atan2(v.y, v.dot(_fw)))


## Giro (grados, + = a su izquierda) de la cabeza respecto al eje del cuerpo: hacia dónde apunta el hueso de la cabeza, en horizontal. Para las pruebas.
func yaw_cabeza() -> float:
	var i: int = _h["cabeza"]
	var f: Vector3 = _sk.get_bone_global_pose(i).basis * _fw_cabeza
	f.y = 0.0
	if f.length() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(f.dot(_lat), f.dot(_fw)))

## Altura de la cabeza sobre la cruz, vaivén lateral de la cabeza respecto al eje grupa-cruz y su avance: [y, lateral, adelante] en unidades del esqueleto (sin escala del nodo). Para las pruebas.
func cabeza_respecto_cruz() -> Array:
	var cruz: Vector3 = (_pos(_h["hombro_i"]) + _pos(_h["hombro_d"])) * 0.5
	var grupa: Vector3 = (_pos(_h["cadera_i"]) + _pos(_h["cadera_d"])) * 0.5
	var hp: Vector3 = _pos(_h["cabeza"])
	return [hp.y - cruz.y, (hp - (cruz + grupa) * 0.5).dot(_lat), (hp - cruz).dot(_fw)]


## Pie delantero estimado (tibia + desvío medido en reposo) en espacio de esqueleto. Para las pruebas de patinado.
func pie_delantero(lado_izq: bool) -> Vector3:
	var b: int = _h["mano_i" if lado_izq else "mano_d"]
	var pie: int = _h["pie_i" if lado_izq else "pie_d"]
	if not _desv_pie.has(b):
		_desv_pie[b] = _sk.get_bone_global_rest(b).affine_inverse() * _sk.get_bone_global_rest(pie).origin
	return _sk.get_bone_global_pose(b) * (_desv_pie[b] as Vector3)


func estado_conducta() -> String:
	return _est


func _pos(i: int) -> Vector3:
	return _sk.get_bone_global_pose(i).origin


func _q_glob(i: int) -> Quaternion:
	if i < 0:
		return Quaternion.IDENTITY
	return _sk.get_bone_global_pose(i).basis.get_rotation_quaternion()


## Gira el hueso `i` un giro GLOBAL `r` (ejes del esqueleto) sobre su propio origen. Lo que cuelga de él lo sigue.
func _girar(i: int, r: Quaternion) -> void:
	var p: Quaternion = _q_glob(_sk.get_bone_parent(i))
	var q: Quaternion = _sk.get_bone_pose_rotation(i)
	_sk.set_bone_pose_rotation(i, (p.inverse() * r * p * q).normalized())


## Deja el hueso `i` con la orientación global `g` (la que tenía antes de torcer el lomo): la pata no se tuerce con el tronco.
func _fijar(i: int, g: Quaternion) -> void:
	var p: Quaternion = _q_glob(_sk.get_bone_parent(i))
	_sk.set_bone_pose_rotation(i, (p.inverse() * g).normalized())


func _abajo(grados: float) -> Quaternion:
	return Quaternion(_lat, deg_to_rad(grados))


func _giro_vertical(grados: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(grados))


func _balanceo(grados: float) -> Quaternion:
	return Quaternion(_fw, deg_to_rad(grados))


func _process_modification() -> void:
	llamadas += 1
	if not _listo or _sk == null:
		return
	var es: String = pj.estado_anim() if pj != null and is_instance_valid(pj) else "muerto"
	if not MARCHA_ANIMAL or es == "muerto" or es == "drown" or es == "empujado" or es == "levantarse":
		_soltar()
		_registrar()
		return
	var dt: float = get_process_delta_time()
	var w: float = influence
	_mov_s = move_toward(_mov_s, clampf(velocidad / 0.3, 0.0, 1.0), dt * 5.0)
	_ag_s = move_toward(_ag_s, agachado, dt * 3.0)
	_mir_s = move_toward(_mir_s, mirar_yaw, dt * 9.0)
	# Fase de la zancada: la del clip que suena ahora.
	var arbol: ArbolAnimPj = pj.arbol() if pj != null else null
	if arbol != null and arbol.listo() and arbol.largo() > 0.05:
		_fase = arbol.posicion() / arbol.largo()
	var amp: float = _mov_s
	var s: float = sin(TAU * _fase) * amp
	var c: float = cos(TAU * _fase) * amp
	# Cabeceo propio del clip (pendiente de torso3 → cuello1, antes de tocar nada): para estabilizar la cabeza.
	var v_cab: Vector3 = _pos(_h["cuello1"]) - _pos(_h["torso3"])
	var pitch_clip: float = rad_to_deg(atan2(v_cab.y, v_cab.dot(_fw)))
	if not _cab_ini:
		_cab_media = pitch_clip
		_cab_ini = true
	_cab_media = lerpf(_cab_media, pitch_clip, clampf(dt / 0.6, 0.0, 1.0))
	# Desvío lateral de la cabeza que trae el clip (sobre el eje grupa-cruz): se compensa girando el cuello desde su base
	var c0: Vector3 = (_pos(_h["hombro_i"]) + _pos(_h["hombro_d"])) * 0.5
	var g0: Vector3 = (_pos(_h["cadera_i"]) + _pos(_h["cadera_d"])) * 0.5
	var x_lat: float = (_pos(_h["cabeza"]) - (c0 + g0) * 0.5).dot(_lat)
	var l_cuello: float = maxf((_pos(_h["cabeza"]) - _pos(_h["cuello1"])).length(), 0.01)
	# Orientación global original de las raíces de las patas y de la cola
	var raices: Array = [_h["hombro_i"], _h["hombro_d"], _h["cadera_i"], _h["cadera_d"], _h["cola1"]]
	var orig: Dictionary = {}
	for r in raices:
		orig[r] = _q_glob(r)
	# 1) Lomo: el delantero sube (se gira el tronco por el torso medio) y, agachado, vuelve a bajar
	var lomo: float = float(tipo["lomo"]) * w * (1.0 - 0.8 * _ag_s)
	_girar(_h["torso"], _abajo(-lomo))
	# 2) Vaivén del lomo y balanceo de los hombros (hiena): el tronco se dobla de lado y los hombros se balancean
	var v_lomo: float = float(tipo["vaiven_lomo"]) * w
	if v_lomo > 0.0:
		_girar(_h["torso"], _giro_vertical(v_lomo * s))
		_girar(_h["torso2"], _giro_vertical(v_lomo * s * 0.7))
	var b_h: float = float(tipo["balanceo_hombros"]) * w
	if b_h > 0.0:
		_girar(_h["torso2"], _balanceo(b_h * c))
	# 3) Las patas conservan su orientación (el tronco no las tuerce)
	for r in raices:
		_fijar(r, orig[r] as Quaternion)
	# 4) Patas delanteras más largas (lo que sube el hombro)
	if _escala_pata > 1.001:
		for b in _eje_pata:
			var e: Vector3 = _eje_pata[b]
			_sk.set_bone_pose_scale(b, Vector3.ONE.lerp(e, w))
	# 5) Cuello y cabeza: morro abajo (marcha, agachado), estabilizada, con vaivén y mirando a la presa
	var cab: float = lerpf(float(tipo["cabeza_parado"]), float(tipo["cabeza_marcha"]), _mov_s) + float(tipo["cabeza_agachado"]) * _ag_s
	var estab: float = float(tipo["estabilizar"]) * (pitch_clip - _cab_media)      # el morro sube → se baja la cabeza (y al revés)
	var total: float = (cab + estab) * w
	if float(tipo["cabeza_base"]) > 0.0:
		_girar(_h["torso3"], _abajo(total * float(tipo["cabeza_base"])))          # la base del cuello también baja (hiena: cabeza por debajo de la cruz)
	var pesos: Array = [0.25, 0.30, 0.25, 0.20]
	var huesos: Array = [_h["cuello1"], _h["cuello2"], _h["cuello3"], _h["cabeza"]]
	var limite: float = deg_to_rad(float(tipo["limite_mirada"]))
	var yaw_mirar: float = clampf(_mir_s, -limite, limite) * w
	var yaw_vaiven: float = deg_to_rad(float(tipo["vaiven_cabeza"])) * -s * w
	var yaw_estab: float = -float(tipo["estabilizar_lateral"]) * x_lat / l_cuello * w
	var pesos_yaw: Array = [0.15, 0.25, 0.3, 0.3]
	for n in huesos.size():
		var r: Quaternion = _abajo(total * float(pesos[n]))
		var yaw: float = (yaw_mirar + yaw_vaiven) * float(pesos_yaw[n])
		if n == 0:
			yaw += yaw_estab
		if absf(yaw) > 0.0001:
			r = Quaternion(Vector3.UP, yaw) * r
		_girar(huesos[n], r)
	_registrar()


## Para las pruebas (`medir = true`): la pose FINAL del esqueleto de este fotograma, tomada dentro del modificador. Fuera de él, Skeleton3D devuelve la pose de la animación sin modificadores.
func _registrar() -> void:
	if not medir:
		return
	ult = {"lomo": pendiente_lomo(), "cab": cabeza_respecto_cruz(), "yaw": yaw_cabeza(), "pie_i": pie_delantero(true), "pie_d": pie_delantero(false), "ik_i": _pos(_h["pie_i"]), "ik_d": _pos(_h["pie_d"])}


## Quita lo que la capa deja puesto entre fotogramas (la escala de las patas: el clip no la reescribe).
func _soltar() -> void:
	for b in _eje_pata:
		_sk.set_bone_pose_scale(b, Vector3.ONE)


# --------------------------------------------------------------------------------------------------------------------------------------------------
#  Velocidades y clips
# --------------------------------------------------------------------------------------------------------------------------------------------------

## Escala del animal respecto a la altura con la que se midieron los clips (la zancada en u crece con el modelo).
func _k_alto() -> float:
	if pj == null:
		return 1.0
	var alto: float = pj.alto_modelo() * pj.scale.y
	return alto / float(perfil["alto_ref"]) if alto > 0.01 else 1.0


## Velocidad de avance (u/s) de un estado de Combate3D: «walk» = patrulla, «run» = persecución.
func v_base(clip: String) -> float:
	return float(perfil["v_perseguir"] if clip == "run" else perfil["v_patrulla"])


## Qué clip y a qué velocidad de reproducción para avanzar a `v` u/s sin patinar. `modo`: «» | «acecho» | «atras» (se reproduce al revés).
## Devuelve {clip, vel, etiqueta, estado}.
func elegir(v: float, modo: String = "") -> Dictionary:
	var clip: String
	var estado: String
	var etiqueta: String
	if modo == "acecho":
		clip = String(perfil["clip_acecho"])
		estado = "andar_acecho"
		etiqueta = "acecho"
	elif v > float(perfil["v_cambio"]):
		clip = String(perfil["clip_correr"])
		estado = "correr_marcha"
		etiqueta = "correr"
	else:
		clip = String(perfil["clip_trote"])
		estado = "andar_marcha"
		etiqueta = "trote"
	var ref: float = float((perfil["v_clip"] as Dictionary).get(clip, 1.0)) * _k_alto()
	var vel: float = clampf(absf(v) / maxf(ref, 0.01), float(perfil["vel_min"]), float(perfil["vel_max"]))
	if modo == "atras":
		vel = -vel
		etiqueta += "_atras"
	return {"clip": clip, "vel": vel, "etiqueta": etiqueta, "estado": estado}


## Pide al árbol de animación el clip elegido (una sola vez por cambio) y le pone la velocidad. Devuelve lo elegido.
func animar_andar(v: float, modo: String = "") -> Dictionary:
	var e: Dictionary = elegir(v, modo)
	var arbol: ArbolAnimPj = pj.arbol()
	if arbol == null:
		return e
	var et: String = String(e["etiqueta"])
	if pj.animacion_actual != et:
		var estado: String = String(e["estado"])
		if arbol.pedir(estado, String(e["clip"]), {"mezcla": 0.18}):
			pj.animacion_actual = et
			_etiqueta = et
	pj.set_velocidad_animacion(float(e["vel"]), false)
	_clip_vel = float(e["vel"])
	return e


# --------------------------------------------------------------------------------------------------------------------------------------------------
#  Giro y conducta (los llama Combate3D)
# --------------------------------------------------------------------------------------------------------------------------------------------------

func rumbo_vec() -> Vector3:
	return Vector3(sin(rumbo), 0.0, cos(rumbo))


func _girar_hacia(ang: float, omega: float, delta: float) -> void:
	rumbo = rumbo + clampf(wrapf(ang - rumbo, -PI, PI), -omega * delta, omega * delta)


## El paso que va a dar el animal (desplazamiento de este fotograma) con el giro limitado: el cuerpo gira hacia donde quiere ir a `omega` máx. y avanza por donde apunta, más despacio
## cuanto más desviado (arco). `de_espaldas`: retrocede sin girar (la cabeza sigue en la presa).
func paso_suave(paso: Vector3, delta: float, de_espaldas: bool = false) -> Vector3:
	var largo: float = paso.length()
	if largo < 0.00001:
		return paso
	_giro_hecho = true
	if de_espaldas:
		return paso
	var deseado: float = atan2(paso.x, paso.z)
	var err: float = absf(wrapf(deseado - rumbo, -PI, PI))
	_girar_hacia(deseado, float(tipo["omega"]), delta)
	var f: float = lerpf(1.0, float(tipo["giro_lento"]), clampf(err / PI, 0.0, 1.0))
	return rumbo_vec() * largo * f


## Cada fotograma tras la IA: si no se ha movido (parado, atacando, mirando a la jugadora), el cuerpo se gira hacia `mirada` con la misma velocidad angular máxima; actualiza la mirada de la
## cabeza, el agachado y los temporizadores de conducta.
func actualizar(delta: float, c: Node3D, mirada: Vector3, presa: Vector3, hay_presa: bool, mov: float) -> void:
	velocidad = mov
	if not _giro_hecho and mirada.length() > 0.01:
		_girar_hacia(atan2(mirada.x, mirada.z), float(tipo["omega_parado"]), delta)
	_giro_hecho = false
	# La cabeza sigue a la presa dentro de un límite
	if hay_presa:
		var d: Vector3 = presa - c.position
		d.y = 0.0
		if d.length() > 0.2:
			mirar_yaw = wrapf(atan2(d.x, d.z) - rumbo, -PI, PI)
	else:
		mirar_yaw = 0.0
	_t_sin_llamar += delta
	_t_vuelta += delta
	_enfriar = maxf(0.0, _enfriar - delta)
	retirada = maxf(0.0, retirada - delta)
	if _t_sin_llamar > 0.5 and _est != "":
		_est = ""
		agachado = 0.0
	if _t_sin_llamar > 2.0:
		_tanteos = 0
		_t_persigue = 0.0


## La patrulla da la vuelta como mucho una vez cada 0,8 s (el giro de 180° tarda en cerrarse y el animal sigue un rato hacia fuera).
func permitir_vuelta() -> bool:
	if _t_vuelta < 0.8:
		return false
	_t_vuelta = 0.0
	return true


## Se llama cuando empieza un ataque (para la retirada de la hiena tras morder).
func al_atacar() -> void:
	_retirada_pendiente = true


## Se llama cuando el ataque ha terminado.
func al_acabar_ataque() -> void:
	if _retirada_pendiente:
		_retirada_pendiente = false
		var r: Dictionary = (perfil["conducta"] as Dictionary).get("retirada", {})
		if not r.is_empty():
			retirada = float(r["t"])
			_tanteos = 0


## La conducta de persecución: recibe la distancia a la presa `d` y la dirección que Combate3D iba a seguir `dir`; devuelve {dir, v (multiplicador de _v_avance), moviendo (0|1|2), modo, atras}.
func conducta(d: float, dir: Vector3, delta: float) -> Dictionary:
	_t_sin_llamar = 0.0
	_t_est += delta
	_t_persigue += delta
	var r: Dictionary = {"dir": dir, "v": 1.0, "moviendo": 2, "modo": "", "atras": false}
	var cd: Dictionary = perfil["conducta"]
	var v_run: float = float(perfil["v_perseguir"])
	# Retirada tras morder (hiena): unos pasos hacia atrás mirando a la presa
	if retirada > 0.0:
		r["dir"] = -dir
		r["v"] = float((cd["retirada"] as Dictionary)["v"]) / v_run
		r["moviendo"] = 1
		r["modo"] = "atras"
		r["atras"] = true
		return r
	if cd.has("acecho"):
		_conducta_lobo(r, d, cd["acecho"], v_run)
	else:
		_conducta_hiena(r, d, dir, cd, v_run, delta)
	return r


func _conducta_lobo(r: Dictionary, d: float, a: Dictionary, v_run: float) -> void:
	match _est:
		"":
			agachado = 0.0
			if d <= float(a["d_ini"]) and _enfriar <= 0.0 and d > float(a["d_fin"]):
				_est = "acecho"
				_t_est = 0.0
		"acecho":
			agachado = 1.0
			r["v"] = float(perfil["v_acecho"]) / v_run
			r["moviendo"] = 1
			r["modo"] = "acecho"
			if d <= float(a["d_fin"]) or _t_est > float(a["max_t"]):
				_est = "pausa"
				_t_est = 0.0
		"pausa":
			agachado = 1.0
			r["v"] = 0.0
			r["moviendo"] = 0
			r["modo"] = "acecho"
			if _t_est >= float(a["pausa"]):
				_est = "embestida"
				_t_est = 0.0
		"embestida":
			agachado = 0.0
			r["v"] = float(a["embestida_v"])
			if _t_est >= float(a["embestida_t"]):
				_est = ""
				_enfriar = float(a["enfriar"])


func _conducta_hiena(r: Dictionary, d: float, dir: Vector3, cd: Dictionary, v_run: float, delta: float) -> void:
	var t: Dictionary = cd["tanteo"]
	var z: Dictionary = cd["zigzag"]
	var ar: Dictionary = cd["arrancada"]
	match _est:
		"":
			# Zigzag al acercarse; la arrancada sale tras el primer tanteo (o si ya lo hizo)
			if d > float(z["d_min"]):
				_t_zig += delta
				if _t_zig >= float(z["periodo"]):
					_t_zig = 0.0
					_signo_zig = -_signo_zig
				var k: float = clampf((d - float(z["d_min"])) / 2.0, 0.0, 1.0)
				r["dir"] = dir.rotated(Vector3.UP, deg_to_rad(float(z["grados"])) * _signo_zig * k)
				r["v"] = 0.8
				r["moviendo"] = 1 if v_run * 0.8 <= float(perfil["v_cambio"]) else 2
			if _tanteos < int(t["tanteos"]) and d <= float(t["d_max"]) and d >= float(t["d_min"]):
				_est = "para"
				_t_est = 0.0
			elif _tanteos >= int(t["tanteos"]) and d <= float(ar["d_ini"]):
				_est = "arrancada"
				_t_est = 0.0
		"para":
			r["v"] = 0.0
			r["moviendo"] = 0
			if _t_est >= float(t["para"]):
				_est = "atras"
				_t_est = 0.0
		"atras":
			r["dir"] = -dir
			r["v"] = float(t["v_atras"]) / v_run
			r["moviendo"] = 1
			r["modo"] = "atras"
			r["atras"] = true
			if _t_est >= float(t["atras"]):
				_tanteos += 1
				_est = ""
				_t_est = 0.0
		"arrancada":
			r["v"] = float(ar["mult"])
			if _t_est >= float(ar["t"]):
				_est = ""
				_tanteos = 0










