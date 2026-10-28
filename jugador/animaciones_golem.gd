class_name AnimacionesGolem
extends RefCounted

## ANIMACIONES DEL GÓLEM DE PIEDRA (golem_piedra_rig.glb, esqueleto Mixamo `mixamorig_*` de 27 huesos; salida de tools/autorig_golem.py). El GLB no trae clips:
##   · TODOS los clips (idle, walk, attack, expuesto, resbalar, levantarse, hit, death) se GENERAN aquí con giros de hueso y curvas, a 30 fps: `construir`. Un gólem es de rocas rígidas: basta girar huesos.
##     (El golpe `attack` fue primero el puñetazo a una mano del elemental de bosque retargeteado; se descartó: doblaba el torso hasta parecer una caída.)
##
## CÓMO SE GIRA: cada pose es {hueso sin prefijo: Vector3(grados X, Y, Z)} con giros en EJES DEL MODELO (X = derecha del personaje, Y arriba, Z delante) y ACUMULATIVOS por la cadena
## (girar Spine arrastra a los brazos y la cabeza). +X inclina hacia DELANTE lo que está por encima del hueso (el torso) y lleva hacia ATRÁS lo que cuelga (brazos, piernas, espinillas);
## +Y gira hacia la izquierda del personaje; +Z inclina hacia la derecha del personaje. La clave especial "_hips" es el desplazamiento de la cadera (m del modelo, 0,704 de alto).
## Los ejes locales de los huesos vienen torcidos (rolls arbitrarios), por eso no se escriben ángulos locales: se calcula la rotación local que da el giro pedido en ejes del modelo.
## El suelo: «pies» ancla el pie más bajo a la altura que tiene en reposo (andar, idle, golpe); «suelo» solo empuja la cadera hacia arriba lo justo para que ningún hueso baje de
## la altura SUELO_HUESO (cuerpo tumbado o de rodillas: el torso tiene medio grosor de 0,17).
##
## Medidas y tiempos: ver las constantes y herramientas/prueba_golem_anim.gd. Las alturas son del modelo (0,704); en el juego, ×1,7/0,704 = ×2,414.

const PREFIJO_HUESO: String = "mixamorig_"
const FPS: float = 30.0

## --- Roles (nombre del clip = rol de Pj3D.SINONIMOS) y duraciones (s) ---
const DUR_IDLE: float = 3.0
const DUR_WALK: float = 1.6                 ## un ciclo completo = dos pasos
const DUR_EXPUESTO: float = 5.4
const DUR_RESBALAR: float = 2.0
const DUR_LEVANTARSE: float = 4.6
const DUR_HIT: float = 0.7
const DUR_DEATH: float = 2.6
const ROLES: Array = ["idle", "walk", "expuesto", "resbalar", "levantarse", "hit", "death"]
const T_EXPUESTO_ABAJO: float = 1.4         ## s en que acaba de caer de rodillas (empieza a mostrar el núcleo); se queda hasta T_EXPUESTO_ARRIBA
const DUR_ATTACK: float = 2.7
const GLB: String = "golem_piedra_rig"
## --- El golpe (`attack`): mazazo con los DOS puños desde arriba, generado por código (el del elemental de bosque se descartó: doblaba el torso hasta parecer una caída). ---
## Fases (s): anticipación 0 -> T_ATK_CARGA (se agacha y echa los brazos atrás), carga T_ATK_CARGA -> T_ATK_ARRIBA (los dos brazos sobre la cabeza, torso arqueado hacia atrás, temblor
## en los últimos 0,3 s), caída T_ATK_ARRIBA -> T_ATK_IMPACTO (rápida; el torso se inclina como mucho ATAQUE_INCLINACION_MAX°), impacto (rebote y temblor con los puños pegados al suelo),
## recuperación hasta DUR_ATTACK (vuelve a la pose del idle en t = 0).
## `ELEM_MOMENTO_GOLPE` (0,6 del clip) del elemental de bosque, en enemigos/combate_3d.gd, NO se toca: es del elemental.
const T_ATK_CARGA: float = 0.25
const T_ATK_ARRIBA: float = 1.25
const T_ATK_IMPACTO: float = 1.43
const T_ATK_FIN_REBOTE: float = 1.62
const ATAQUE_INCLINACION_MAX: float = 30.0   ## grados desde la vertical (la prueba lo comprueba)
## AVANCE DEL GOLPE (raíz): el gólem embiste ~media casilla durante la carga final y la caída para que los puños caigan por delante. Va en la RAÍZ del clip (pista de posición de
## `mixamorig_Hips`, +Z del modelo) y NO se deshace: al acabar el clip el gólem está AVANCE_GOLPE u más adelante y con la pose del idle. OPCIÓN (a), root motion: el modelo avanza
## dentro del clip y al terminar el golpe el enemigo debe sumar `AVANCE_GOLPE` (u del juego, en la dirección en que mira) a la posición de su nodo en el MISMO instante en que
## Pj3D vuelve a idle (si no, el modelo salta atrás de golpe). Si el enemigo prefiere moverse él durante el golpe, usa `avance_golpe_en(t)` (u del juego acumulados a los t s del clip).
## Tramo: empieza T_AVANCE_INI (un 15 % del avance hasta T_AVANCE_IMPULSO), el resto acelera hasta el impacto (INSTANTE_GOLPE) y se para en seco; después no se mueve.
const AVANCE_GOLPE: float = 1.15            ## u del juego (media casilla de 2,3), con el gólem a 1,7 de alto
const T_AVANCE_INI: float = 1.15
const T_AVANCE_IMPULSO: float = 1.25
const ESCALA_JUEGO: float = 1.7 / 0.704346  ## u del juego por unidad del modelo (cuerpo de 0,704 de alto a 1,7)
const AVANCE_IMPULSO: float = 0.15          ## fracción del avance que se hace en la última décima de la carga
## Segundo del clip `attack` en que los puños llegan al suelo: el instante del impacto y del aviso (como Pj3D.INSTANTE_CLIP). Medido con herramientas/prueba_golem_anim.gd.
const INSTANTE_GOLPE: float = 1.43
const T_EXPUESTO_ARRIBA: float = 3.9


