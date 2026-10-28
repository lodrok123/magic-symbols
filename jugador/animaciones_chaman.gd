class_name AnimacionesChaman
extends RefCounted

## ANIMACIONES DEL CHAMÁN GOBLIN (goblin_chaman_rig.glb: el esqueleto de Marimanta de 66 huesos sobre su malla, salida de tools/autorig_chaman.py). El GLB no trae clips:
##   · idle, andar, hablar, tramar, correr: los de Marimanta traducidos con ClipsFamilia; hit, death, ahogarse: los del goblin guerrero.
##   · `trazar`, `clavar` y `lanzar` se GENERAN aquí, a 30 fps, con cinemática directa para el cuerpo y CINEMÁTICA INVERSA de dos huesos para brazos y piernas:
##       - los pies se quedan clavados donde están en reposo (IK de las piernas) y el cuerpo se inclina/agacha sobre ellos;
##       - el bastón va agarrado a la mano DERECHA con la transformación de Equipo3D (BASTON_CHAMAN_POS, el palo por el eje +Z de la mano, a BASTON_CHAMAN_AGARRE de la punta) y la izquierda
##         lo sujeta más abajo (AGARRE_IZQ): el clip se define por el BASTÓN (punta, dirección) y de ahí salen las muñecas y la orientación de las manos.
## Unidades del modelo (0,95 de alto; en el juego ×0,85/0,95). Ejes del modelo: Y arriba, +Z delante, +X la izquierda del chamán.
##   trazar (bucle, DUR_TRAZAR): inclinado, el bastón con la punta rozando el suelo delante de él, que recorre los trazos de TrazosRitual (sello y rombo) con el barrido de la punta.
##   clavar (una vez, DUR_CLAVAR): alza el bastón con las dos manos (tan alto como llegan sus brazos cortos), lo baja de golpe y clava la punta en el centro de la runa a los INSTANTE_CLAVAR s.
##   lanzar (una vez, DUR_LANZAR): echa el bastón atrás y lo lanza hacia delante, soltando la bola de veneno del orbe a los INSTANTE_LANZAR s.

const GLB: String = "goblin_chaman_rig"
const PREFIJO_HUESO: String = "mixamorig_"
const FPS: float = 30.0

const DUR_TRAZAR: float = 2.5
const DUR_CLAVAR: float = 1.0
const DUR_LANZAR: float = 1.1
const ROLES: Array = ["trazar", "clavar", "lanzar"]
## Segundo del clip `clavar` en que la punta llega al suelo (el impacto: onda, destello). Medido en herramientas/prueba_rig_chaman.gd.
const INSTANTE_CLAVAR: float = 0.62
## Segundo del clip `lanzar` en que sale la bola de veneno (el orbe llega hacia delante).
const INSTANTE_LANZAR: float = 0.55
const T_CLAVAR_ALZADO: float = 0.42             ## s en que el bastón llega arriba
const T_CLAVAR_BAJA: float = 0.50               ## s en que empieza a bajar de golpe

