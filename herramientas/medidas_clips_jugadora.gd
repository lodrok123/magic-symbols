class_name MedidasClipsJugadora
extends RefCounted
## MEDIDAS Y COMPROBACIONES de los clips nuevos de la jugadora (24/10: abrir_cofre, agacharse, ofrecer, saludo, empujar; arte/meshy/jugadora_clips.glb vía ClipsFamilia).
## Las comparten prueba_jugadora_base.gd (la base con ropa) y prueba_estados_anim.gd (la jugadora actual, woodland_wanderer): los dos usan `comprobar`.
## Se miran los clips tal como los reproduce el personaje (los traducidos a su esqueleto), con el AnimationPlayer a pelo (el árbol se apaga).

const ROLES: Array = ["abrir_cofre", "agacharse", "ofrecer", "saludo", "empujar"]
const MUESTRAS: int = 30
## Duraciones esperadas (s) de cada clip recortado, con su tolerancia (jugadora_clips.glb: AbrirCofre 0,8..3,6 · Agacharse 0..3,5 · Ofrecer 2,97 · Saludo 2,0 · Empujar 3,67..5,30).
const DURACION: Dictionary = {"abrir_cofre": 2.8, "agacharse": 3.5, "ofrecer": 2.97, "saludo": 2.0, "empujar": 1.63}
const DURACION_TOL: float = 0.05
## Pies: ningún hueso de suela por debajo del suelo (hundido) ni a más de esto del alto del modelo (flotando) en NINGÚN fotograma; con los pies plantados (agacharse, abrir, ofrecer,
## saludo) el mínimo sale en torno a 0.
const SUELA_HUNDE_MAX: float = 0.04
const SUELA_FLOTA_MAX: float = 0.06
## El avance horizontal de la cadera de `empujar` a lo largo del clip (fracción del alto del modelo): sin deriva de raíz.
const EMPUJAR_DERIVA_MAX: float = 0.02
## Cierre del bucle de `empujar`: diferencia de altura de la cadera entre el último fotograma y el primero (fracción del alto) y giro medio por hueso (rad) entre ellos.
const EMPUJAR_CIERRE_Y_MAX: float = 0.01
const EMPUJAR_CIERRE_GIRO_MAX: float = 0.10
## Cuánto se aleja la cadera del clip, en horizontal, de la del Idle (fracción del alto): los clips de Meshy traen la postura puesta algo de lado.
const CADERA_DE_IDLE_MAX: float = 0.12
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]


## Mide el clip `clip` del personaje `p`: altura de suela mínima y máxima sobre el reposo (u del modelo, ya divididas por `alto`), deriva horizontal de la cadera respecto
## a su primer fotograma, posición horizontal de la cadera en el primer fotograma, y los saltos entre el último fotograma y el primero (altura de cadera y giro medio por hueso).
static func medir(p: Pj3D, clip: String) -> Dictionary:
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap: AnimationPlayer = p._ap
	var alto: float = p.alto_modelo()
	var cadera: int = sk.find_bone("mixamorig_Hips")
	var reposo: float = _suela_min_reposo(sk)
	var largo: float = ap.get_animation(clip).length
	var suela_min: float = INF
	var suela_max: float = -INF
	var p0 := Vector3.ZERO
	var deriva: float = 0.0
	var pose_ini: Array = []
	var pose_fin: Array = []
	for k in range(MUESTRAS + 1):
		var t: float = largo * float(k) / float(MUESTRAS)
		t = minf(t, largo - 0.001)         # (el clip va en bucle: en `largo` justo volvería al primer fotograma)
		var y: float = _suela_en(p, sk, ap, clip, t) - reposo
		suela_min = minf(suela_min, y)
		suela_max = maxf(suela_max, y)
		var o: Vector3 = sk.get_bone_global_pose(cadera).origin
		if k == 0:
			p0 = o
			pose_ini = _giros(sk)
		deriva = maxf(deriva, Vector2(o.x - p0.x, o.z - p0.z).length())
		if k == MUESTRAS:
			pose_fin = _giros(sk)
			var giro: float = 0.0
			for i in range(pose_ini.size()):
				giro += (pose_ini[i] as Quaternion).angle_to(pose_fin[i] as Quaternion)
			return {"suela_min": suela_min / alto, "suela_max": suela_max / alto, "deriva": deriva / alto, "cadera0": Vector2(p0.x, p0.z) / alto,
				"cierre_y": absf(o.y - p0.y) / alto, "cierre_giro": giro / float(maxi(pose_ini.size(), 1))}
	return {}