## Alturas mínimas por hueso (modo «suelo»): m del modelo, centro del hueso. El torso tumbado tiene ~0,17 de medio fondo.
const SUELO_HUESO: Dictionary = {
	"Hips": 0.16, "Spine": 0.17, "Spine1": 0.17, "Spine2": 0.17, "Neck": 0.12, "Head": 0.08, "HeadTop_End": 0.03,
	"LeftShoulder": 0.1, "RightShoulder": 0.1, "LeftArm": 0.09, "RightArm": 0.09, "LeftForeArm": 0.06, "RightForeArm": 0.06,
	"LeftHand": 0.04, "RightHand": 0.04, "LeftHandMiddle4": 0.02, "RightHandMiddle4": 0.02,
	"LeftUpLeg": 0.08, "RightUpLeg": 0.08, "LeftLeg": 0.05, "RightLeg": 0.05, "LeftFoot": 0.02, "RightFoot": 0.02,
	"LeftToeBase": 0.01, "RightToeBase": 0.01, "LeftToe_End": 0.005, "RightToe_End": 0.005,
}
const HUESOS_PIE: Array = ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "LeftToe_End", "RightToe_End"]


## ---------------------------------------------------------------------------------------------------------------------------------------
##  API
## ---------------------------------------------------------------------------------------------------------------------------------------

## Los clips generados ({rol: Animation}). `prefijo` = «ruta del Skeleton3D desde la raíz del AnimationPlayer:» (p. ej. «Armature/Skeleton3D:»).
static func construir(sk: Skeleton3D, prefijo: String) -> Dictionary:
	var c := _Ctx.new(sk, prefijo)
	var r: Dictionary = {}
	r["idle"] = c.animar(DUR_IDLE, AnimacionesGolem._pose_idle, "pies", true)
	r["walk"] = c.animar(DUR_WALK, AnimacionesGolem._pose_walk, "pies", true)
	r["expuesto"] = c.animar(DUR_EXPUESTO, AnimacionesGolem._pose_expuesto, "suelo", false)
	r["resbalar"] = c.animar(DUR_RESBALAR, AnimacionesGolem._pose_resbalar, "suelo", false)
	r["levantarse"] = c.animar(DUR_LEVANTARSE, AnimacionesGolem._pose_levantarse, "suelo", false)
	r["hit"] = c.animar(DUR_HIT, AnimacionesGolem._pose_hit, "pies", false)
	r["attack"] = c.animar(DUR_ATTACK, AnimacionesGolem._pose_attack, "pies", false)
	r["death"] = c.animar(DUR_DEATH, AnimacionesGolem._pose_death, "suelo", false)
	return r



## ---------------------------------------------------------------------------------------------------------------------------------------
##  Curvas de pose: cada función devuelve {hueso: Vector3(grados), "_hips": Vector3(m)} para el instante t
## ---------------------------------------------------------------------------------------------------------------------------------------

## Interpolación entre llaves [[t, pose], ...] con suavizado (smoothstep). Lo que una llave no nombra vale 0.
static func _llaves(llaves: Array, t: float) -> Dictionary:
	var n: int = llaves.size()
	if t <= float(llaves[0][0]):
		return (llaves[0][1] as Dictionary).duplicate()
	if t >= float(llaves[n - 1][0]):
		return (llaves[n - 1][1] as Dictionary).duplicate()
	for i in range(1, n):
		if t <= float(llaves[i][0]):
			var a: Dictionary = llaves[i - 1][1]
			var b: Dictionary = llaves[i][1]
			var u: float = (t - float(llaves[i - 1][0])) / maxf(float(llaves[i][0]) - float(llaves[i - 1][0]), 0.00001)
			var modo: String = String(llaves[i][2]) if (llaves[i] as Array).size() > 2 else "suave"
			u = _curva(u, modo)
			var r: Dictionary = {}
			for k in a:
				r[k] = (a[k] as Vector3).lerp(b.get(k, Vector3.ZERO) as Vector3, u)
			for k in b:
				if not r.has(k):
					r[k] = (Vector3.ZERO).lerp(b[k] as Vector3, u)
			return r
	return {}


static func _curva(u: float, modo: String) -> float:
	match modo:
		"acelera":
			return u * u
		"frena":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"lineal":
			return u
	return u * u * (3.0 - 2.0 * u)


