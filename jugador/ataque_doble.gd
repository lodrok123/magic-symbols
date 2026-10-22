class_name AtaqueDoble
extends RefCounted

## ATAQUE DOBLE del goblin asesino (22/10): dos cortes cruzados con una daga en cada mano, construido POR CÓDIGO sobre la guardia (el Idle) del propio goblin,
## como Empujado/Levantarse/ManoQuemada en Pj3D. Ningún clip de los que se tienen (Gribble, goblins de Meshy) es un ataque con los brazos extendidos.
##
## Secuencia (DURACION s, la fracción de cada instante va en las constantes T_*):
##   1. ANTICIPACIÓN  (0 → T_PLEGADO): los dos brazos se recogen y se cruzan sobre el pecho (el derecho por encima), el torso se gira hacia la IZQUIERDA y se inclina.
##   2. CORTE 1 (T_PLEGADO → T_FIN_DERECHO): el brazo DERECHO se estira y barre en horizontal, a la altura del hombro, de delante-izquierda a la derecha del cuerpo
##      (el azimut pasa por 0, o sea justo de frente, en T_CORTE_DERECHO). El torso gira hacia la derecha acompañándolo.
##   3. CORTE 2 (T_FIN_DERECHO → T_FIN_IZQUIERDO): el IZQUIERDO, que seguía cruzado, hace lo mismo en sentido contrario (de delante-derecha a la izquierda,
##      de frente en T_CORTE_IZQUIERDO) y el torso gira hacia la izquierda. Los dos cortes se cruzan por delante.
##   4. VUELTA: los dos brazos extendidos se bajan juntos hasta la guardia en el último tramo.
##
## CÓMO SE CONSTRUYE (no se escriben ángulos locales a ciegas: los ejes de los huesos Mixamo vienen torcidos, como se vio con Ahogarse en anadir_ahogarse.py):
##   · el cuerpo parte de la pose del Idle en t = 0 (la guardia) y cada hueso se recalcula por cinemática directa en ESPACIO DE ESQUELETO;
##   · torso: Spine, Spine1 y Spine2 giran en vertical (guiñada, a partes iguales) y Spine se inclina hacia delante; el cuello contragira para que la cabeza siga mirando
##     al frente; los hombros (Shoulder) giran en vertical para adelantar el que corta;
##   · brazos: para Arm, ForeArm y Hand se da la DIRECCIÓN en que apunta el hueso (azimut y elevación, en grados: azimut 0 = delante, + = izquierda del personaje;
##     elevación + = arriba). El hueso se orienta con el giro mínimo desde la pose que le tocaría por su padre (así conserva su torsión y no se retuerce el codo)
##     y un giro propio sobre su eje (roll). La dirección entre dos llaves se interpola esféricamente con un modo (suave, lineal, acelera, frena).

const NOMBRE_CLIP: String = "AtaqueDoble"
const DURACION: float = 1.0
const FPS: float = 60.0                      ## muestreo del clip: los barridos duran ~0,1 s y a 30 fps saldrían a saltos
const PREFIJO_HUESO: String = "mixamorig_"

## --- Instantes (fracción de DURACION) ---
const T_PLEGADO: float = 0.26                ## acaban de cruzarse los brazos sobre el pecho
const T_ESTIRA: float = 0.31                 ## el derecho ya está estirado, cruzado hacia la izquierda (empieza el barrido)
const T_CORTE_DERECHO: float = 0.36          ## el brazo derecho pasa por delante: EL PRIMER CORTE
const T_FIN_DERECHO: float = 0.46            ## acaba el barrido a la derecha
const T_ESTIRA_IZQ: float = 0.51
const T_CORTE_IZQUIERDO: float = 0.56        ## el brazo izquierdo pasa por delante: EL SEGUNDO CORTE
const T_FIN_IZQUIERDO: float = 0.66
const T_VUELTA: float = 0.78                 ## desde aquí los dos brazos bajan hasta la guardia (llegan en t = 1)
## Los instantes en que el golpe «sale» (los usa Combate3D y la prueba).
const CORTES: Array = [T_CORTE_DERECHO, T_CORTE_IZQUIERDO]

