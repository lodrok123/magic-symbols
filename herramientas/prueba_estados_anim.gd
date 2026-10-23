extends SceneTree

## PRUEBA DE LA MÁQUINA DE ESTADOS DE ANIMACIÓN (A1 + A2, 20/10; PLAN_TRES_FRENTES §1). Sin ventana:
##   tools\prueba_una.cmd prueba_estados_anim        (o godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_estados_anim.gd)
##
## Lo que comprueba (el «criterio de resuelto» del plan):
##   1. el héroe tiene un ArbolAnimPj y TODA la animación pasa por él (nadie fuera llama a play/seek/speed_scale de un AnimationPlayer);
##   2. TODAS las transiciones entre los roles del héroe, permitidas y prohibidas: las permitidas llegan al estado pedido, las prohibidas no cambian nada
##      y se cuentan; la tabla de prohibidas se declara AQUÍ aparte, no se lee de la clase, para que la prueba pueda llevarle la contraria;
##   3. ningún estado colgado: tras cada transición y tras 600 secuencias de eventos al azar el estado real de la máquina es el pedido;
##   4. sin «clip no encontrado»: ningún rol con clip llega al árbol sin él, y los roles sin clip no cambian nada;
##   5. los enemigos (grafo reducido): solo idle, andar, correr, atacar, lanzar, golpeado y muerto; muerto no se abandona;
##   6. los subestados de lanzar (cast points), beber, el giro al andar y el apuntado del arquero siguen funcionando por el árbol;
##   7. el LIBRO acaba siempre en un estado válido tras 1 000 secuencias al azar de eventos (lanzar, cancelar, rodar, ser golpeado, abrir/cerrar libro, nadar).

var fallos: int = 0
var pj: Pj3D = null

## Los roles del héroe que la prueba recorre (los que el GLB de la elfa trae).
const ROLES_HEROE: Array = ["idle", "walk", "run", "swim", "leer", "hit", "roll", "drink", "death", "cast_proyectil", "cast_corro", "cast_columna",
	"cast_muro", "cast_empuje", "attack", "talk"]
## Prohibidas declaradas aquí: desde muerte solo se sale a idle; nadando (o muerto) no se rueda, ni se bebe, ni se apunta ni se lanza.
const SALIDAS_DE_MUERTE_PERMITIDAS: Array = ["idle", "death"]
const BLOQUEADAS_NADANDO: Array = ["roll", "drink", "leer", "cast_proyectil", "cast_corro", "cast_columna", "cast_muro", "cast_empuje"]
## Lo que se pide para enemigos en el grafo reducido.
const ROLES_ENEMIGO_OK: Array = ["idle", "walk", "run", "attack", "hit", "death"]
const ROLES_ENEMIGO_NO: Array = ["leer", "talk", "swim", "roll", "drink"]


func _init() -> void:
	Estado.nuevo()
	await process_frame
	await _correr()
	print("FALLOS: %d" % fallos)
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, texto: String, detalle: String = "") -> void:
	if cond:
		print("OK    ", texto)
	else:
		fallos += 1
		print("FALLO ", texto, "  ", detalle)


## Avanza el árbol a mano `t` s en pasos de un fotograma (el motor haría lo mismo).
func _avanzar(p: Pj3D, t: float) -> void:
	var n: int = maxi(int(ceil(t * 30.0)), 1)
	for i in range(n):
		p.arbol().avanzar(1.0 / 30.0)


func _nuevo(id: String, p_grafo: String = ArbolAnimPj.GRAFO_HEROE) -> Pj3D:
	var p := Pj3D.new()
	root.add_child(p)
	p.cargar(id)
	p.grafo = p_grafo
	return p


func _prohibida_esperada(de: String, a: String) -> bool:
	if de == "death" and not SALIDAS_DE_MUERTE_PERMITIDAS.has(a):
		return true
	if (de == "swim" or de == "death") and BLOQUEADAS_NADANDO.has(a):
		return true
	return false


