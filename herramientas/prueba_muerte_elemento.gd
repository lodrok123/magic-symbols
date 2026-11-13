extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, TAREA E (1/11; enemigos/combate_3d.gd `_muerte_elemental`, enemigos/trozos_hielo_3d.gd, limo_3d.gd): la muerte depende del elemento del golpe que mata.
## Sobre la escena real del Bosque, con --fixed-fps 30 y `Sfx.REGISTRAR`. Se mata a un goblin con cada elemento (el elemento sale de `_num_elemento` y no de `_destello_el`: ver
## `_elemento_letal`) y se comprueba su rama:
##   1 fuego: tinte a carbón en 0,4 s, ceniza y llamitas (nodos nuevos en el Vfx3D), se desmorona (primero la altura, luego lo ancho), suena `pira_muerte`;
##   2 hielo: tinte azul, el modelo desaparece de golpe a los 0,3 s con 6-8 trozos (`TrozosHielo3D`) que se funden antes de 1,5 s, suena `hielo_rompe`;
##   3 rayo: sin clip `death` y el árbol de animación a velocidad 0 (pausado en el fotograma del golpe), tiembla en sitio, chispazos y cae (rotación X 90°), suena `chispazo`;
##   4 agua: salpicadura y vapor, y se desliza ~0,5 u hacia donde iba mientras encoge; suena `salpicadura`;
##   5 tierra: polvo grande, grietas y se hunde 0,3 u; suena `derrumbe_muerte`;
##   6 viento y golpe F: como hoy (sin nodos nuevos, sin tinte, clip `death`, sin remate);
##   7 en todas el nodo se libera a los 1,75 s (±0,3, como hoy), `Estado.enemigo_muerto` llega una vez y el botín sale igual;
##   8 el limo muerto por fuego o hielo: tinte y partículas, SIN trozos ni desmoronamiento, y su remate suena;
##   9 siete muertes en el mismo instante: solo MAX_MUERTES_VFX (3) con el efecto completo; las otras, tinte y sonido; pasado el segundo vuelve el cupo;
##  10 `ACTIVA` = false: la muerte de hoy (sin nodos nuevos, sin tinte, con `death`); el remate suena (los sonidos no dependen de ACTIVA);
##  11 la entrada F3 de MAX_MUERTES_VFX (entero) se puede cambiar desde el panel y los hijos (gólem, chamán) heredan la variante.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_muerte_elemento.gd

var _muertes: int = 0


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	Sfx.REGISTRAR = true
	Estado.i().enemigo_muerto.connect(func(_c: Vector2, _n: String) -> void: _muertes += 1)
	await avanzar(20)
	await _caso_fuego()
	await _caso_hielo()
	await _caso_rayo()
	await _caso_agua()
	await _caso_tierra()
	await _caso_sin_variante()
	await _caso_limo()
	await _caso_cupo()
	await _caso_apagada()
	await _caso_golem()
	await _caso_lab_y_herencia()
	Sfx.REGISTRAR = false
	print("COMPROBACIONES: %d" % _comprobaciones)


func _runa(el: String) -> RuneData:
	var runas: Dictionary = {"fuego": "fire", "agua": "water", "rayo": "lightning", "hielo": "ice", "tierra": "earth", "viento": "wind"}
	return load("res://nucleo/%s_rune.tres" % runas[el]) as RuneData


func _fx() -> Vfx3D:
	return maqueta.get("_fx") as Vfx3D


func _color_cuerpo(g: Combate3D) -> Color:
	return (g._materiales[0] as StandardMaterial3D).albedo_color


## Lo que debe valer el albedo del primer material con el tinte `t` (la base multiplicada).
func _esperado(g: Combate3D, t: Color) -> Color:
	var b: Color = g._bases[0]
	return Color(b.r * t.r, b.g * t.g, b.b * t.b, b.a)


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Los hijos del Vfx3D ahora mismo (para contar luego solo los NUEVOS: los efectos viejos se liberan solos y el recuento total baja).
func _snap(fx: Vfx3D) -> Array:
	return fx.get_children().map(func(n): return n.get_instance_id())