## --- Tablas de los brazos ---
## Llave = [fracción del clip, dirección del Arm (azimut, elevación), dirección del ForeArm, roll en grados (sobre el eje del brazo), modo con el que se LLEGA a la llave].
## Dirección null = la de la guardia (la del Idle en t = 0). La mano (Hand) apunta siempre como el antebrazo salvo en la guardia.
## Modos: «suave» (empieza y acaba despacio), «lineal», «acelera» (empieza despacio), «frena» (llega despacio: el final de un barrido).
const AZ_EXTENDIDO_CRUZADO: float = 45.0     ## donde empieza el barrido: el brazo estirado cruzado por delante del pecho (grados, hacia el lado contrario)
const AZ_EXTENDIDO_ABIERTO: float = -85.0    ## donde acaba: el brazo estirado casi de lado (grados, hacia su propio lado)
const ELEV_HORIZONTAL: float = 0.0           ## el brazo estirado va a la altura del hombro
const ELEV_CRUCE: float = 8.0                ## al principio del barrido (cruzado por delante del pecho) el brazo va algo más alto para no rozar el esternón
## Plegado cruzado sobre el pecho: el derecho (por encima y más adelantado) y el izquierdo (por debajo y más atrás), para que no se atraviesen.
## [dirección del Arm, dirección del ForeArm]; las muñecas pasan del eje del cuerpo, con las manos llegando al hombro contrario.
const PLEGADO_DERECHO: Array = [Vector2(28.0, -50.0), Vector2(85.0, 35.0)]
const PLEGADO_IZQUIERDO: Array = [Vector2(-25.0, -70.0), Vector2(-85.0, 10.0)]

## Paso intermedio de la anticipación: el antebrazo pasa por DELANTE del cuerpo (si fuera en línea recta desde la guardia, con la mano de atrás, la muñeca atravesaría el torso).
const PASO_DERECHO: Array = [Vector2(20.0, -60.0), Vector2(15.0, 10.0)]
const PASO_IZQUIERDO: Array = [Vector2(-10.0, -70.0), Vector2(-15.0, 10.0)]
const T_PASO: float = 0.14

const BRAZO_DERECHO: Array = [
	[0.0, null, null, 0.0, "acelera"],
	[T_PASO, PASO_DERECHO[0], PASO_DERECHO[1], 0.0, "acelera"],
	[T_PLEGADO, PLEGADO_DERECHO[0], PLEGADO_DERECHO[1], 0.0, "frena"],
	[T_ESTIRA, Vector2(AZ_EXTENDIDO_CRUZADO, ELEV_CRUCE), Vector2(AZ_EXTENDIDO_CRUZADO, ELEV_CRUCE), 0.0, "acelera"],
	[T_CORTE_DERECHO, Vector2(0.0, ELEV_HORIZONTAL), Vector2(0.0, ELEV_HORIZONTAL), 0.0, "lineal"],
	[T_FIN_DERECHO, Vector2(AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), Vector2(AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), 0.0, "frena"],
	[T_VUELTA, Vector2(AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), Vector2(AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), 0.0, "lineal"],
	[1.0, null, null, 0.0, "suave"],
]