## --- La pose de trazar (todo en unidades del modelo) ---
## El chamán GIRA sobre sí mismo (el nodo rota: `yaw_en(u)`, lo aplica ChamanRitual) con la punta del bastón fuera, a `rho` de él: así la punta recorre el sello CENTRADO EN SUS PIES. El círculo es
## una vuelta entera; el rombo, un barrido de esquina a esquina con el cuerpo girando hacia cada una. El clip solo lleva la distancia de la punta (siempre recta delante) y la inclinación del palo.
const RADIO_TRAZO: float = 0.62                 ## radio del sello que dibuja la punta (= 0,55 u de juego); lo máximo que alcanza con los brazos cortos
const CENTRO_TRAZO: Vector3 = Vector3(0.0, 0.0, 0.0)       ## el centro del sello son sus pies
const PUNTA_Y: float = 0.004                    ## la punta roza el suelo a esta altura (el suelo del modelo es y = 0)
const PUNTA_ALZADA: float = 0.028               ## cuánto se alza entre trazos
const PALMA_Z: float = 0.15                     ## la mano derecha queda a esto por delante de los pies: de ahí sale la inclinación del palo según hasta dónde llega la punta
const RHO_CLAVAR: float = 0.38                  ## a qué distancia de sus pies clava el bastón (el centro del sello, lo más cerca que cabe)
const N_TABLA: int = 1500
const AGARRE_IZQ: float = 0.62                  ## a qué distancia de la punta sujeta la mano izquierda (la derecha va a Equipo3D.BASTON_CHAMAN_AGARRE)
const INCLINACION: float = 60.0
const CADERA_TRAZAR: Vector3 = Vector3(0.0, -0.04, -0.02)
const REPARTO_INCL: Array = [0.2, 0.25, 0.25, 0.3]         ## Hips, Spine, Spine1, Spine2
const CABEZA_CONTRA: float = 0.6                ## fracción de la inclinación que la cabeza deshace (mira hacia delante y un poco abajo)
const POLO_CODO_D: Vector3 = Vector3(-0.5, -0.8, -0.3)
const POLO_CODO_I: Vector3 = Vector3(0.5, -0.8, -0.3)
const POLO_RODILLA: Vector3 = Vector3(0.0, 0.0, 1.0)
const MANO_IZQ_PALMA: Vector3 = Vector3(0.012, 0.035, 0.0)  ## el centro de la palma izquierda, en el espacio de su hueso (simétrico al de la derecha)

## ---------------------------------------------------------------------------------------------------------------------------------------
##  API
## ---------------------------------------------------------------------------------------------------------------------------------------

## Los clips generados ({rol: Animation}). `prefijo` = «ruta del Skeleton3D desde la raíz del AnimationPlayer:».
static func construir(sk: Skeleton3D, prefijo: String) -> Dictionary:
	var rig := _Rig.new(sk)
	var r: Dictionary = {}
	r["trazar"] = rig.animar(prefijo, DUR_TRAZAR, AnimacionesChaman._estado_trazar_t, true)
	r["clavar"] = rig.animar(prefijo, DUR_CLAVAR, AnimacionesChaman._estado_clavar, false)
	r["lanzar"] = rig.animar(prefijo, DUR_LANZAR, AnimacionesChaman._estado_lanzar, false)
	return r


## Dónde está la punta del bastón (en el espacio del modelo) a los `t` s de `an`, y el desvío de las manos respecto a donde las pedía el clip.
static func punta_de_clip(sk: Skeleton3D, an: Animation, t: float) -> Vector3:
	var rig := _Rig.new(sk)
	var f: Array = rig.fk_clip(an, t)
	var go: Array = f[1]
	var gb: Array = f[0]
	var h: int = rig.ix["RightHand"]
	return (go[h] as Vector3) + (gb[h] as Basis) * Equipo3D.BASTON_CHAMAN_POS


## Lo mismo para el orbe (centro, 0,88 del palo).
static func orbe_de_clip(sk: Skeleton3D, an: Animation, t: float) -> Vector3:
	var rig := _Rig.new(sk)
	var f: Array = rig.fk_clip(an, t)
	var h: int = rig.ix["RightHand"]
	var punta: Vector3 = (f[1][h] as Vector3) + (f[0][h] as Basis) * Equipo3D.BASTON_CHAMAN_POS
	var eje: Vector3 = (f[0][h] as Basis) * Vector3(0, 0, 1)
	return punta + eje * (Equipo3D.BASTON_CHAMAN_ESCALA * 0.88)


## Tabla del recorrido polar de la punta: para cada instante u (0..1) la distancia `rho` a sus pies y el giro `yaw` (relativo, sin dar saltos de 2π) que lleva su frente hacia la punta.
static var _t_rho: PackedFloat32Array = PackedFloat32Array()
static var _t_yaw: PackedFloat32Array = PackedFloat32Array()


static func _tabla() -> void:
	if _t_rho.size() > 0:
		return
	var prev: float = 0.0
	var y0: float = 0.0
	for i in range(N_TABLA + 1):
		var u: float = float(i) / float(N_TABLA)
		var ab: Vector2 = TrazosRitual.punta(u)["pos"]
		var x: float = -ab.x * RADIO_TRAZO
		var z: float = ab.y * RADIO_TRAZO
		var ang: float = atan2(x, z)
		if i == 0:
			y0 = ang
			prev = 0.0
		var rel: float = ang - y0
		rel = prev + wrapf(rel - prev, -PI, PI)
		prev = rel
		_t_rho.append(sqrt(x * x + z * z))
		_t_yaw.append(rel)