## Hace las comprobaciones de los cinco roles en `p` (la jugadora actual o la base) y las cuenta con `ok` (Callable(bool, String)).
static func comprobar(p: Pj3D, etiqueta: String, ok: Callable) -> void:
	var idle: String = p.clip_de("idle")
	var cadera_idle := Vector2.ZERO
	if idle != "":
		cadera_idle = medir(p, idle)["cadera0"] as Vector2
	for r in ROLES:
		var clip: String = p.clip_de(r)
		ok.call(clip != "" and p.duracion(r) > 0.0, "%s: el rol %s resuelve a un clip (%s, %.2f s)" % [etiqueta, r, clip, p.duracion(r)])
		if clip == "":
			continue
		ok.call(absf(p.duracion(r) - float(DURACION[r])) <= DURACION_TOL, "%s: %s dura %.2f s (esperado %.2f ±%.2f)" % [etiqueta, r, p.duracion(r), float(DURACION[r]), DURACION_TOL])
		var m: Dictionary = medir(p, clip)
		print("INFO  %s: %s suela %.3f..%.3f · deriva %.3f · cadera0 %s (idle %s) · cierre y %.3f giro %.3f rad" % [etiqueta, r, m["suela_min"], m["suela_max"], m["deriva"],
			(m["cadera0"] as Vector2).snappedf(0.001), cadera_idle.snappedf(0.001), m["cierre_y"], m["cierre_giro"]])
		ok.call(float(m["suela_min"]) >= -SUELA_HUNDE_MAX and float(m["suela_max"]) <= SUELA_FLOTA_MAX,
			"%s: %s no hunde ni levanta los pies (suela %.3f..%.3f del alto, tope -%.2f..%.2f)" % [etiqueta, r, m["suela_min"], m["suela_max"], SUELA_HUNDE_MAX, SUELA_FLOTA_MAX])
		ok.call(((m["cadera0"] as Vector2) - cadera_idle).length() <= CADERA_DE_IDLE_MAX, "%s: %s empieza con la cadera cerca de la del idle (%.3f del alto, tope %.2f)" % [etiqueta, r,
			((m["cadera0"] as Vector2) - cadera_idle).length(), CADERA_DE_IDLE_MAX])
	# empujar: sin avance de raíz y el bucle cierra.
	var me: Dictionary = medir(p, p.clip_de("empujar"))
	ok.call(float(me["deriva"]) <= EMPUJAR_DERIVA_MAX, "%s: empujar no tiene deriva de raíz (%.4f del alto, tope %.2f)" % [etiqueta, me["deriva"], EMPUJAR_DERIVA_MAX])
	ok.call(float(me["cierre_y"]) <= EMPUJAR_CIERRE_Y_MAX and float(me["cierre_giro"]) <= EMPUJAR_CIERRE_GIRO_MAX,
		"%s: el bucle de empujar cierra (altura de cadera %.4f, giro medio %.3f rad entre el último fotograma y el primero)" % [etiqueta, me["cierre_y"], me["cierre_giro"]])
	# jugar() pone cada rol y se queda en él; y «saludo» / «ofrecer» no pisan a `talk` ni a `wave`.
	if p._arbol != null:
		p._ap.stop()
		p._ap.active = false          # `medir` apagó el árbol para mirar los clips a pelo: se devuelve el mando al árbol
		p._arbol.active = true
	for r in ROLES:
		p.animacion_actual = ""
		p.jugar(r, r != "empujar")
		ok.call(p.animacion_actual == r and p.estado_anim() == Pj3D.estado_de(r), "%s: jugar(%s) deja estado «%s» (%s)" % [etiqueta, r, Pj3D.estado_de(r), p.estado_anim()])
	p.animacion_actual = ""
	p.jugar("idle")
	ok.call(p.clip_de("talk") != p.clip_de("ofrecer") and p.clip_de("talk") != "", "%s: `talk` sigue siendo su clip de siempre (%s), distinto de ofrecer (%s)" % [etiqueta, p.clip_de("talk"), p.clip_de("ofrecer")])


static func _giros(sk: Skeleton3D) -> Array:
	var res: Array = []
	for i in range(sk.get_bone_count()):
		res.append(sk.get_bone_pose_rotation(i))
	return res


static func _suela_min_reposo(sk: Skeleton3D) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_rest(i).origin.y)
	return m


static func _suela_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String, t: float) -> float:
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	ap.play(clip)
	ap.seek(t, true)
	sk.force_update_all_bone_transforms()
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_pose(i).origin.y)
	return m