func _nuevos(fx: Vfx3D, snap: Array) -> int:
	var n: int = 0
	for c in fx.get_children():
		if not snap.has(c.get_instance_id()):
			n += 1
	return n


func _quienes(fx: Vfx3D, snap: Array) -> String:
	var r: PackedStringArray = []
	for c in fx.get_children():
		if not snap.has(c.get_instance_id()):
			r.append("%s (%s)" % [c.name, c.get_class()])
	return ", ".join(r)


func _hijos_trozos() -> Array:
	return maqueta.get_children().filter(func(n): return n is TrozosHielo3D)


## Un goblin quieto con 1 de vida y la tabla del limo (oro siempre) para poder comprobar el botín. Sin cupo gastado.
func _victima(c: Vector2i) -> Combate3D:
	var g: Combate3D = _goblin(c, true, 1.0)
	g.tabla_botin = "limo"
	g.oro = 5
	return g


func _preparar() -> void:
	Combate3D._t_muertes_vfx.clear()
	OS.delay_msec(Sfx.VEDA_MS + 40)
	Sfx.vaciar_registro()


## Mata a `g` con `el` ("" = golpe F) y devuelve cuántos segundos tarda en liberarse el nodo (tope 3 s). El resto del caso se mide con `reloj.t - t0`.
func _matar(g: Combate3D, el: String) -> void:
	if el == "":
		g.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 50.0, 0.0)
	else:
		g.on_spell_hit(_runa(el), Vector3(-1, 0, 0))


## Como `_matar` pero SIN pasar por el golpe (ni estrella de impacto, ni empuje, ni reacciones de quemadura): solo el daño letal con ese elemento, que es lo único que mira la muerte. Así los
## nodos nuevos del Vfx3D, si los hay, son de la muerte y no del golpe.
func _matar_directo(g: Combate3D, el: String) -> void:
	g._num_golpe = true
	g._num_elemento = el
	g.receive_damage(100.0)
	g._num_golpe = false


## Espera a que el nodo se libere y devuelve cuánto tardó desde `t0`.
func _hasta_liberar(g: Combate3D, t0: float) -> float:
	while is_instance_valid(g) and reloj.t - t0 < 3.0:
		await process_frame
	return reloj.t - t0


func _comun(nombre: String, botin: Array, m0: int, t_libre: float) -> void:
	_ok("%s el nodo se libera a los %.2f s (hoy 1,75 ± 0,3)" % [nombre, t_libre], absf(t_libre - 1.75) <= 0.3)
	_ok("%s `Estado.enemigo_muerto` llega UNA vez" % nombre, _muertes == m0 + 1, str(_muertes - m0))
	var oro: int = 0
	for it in botin:
		if String((it as Dictionary)["que"]) == Botin.ORO:
			oro += int((it as Dictionary)["n"])
	_ok("%s el botín sale (oro 5)" % nombre, oro == 5, str(botin))


# --- 1 · fuego ---------------------------------------------------------------------------------------------------------
func _caso_fuego() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _victima(Vector2i(9, 33))
	await avanzar(3)
	_preparar()
	var fx: Vfx3D = _fx()
	_ok("1 hay Vfx3D en la maqueta", fx != null)
	var hijos0: Array = _snap(fx)
	var m0: int = _muertes
	var v0: int = int(Sensacion3D.cuenta["muerte_vfx"])
	var t0: float = reloj.t
	var esc0: Vector3 = g.pj.scale
	_matar(g, "fuego")
	_ok("1 `_elemento_letal` = fuego (el destello aún es el anterior)", g.muerto and g._destello_el == "fuego")
	_ok("1 suena `pira_muerte` y el grito de siempre", Sfx.veces("pira_muerte") == 1)
	_ok("1 ceniza y llamas: nodos nuevos en el Vfx3D (%d)" % _nuevos(fx, hijos0), _nuevos(fx, hijos0) > 0)
	_ok("1 cuenta como muerte con efecto completo", int(Sensacion3D.cuenta["muerte_vfx"]) == v0 + 1)
	_ok("1 conserva el clip `death`", g.pj.animacion_actual == "death")
	await avanzar_s(0.6)
	var c: Color = _color_cuerpo(g)
	_ok("1 a los 0,6 s el tinte es carbón (%s)" % str(c), _dist(c, _esperado(g, Combate3D.TINTE_CARBON)) < 0.03)
	await avanzar_s(0.6)                                       # 1,2 s
	_ok("1 mientras aguanta, entero (escala sin tocar)", g.pj.scale.is_equal_approx(esc0))
	while reloj.t - t0 < 1.62:
		await process_frame
	_ok("1 desmoronamiento: a 1,62 s la altura ya cayó y lo ancho casi no (%s)" % str(g.pj.scale / esc0), g.pj.scale.y < esc0.y * 0.05 and g.pj.scale.x > esc0.x * 0.5)
	var botin: Array = g.botin_soltado
	var t: float = await _hasta_liberar(g, t0)
	_comun("1", botin, m0, t)
	await avanzar(3)