static func _suma(a: Dictionary, b: Dictionary) -> Dictionary:
	var r: Dictionary = a.duplicate()
	for k in b:
		r[k] = (r.get(k, Vector3.ZERO) as Vector3) + (b[k] as Vector3)
	return r


## idle: respiración lenta (3 s, bucle) del pecho y los hombros y un balanceo mínimo.
static func _pose_idle(t: float) -> Dictionary:
	var f: float = TAU * t / DUR_IDLE
	var s: float = sin(f)
	var r: Dictionary = {}
	r["Spine1"] = Vector3(-0.6 * s, 0.0, 0.0)
	r["Spine2"] = Vector3(-1.4 * s, 0.7 * sin(f - 0.8), 0.0)
	r["LeftShoulder"] = Vector3(0.0, 0.0, 2.2 * maxf(s, -0.4))
	r["RightShoulder"] = Vector3(0.0, 0.0, -2.2 * maxf(s, -0.4))
	r["Head"] = Vector3(0.8 * s, 1.2 * sin(f + 1.2), 0.0)
	r["Hips"] = Vector3(0.0, 0.0, 0.9 * sin(f + 0.7))
	r["Spine"] = Vector3(0.0, 1.0 * sin(f - 0.5), -0.5 * sin(f + 0.7))
	r["LeftArm"] = Vector3(0.9 * s, 0.0, 0.5 * s)
	r["RightArm"] = Vector3(0.9 * s, 0.0, -0.5 * s)
	r["_hips"] = Vector3(0.004 * sin(f + 0.7), 0.0, 0.0)
	return r


## walk: paso pesado de piernas cortas (ciclo de 1,6 s = dos pasos), balanceo lateral grande del torso, brazos colgando en contrafase.
const WALK_PIERNA: float = 28.0       ## grados de la cadera hacia delante/atrás
const WALK_RODILLA: float = 40.0
const WALK_BRAZO: float = 14.0
const WALK_BALANCEO: float = 5.0
static func _pose_walk(t: float) -> Dictionary:
	var f: float = TAU * t / DUR_WALK
	var sl: float = sin(f)
	var sr: float = sin(f + PI)
	var r: Dictionary = {}
	var cl: float = cos(f)
	var rod_l: float = WALK_RODILLA * pow(maxf(cl, 0.0), 1.3)
	var rod_r: float = WALK_RODILLA * pow(maxf(-cl, 0.0), 1.3)
	r["LeftUpLeg"] = Vector3(-WALK_PIERNA * sl, 0.0, 0.0)
	r["RightUpLeg"] = Vector3(-WALK_PIERNA * sr, 0.0, 0.0)
	r["LeftLeg"] = Vector3(rod_l, 0.0, 0.0)
	r["RightLeg"] = Vector3(rod_r, 0.0, 0.0)
	# el pie se mantiene plano: contrarresta lo que giran muslo y espinilla
	r["LeftFoot"] = Vector3(0.9 * (WALK_PIERNA * sl - rod_l), 0.0, 0.0)
	r["RightFoot"] = Vector3(0.9 * (WALK_PIERNA * sr - rod_r), 0.0, 0.0)
	r["Hips"] = Vector3(0.0, 6.0 * sl, WALK_BALANCEO * cl)
	r["Spine"] = Vector3(2.0, -3.0 * sl, 0.45 * WALK_BALANCEO * cl)
	r["Spine2"] = Vector3(1.0, -3.0 * sl, 0.7 * WALK_BALANCEO * cl)
	r["Head"] = Vector3(0.0, 0.0, -0.9 * WALK_BALANCEO * cl)
	r["LeftArm"] = Vector3(WALK_BRAZO * sl, 0.0, 3.0)
	r["RightArm"] = Vector3(-WALK_BRAZO * sl, 0.0, -3.0)
	r["LeftForeArm"] = Vector3(-8.0 - 6.0 * maxf(-sl, 0.0), 0.0, 0.0)
	r["RightForeArm"] = Vector3(-8.0 - 6.0 * maxf(sl, 0.0), 0.0, 0.0)
	r["_hips"] = Vector3(-0.022 * cl, 0.0, 0.0)
	return r


