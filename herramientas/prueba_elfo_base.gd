extends SceneTree
## PRUEBA del elfo base (arte/modelos/elfo_base.glb, Tripo, esqueleto Mixamo de 65 huesos, sin animaciones): carga como Pj3D, mide lo que debe,
## trae los clips de la familia (chibi_elf, vía ClipsFamilia) y tiene los pies en el suelo. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_elfo_base.gd
## Cómo se VE se mira en docs/capturas/elfo_base/ (herramientas/captura_elfo_base.gd).

const ID: String = "elfo_base"
const ALTO_ESPERADO: float = 1.0          ## u de juego (el de ALTO_PJ en PruebaTest2)
const TOL_ALTO: float = 0.05              ## ±5 %
## Clips propios del GLB (Tripo, 22/10) y el rol que debe resolver a cada uno.
const CLIPS_PROPIOS: Array = ["idle", "walk", "hablar", "greet_02", "cheer"]
const ROLES_PROPIOS: Dictionary = {"idle": "idle", "walk": "walk", "talk": "hablar", "saludo": "greet_02", "celebrar": "cheer"}
## Roles que elfo_base aún no tiene (a la espera de más clips de Pablo): solo se informa, y `run` se sustituye por walk.
const ROLES_PENDIENTES: Array = ["run", "cast", "hit", "death", "roll", "leer", "swim"]
## Bucle de cada clip propio (idle, andar y hablar en bucle; saludar y celebrar, una vez al pedirlos con una_vez).
const CLIPS_EN_BUCLE: Array = ["idle", "walk", "hablar"]
## Cuánto puede alejarse la cadera de donde empieza el clip en horizontal (fracción del alto del modelo): sin movimiento de raíz que desplace al NPC.
const RAIZ_MAX: float = 0.08
## El idle de Tripo (15 s) carga el peso de un pie al otro: la cadera se va ~0,15 del alto hacia un lado y vuelve, con los pies en el suelo. Es balanceo, no deriva.
const IDLE_BALANCEO_MAX: float = 0.2
## Postura del idle: la cabeza (hueso Head) por encima del pecho (Spine2) al menos esta fracción del alto, y su inclinación hacia delante/atrás
## respecto a la vertical (grados, en el plano del cuerpo) por debajo de esto: mira al frente, no cabizbaja.
const CABEZA_SOBRE_PECHO_MIN: float = 0.05
const CABEZA_INCLINACION_MAX: float = 25.0
## Cuánto puede separarse del suelo el hueso de suela más bajo en idle y andar/correr (fracción del alto del modelo). Al andar un pie siempre está en el aire.
const SUELO_IDLE_TOL: float = 0.02
const SUELO_MARCHA_MIN: float = 0.04      ## pisa: el pie más bajo, en el punto más bajo del ciclo, queda a menos de esto
const SUELO_MARCHA_HUNDE: float = -0.03   ## y no atraviesa el suelo más de esto
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	_ok(p.cargar(ID), "elfo_base carga")
	p.set_alto(ALTO_ESPERADO)
	await process_frame
	_ok(absf(p.alto_modelo() * p.scale.y - ALTO_ESPERADO) <= ALTO_ESPERADO * TOL_ALTO, "altura en el juego %.3f (esperada %.2f ±5 %%)" % [p.alto_modelo() * p.scale.y, ALTO_ESPERADO])
	var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
	_ok(not sks.is_empty() and (sks[0] as Skeleton3D).find_bone("mixamorig_Hips") >= 0, "esqueleto con huesos mixamorig")
	var sk: Skeleton3D = sks[0] as Skeleton3D
	_ok(sk.get_bone_count() == 65, "65 huesos (%d)" % sk.get_bone_count())
	_ok(sk.find_bone("mixamorig_LeftHandIndex1") >= 0, "tiene dedos")
	var ap: AnimationPlayer = p._ap
	_ok(ap != null, "AnimationPlayer con los clips propios del GLB (%d clips)" % (ap.get_animation_list().size() if ap != null else 0))
	if ap == null:
		_acabar()
		return
	for c in CLIPS_PROPIOS:
		_ok(ap.has_animation(c), "clip propio «%s» (%.2f s)" % [c, ap.get_animation(c).length if ap.has_animation(c) else 0.0])
	for r in ROLES_PROPIOS.keys():
		_ok(p.clip_de(r) == String(ROLES_PROPIOS[r]) and p.duracion(r) > 0.0, "rol %s -> %s (%.2f s)" % [r, p.clip_de(r), p.duracion(r)])
	for r in ROLES_PENDIENTES:
		print("INFO  rol %s -> %s (pendiente de los clips de Pablo)" % [r, p.clip_de(r) if p.clip_de(r) != "" else "(sin clip)"])
	_ok(p._arbol != null, "árbol de animación montado")
	for c in CLIPS_PROPIOS:
		var bucle: bool = ap.get_animation(c).loop_mode != Animation.LOOP_NONE
		print("INFO  %s: bucle %s (el juego lo pide %s)" % [c, bucle, "en bucle" if CLIPS_EN_BUCLE.has(c) else "una vez"])
	p.jugar("walk")
	await process_frame
	_ok(p.animacion_actual == "walk", "jugar(walk) (actual: %s)" % p.animacion_actual)
	p.jugar("run")
	await process_frame
	_ok(p.animacion_actual == "walk", "jugar(run) sin clip de correr: sigue andando (actual: %s)" % p.animacion_actual)
	for r in ["saludo", "celebrar", "talk"]:
		p.jugar(r, r != "talk")
		await process_frame
		_ok(p.animacion_actual == r, "jugar(%s) sin error (actual: %s)" % [r, p.animacion_actual])
	p.jugar("idle")
	await process_frame
	# Pies: para cada rol, pose real del esqueleto en varios instantes del clip, altura del hueso de suela más bajo (en alturas del modelo).
	var alto: float = p.alto_modelo()
	var reposo: float = _suela_min_reposo(sk)
	_ok(true, "suela más baja en reposo: %.4f u" % reposo)
	for r in ["idle", "walk"]:
		var clip2: String = p.clip_de(r)
		var an: Animation = ap.get_animation(clip2)
		var pasos: int = 24
		var minimo: float = INF
		var maximo: float = -INF
		for k in range(pasos):
			var y: float = _suela_en(p, sk, ap, clip2, an.length * float(k) / float(pasos)) - reposo
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		var rel_min: float = minimo / alto
		var rel_max: float = maximo / alto
		print("INFO  %s (%s): suela mínima %.1f %% , máxima %.1f %% del alto" % [r, clip2, rel_min * 100.0, rel_max * 100.0])
		if r == "idle":
			_ok(absf(rel_min) <= SUELO_IDLE_TOL and absf(rel_max) <= SUELO_IDLE_TOL * 3.0, "idle: pies en el suelo (mín %.3f, máx %.3f del alto)" % [rel_min, rel_max])
		else:
			_ok(rel_min <= SUELO_MARCHA_MIN and rel_min >= SUELO_MARCHA_HUNDE, "%s: pisa el suelo sin hundirse (mín %.3f del alto)" % [r, rel_min])
	# Raíz: la cadera no se aleja en horizontal (el Juego es quien mueve al personaje) en los clips que se quedan en su sitio.
	for c in ["idle", "walk", "hablar"]:
		var deriva: float = _deriva_cadera(p, sk, ap, c) / alto
		var tope: float = IDLE_BALANCEO_MAX if c == "idle" else RAIZ_MAX
		_ok(deriva <= tope, "%s: sin movimiento de raíz (deriva %.3f del alto, tope %.2f)" % [c, deriva, tope])
	# Postura del idle: cabeza por encima del pecho y mirando al frente, en varios instantes.
	var an_i: Animation = ap.get_animation(p.clip_de("idle"))
	var peor_inc: float = 0.0
	var min_sobre: float = INF
	for k in range(8):
		_suela_en(p, sk, ap, p.clip_de("idle"), an_i.length * float(k) / 8.0)
		var cabeza: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
		var pecho: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_Spine2")).origin
		min_sobre = minf(min_sobre, (cabeza.y - pecho.y) / alto)
		var punta: int = sk.find_bone("mixamorig_HeadTop_End")
		if punta >= 0:
			var d: Vector3 = sk.get_bone_global_pose(punta).origin - cabeza
			peor_inc = maxf(peor_inc, absf(rad_to_deg(atan2(d.z, d.y))))
	_ok(min_sobre >= CABEZA_SOBRE_PECHO_MIN, "idle: la cabeza por encima del pecho (mín %.3f del alto)" % min_sobre)
	_ok(peor_inc <= CABEZA_INCLINACION_MAX, "idle: cabeza al frente (inclinación máx %.1f°, tope %.0f°)" % [peor_inc, CABEZA_INCLINACION_MAX])
	_acabar()


func _acabar() -> void:
	print("RESULTADO elfo_base · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _suela_min_reposo(sk: Skeleton3D) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_rest(i).origin.y)
	return m


## Máxima distancia horizontal (u del modelo) de la cadera a su posición en t = 0, a lo largo del clip.
func _deriva_cadera(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> float:
	var h: int = sk.find_bone("mixamorig_Hips")
	var largo: float = ap.get_animation(clip).length
	_suela_en(p, sk, ap, clip, 0.0)
	var o: Vector3 = sk.get_bone_global_pose(h).origin
	var m: float = 0.0
	for k in range(1, 25):
		_suela_en(p, sk, ap, clip, largo * float(k) / 25.0)
		var q: Vector3 = sk.get_bone_global_pose(h).origin
		m = maxf(m, Vector2(q.x - o.x, q.z - o.z).length())
	return m


## Altura (espacio del esqueleto, u del modelo) del hueso de suela más bajo con el clip en `t`.
func _suela_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String, t: float) -> float:
	if p._arbol != null:
		p._arbol.active = false          # el árbol manda sobre el reproductor: se apaga para mirar el clip a pelo
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