func _correr() -> void:
	# --- 1 · el héroe ---
	pj = _nuevo("woodland_wanderer")
	await process_frame
	await process_frame
	var ar: ArbolAnimPj = pj.arbol()
	_ok(ar != null and ar.active and ar.get_parent() == pj._ap.get_parent(), "1 la elfa tiene su ArbolAnimPj activo, hermano del AnimationPlayer")
	_ok(not pj._ap.active, "1 el AnimationPlayer propio está parado (el árbol es el único que escribe las pistas)")
	_avanzar(pj, 0.2)
	_ok(pj.estado_anim() == "idle" and ar.estado_real() == "idle" and pj.clip_actual() == pj._buscar_clip("idle"),
		"1 al cargar queda en «idle» con su clip", "%s / %s" % [pj.estado_anim(), ar.estado_real()])
	var propios: PackedStringArray = PackedStringArray()
	for f in ["res://jugador/pj_3d.gd"]:
		var texto: String = FileAccess.get_file_as_string(f)
		for l in texto.split("\n"):
			var ll: String = l.strip_edges()
			if ll.begins_with("#") or ll.begins_with("##"):
				continue
			for pat in ["_ap.play(", "_ap.seek(", "_ap.speed_scale", "_ap.pause(", "_ap.stop("]:
				if ll.contains(pat) and not ll.contains("ap.stop()"):
					propios.append(ll)
	_ok(propios.is_empty(), "1 pj_3d.gd no llama a play/seek/speed_scale/pause del AnimationPlayer (solo el árbol)", ", ".join(propios))
	_ok(not FileAccess.get_file_as_string("res://jugador/jugador_3d.gd").contains("ap.pause()"), "1 jugador_3d.gd tampoco pausa ningún AnimationPlayer")

	# --- 1b · los clips nuevos de la jugadora (24/10; MedidasClipsJugadora): abrir_cofre, agacharse, ofrecer, saludo, empujar ---
	var nueva: Pj3D = _nuevo("woodland_wanderer")
	await process_frame
	MedidasClipsJugadora.comprobar(nueva, "1b elfa jugadora", _ok)
	nueva.queue_free()

	# --- 2 · TODAS las transiciones ---
	var roles: Array = []
	for r in ROLES_HEROE:
		if pj._buscar_clip(String(r)) != "":
			roles.append(r)
		else:
			print("AVISO  el GLB de la elfa no trae clip para «%s»: se salta" % r)
	_ok(roles.size() >= 13, "2 hay al menos 13 roles con clip para recorrer (%d)" % roles.size())
	var pares: int = 0
	var permitidas: int = 0
	var prohibidas: int = 0
	var mal: PackedStringArray = PackedStringArray()
	var colgados: int = 0
	for a in roles:
		for b in roles:
			if a == b:
				continue
			pares += 1
			# Punto de partida: idle (desde muerte se vuelve a idle, que está permitido) y luego `a`.
			pj.animacion_actual = ""
			pj.jugar("idle")
			_avanzar(pj, 0.1)
			pj.animacion_actual = ""
			pj.jugar(String(a))
			_avanzar(pj, 0.2)
			var rech_antes: int = ar.rechazos
			pj.jugar(String(b))
			_avanzar(pj, 0.3)
			var espera_no: bool = _prohibida_esperada(String(a), String(b))
			if espera_no:
				prohibidas += 1
				var intacto: bool = pj.animacion_actual == String(a) and ar.estado == Pj3D.estado_de(String(a)) and ar.rechazos == rech_antes + 1
				if not intacto:
					mal.append("%s→%s debía rechazarse (anim=%s estado=%s rech=%d)" % [a, b, pj.animacion_actual, ar.estado, ar.rechazos - rech_antes])
			else:
				permitidas += 1
				var llego: bool = pj.animacion_actual == String(b) and ar.estado == Pj3D.estado_de(String(b)) and ar.rechazos == rech_antes
				if not llego:
					mal.append("%s→%s debía llegar (anim=%s estado=%s rech=%d)" % [a, b, pj.animacion_actual, ar.estado, ar.rechazos - rech_antes])
			if ar.estado_real() != ar.estado:
				colgados += 1
	_ok(mal.is_empty(), "2 las %d transiciones (%d permitidas, %d prohibidas) hacen lo que dice la tabla" % [pares, permitidas, prohibidas], "; ".join(mal.slice(0, 5)))
	_ok(prohibidas >= 20 and permitidas >= 100, "2 hay transiciones de las dos clases (prohibidas %d, permitidas %d)" % [prohibidas, permitidas])
	_ok(colgados == 0, "3 ningún estado colgado tras las transiciones (estado real = el pedido)", "%d" % colgados)
	# Con las reglas de motivo_prohibida de la clase: la misma respuesta que la tabla de la prueba.
	var difiere: int = 0
	for a in roles:
		for b in roles:
			if a != b and (ar.motivo_prohibida(Pj3D.estado_de(String(a)), Pj3D.estado_de(String(b))) != "") != _prohibida_esperada(String(a), String(b)):
				difiere += 1
	_ok(difiere == 0, "2 `motivo_prohibida` de la clase coincide con la tabla de la prueba en los %d pares" % pares, "%d" % difiere)

	# --- 3 · secuencias al azar sobre el héroe ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 20102026
	pj.animacion_actual = ""
	pj.jugar("idle")
	_avanzar(pj, 0.1)
	var raros: int = 0
	var rech0: int = ar.rechazos
	for sec in range(600):
		for paso in range(rng.randi_range(3, 8)):
			var r: String = String(roles[rng.randi() % roles.size()])
			match rng.randi() % 5:
				0:
					pj.animacion_actual = ""
					pj.jugar(r)
				1:
					pj.jugar(r, rng.randf() < 0.5)
				2:
					pj.set_velocidad_animacion(rng.randf_range(0.0, 2.5))
				3:
					pj.soltar_lanzar(rng.randf() < 0.5)
				4:
					pj.jugar("idle")
			_avanzar(pj, rng.randf_range(0.0, 0.25))
		# Salida limpia: si murió, vuelve a idle (reaparecer) y la velocidad a 1.
		pj.set_velocidad_animacion(1.0)
		pj.animacion_actual = ""
		pj.jugar("idle")
		_avanzar(pj, 0.5)                                   # (un travel pedido en pleno fundido espera a que acabe: ≤ 0,15 s por fundido)
		if ar.estado_real() != ar.estado or ar.estado != "idle" or ar.historial.is_empty():
			raros += 1
	_ok(raros == 0, "3 600 secuencias al azar acaban en «idle» y con la máquina en el estado pedido", "%d raras" % raros)
	_ok(ar.rechazos > rech0, "3 en las secuencias al azar la máquina rechazó transiciones prohibidas (%d)" % (ar.rechazos - rech0))
	_ok(pj.velocidad_animacion() == 1.0, "3 la velocidad de animación vuelve a 1")

	# --- 4 · roles sin clip ---
	var antes: String = pj.animacion_actual
	var estado_antes: String = ar.estado
	pj.jugar("walk_back")
	pj.jugar("rol_que_no_existe")
	_ok(pj.animacion_actual == antes and ar.estado == estado_antes, "4 un rol sin clip no cambia nada (ni animacion_actual ni el estado)")
	var avisos: PackedStringArray = pj.validar()
	var faltan: int = 0
	for av in avisos:
		if av.begins_with("falta el clip"):
			faltan += 1
	_ok(faltan == 0, "4 `validar()` de la elfa no echa en falta ningún clip mínimo", "; ".join(avisos))
	var sin_clip_pedido: bool = false
	for h in ar.historial:
		if String(h["a"]) == "":
			sin_clip_pedido = true
	_ok(not sin_clip_pedido, "4 ninguna petición llegó al árbol sin estado")

	# --- 5 · enemigos: grafo reducido ---
	var gob: Pj3D = _nuevo("goblin_warrior_chibi", ArbolAnimPj.GRAFO_REDUCIDO)
	await process_frame
	var ag: ArbolAnimPj = gob.arbol()
	_avanzar(gob, 0.2)
	var ok_todos: bool = true
	for r in ROLES_ENEMIGO_OK:
		if gob._buscar_clip(String(r)) == "":
			continue
		gob.animacion_actual = ""
		gob.jugar("idle")
		_avanzar(gob, 0.1)
		gob.animacion_actual = ""
		gob.jugar(String(r), r == "attack" or r == "hit")
		_avanzar(gob, 0.2)
		if ag.estado != Pj3D.estado_de(String(r)) or ag.estado_real() != ag.estado:
			ok_todos = false
			print("      ", r, " → ", ag.estado, " / ", ag.estado_real())
	_ok(ok_todos, "5 el enemigo reproduce idle, andar, correr, atacar, golpeado y muerto")
	gob.animacion_actual = ""
	gob.jugar("idle")
	_avanzar(gob, 0.1)
	var r5: int = ag.rechazos
	var cambia: bool = false
	for r in ROLES_ENEMIGO_NO:
		gob.animacion_actual = ""
		gob.jugar(String(r))
		if gob._buscar_clip(String(r)) != "" and ag.estado != "idle":
			cambia = true
	_ok(not cambia, "5 en el grafo reducido los roles que no existen (apuntar, hablar, nadar, rodar, beber) no cambian nada")
	var gob2: Pj3D = _nuevo("woodland_wanderer", ArbolAnimPj.GRAFO_REDUCIDO)
	await process_frame
	_avanzar(gob2, 0.1)
	gob2.animacion_actual = ""
	gob2.jugar("leer")
	gob2.animacion_actual = ""
	gob2.jugar("swim")
	_ok(gob2.arbol().estado == "idle" and gob2.arbol().rechazos >= 2, "5 un modelo con clips de sobra tampoco los usa si el grafo es reducido (rechazos %d)" % gob2.arbol().rechazos)
	gob.animacion_actual = ""
	gob.jugar("death", true)
	_avanzar(gob, 0.2)
	gob.animacion_actual = ""
	gob.jugar("walk")
	gob.jugar("attack")
	_avanzar(gob, 0.2)
	_ok(ag.estado == "muerto", "5 el enemigo muerto no se levanta (muerto solo sale a idle)", ag.estado)
	ag.pedir("idle", gob._buscar_clip("idle"))
	_avanzar(gob, 0.1)
	_ok(ag.estado == "idle", "5 …salvo con un idle explícito (reaparecer)")
	gob.queue_free()
	gob2.queue_free()

	# --- 6 · lanzar con cast point, beber, giro, apuntado ---
	pj.animacion_actual = ""
	pj.jugar("idle")
	_avanzar(pj, 0.2)
	var dur: float = pj.lanzar("proyectil", "fire", "x_mano")
	_ok(dur > 0.0 and pj.cast_activo() and ar.estado == "lanzar_x_mano", "6 lanzar con cast point entra en el estado «lanzar_x_mano»", ar.estado)
	_ok(ar.definicion("lanzar_x_mano").get("bucle", -1) == Animation.LOOP_NONE and float(ar.definicion("lanzar_x_mano").get("desde", 0.0)) > 0.0,
		"6 …que es un recorte del clip, sin bucle")
	_avanzar(pj, 0.2)
	var f1: float = pj.fraccion_clip()
	_avanzar(pj, 0.2)
	_ok(pj.fraccion_clip() > f1 and f1 > 0.0, "6 la fracción del clip avanza (%.2f → %.2f)" % [f1, pj.fraccion_clip()])
	var p6: Pj3D = pj
	pj.soltar_lanzar()
	_avanzar(pj, 0.2)
	_ok(not p6.cast_activo() and ar.estado == "idle" and pj.velocidad_animacion() == 1.0, "6 soltar_lanzar vuelve a idle y a velocidad 1")
	# nadando no se lanza
	pj.animacion_actual = ""
	pj.jugar("swim")
	_avanzar(pj, 0.2)
	_ok(pj.lanzar("proyectil", "fire", "x_mano") == 0.0 and ar.estado == "nadar" and not pj.cast_activo(), "6 nadando, lanzar devuelve 0 y no cambia nada")
	pj.animacion_actual = ""
	pj.jugar("idle")
	_avanzar(pj, 0.2)
	# Beber
	var terminado: Array = [false]
	pj.bebida_terminada.connect(func() -> void: terminado[0] = true)
	var d_beber: float = pj.beber(0.5)
	_avanzar(pj, 0.1)
	_ok(d_beber == 0.5 and ar.estado == "beber" and absf(ar.definicion("beber")["desde"] - Pj3D.BEBER_DESDE) < 0.001 and absf(ar.definicion("beber")["hasta"] - Pj3D.BEBER_HASTA) < 0.001,
		"6 beber es el estado «beber», recortado a 2…6 s del clip")
	_ok(absf(ar.vel_estado - (Pj3D.BEBER_HASTA - Pj3D.BEBER_DESDE) / 0.5) < 0.01, "6 …acelerado para durar lo pedido (×%.1f)" % ar.vel_estado)
	await create_timer(0.7).timeout
	_ok(terminado[0] and ar.estado == "idle", "6 al acabar vuelve a idle y emite bebida_terminada", "%s %s" % [terminado[0], ar.estado])
	# Giro al andar
	pj.animacion_actual = ""
	pj.jugar("walk")
	_avanzar(pj, 0.3)
	pj.giro_al_andar(90.0)
	_avanzar(pj, 0.1)
	_ok(ar.estado == "giro" and pj.animacion_actual == "walk", "6 giro_al_andar pasa por el estado «giro» sin cambiar animacion_actual")
	await create_timer(0.6).timeout
	_avanzar(pj, 0.2)
	_ok(ar.estado == "andar", "6 …y vuelve a andar solo", ar.estado)
	# Pose fija
	_ok(pj.pose_fija("cast_corro", 1.2) and ar.retenido, "6 pose_fija pone un clip en un instante y lo retiene (para laboratorios y pruebas)")
	var p0: float = ar.posicion()
	_avanzar(pj, 0.3)
	_ok(is_equal_approx(ar.posicion(), p0), "6 …y no avanza")
	pj.animacion_actual = ""
	pj.jugar("idle")
	_avanzar(pj, 0.2)
	_ok(not ar.retenido, "6 al pedir otro estado el árbol deja de retener")
	# Hitstop
	pj.animacion_actual = ""
	pj.jugar("walk")
	_avanzar(pj, 0.2)
	pj.set_velocidad_animacion(0.0)
	var q0: float = ar.posicion()
	_avanzar(pj, 0.3)
	_ok(is_equal_approx(ar.posicion(), q0), "6 set_velocidad_animacion(0) congela (hitstop)")
	pj.set_velocidad_animacion(1.0)
	_avanzar(pj, 0.2)
	_ok(ar.posicion() > q0 or ar.posicion() < q0, "6 …y con 1 sigue")
	# Una vez: se queda en el último fotograma
	pj.animacion_actual = ""
	pj.jugar("hit", true)
	_avanzar(pj, 0.1)
	var largo_hit: float = ar.largo()
	_avanzar(pj, largo_hit + 1.0)
	_ok(ar.terminado() and is_equal_approx(ar.posicion(), ar.largo()), "6 un clip «una vez» se queda en su último fotograma", "%.2f / %.2f" % [ar.posicion(), ar.largo()])
	pj.animacion_actual = ""
	pj.jugar("idle")
	_avanzar(pj, 0.2)

	# --- 7 · el libro: 1 000 secuencias al azar ---
	_ok(pj.libro_estado() == "cinto" and pj.libro_valido(), "7 al empezar el libro está en el cinto")
	pj.libro_en_manos(true)
	_ok(pj.libro_estado() == "en_mano_abierto" and pj.libro_valido(), "7 abrir lo pone en la mano (en_mano_abierto)")
	pj.libro_en_manos(true, 0.3, "izquierda", true)
	_ok(pj.libro_estado() == "en_mano_cerrado" and pj.libro_valido(), "7 …y al lanzar pasa a en_mano_cerrado sin sacar otro libro")
	pj.libro_en_manos(false, 0.15)
	_ok(pj.libro_estado() == "volando" and pj.libro_valido(), "7 cerrar lo manda volando")
	pj.libro_en_manos(false, 0.15)
	pj.libro_en_manos(false, 0.15)
	_ok(pj.libro_estado() == "volando" and pj.libro_valido(), "7 cerrar otra vez mientras vuela no lo interrumpe (antes dejaba el libro cosido a la mano)")
	pj.libro_avanzar(1.0)
	_ok(pj.libro_estado() == "cinto" and pj.libro_valido(), "7 al acabar el vuelo está en el cinto")
	pj.libro_en_manos(true)
	pj.libro_en_manos(false, 0.15)
	pj.libro_en_manos(true)
	_ok(pj.libro_estado() == "en_mano_abierto" and pj.libro_valido(), "7 abrir mientras vuela remata el vuelo y saca otro libro")
	pj.libro_asentar()
	pj.libro_en_manos(false, 0.15)
	pj.libro_asentar()
	_ok(pj.libro_estado() == "cinto" and pj.libro_valido(), "7 libro_asentar() termina lo que haya en marcha")
	CastPoints.POR_NOMBRE["x_mano"] = "x_mano"
	var malos: PackedStringArray = PackedStringArray()
	var recuento: Dictionary = {}
	rng.seed = 99
	for sec in range(1000):
		var traza: Array = []
		for paso in range(rng.randi_range(4, 12)):
			var ev: int = rng.randi() % 10
			traza.append(ev)
			match ev:
				0:
					pj.apuntar()
				1:
					pj.cancelar_apuntar()
				2:
					pj.lanzar("proyectil", "fire", "x_mano" if rng.randf() < 0.7 else "")
				3:
					pj.soltar_lanzar(rng.randf() < 0.5)
				4:
					pj.rodar()
				5:
					pj.soltar_rodar()
				6:
					pj.jugar("hit", true)
				7:
					pj.libro_en_manos(rng.randf() < 0.5, rng.randf_range(0.1, 0.4), "izquierda" if rng.randf() < 0.5 else "derecha", rng.randf() < 0.5)
				8:
					pj.animacion_actual = ""
					pj.jugar("swim")
				9:
					pj.animacion_actual = ""
					pj.jugar("idle")
			pj.libro_avanzar(rng.randf_range(0.0, 0.35))
			pj.arbol().avanzar(rng.randf_range(0.0, 0.1))
			if not pj.libro_valido():
				malos.append("sec %d paso %d evento %d: estado %s" % [sec, paso, ev, pj.libro_estado()])
				break
		pj.libro_asentar()
		recuento[pj.libro_estado()] = int(recuento.get(pj.libro_estado(), 0)) + 1
		if not pj.libro_valido():
			malos.append("sec %d al asentar: estado %s %s" % [sec, pj.libro_estado(), traza])
		# Cierre limpio: el libro vuelve al cinto y se ve el del cinto.
		pj.soltar_lanzar(true)
		pj.libro_en_manos(false, 0.15)
		pj.libro_asentar()
		var c: Node3D = pj._libro_cinto()
		if pj.libro_estado() != "cinto" or not pj.libro_valido() or (c != null and not c.visible):
			malos.append("sec %d al cerrar: estado %s, cinto visible %s" % [sec, pj.libro_estado(), str(c.visible) if c != null else "sin cinto"])
		pj.arbol().avanzar(0.5)
		if pj.arbol().estado_real() != pj.arbol().estado and pj.arbol().listo():
			malos.append("sec %d: árbol colgado %s / %s" % [sec, pj.arbol().estado_real(), pj.arbol().estado])
		pj.animacion_actual = ""
		pj.jugar("idle")
	_ok(malos.is_empty(), "7 1 000 secuencias al azar: el libro está SIEMPRE en un estado válido, y al cerrar vuelve al cinto a la vista", "; ".join(malos.slice(0, 4)))
	print("      estados al asentar: ", recuento)
	_ok(recuento.size() >= 3, "7 las secuencias pasaron por varios estados distintos (%s)" % str(recuento.keys()))
	pj.set_velocidad_animacion(1.0)
	_ok(ar.rechazos > 0 and ar.historial.size() <= ArbolAnimPj.MAX_HISTORIAL, "7 el historial del árbol se mantiene acotado (%d)" % ar.historial.size())