## expuesto: tras el golpe cae de rodillas con el pecho adelantado (el núcleo a la vista), se queda hasta T_EXPUESTO_ARRIBA y se levanta. Una vez.
static func _pose_expuesto(t: float) -> Dictionary:
	var de_pie: Dictionary = {}
	var antic: Dictionary = {"Spine": Vector3(5.0, 0.0, 0.0), "Spine2": Vector3(4.0, 0.0, 0.0), "Head": Vector3(6.0, 0.0, 0.0), "LeftLeg": Vector3(14.0, 0.0, 0.0), "RightLeg": Vector3(14.0, 0.0, 0.0), "LeftUpLeg": Vector3(-6.0, 0.0, 0.0), "RightUpLeg": Vector3(-6.0, 0.0, 0.0), "_hips": Vector3(0.0, -0.035, 0.0)}
	var rodillas: Dictionary = {
		"LeftUpLeg": Vector3(-6.0, 0.0, 6.0), "RightUpLeg": Vector3(-6.0, 0.0, -6.0), "LeftLeg": Vector3(88.0, 0.0, 0.0), "RightLeg": Vector3(88.0, 0.0, 0.0),
		"LeftFoot": Vector3(-20.0, 0.0, 0.0), "RightFoot": Vector3(-20.0, 0.0, 0.0),
		"Spine": Vector3(-6.0, 0.0, 0.0), "Spine1": Vector3(-5.0, 0.0, 0.0), "Spine2": Vector3(-6.0, 0.0, 0.0), "Head": Vector3(-6.0, 0.0, 0.0),
		"LeftArm": Vector3(-14.0, 0.0, 6.0), "RightArm": Vector3(-14.0, 0.0, -6.0), "LeftForeArm": Vector3(-18.0, 0.0, 0.0), "RightForeArm": Vector3(-18.0, 0.0, 0.0),
		"LeftShoulder": Vector3(0.0, 0.0, -3.0), "RightShoulder": Vector3(0.0, 0.0, 3.0),
		"_hips": Vector3(0.0, -0.12, 0.0)}
	var latido: float = sin(TAU * (t - T_EXPUESTO_ABAJO) / 2.2)
	var respira: Dictionary = {"Spine2": Vector3(-1.6 * latido, 0.0, 0.0), "Head": Vector3(-0.8 * latido, 0.0, 0.0), "LeftShoulder": Vector3(0.0, 0.0, 1.5 * latido), "RightShoulder": Vector3(0.0, 0.0, -1.5 * latido)}
	var llaves: Array = [
		[0.0, de_pie],
		[0.55, antic, "suave"],
		[T_EXPUESTO_ABAJO, rodillas, "acelera"],
		[T_EXPUESTO_ARRIBA, rodillas, "lineal"],
		[4.7, antic, "suave"],
		[DUR_EXPUESTO, de_pie, "suave"],
	]
	var p: Dictionary = _llaves(llaves, t)
	if t > T_EXPUESTO_ABAJO + 0.35 and t < T_EXPUESTO_ARRIBA:
		var u: float = clampf(minf(t - (T_EXPUESTO_ABAJO + 0.35), T_EXPUESTO_ARRIBA - t) / 0.4, 0.0, 1.0)
		p = _suma(p, _escalar(respira, u))
	elif t >= T_EXPUESTO_ABAJO and t <= T_EXPUESTO_ABAJO + 0.35:
		# el golpe de las rodillas contra el suelo: el torso rebota un poco
		var u: float = (t - T_EXPUESTO_ABAJO) / 0.35
		p = _suma(p, {"Spine2": Vector3(5.0 * sin(PI * u), 0.0, 0.0), "Head": Vector3(4.0 * sin(PI * u), 0.0, 0.0)})
	return p


static func _escalar(p: Dictionary, k: float) -> Dictionary:
	var r: Dictionary = {}
	for h in p:
		r[h] = (p[h] as Vector3) * k
	return r


## resbalar: pierde el equilibrio hacia atrás, agita los brazos y cae de espaldas; queda tumbado (los últimos 0,4 s son la pose final).
static func _pose_resbalar(t: float) -> Dictionary:
	var estar: Dictionary = {}
	var k1: Dictionary = {"Hips": Vector3(-5.0, 0.0, 0.0), "Spine": Vector3(-5.0, 0.0, 0.0), "Spine2": Vector3(-4.0, 0.0, 0.0),
		"LeftArm": Vector3(-35.0, 0.0, 30.0), "RightArm": Vector3(-35.0, 0.0, -30.0), "LeftLeg": Vector3(10.0, 0.0, 0.0), "RightLeg": Vector3(4.0, 0.0, 0.0),
		"LeftUpLeg": Vector3(-14.0, 0.0, 0.0), "RightUpLeg": Vector3(-5.0, 0.0, 0.0), "Head": Vector3(-5.0, 0.0, 0.0), "_hips": Vector3(0.0, 0.0, -0.01)}
	var k2: Dictionary = {"Hips": Vector3(-24.0, 0.0, 0.0), "Spine": Vector3(-4.0, 0.0, 0.0), "Spine2": Vector3(-6.0, 0.0, 0.0),
		"LeftArm": Vector3(-95.0, 0.0, 55.0), "RightArm": Vector3(-60.0, 0.0, -65.0), "LeftForeArm": Vector3(-20.0, 0.0, 0.0), "RightForeArm": Vector3(-30.0, 0.0, 0.0),
		"LeftUpLeg": Vector3(-30.0, 0.0, 0.0), "RightUpLeg": Vector3(-10.0, 0.0, 0.0), "LeftLeg": Vector3(20.0, 0.0, 0.0), "RightLeg": Vector3(10.0, 0.0, 0.0),
		"Head": Vector3(-10.0, 0.0, 0.0), "_hips": Vector3(0.0, 0.0, -0.05)}
	var k3: Dictionary = {"Hips": Vector3(-56.0, 0.0, 0.0), "Spine": Vector3(-4.0, 0.0, 0.0), "Spine2": Vector3(-6.0, 0.0, 0.0),
		"LeftArm": Vector3(-70.0, 0.0, 70.0), "RightArm": Vector3(-110.0, 0.0, -50.0), "LeftForeArm": Vector3(-30.0, 0.0, 0.0), "RightForeArm": Vector3(-10.0, 0.0, 0.0),
		"LeftUpLeg": Vector3(-14.0, 0.0, 0.0), "RightUpLeg": Vector3(-24.0, 0.0, 0.0), "LeftLeg": Vector3(8.0, 0.0, 0.0), "RightLeg": Vector3(24.0, 0.0, 0.0),
		"Head": Vector3(-14.0, 0.0, 0.0), "_hips": Vector3(0.0, 0.0, -0.09)}
	var k4: Dictionary = {"Hips": Vector3(-88.0, 0.0, 0.0), "Spine": Vector3(-2.0, 0.0, 0.0), "Spine2": Vector3(-3.0, 0.0, 0.0),
		"LeftArm": Vector3(-15.0, 0.0, 50.0), "RightArm": Vector3(-15.0, 0.0, -50.0), "LeftForeArm": Vector3(-8.0, 0.0, 0.0), "RightForeArm": Vector3(-8.0, 0.0, 0.0),
		"LeftUpLeg": Vector3(-4.0, 0.0, 8.0), "RightUpLeg": Vector3(-4.0, 0.0, -8.0), "LeftLeg": Vector3(6.0, 0.0, 0.0), "RightLeg": Vector3(6.0, 0.0, 0.0),
		"Head": Vector3(-12.0, 0.0, 0.0), "_hips": Vector3(0.0, 0.0, -0.13)}
	return _llaves([[0.0, estar], [0.3, k1, "acelera"], [0.7, k2, "lineal"], [1.15, k3, "lineal"], [1.55, k4, "acelera"], [DUR_RESBALAR, k4, "lineal"]], t)