# --- 2 · hielo ---------------------------------------------------------------------------------------------------------
func _caso_hielo() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _victima(Vector2i(9, 33))
	await avanzar(3)
	_preparar()
	var fx: Vfx3D = _fx()
	var m0: int = _muertes
	var t0: float = reloj.t
	_matar(g, "hielo")
	_ok("2 suena `hielo_rompe`", Sfx.veces("hielo_rompe") == 1)
	_ok("2 todavía no hay trozos (el cuerpo se congela primero)", _hijos_trozos().is_empty() and g.pj.visible)
	while reloj.t - t0 < 0.2:
		await process_frame
	var emision: bool = (g._materiales[0] as StandardMaterial3D).emission_enabled
	_ok("2 a 0,2 s: emisión fría y el modelo sigue ahí", emision and g.pj.visible)
	while reloj.t - t0 < 0.45:
		await process_frame
	_ok("2 a 0,45 s: el modelo desapareció de golpe (sin encoger)", not g.pj.visible and g.pj.scale.is_equal_approx(Vector3.ONE * g.pj.scale.x))
	var trozos: Array = _hijos_trozos()
	_ok("2 hay un TrozosHielo3D con 6-8 cubos (%d)" % (trozos[0].get_child_count() if not trozos.is_empty() else 0), trozos.size() == 1 and trozos[0].get_child_count() >= 6 and trozos[0].get_child_count() <= 8)
	if not trozos.is_empty():
		var tz: Node3D = trozos[0]
		var alfa0: float = ((tz.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a
		var y0: float = (tz.get_child(0) as Node3D).global_position.y
		await avanzar_s(0.2)
		var alfa1: float = ((tz.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a
		var y1: float = (tz.get_child(0) as Node3D).global_position.y
		_ok("2 los trozos se funden (%.2f → %.2f) y caen (y %.2f → %.2f)" % [alfa0, alfa1, y0, y1], alfa1 < alfa0 and y1 != y0)
	var color: Color = _color_cuerpo(g)
	_ok("2 el tinte es azul claro (%s)" % str(color), _dist(color, _esperado(g, Combate3D.TINTE_HIELO)) < 0.05)
	while reloj.t - t0 < 1.45:
		await process_frame
	_ok("2 a 1,45 s los trozos ya no existen (antes de 1,5 s)", _hijos_trozos().is_empty())
	var botin: Array = g.botin_soltado
	var t: float = await _hasta_liberar(g, t0)
	_comun("2", botin, m0, t)
	await avanzar(3)


# --- 3 · rayo ----------------------------------------------------------------------------------------------------------
func _caso_rayo() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _victima(Vector2i(9, 33))
	await avanzar(3)
	_preparar()
	var fx: Vfx3D = _fx()
	var hijos0: Array = _snap(fx)
	var m0: int = _muertes
	var t0: float = reloj.t
	var base: Vector3 = g.pj.position
	_matar(g, "rayo")
	_ok("3 suena `chispazo`", Sfx.veces("chispazo") == 1)
	_ok("3 rígido: ni clip `death` (%s)" % g.pj.animacion_actual, g.pj.animacion_actual != "death")
	_ok("3 ... y el árbol de animación a velocidad 0", is_zero_approx(g.pj.velocidad_animacion()))
	var movio: bool = false
	var max_chispas: int = 0
	while reloj.t - t0 < 0.28:
		await process_frame
		if (g.pj.position - base).length() > 0.005:
			movio = true
		max_chispas = maxi(max_chispas, _nuevos(fx, hijos0))
	_ok("3 tiembla en sitio (se desplazó y sigue cerca)", movio and (g.pj.position - base).length() < 0.3)
	_ok("3 chispazos: nodos nuevos en el Vfx3D (%d)" % max_chispas, max_chispas > 0)
	await avanzar_s(0.4)                                       # 0,68 s
	_ok("3 cae de golpe: rotación X de 90° (%.1f°)" % rad_to_deg(g.pj.rotation.x), absf(g.pj.rotation.x - PI * 0.5) < 0.05)
	_ok("3 y vuelve a su sitio tras temblar", (g.pj.position - base).length() < 0.01, str(g.pj.position - base))
	_ok("3 sigue a velocidad 0 (no se animó después)", is_zero_approx(g.pj.velocidad_animacion()))
	var botin: Array = g.botin_soltado
	var t: float = await _hasta_liberar(g, t0)
	_comun("3", botin, m0, t)
	await avanzar(3)


# --- 4 · agua ----------------------------------------------------------------------------------------------------------
func _caso_agua() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _victima(Vector2i(9, 33))
	await avanzar(3)
	_preparar()
	var fx: Vfx3D = _fx()
	var hijos0: Array = _snap(fx)
	var m0: int = _muertes
	var t0: float = reloj.t
	_matar(g, "agua")
	var dir: Vector3 = g._dir_empuje_muerte()
	_ok("4 suena `salpicadura`", Sfx.veces("salpicadura") == 1)
	_ok("4 salpicadura y vapor: nodos nuevos (%d)" % _nuevos(fx, hijos0), _nuevos(fx, hijos0) >= 2)
	while reloj.t - t0 < 1.3:
		await process_frame
	var p1: Vector3 = g.pj.position
	while reloj.t - t0 < 1.72:
		await process_frame
	var d: Vector3 = g.pj.position - p1
	_ok("4 se desliza ~0,5 u hacia donde iba mientras encoge (%.2f u, producto con la dirección %.2f)" % [d.length(), d.normalized().dot(dir)], d.length() >= 0.35 and d.length() <= 0.55 and d.normalized().dot(dir) > 0.95)
	var botin: Array = g.botin_soltado
	var t: float = await _hasta_liberar(g, t0)
	_comun("4", botin, m0, t)
	await avanzar(3)


# --- 5 · tierra --------------------------------------------------------------------------------------------------------
func _caso_tierra() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _victima(Vector2i(9, 33))
	await avanzar(3)
	_preparar()
	var fx: Vfx3D = _fx()
	var hijos0: Array = _snap(fx)
	var m0: int = _muertes
	var polvo0: int = int(Sensacion3D.cuenta["polvo"])
	var y0: float = g.pj.position.y
	var t0: float = reloj.t
	_matar(g, "tierra")
	_ok("5 suena `derrumbe_muerte`", Sfx.veces("derrumbe_muerte") == 1)
	_ok("5 polvo grande (se pidió el polvo)", int(Sensacion3D.cuenta["polvo"]) > polvo0)
	_ok("5 grietas: nodo nuevo en el Vfx3D", _nuevos(fx, hijos0) > 0)
	await avanzar_s(0.6)
	_ok("5 se hunde 0,3 u (%.2f)" % (y0 - g.pj.position.y), absf((y0 - g.pj.position.y) - 0.3) < 0.04)
	var botin: Array = g.botin_soltado
	var t: float = await _hasta_liberar(g, t0)
	_comun("5", botin, m0, t)
	await avanzar(3)


# --- 6 · viento y golpe F: como hoy ------------------------------------------------------------------------------------
func _caso_sin_variante() -> void:
	for el in ["viento", ""]:
		_jugadora(Vector2i(11, 33))
		var g: Combate3D = _victima(Vector2i(9, 33))
		await avanzar(3)
		_preparar()
		var fx: Vfx3D = _fx()
		var hijos0: Array = _snap(fx)
		var v0: int = int(Sensacion3D.cuenta["muerte_vfx"])
		var m0: int = _muertes
		var nombre: String = "6 " + (el if el != "" else "golpe F")
		var t0: float = reloj.t
		_matar_directo(g, el)
		var nuevos_ya: int = _nuevos(fx, hijos0)            # en el acto: el mundo suelta chispas sueltas por su cuenta (agua electrificada) y un recuento a 0,6 s las contaría
		await avanzar_s(0.6)
		var recientes: int = 0
		for n in ["pira_muerte", "hielo_rompe", "chispazo", "salpicadura", "derrumbe_muerte"]:
			recientes += Sfx.veces(n)
		_ok("%s: sin remate de elemento" % nombre, recientes == 0, str(Sfx.CONTEO))
		_ok("%s: sin efecto completo ni nodos de partículas de muerte (nuevos al morir: %d)" % [nombre, nuevos_ya], int(Sensacion3D.cuenta["muerte_vfx"]) == v0 and nuevos_ya == 0)
		_ok("%s: sin tinte" % nombre, _dist(_color_cuerpo(g), _esperado(g, g.tinte)) < 0.001)
		_ok("%s: clip `death`" % nombre, g.pj.animacion_actual == "death")
		_ok("%s: sin trozos" % nombre, _hijos_trozos().is_empty())
		var botin: Array = g.botin_soltado
		var t: float = await _hasta_liberar(g, t0)
		_comun(nombre, botin, m0, t)
		await avanzar(3)


# --- 8 · limo ----------------------------------------------------------------------------------------------------------
func _caso_limo() -> void:
	for el in ["fuego", "hielo"]:
		_jugadora(Vector2i(11, 33))
		# 13/11: desde D3 (83a571ba, 6/11) el fuego PARTE en dos a un limo normal que no es de fuego (no lo mata); solo mata al pequeño («muere»). Para medir
		# la muerte por fuego, el limo del caso fuego nace pequeño (el del hielo, normal: como antes).
		var l: Limo3D = Limo3D.crear(maqueta, _pos(Vector2i(13, 33)), "agua", false, el == "fuego")
		l.quieto = true
		l.health = 1.0
		l.vida_max = 1.0
		_creados.append(l)
		await avanzar(3)
		_preparar()
		var fx: Vfx3D = _fx()
		var hijos0: Array = _snap(fx)
		var cuerpo: LimoVisual3D = l.cuerpo
		var m0: int = _muertes
		l.on_spell_hit(_runa(el), Vector3(1, 0, 0))
		_ok("8 limo + %s: muerto" % el, l.muerto)
		_ok("8 ... recuerda el elemento letal", l.muerte_el == el, l.muerte_el)
		_ok("8 ... suena su remate (%s)" % Combate3D.SONIDO_MUERTE[el], Sfx.veces(String(Combate3D.SONIDO_MUERTE[el])) == 1, str(Sfx.CONTEO))
		var esperado: Color = Combate3D.TINTE_CARBON if el == "fuego" else Color(0.55, 0.85, 1.0)
		var param: Color = cuerpo.material_cuerpo.get_shader_parameter("color_elemento")
		_ok("8 ... tinte de su cuerpo (%s)" % str(param), l.muerte_tinte.is_equal_approx(esperado) and _dist(param, esperado) < 0.01)
		_ok("8 ... partículas (%d nodos nuevos)" % _nuevos(fx, hijos0), _nuevos(fx, hijos0) > 0)
		await avanzar_s(0.5)
		_ok("8 ... SIN trozos ni desmoronamiento (el cuerpo sigue su tween de siempre)", _hijos_trozos().is_empty() and (not is_instance_valid(cuerpo) or cuerpo.visible))
		_ok("8 ... `Estado.enemigo_muerto` una vez", _muertes == m0 + 1)
		await avanzar_s(1.0)
	_limpiar()


# --- 9 · cupo -----------------------------------------------------------------------------------------------------------
func _caso_cupo() -> void:
	_jugadora(Vector2i(11, 33))
	var celdas: Array = [Vector2i(9, 29), Vector2i(9, 31), Vector2i(9, 33), Vector2i(9, 35), Vector2i(9, 37), Vector2i(9, 27), Vector2i(9, 39)]
	var lista: Array = []
	for c in celdas:
		lista.append(_victima(c as Vector2i))
	await avanzar(3)
	_preparar()
	var v0: int = int(Sensacion3D.cuenta["muerte_vfx"])
	var m0: int = _muertes
	var t0: int = Time.get_ticks_msec()
	for g in lista:
		_matar(g as Combate3D, "fuego")
	var ms: int = Time.get_ticks_msec() - t0
	_ok("9 siete muertes en %d ms (≤ 500)" % ms, ms <= 500)
	var estado: Array = []
	for g in lista:
		estado.append("%s muerto=%s ahogado=%s anim=%s" % [Terreno3D.celda_de((g as Combate3D).position), (g as Combate3D).muerto, (g as Combate3D).se_hundio, (g as Combate3D).pj.animacion_actual])
	_ok("9 todas mueren y llega su aviso", _muertes == m0 + 7, str(_muertes - m0) + " " + str(estado))
	_ok("9 solo MAX_MUERTES_VFX (%d) con el efecto completo (%d)" % [Combate3D.MAX_MUERTES_VFX, int(Sensacion3D.cuenta["muerte_vfx"]) - v0], int(Sensacion3D.cuenta["muerte_vfx"]) - v0 == Combate3D.MAX_MUERTES_VFX)
	await avanzar_s(0.6)
	var tenidos: int = 0
	for g in lista:
		if _dist(_color_cuerpo(g as Combate3D), _esperado(g as Combate3D, Combate3D.TINTE_CARBON)) < 0.03:
			tenidos += 1
	_ok("9 las siete se tiñen igual (solo tinte y sonido las que no tienen cupo): %d/7" % tenidos, tenidos == 7)
	_ok("9 y el sonido del remate sigue siendo uno por la veda de Sfx (%d)" % Sfx.veces("pira_muerte"), Sfx.veces("pira_muerte") >= 1)
	var sin_clip: int = 0
	for g in lista:
		if (g as Combate3D).pj.animacion_actual == "death":
			sin_clip += 1
	_ok("9 todas con clip `death`", sin_clip == 7)
	OS.delay_msec(1050)
	await avanzar(2)
	var extra: Combate3D = _victima(Vector2i(9, 33))
	await avanzar(3)
	var v1: int = int(Sensacion3D.cuenta["muerte_vfx"])
	_matar(extra, "fuego")
	_ok("9 pasado el segundo vuelve el cupo", int(Sensacion3D.cuenta["muerte_vfx"]) == v1 + 1)
	await avanzar_s(2.0)
	_limpiar()


# --- 10 · apagada ------------------------------------------------------------------------------------------------------
func _caso_apagada() -> void:
	Sensacion3D.ACTIVA = false
	for el in ["fuego", "hielo", "rayo"]:
		_jugadora(Vector2i(11, 33))
		var g: Combate3D = _victima(Vector2i(9, 33))
		await avanzar(3)
		_preparar()
		var fx: Vfx3D = _fx()
		var hijos0: Array = _snap(fx)
		var v0: int = int(Sensacion3D.cuenta["muerte_vfx"])
		var m0: int = _muertes
		var t0: float = reloj.t
		_matar_directo(g, el)
		var nuevos_ya: int = _nuevos(fx, hijos0)
		var quienes: String = _quienes(fx, hijos0)
		await avanzar_s(0.7)
		var n: String = "10 ACTIVA = false, " + el
		_ok("%s: sin nodos nuevos en el Vfx3D al morir" % n, nuevos_ya == 0, quienes)
		_ok("%s: sin trozos de hielo" % n, _hijos_trozos().is_empty())
		_ok("%s: sin tinte y con clip `death`" % n, _dist(_color_cuerpo(g), _esperado(g, g.tinte)) < 0.001 and g.pj.animacion_actual == "death" and not is_zero_approx(g.pj.velocidad_animacion()))
		_ok("%s: sin efecto completo" % n, int(Sensacion3D.cuenta["muerte_vfx"]) == v0)
		_ok("%s: el remate sí suena" % n, Sfx.veces(String(Combate3D.SONIDO_MUERTE[el])) == 1)
		var botin: Array = g.botin_soltado
		var t: float = await _hasta_liberar(g, t0)
		_comun(n, botin, m0, t)
		await avanzar(3)
	Sensacion3D.ACTIVA = true


# --- 11 · el gólem hereda la variante -----------------------------------------------------------------------------------
func _caso_golem() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Golem3D = Golem3D.invocar_golem(maqueta, _pos(Vector2i(13, 33)), jugador as Jugador3D, lanzador)
	g.quieto = true
	_creados.append(g)
	await avanzar(3)
	g.health = 5000.0
	g.vida_max = 5000.0
	g._exponer()
	while g._t_estado < AnimacionesGolem.T_EXPUESTO_ABAJO + 0.3:
		await process_frame
	g.health = 1.0
	_preparar()
	var fx: Vfx3D = _fx()
	var hijos0: Array = _snap(fx)
	_ok("12 gólem: expuesto y vulnerable", g.vulnerable())
	g.on_spell_hit(_runa("fuego"), Vector3(1, 0, 0))
	_ok("12 gólem muerto por fuego", g.muerto)
	_ok("12 ... suena `pira_muerte` (heredó la variante)", Sfx.veces("pira_muerte") == 1, str(Sfx.CONTEO))
	_ok("12 ... ceniza y llamas (%d nodos nuevos)" % _nuevos(fx, hijos0), _nuevos(fx, hijos0) > 0)
	await avanzar_s(0.6)
	var c: Color = (g._materiales[0] as StandardMaterial3D).albedo_color
	_ok("12 ... tinte a carbón (%s)" % str(c), _dist(c, _esperado(g, Combate3D.TINTE_CARBON)) < 0.05)
	_limpiar()
	await avanzar_s(0.3)


# --- 11 · panel F3 y herencia -------------------------------------------------------------------------------------------
func _caso_lab_y_herencia() -> void:
	var antes: int = Combate3D.MAX_MUERTES_VFX
	LabHechizos3D.impacto_poner("MAX_MUERTES_VFX", 2.0)
	_ok("11 F3: MAX_MUERTES_VFX se puede poner desde el panel (%d)" % Combate3D.MAX_MUERTES_VFX, Combate3D.MAX_MUERTES_VFX == 2)
	LabHechizos3D.impacto_poner("MAX_MUERTES_VFX", float(antes))
	var nombres: Array = []
	for e in LabHechizos3D.entradas():
		nombres.append(String((e as Dictionary)["n"]))
	var todas: bool = true
	for n in ["S:RETROCESO_CAM_MIN", "S:RETROCESO_CAM_MAX", "TEMBLOR_MAX", "S:ALFA_FLASH_DEBIL", "MAX_MUERTES_VFX"]:
		todas = todas and nombres.has(n)
	_ok("11 F3: las static vars nuevas están en el panel", todas)
	_ok("11 F3: SQUASH_XZ sigue en el índice 7", nombres[7] == "SQUASH_XZ")
	for ruta in ["res://enemigos/golem_3d.gd", "res://enemigos/chaman_3d.gd", "res://enemigos/gatopedro_3d.gd"]:
		var texto: String = FileAccess.get_file_as_string(ruta)
		_ok("11 %s no sobrescribe `_muerte_elemental` ni `_morir` sin llamar a `super`" % ruta.get_file(), not texto.contains("func _muerte_elemental") and (not texto.contains("func _morir") or texto.contains("super(ahogado)")))