## El izquierdo es el espejo del derecho (azimut de signo cambiado) con los tiempos desplazados: corta DESPUÉS, cuando el derecho ya ha acabado.
const BRAZO_IZQUIERDO: Array = [
	[0.0, null, null, 0.0, "acelera"],
	[T_PASO, PASO_IZQUIERDO[0], PASO_IZQUIERDO[1], 0.0, "acelera"],
	[T_PLEGADO, PLEGADO_IZQUIERDO[0], PLEGADO_IZQUIERDO[1], 0.0, "frena"],
	[T_FIN_DERECHO, PLEGADO_IZQUIERDO[0], PLEGADO_IZQUIERDO[1], 0.0, "lineal"],
	[T_ESTIRA_IZQ, Vector2(-AZ_EXTENDIDO_CRUZADO, ELEV_CRUCE), Vector2(-AZ_EXTENDIDO_CRUZADO, ELEV_CRUCE), 0.0, "acelera"],
	[T_CORTE_IZQUIERDO, Vector2(0.0, ELEV_HORIZONTAL), Vector2(0.0, ELEV_HORIZONTAL), 0.0, "lineal"],
	[T_FIN_IZQUIERDO, Vector2(-AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), Vector2(-AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), 0.0, "frena"],
	[T_VUELTA, Vector2(-AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), Vector2(-AZ_EXTENDIDO_ABIERTO, ELEV_HORIZONTAL), 0.0, "lineal"],
	[1.0, null, null, 0.0, "suave"],
]

## --- Torso (llave = [fracción, grados, modo]) ---
## Giro del torso: hacia dónde miran los hombros (grados alrededor de la vertical: 0 = de frente, + = girado a la izquierda del personaje; null = el de la guardia, que en
## Combat_Stance es de ~-46°: la postura de boxeador, de medio lado). Se reparte a partes iguales entre Spine, Spine1 y Spine2.
const TORSO_GIRO: Array = [
	[0.0, null, "suave"], [T_PLEGADO, 22.0, "suave"], [T_FIN_DERECHO, -25.0, "suave"], [T_FIN_IZQUIERDO, 25.0, "suave"], [1.0, null, "suave"],
]
## Inclinación hacia delante (se la lleva Spine).
const TORSO_INCLINA: Array = [
	[0.0, 0.0, "suave"], [T_PLEGADO, 8.0, "suave"], [T_FIN_DERECHO, 10.0, "suave"], [T_FIN_IZQUIERDO, 10.0, "suave"], [1.0, 0.0, "suave"],
]
## Cuánto de ese giro contrarresta el cuello (0 = la cabeza gira con el torso, 1 = se queda de frente).
const CABEZA_CONTRAGIRO: float = 0.85
## Adelantar el hombro del brazo que corta (guiñada del Shoulder, en grados; + = hacia delante del hombro DERECHO; el izquierdo lo hace con el signo cambiado).
const HOMBRO_DERECHO: Array = [
	[0.0, 0.0, "suave"], [T_ESTIRA, 0.0, "suave"], [T_CORTE_DERECHO, 12.0, "suave"], [T_FIN_DERECHO, 16.0, "suave"], [T_VUELTA, 16.0, "lineal"], [1.0, 0.0, "suave"],
]
const HOMBRO_IZQUIERDO: Array = [
	[0.0, 0.0, "suave"], [T_ESTIRA_IZQ, 0.0, "suave"], [T_CORTE_IZQUIERDO, 12.0, "suave"], [T_FIN_IZQUIERDO, 16.0, "suave"], [T_VUELTA, 16.0, "lineal"], [1.0, 0.0, "suave"],
]

const ARRIBA: Vector3 = Vector3(0.0, 1.0, 0.0)
const DERECHA_MODELO: Vector3 = Vector3(1.0, 0.0, 0.0)    ## eje X del modelo (izquierda del personaje): la inclinación hacia delante gira alrededor de él


## Dirección (en espacio de esqueleto, +Z = delante, +X = izquierda del personaje) de azimut `az` y elevación `el`, en grados.
static func direccion(az: float, el: float) -> Vector3:
	var a: float = deg_to_rad(az)
	var e: float = deg_to_rad(el)
	return Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e)).normalized()


## Cuánto de una llave a la siguiente (0..1) lleva el progreso lineal `s` según el modo con el que se llega a la segunda.
static func _curva(modo: String, s: float) -> float:
	match modo:
		"suave":
			return smoothstep(0.0, 1.0, s)
		"acelera":
			return s * s
		"frena":
			return 1.0 - (1.0 - s) * (1.0 - s)
	return s