## Pose final de `resbalar` (tumbado de espaldas): el punto de partida de `levantarse`.
static func pose_tumbado() -> Dictionary:
	return _pose_resbalar(DUR_RESBALAR)


## levantarse: desde tumbado se apoya en los puños y se incorpora despacio (4,6 s): sentado, de rodillas, de pie.
static func _pose_levantarse(t: float) -> Dictionary:
	var tumbado: Dictionary = pose_tumbado()
	var apoya: Dictionary = tumbado.duplicate(true)
	apoya["LeftArm"] = Vector3(-10.0, 0.0, 30.0)
	apoya["RightArm"] = Vector3(-10.0, 0.0, -30.0)
	apoya["Spine"] = Vector3(8.0, 0.0, 0.0)
	apoya["Spine2"] = Vector3(14.0, 0.0, 0.0)
	apoya["Head"] = Vector3(18.0, 0.0, 0.0)
	var sentado: Dictionary = {
		"Hips": Vector3(-88.0, 0.0, 0.0), "Spine": Vector3(40.0, 0.0, 0.0), "Spine1": Vector3(20.0, 0.0, 0.0), "Spine2": Vector3(14.0, 0.0, 0.0), "Head": Vector3(-10.0, 0.0, 0.0),
		"LeftArm": Vector3(-30.0, 0.0, 28.0), "RightArm": Vector3(-30.0, 0.0, -28.0),
		"LeftUpLeg": Vector3(-4.0, 0.0, 10.0), "RightUpLeg": Vector3(-4.0, 0.0, -10.0), "LeftLeg": Vector3(28.0, 0.0, 0.0), "RightLeg": Vector3(28.0, 0.0, 0.0), "_hips": Vector3(0.0, 0.0, -0.06)}
	var acuclillado: Dictionary = {
		"Hips": Vector3(-28.0, 0.0, 0.0), "Spine": Vector3(16.0, 0.0, 0.0), "Spine1": Vector3(8.0, 0.0, 0.0), "Spine2": Vector3(6.0, 0.0, 0.0),
		"LeftUpLeg": Vector3(-72.0, 0.0, 12.0), "RightUpLeg": Vector3(-72.0, 0.0, -12.0), "LeftLeg": Vector3(100.0, 0.0, 0.0), "RightLeg": Vector3(100.0, 0.0, 0.0),
		"LeftFoot": Vector3(-10.0, 0.0, 0.0), "RightFoot": Vector3(-10.0, 0.0, 0.0),
		"LeftArm": Vector3(-30.0, 0.0, 14.0), "RightArm": Vector3(-30.0, 0.0, -14.0), "_hips": Vector3(0.0, -0.1, 0.0)}
	var de_pie: Dictionary = {}
	return _llaves([[0.0, tumbado], [0.5, apoya, "suave"], [1.7, sentado, "suave"], [3.0, acuclillado, "suave"], [4.2, de_pie, "suave"], [DUR_LEVANTARSE, de_pie, "lineal"]], t)


## u del juego recorridas hacia delante a los `t` s del clip `attack` (0 hasta T_AVANCE_INI, AVANCE_GOLPE desde INSTANTE_GOLPE). Es lo que sube la raíz del modelo (÷ ESCALA_JUEGO).
static func avance_golpe_en(t: float) -> float:
	if t <= T_AVANCE_INI:
		return 0.0
	if t <= T_AVANCE_IMPULSO:
		var u: float = (t - T_AVANCE_INI) / (T_AVANCE_IMPULSO - T_AVANCE_INI)
		return AVANCE_GOLPE * AVANCE_IMPULSO * u * u * (3.0 - 2.0 * u)
	if t < INSTANTE_GOLPE:
		var v: float = (t - T_AVANCE_IMPULSO) / (INSTANTE_GOLPE - T_AVANCE_IMPULSO)
		return AVANCE_GOLPE * (AVANCE_IMPULSO + (1.0 - AVANCE_IMPULSO) * v * v)
	return AVANCE_GOLPE