static func _muestra(t: PackedFloat32Array, u: float) -> float:
	var f: float = clampf(u, 0.0, 1.0) * float(N_TABLA)
	var i: int = mini(int(f), N_TABLA - 1)
	return lerpf(t[i], t[i + 1], f - float(i))


## Giro (rad) que lleva el chamán desde su orientación inicial a los `u` del trazo (el nodo gira en el sitio; la punta queda siempre delante).
static func yaw_en(u: float) -> float:
	_tabla()
	return _muestra(_t_yaw, u)


## La punta (modelo) que pide `trazar` a la fracción `u`: siempre delante (x = 0), a `rho` de sus pies y a ras de suelo salvo entre trazos.
static func punta_pedida(u: float) -> Vector3:
	_tabla()
	var p: Dictionary = TrazosRitual.punta(u)
	return Vector3(0.0, PUNTA_Y + (1.0 - float(p["baja"])) * PUNTA_ALZADA, _muestra(_t_rho, u))


## Estado del bastón con la punta a `rho` delante: el palo cae hacia el cuerpo con la elevación que deja la mano a PALMA_Z.
static func _estado_rho(rho: float, y: float, incl: float = INCLINACION) -> Dictionary:
	var c: float = clampf((rho - PALMA_Z) / Equipo3D.BASTON_CHAMAN_AGARRE, 0.2, 0.98)
	var d := Vector3(0.0, sqrt(1.0 - c * c), -c)
	return {"punta": Vector3(0.0, y, rho), "d": d, "incl": incl, "cadera": CADERA_TRAZAR, "izq": AGARRE_IZQ}


static func _estado_trazar_t(t: float) -> Dictionary:
	return _estado_trazar(t / DUR_TRAZAR)


static func _estado_trazar(u: float) -> Dictionary:
	var p: Vector3 = punta_pedida(u)
	return _estado_rho(p.z, p.y)