## La llave que hay antes de `u` y la que hay después, y el progreso (ya con la curva del modo) entre las dos: [índice a, índice b, f].
static func _tramo(llaves: Array, u: float) -> Array:
	var n: int = llaves.size()
	for i in range(n - 1):
		var ua: float = float((llaves[i] as Array)[0])
		var ub: float = float((llaves[i + 1] as Array)[0])
		if u <= ub or i == n - 2:
			var s: float = clampf((u - ua) / maxf(ub - ua, 0.00001), 0.0, 1.0)
			return [i, i + 1, _curva(String((llaves[i + 1] as Array)[-1]), s)]
	return [0, 0, 0.0]


## Valor de una tabla [fracción, grados, modo] en `u`. Un valor null vale `guardia`.
static func valor(tabla: Array, u: float, guardia: float = 0.0) -> float:
	var t: Array = _tramo(tabla, u)
	var va: Variant = (tabla[int(t[0])] as Array)[1]
	var vb: Variant = (tabla[int(t[1])] as Array)[1]
	return lerpf(guardia if va == null else float(va), guardia if vb == null else float(vb), float(t[2]))


## Dirección de la tabla de un brazo en `u`: `cual` 1 = Arm, 2 = ForeArm. `guardia` = la dirección de la guardia (la que vale la llave null).
static func direccion_brazo(tabla: Array, u: float, cual: int, guardia: Vector3) -> Vector3:
	var t: Array = _tramo(tabla, u)
	var da: Vector3 = _dir_llave(tabla[int(t[0])] as Array, cual, guardia)
	var db: Vector3 = _dir_llave(tabla[int(t[1])] as Array, cual, guardia)
	if da.dot(db) > 0.99999:
		return db
	return da.slerp(db, float(t[2]))


static func _dir_llave(llave: Array, cual: int, guardia: Vector3) -> Vector3:
	var v: Variant = llave[cual]
	if v == null:
		return guardia
	var d: Vector2 = v as Vector2
	return direccion(d.x, d.y)


## Roll (grados) de la tabla de un brazo en `u`.
static func roll_brazo(tabla: Array, u: float) -> float:
	var t: Array = _tramo(tabla, u)
	return lerpf(float((tabla[int(t[0])] as Array)[3]), float((tabla[int(t[1])] as Array)[3]), float(t[2]))