## attack: mazazo con los dos puños (ver las constantes T_ATK_*). Las rotaciones son acumulativas por la cadena y en ejes del modelo (+X = hacia delante lo de arriba y hacia atrás lo que cuelga).
static func _pose_attack(t: float) -> Dictionary:
	var reposo: Dictionary = _pose_idle(0.0)
	var antic: Dictionary = {
		"LeftUpLeg": Vector3(-14.0, 0.0, 0.0), "RightUpLeg": Vector3(-14.0, 0.0, 0.0), "LeftLeg": Vector3(26.0, 0.0, 0.0), "RightLeg": Vector3(26.0, 0.0, 0.0),
		"LeftFoot": Vector3(-12.0, 0.0, 0.0), "RightFoot": Vector3(-12.0, 0.0, 0.0),
		"Spine": Vector3(4.0, 0.0, 0.0), "Spine2": Vector3(2.0, 0.0, 0.0), "Head": Vector3(-3.0, 0.0, 0.0),
		"LeftArm": Vector3(24.0, 0.0, 6.0), "RightArm": Vector3(24.0, 0.0, -6.0), "LeftForeArm": Vector3(8.0, 0.0, 0.0), "RightForeArm": Vector3(8.0, 0.0, 0.0)}
	var carga: Dictionary = {
		"LeftUpLeg": Vector3(-10.0, 0.0, 0.0), "RightUpLeg": Vector3(-10.0, 0.0, 0.0), "LeftLeg": Vector3(18.0, 0.0, 0.0), "RightLeg": Vector3(18.0, 0.0, 0.0),
		"LeftFoot": Vector3(-8.0, 0.0, 0.0), "RightFoot": Vector3(-8.0, 0.0, 0.0),
		"Spine": Vector3(-5.0, 0.0, 0.0), "Spine1": Vector3(-4.0, 0.0, 0.0), "Spine2": Vector3(-4.0, 0.0, 0.0), "Head": Vector3(12.0, 0.0, 0.0),
		"LeftShoulder": Vector3(0.0, 0.0, 6.0), "RightShoulder": Vector3(0.0, 0.0, -6.0),
		"LeftArm": Vector3(-170.0, 0.0, -24.0), "RightArm": Vector3(-170.0, 0.0, 24.0), "LeftForeArm": Vector3(-6.0, 0.0, 0.0), "RightForeArm": Vector3(-6.0, 0.0, 0.0)}
	var caida: Dictionary = {
		"LeftUpLeg": Vector3(-78.0, 0.0, 0.0), "RightUpLeg": Vector3(-62.0, 0.0, 0.0), "LeftLeg": Vector3(120.0, 0.0, 0.0), "RightLeg": Vector3(108.0, 0.0, 0.0),
		"LeftFoot": Vector3(-42.0, 0.0, 0.0), "RightFoot": Vector3(-46.0, 0.0, 0.0),
		"Spine": Vector3(10.0, 0.0, 0.0), "Spine1": Vector3(9.0, 0.0, 0.0), "Spine2": Vector3(9.0, 0.0, 0.0), "Head": Vector3(-14.0, 0.0, 0.0),
		"LeftShoulder": Vector3(0.0, 0.0, 2.0), "RightShoulder": Vector3(0.0, 0.0, -2.0),
		"LeftArm": Vector3(-50.0, 0.0, -8.0), "RightArm": Vector3(-50.0, 0.0, 8.0), "LeftForeArm": Vector3(-4.0, 0.0, 0.0), "RightForeArm": Vector3(-4.0, 0.0, 0.0)}
	var agachado: Dictionary = {
		"LeftUpLeg": Vector3(-14.0, 0.0, 0.0), "RightUpLeg": Vector3(-14.0, 0.0, 0.0), "LeftLeg": Vector3(26.0, 0.0, 0.0), "RightLeg": Vector3(26.0, 0.0, 0.0),
		"LeftFoot": Vector3(-12.0, 0.0, 0.0), "RightFoot": Vector3(-12.0, 0.0, 0.0),
		"Spine": Vector3(6.0, 0.0, 0.0), "Spine1": Vector3(4.0, 0.0, 0.0), "Spine2": Vector3(3.0, 0.0, 0.0),
		"LeftArm": Vector3(-30.0, 0.0, 0.0), "RightArm": Vector3(-30.0, 0.0, 0.0), "LeftForeArm": Vector3(-8.0, 0.0, 0.0), "RightForeArm": Vector3(-8.0, 0.0, 0.0)}
	var llaves: Array = [
		[0.0, reposo],
		[T_ATK_CARGA, antic, "suave"],
		[T_ATK_ARRIBA, carga, "suave"],
		[T_ATK_IMPACTO, caida, "acelera"],
		[T_ATK_FIN_REBOTE, caida, "lineal"],
		[2.05, agachado, "suave"],
		[DUR_ATTACK, reposo, "suave"],
	]
	var p: Dictionary = _llaves(llaves, t)
	# temblor de tensión en los últimos 0,3 s de la carga
	if t > T_ATK_ARRIBA - 0.3 and t <= T_ATK_ARRIBA:
		var u: float = (t - (T_ATK_ARRIBA - 0.3)) / 0.3
		var tem: float = sin(TAU * 11.0 * t) * u
		p = _suma(p, {"LeftArm": Vector3(2.0 * tem, 0.0, 0.0), "RightArm": Vector3(2.0 * tem, 0.0, 0.0), "Spine2": Vector3(0.8 * tem, 0.0, 0.0), "Hips": Vector3(0.0, 0.0, 0.6 * tem)})
	# rebote y temblor tras el impacto: todo el cuerpo se sacude y los brazos se despegan un pelo del suelo (solo hacia arriba: nunca atraviesan)
	if t > T_ATK_IMPACTO and t < T_ATK_IMPACTO + 0.4:
		var d: float = t - T_ATK_IMPACTO
		var env: float = exp(-d * 9.0)
		var osc: float = sin(TAU * 11.0 * d)
		p = _suma(p, {"Spine2": Vector3(-2.5 * osc * env, 0.0, 0.0), "Head": Vector3(2.0 * osc * env, 0.0, 0.0), "Hips": Vector3(0.0, 0.0, 1.2 * osc * env),
			"LeftArm": Vector3(2.0 * maxf(osc, 0.0) * env, 0.0, 0.0), "RightArm": Vector3(2.0 * maxf(osc, 0.0) * env, 0.0, 0.0), "_hips": Vector3(0.0, 0.004 * maxf(osc, 0.0) * env, 0.0)})
	p = _suma(p, {"_hips": Vector3(0.0, 0.0, avance_golpe_en(t) / ESCALA_JUEGO)})
	return p