## Mezcla dos estados (todo lo numérico) con `u` ya suavizado.
static func _mezcla(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var r: Dictionary = {}
	for k in a:
		var x: Variant = a[k]
		var y: Variant = b[k]
		if x is Vector3:
			r[k] = (x as Vector3).lerp(y as Vector3, u)
		else:
			r[k] = lerpf(float(x), float(y), u)
	return r


static func _suave(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _estado_clavar(t: float) -> Dictionary:
	var ini: Dictionary = _estado_trazar(0.0)
	# ANTICIPACIÓN: se echa un poco atrás y baja el bastón antes de subirlo; arriba, el palo vertical lo más alto que dan sus brazos, con el cuerpo erguido y arqueado hacia atrás
	var atras: Dictionary = {"punta": Vector3(0.0, 0.0, 0.40), "d": Vector3(0, 0.80, -0.6).normalized(), "incl": 30.0, "cadera": Vector3(0.0, -0.05, -0.04), "izq": AGARRE_IZQ}
	var arriba: Dictionary = {"punta": Vector3(-0.02, 0.07, 0.10), "d": Vector3(0, 0.99, -0.1).normalized(), "incl": -6.0, "cadera": Vector3(0.0, 0.01, 0.0), "izq": 0.62}
	var impacto: Dictionary = _estado_rho(RHO_CLAVAR, 0.0)
	const T_ATRAS: float = 0.12
	if t <= T_ATRAS:
		return _mezcla(ini, atras, _suave(t / T_ATRAS))
	if t <= T_CLAVAR_ALZADO:
		return _mezcla(atras, arriba, _suave((t - T_ATRAS) / (T_CLAVAR_ALZADO - T_ATRAS)))
	if t <= T_CLAVAR_BAJA:
		var temblor: float = sin(TAU * 18.0 * t) * 0.004
		var e: Dictionary = arriba.duplicate(true)
		e["punta"] = (e["punta"] as Vector3) + Vector3(temblor, 0.0, 0.0)
		return e
	var u: float = clampf((t - T_CLAVAR_BAJA) / (INSTANTE_CLAVAR - T_CLAVAR_BAJA), 0.0, 1.0)
	var m: Dictionary = _mezcla(arriba, impacto, u * u)
	m["d"] = (m["d"] as Vector3).normalized()
	if t > INSTANTE_CLAVAR:
		var d: float = t - INSTANTE_CLAVAR
		var env: float = exp(-d * 10.0)
		m["incl"] = INCLINACION + 3.0 * sin(TAU * 8.0 * d) * env
		m["cadera"] = CADERA_TRAZAR + Vector3(0, -0.01 * sin(TAU * 8.0 * d) * env, 0)
	return m


static func _estado_lanzar(t: float) -> Dictionary:
	var palma_a := Vector3(-0.06, 0.52, 0.06)        # atrás: el palo alzado con el orbe hacia atrás
	var d_a: Vector3 = Vector3(0, 0.80, -0.6).normalized()
	var palma_b := Vector3(-0.05, 0.46, 0.20)        # el brazo lanza hacia delante: el orbe apunta al frente
	var d_b: Vector3 = Vector3(0, 0.18, 0.98).normalized()
	var palma_0 := Vector3(-0.07, 0.40, 0.10)
	var d_0: Vector3 = Vector3(0, 0.97, -0.2).normalized()
	var u: float
	var palma: Vector3
	var d: Vector3
	var incl: float
	if t <= 0.40:
		u = _suave(t / 0.40)
		palma = palma_0.lerp(palma_a, u)
		d = d_0.lerp(d_a, u).normalized()
		incl = lerpf(4.0, -4.0, u)
	elif t <= INSTANTE_LANZAR:
		u = clampf((t - 0.40) / (INSTANTE_LANZAR - 0.40), 0.0, 1.0)
		u = u * u
		palma = palma_a.lerp(palma_b, u)
		d = d_a.lerp(d_b, u).normalized()
		incl = lerpf(-4.0, 14.0, u)
	else:
		u = _suave((t - INSTANTE_LANZAR - 0.08) / (DUR_LANZAR - INSTANTE_LANZAR - 0.08))
		palma = palma_b.lerp(palma_0, u)
		d = d_b.lerp(d_0, u).normalized()
		incl = lerpf(14.0, 4.0, u)
	var punta: Vector3 = palma - d * Equipo3D.BASTON_CHAMAN_AGARRE
	return {"punta": punta, "d": d, "incl": incl, "cadera": Vector3(0, -0.01, -0.01), "izq": -1.0}


## ---------------------------------------------------------------------------------------------------------------------------------------
##  Esqueleto: cinemática directa + IK de dos huesos
## ---------------------------------------------------------------------------------------------------------------------------------------
class _Rig:
	var sk: Skeleton3D
	var n: int = 0
	var nom: PackedStringArray = PackedStringArray()
	var padre: Array[int] = []
	var rest_l: Array[Transform3D] = []
	var rest_gb: Array[Basis] = []
	var rest_go: Array[Vector3] = []
	var orden: Array[int] = []
	var ix: Dictionary = {}

	func _init(p_sk: Skeleton3D) -> void:
		sk = p_sk
		n = sk.get_bone_count()
		for i in n:
			var corto: String = String(sk.get_bone_name(i)).trim_prefix(AnimacionesChaman.PREFIJO_HUESO)
			nom.append(corto)
			ix[corto] = i
			padre.append(sk.get_bone_parent(i))
			rest_l.append(sk.get_bone_rest(i))
		var visto: Dictionary = {}
		var pend: Array[int] = []
		for i in n:
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
		rest_gb.resize(n)
		rest_go.resize(n)
		for i in orden:
			var pb: Basis = Basis.IDENTITY if padre[i] < 0 else rest_gb[padre[i]]
			var po: Vector3 = Vector3.ZERO if padre[i] < 0 else rest_go[padre[i]]
			rest_gb[i] = pb * rest_l[i].basis
			rest_go[i] = po + pb * rest_l[i].origin

	## IK de dos huesos a-b-c (muslo/espinilla/pie o brazo/antebrazo/mano): devuelve [base global de a, base global de b, muñeca/tobillo alcanzado].
	func _dos_huesos(a: int, b: int, c: int, s: Vector3, objetivo: Vector3, polo: Vector3) -> Array:
		var v1: Vector3 = rest_go[b] - rest_go[a]
		var v2: Vector3 = rest_go[c] - rest_go[b]
		var l1: float = v1.length()
		var l2: float = v2.length()
		var u: Vector3 = objetivo - s
		var dist: float = clampf(u.length(), 0.001, l1 + l2 - 0.0005)
		u = u.normalized()
		var x: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
		var h: float = sqrt(maxf(l1 * l1 - x * x, 0.0))
		var pv: Vector3 = polo - u * polo.dot(u)
		pv = pv.normalized() if pv.length() > 0.0001 else Vector3.UP.cross(u).normalized()
		var e: Vector3 = s + u * x + pv * h
		var w: Vector3 = s + u * dist
		var ba: Basis = Basis(Quaternion(v1.normalized(), (e - s).normalized())) * rest_gb[a]
		var bb: Basis = Basis(Quaternion(v2.normalized(), (w - e).normalized())) * rest_gb[b]
		return [ba, bb, w]

	## Resuelve una pose: devuelve [bases globales, orígenes globales, rotaciones locales, {"res_d", "res_i"} desvío de muñecas (m)].
	func resolver(est: Dictionary) -> Array:
		var gb: Array[Basis] = []
		var go: Array[Vector3] = []
		var lq: Array[Quaternion] = []
		gb.resize(n)
		go.resize(n)
		lq.resize(n)
		var cadera: Vector3 = est.get("cadera", Vector3.ZERO)
		var incl: float = float(est.get("incl", 0.0))
		var eul: Dictionary = {}
		var rep: Array = AnimacionesChaman.REPARTO_INCL
		eul["Hips"] = Vector3(incl * float(rep[0]), 0, 0)
		eul["Spine"] = Vector3(incl * float(rep[1]), 0, 0)
		eul["Spine1"] = Vector3(incl * float(rep[2]), 0, 0)
		eul["Spine2"] = Vector3(incl * float(rep[3]), 0, 0)
		eul["Neck"] = Vector3(-incl * 0.2, 0, 0)
		eul["Head"] = Vector3(-incl * (AnimacionesChaman.CABEZA_CONTRA - 0.2), 0, 0)
		var ov: Dictionary = {}
		var res: Dictionary = {"res_d": 0.0, "res_i": 0.0}
		# El bastón: punta, dirección y las dos manos.
		var punta: Vector3 = est["punta"]
		var d: Vector3 = (est["d"] as Vector3).normalized()
		var zw: Vector3 = d
		var xw: Vector3 = Vector3(-1, 0, 0) - zw * zw.dot(Vector3(-1, 0, 0))
		xw = xw.normalized()
		var yw: Vector3 = zw.cross(xw)
		var rh := Basis(xw, yw, zw)
		var muneca_d: Vector3 = punta - rh * Equipo3D.BASTON_CHAMAN_POS
		var izq_libre: bool = float(est.get("izq", AnimacionesChaman.AGARRE_IZQ)) < 0.0
		if izq_libre:
			eul["LeftArm"] = Vector3(-18.0, 0.0, 6.0)
			eul["LeftForeArm"] = Vector3(-25.0, 0.0, 0.0)
		var muneca_i: Vector3 = punta + d * float(est.get("izq", AnimacionesChaman.AGARRE_IZQ)) - rh * AnimacionesChaman.MANO_IZQ_PALMA
		for i in orden:
			var nombre: String = nom[i]
			var pg: Basis = Basis.IDENTITY if padre[i] < 0 else gb[padre[i]]
			var po: Vector3 = Vector3.ZERO if padre[i] < 0 else go[padre[i]]
			var lo: Vector3 = rest_l[i].origin + (cadera if padre[i] < 0 else Vector3.ZERO)
			go[i] = po + pg * lo
			if nombre == "RightArm" or (nombre == "LeftArm" and not izq_libre):
				var der: bool = nombre == "RightArm"
				var pre: String = "Right" if der else "Left"
				var r2: Array = _dos_huesos(i, ix[pre + "ForeArm"], ix[pre + "Hand"], go[i], muneca_d if der else muneca_i, AnimacionesChaman.POLO_CODO_D if der else AnimacionesChaman.POLO_CODO_I)
				ov[i] = r2[0]
				ov[ix[pre + "ForeArm"]] = r2[1]
				ov[ix[pre + "Hand"]] = rh
				res["res_d" if der else "res_i"] = ((r2[2] as Vector3) - (muneca_d if der else muneca_i)).length()
			elif nombre == "RightUpLeg" or nombre == "LeftUpLeg":
				var pre2: String = "Right" if nombre == "RightUpLeg" else "Left"
				var r3: Array = _dos_huesos(i, ix[pre2 + "Leg"], ix[pre2 + "Foot"], go[i], rest_go[ix[pre2 + "Foot"]], AnimacionesChaman.POLO_RODILLA)
				ov[i] = r3[0]
				ov[ix[pre2 + "Leg"]] = r3[1]
				ov[ix[pre2 + "Foot"]] = rest_gb[ix[pre2 + "Foot"]]
			var b: Basis
			if ov.has(i):
				b = ov[i]
			else:
				var e: Vector3 = eul.get(nombre, Vector3.ZERO)
				var r: Basis = Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ) if e != Vector3.ZERO else Basis.IDENTITY
				b = r * pg * rest_l[i].basis
			gb[i] = b
			lq[i] = (pg.inverse() * b).get_rotation_quaternion()
		return [gb, go, lq, res]

	func animar(prefijo: String, dur: float, f: Callable, bucle: bool) -> Animation:
		var an := Animation.new()
		an.length = dur
		an.loop_mode = Animation.LOOP_LINEAR if bucle else Animation.LOOP_NONE
		var pistas: Array[int] = []
		for i in n:
			var p: int = an.add_track(Animation.TYPE_ROTATION_3D)
			an.track_set_path(p, NodePath(prefijo + sk.get_bone_name(i)))
			pistas.append(p)
		var raiz: int = ix["Hips"]
		var pc: int = an.add_track(Animation.TYPE_POSITION_3D)
		an.track_set_path(pc, NodePath(prefijo + sk.get_bone_name(raiz)))
		var nf: int = int(round(dur * AnimacionesChaman.FPS))
		var previo: Array = []
		previo.resize(n)
		for k in range(nf + 1):
			var t: float = minf(float(k) / AnimacionesChaman.FPS, dur)
			var est: Dictionary = f.call(t if not (bucle and k == nf) else 0.0)
			var r: Array = resolver(est)
			var lq: Array[Quaternion] = r[2]
			for i in n:
				var q: Quaternion = lq[i]
				if previo[i] != null and (previo[i] as Quaternion).dot(q) < 0.0:
					q = -q
				previo[i] = q
				an.rotation_track_insert_key(pistas[i], t, q)
			an.position_track_insert_key(pc, t, rest_l[raiz].origin + (est.get("cadera", Vector3.ZERO) as Vector3))
		return an

	## FK de un clip (sus pistas de rotación y la de la cadera) en el instante `t`: [bases globales, orígenes globales].
	func fk_clip(an: Animation, t: float) -> Array:
		var gb: Array[Basis] = []
		var go: Array[Vector3] = []
		gb.resize(n)
		go.resize(n)
		var rot: Dictionary = {}
		var pos_cadera: Vector3 = rest_l[ix["Hips"]].origin
		for k in an.get_track_count():
			var b: int = sk.find_bone(String(an.track_get_path(k)).get_slice(":", 1))
			if b < 0:
				continue
			if an.track_get_type(k) == Animation.TYPE_ROTATION_3D:
				rot[b] = an.rotation_track_interpolate(k, t)
			elif an.track_get_type(k) == Animation.TYPE_POSITION_3D and b == ix["Hips"]:
				pos_cadera = an.position_track_interpolate(k, t)
		for i in orden:
			var l := Transform3D(Basis(rot[i] as Quaternion) if rot.has(i) else rest_l[i].basis, pos_cadera if padre[i] < 0 else rest_l[i].origin)
			var pg: Basis = Basis.IDENTITY if padre[i] < 0 else gb[padre[i]]
			var po: Vector3 = Vector3.ZERO if padre[i] < 0 else go[padre[i]]
			gb[i] = pg * l.basis
			go[i] = po + pg * l.origin
		return [gb, go]