## Construye el clip sobre el esqueleto `sk`. `base` es el Idle del personaje (ya traducido a `sk`): se toma su pose en t = 0 como guardia.
## `prefijo` = ruta del esqueleto relativa a la raíz del AnimationPlayer, con los dos puntos («Armature/Skeleton3D:»).
static func construir(sk: Skeleton3D, base: Animation, prefijo: String) -> Animation:
	var n: int = sk.get_bone_count()
	# La guardia: rotación local de cada hueso con el Idle en t = 0 (los huesos sin pista se quedan en su reposo) y posición de la cadera.
	var local0: Array = []
	local0.resize(n)
	var cadera: int = sk.find_bone(PREFIJO_HUESO + "Hips")
	var pos_cadera: Vector3 = sk.get_bone_rest(cadera).origin if cadera >= 0 else Vector3.ZERO
	for i in range(n):
		local0[i] = sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
	for t in range(base.get_track_count()):
		var nom: String = String(base.track_get_path(t)).get_slice(":", 1)
		var b: int = sk.find_bone(nom)
		if b < 0:
			continue
		if base.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			local0[b] = base.rotation_track_interpolate(t, 0.0)
		elif base.track_get_type(t) == Animation.TYPE_POSITION_3D and b == cadera:
			pos_cadera = base.position_track_interpolate(t, 0.0)
	var orden: Array = _orden(sk)
	# Direcciones de la guardia de cada hueso de brazo (sin tocar el torso): hay que conocerlas ANTES de recorrer los fotogramas.
	var guardia: Dictionary = _direcciones_guardia(sk, orden, local0)
	var giro_guardia: float = _giro_hombros_guardia(sk, orden, local0, pos_cadera)
	var cadenas: Dictionary = {}   # índice de hueso -> [tabla del brazo, cual (1 Arm, 2 ForeArm, 3 Hand)]
	var hombros: Dictionary = {}   # índice de hueso -> [tabla, signo]
	for lado in ["Right", "Left"]:
		var tabla: Array = BRAZO_DERECHO if lado == "Right" else BRAZO_IZQUIERDO
		for k in [["Arm", 1], ["ForeArm", 2], ["Hand", 3]]:
			var b: int = sk.find_bone("%s%s%s" % [PREFIJO_HUESO, lado, k[0]])
			if b >= 0:
				cadenas[b] = [tabla, int(k[1])]
		var hs: int = sk.find_bone("%s%sShoulder" % [PREFIJO_HUESO, lado])
		if hs >= 0:
			hombros[hs] = [HOMBRO_DERECHO if lado == "Right" else HOMBRO_IZQUIERDO, 1.0 if lado == "Right" else -1.0]
	var espina: Array = []
	for nom in ["Spine", "Spine1", "Spine2"]:
		var b: int = sk.find_bone(PREFIJO_HUESO + nom)
		if b >= 0:
			espina.append(b)
	var cuello: int = sk.find_bone(PREFIJO_HUESO + "Neck")
	# El clip.
	var dest := Animation.new()
	dest.length = DURACION
	dest.loop_mode = Animation.LOOP_NONE
	var pistas: Array = []
	pistas.resize(n)
	for i in range(n):
		var t_n: int = dest.add_track(Animation.TYPE_ROTATION_3D)
		dest.track_set_path(t_n, NodePath(prefijo + sk.get_bone_name(i)))
		pistas[i] = t_n
	var t_pos: int = -1
	if cadera >= 0:
		t_pos = dest.add_track(Animation.TYPE_POSITION_3D)
		dest.track_set_path(t_pos, NodePath(prefijo + sk.get_bone_name(cadera)))
	var pasos: int = maxi(int(ceil(DURACION * FPS)), 2)
	var previo: Array = []
	previo.resize(n)
	for f in range(pasos + 1):
		var u: float = float(f) / float(pasos)
		var psi: float = valor(TORSO_GIRO, u, giro_guardia) - giro_guardia      # lo que hay que girar desde la guardia
		var cabeceo: float = valor(TORSO_INCLINA, u)
		var g: Array = []
		g.resize(n)
		for i in orden:
			var p: int = sk.get_bone_parent(i)
			var gp: Quaternion = Quaternion.IDENTITY if p < 0 else (g[p] as Quaternion)
			var q: Quaternion = gp * (local0[i] as Quaternion)
			if espina.has(i):
				if i == espina[0]:
					q = Quaternion(DERECHA_MODELO, deg_to_rad(cabeceo)) * q
				q = Quaternion(ARRIBA, deg_to_rad(psi) / float(espina.size())) * q
			elif i == cuello:
				q = Quaternion(ARRIBA, -deg_to_rad(psi) * CABEZA_CONTRAGIRO) * q
			elif hombros.has(i):
				var hd: Array = hombros[i]
				q = Quaternion(ARRIBA, deg_to_rad(valor(hd[0] as Array, u) * float(hd[1]))) * q
			elif cadenas.has(i):
				var cd: Array = cadenas[i]
				var cual: int = int(cd[1])
				var dir: Vector3
				if cual < 3:
					dir = direccion_brazo(cd[0] as Array, u, cual, guardia[i] as Vector3)
				else:
					# La mano sigue la dirección del antebrazo, salvo en la guardia (donde vale la suya): mezcla por el peso de «estar en la guardia».
					var peso_guardia: float = _peso_guardia(cd[0] as Array, u)
					dir = direccion_brazo(cd[0] as Array, u, 2, guardia[sk.get_bone_parent(i)] as Vector3)
					if peso_guardia > 0.0:
						dir = dir.slerp(guardia[i] as Vector3, peso_guardia)
				var actual: Vector3 = q * ARRIBA
				q = Quaternion(actual.normalized(), dir) * q
				q = Quaternion(dir, deg_to_rad(roll_brazo(cd[0] as Array, u))) * q
			q = q.normalized()
			g[i] = q
			var loc: Quaternion = (gp.inverse() * q).normalized()
			if previo[i] != null and (previo[i] as Quaternion).dot(loc) < 0.0:
				loc = Quaternion(-loc.x, -loc.y, -loc.z, -loc.w)    # mismo giro en el otro hemisferio: sin vueltas largas al interpolar
			previo[i] = loc
			dest.rotation_track_insert_key(int(pistas[i]), DURACION * u, loc)
		if t_pos >= 0:
			dest.position_track_insert_key(t_pos, DURACION * u, pos_cadera)
	return dest