## hit: un temblor corto con el torso un poco hacia atrás; apenas se inmuta.
static func _pose_hit(t: float) -> Dictionary:
	var a: float = (t / 0.06) if t < 0.06 else exp(-(t - 0.06) * 5.0)
	var tem: float = sin(TAU * 13.0 * t) * exp(-t * 7.0)
	var r: Dictionary = {}
	r["Spine"] = Vector3(-5.0 * a, 0.0, 0.0)
	r["Spine2"] = Vector3(-4.0 * a + 1.6 * tem, 1.0 * tem, 0.0)
	r["Head"] = Vector3(-4.0 * a - 1.0 * tem, 0.0, 0.0)
	r["LeftArm"] = Vector3(6.0 * a, 0.0, 0.0)
	r["RightArm"] = Vector3(6.0 * a, 0.0, 0.0)
	r["LeftShoulder"] = Vector3(0.0, 0.0, 1.5 * tem)
	r["RightShoulder"] = Vector3(0.0, 0.0, -1.5 * tem)
	r["_hips"] = Vector3(0.0, 0.0, -0.012 * a)
	return r


## death: se desploma hacia delante (las piernas ceden, cae de bruces) y queda quieto. El desmoronado en rocas lo hace el juego.
static func _pose_death(t: float) -> Dictionary:
	var k0: Dictionary = {}
	var k1: Dictionary = {"LeftUpLeg": Vector3(-10.0, 0.0, 0.0), "RightUpLeg": Vector3(-10.0, 0.0, 0.0), "LeftLeg": Vector3(26.0, 0.0, 0.0), "RightLeg": Vector3(26.0, 0.0, 0.0),
		"Spine": Vector3(8.0, 0.0, 0.0), "Head": Vector3(10.0, 0.0, 0.0), "_hips": Vector3(0.0, -0.05, 0.0), "LeftArm": Vector3(-8.0, 0.0, 0.0), "RightArm": Vector3(-8.0, 0.0, 0.0)}
	var k2: Dictionary = {"LeftUpLeg": Vector3(-8.0, 0.0, 4.0), "RightUpLeg": Vector3(-8.0, 0.0, -4.0), "LeftLeg": Vector3(86.0, 0.0, 0.0), "RightLeg": Vector3(86.0, 0.0, 0.0),
		"LeftFoot": Vector3(-20.0, 0.0, 0.0), "RightFoot": Vector3(-20.0, 0.0, 0.0),
		"Spine": Vector3(24.0, 0.0, 0.0), "Spine2": Vector3(10.0, 0.0, 0.0), "Head": Vector3(14.0, 0.0, 0.0), "_hips": Vector3(0.0, -0.12, 0.0),
		"LeftArm": Vector3(-20.0, 0.0, 6.0), "RightArm": Vector3(-20.0, 0.0, -6.0)}
	var k3: Dictionary = {"Hips": Vector3(86.0, 0.0, 0.0), "LeftUpLeg": Vector3(-2.0, 0.0, 6.0), "RightUpLeg": Vector3(-2.0, 0.0, -6.0), "LeftLeg": Vector3(10.0, 0.0, 0.0), "RightLeg": Vector3(10.0, 0.0, 0.0),
		"Spine": Vector3(4.0, 0.0, 0.0), "Spine2": Vector3(2.0, 0.0, 0.0), "Head": Vector3(-10.0, 0.0, 0.0), "_hips": Vector3(0.0, 0.0, 0.16),
		"LeftArm": Vector3(-130.0, 0.0, 25.0), "RightArm": Vector3(-130.0, 0.0, -25.0)}
	return _llaves([[0.0, k0], [0.45, k1, "acelera"], [1.0, k2, "suave"], [1.9, k3, "acelera"], [DUR_DEATH, k3, "lineal"]], t)