## Cuánto de «estar en la guardia» (0..1) hay en `u` según las llaves null de la tabla de un brazo (1 en las llaves null, 0 en las demás, lineal entre llaves).
static func _peso_guardia(tabla: Array, u: float) -> float:
	var t: Array = _tramo(tabla, u)
	var wa: float = 1.0 if (tabla[int(t[0])] as Array)[1] == null else 0.0
	var wb: float = 1.0 if (tabla[int(t[1])] as Array)[1] == null else 0.0
	return lerpf(wa, wb, float(t[2]))


## Dirección de cada hueso de brazo con la pose de la guardia, en espacio de esqueleto: {índice de hueso: Vector3}.
static func _direcciones_guardia(sk: Skeleton3D, orden: Array, local0: Array) -> Dictionary:
	var g: Array = []
	g.resize(sk.get_bone_count())
	var res: Dictionary = {}
	for i in orden:
		var p: int = sk.get_bone_parent(i)
		g[i] = (Quaternion.IDENTITY if p < 0 else (g[p] as Quaternion)) * (local0[i] as Quaternion)
		var nom: String = sk.get_bone_name(i)
		if nom.ends_with("Arm") or nom.ends_with("ForeArm") or nom.ends_with("Hand"):
			res[i] = ((g[i] as Quaternion) * ARRIBA).normalized()
	return res


## Hacia dónde miran los hombros en la guardia (grados alrededor de la vertical; 0 = de frente, + = girado a la izquierda): la línea del hombro derecho al izquierdo.
static func _giro_hombros_guardia(sk: Skeleton3D, orden: Array, local0: Array, pos_cadera: Vector3) -> float:
	var g: Array = []
	g.resize(sk.get_bone_count())
	var o: Array = []
	o.resize(sk.get_bone_count())
	for i in orden:
		var p: int = sk.get_bone_parent(i)
		g[i] = (Quaternion.IDENTITY if p < 0 else (g[p] as Quaternion)) * (local0[i] as Quaternion)
		var reposo: Vector3 = sk.get_bone_rest(i).origin
		if p < 0:
			o[i] = pos_cadera
		else:
			o[i] = (o[p] as Vector3) + (g[p] as Quaternion) * reposo
	var r: int = sk.find_bone(PREFIJO_HUESO + "RightArm")
	var l: int = sk.find_bone(PREFIJO_HUESO + "LeftArm")
	if r < 0 or l < 0:
		return 0.0
	var d: Vector3 = (o[l] as Vector3) - (o[r] as Vector3)
	return rad_to_deg(atan2(-d.z, d.x))


## Índices de hueso con los padres antes que los hijos.
static func _orden(sk: Skeleton3D) -> Array:
	var res: Array = []
	var visto: Dictionary = {}
	for i in range(sk.get_bone_count()):
		var cadena: Array = []
		var b: int = i
		while b >= 0 and not visto.has(b):
			cadena.push_front(b)
			visto[b] = true
			b = sk.get_bone_parent(b)
		res.append_array(cadena)
	return res