## ---------------------------------------------------------------------------------------------------------------------------------------
##  Cinemática directa y muestreo
## ---------------------------------------------------------------------------------------------------------------------------------------
class _Ctx:
	var sk: Skeleton3D
	var prefijo: String
	var orden: Array[int] = []
	var rest_local: Array[Transform3D] = []
	var padre: Array[int] = []

	func _init(p_sk: Skeleton3D, p_prefijo: String) -> void:
		sk = p_sk
		prefijo = p_prefijo
		for i in sk.get_bone_count():
			rest_local.append(sk.get_bone_rest(i))
			padre.append(sk.get_bone_parent(i))
		var visto: Dictionary = {}
		var pend: Array[int] = []
		for i in sk.get_bone_count():
			pend.append(i)
		while not pend.is_empty():
			var sig: Array[int] = []
			for i in pend:
				if padre[i] < 0 or visto.has(padre[i]):
					orden.append(i)
					visto[i] = true
				else:
					sig.append(i)
			pend = sig

	func hueso(nombre: String) -> int:
		return sk.find_bone(AnimacionesGolem.PREFIJO_HUESO + nombre)

	## Cinemática directa de una pose {hueso: grados}: devuelve [bases globales, orígenes globales, rotaciones locales (Quaternion)]. `desp` mueve la cadera.
	func fk(pose: Dictionary, desp: Vector3) -> Array:
		var n: int = sk.get_bone_count()
		var gb: Array[Basis] = []
		var go: Array[Vector3] = []
		var lq: Array[Quaternion] = []
		gb.resize(n)
		go.resize(n)
		lq.resize(n)
		for i in orden:
			var nombre: String = String(sk.get_bone_name(i)).trim_prefix(AnimacionesGolem.PREFIJO_HUESO)
			var e: Vector3 = pose.get(nombre, Vector3.ZERO)
			var r := Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ) if e != Vector3.ZERO else Basis.IDENTITY
			var rl: Transform3D = rest_local[i]
			var pg: Basis = Basis.IDENTITY
			var po := Vector3.ZERO
			if padre[i] >= 0:
				pg = gb[padre[i]]
				po = go[padre[i]]
			var lb: Basis = pg.inverse() * r * pg * rl.basis
			var lo: Vector3 = rl.origin + (desp if padre[i] < 0 else Vector3.ZERO)
			lq[i] = lb.get_rotation_quaternion()
			gb[i] = pg * lb
			go[i] = po + pg * lo
		return [gb, go, lq]

	func animar(dur: float, f: Callable, modo: String, bucle: bool) -> Animation:
		var an := Animation.new()
		an.length = dur
		an.loop_mode = Animation.LOOP_LINEAR if bucle else Animation.LOOP_NONE
		var n: int = sk.get_bone_count()
		var pistas: Array[int] = []
		for i in n:
			var p: int = an.add_track(Animation.TYPE_ROTATION_3D)
			an.track_set_path(p, NodePath(prefijo + sk.get_bone_name(i)))
			pistas.append(p)
		var pc: int = an.add_track(Animation.TYPE_POSITION_3D)
		var raiz: int = hueso("Hips")
		an.track_set_path(pc, NodePath(prefijo + sk.get_bone_name(raiz)))
		# referencia de los pies en reposo (modo «pies»)
		var ref: Array = fk({}, Vector3.ZERO)
		var base_pie: float = 1e9
		for h in AnimacionesGolem.HUESOS_PIE:
			base_pie = minf(base_pie, (ref[1] as Array[Vector3])[hueso(h)].y)
		var nf: int = int(round(dur * AnimacionesGolem.FPS))
		var previo: Array = []
		previo.resize(n)
		for k in range(nf + 1):
			var t: float = minf(float(k) / AnimacionesGolem.FPS, dur)
			var pose: Dictionary = f.call(t if not (bucle and k == nf) else 0.0)
			var desp: Vector3 = pose.get("_hips", Vector3.ZERO)
			var r: Array = fk(pose, desp)
			var go: Array[Vector3] = r[1]
			var dy: float = 0.0
			if modo == "pies":
				var bajo: float = 1e9
				for h in AnimacionesGolem.HUESOS_PIE:
					bajo = minf(bajo, go[hueso(h)].y)
				dy = base_pie - bajo
			else:
				for nombre in AnimacionesGolem.SUELO_HUESO:
					var b: int = hueso(nombre)
					if b >= 0:
						dy = maxf(dy, float(AnimacionesGolem.SUELO_HUESO[nombre]) - go[b].y)
			var lq: Array[Quaternion] = r[2]
			for i in n:
				var q: Quaternion = lq[i]
				if previo[i] != null and (previo[i] as Quaternion).dot(q) < 0.0:
					q = -q
				previo[i] = q
				an.rotation_track_insert_key(pistas[i], t, q)
			an.position_track_insert_key(pc, t, rest_local[raiz].origin + desp + Vector3(0.0, dy, 0.0))
		return an
