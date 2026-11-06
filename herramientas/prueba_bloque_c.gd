extends "res://herramientas/escenario_base.gd"
## BLOQUE C · GLIFOS Y LANZAMIENTO (6/11/2026; docs/PROPUESTAS_COMBATE_2026-11-06.md §2 bloque C): C1 sobrecarga de página, C2 orden de glifos, C4 tope de barreras, C5 el golpe F devuelve tinta.
##
## Va sobre la ESCENA REAL (PruebaBosque) y por el camino REAL de entrada, como `prueba_lanzamiento_rapido`: 1 y F entran con `Input.parse_input_event(InputEventKey)` y el ratón con
## `InputEventMouseMotion`. El tiempo de mantener la tecla se mira en `Lanzador3D.t_mantener` (segundos REALES: el reloj del juego va a 0,7 en el modo rápido).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bloque_c.gd

var _comprobaciones: int = 0
var _premios: Array = []                 ## [tipo, tinta] de cada premio de tinta (señal reaccion_premiada)
var _goblins: Array = []
var _libre: Vector2i = Vector2i.ZERO
const ESTE := Vector3(1, 0, 0)
const OESTE := Vector3(-1, 0, 0)
const NORTE := Vector3(0, 0, -1)
const SUR := Vector3(0, 0, 1)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


# --- utilidades ----------------------------------------------------------------------------------------------------

func _tinta() -> float:
	return lanzador.tinta.actual if lanzador.tinta != null else 0.0


func _rune(e: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % e)


func _raton(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = root.get_final_transform() * p
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _pantalla_de(p: Vector3) -> Vector2:
	return lanzador.camara.unproject_position(Vector3(p.x, float(jugador.call("y_pies_actual")), p.z))


func _punto(dir: Vector3, casillas: float) -> Vector3:
	return jugador.position + dir.normalized() * casillas * Terreno3D.casilla


func _preparar(elemento: String, glifos: Array) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.maxima = Tinta.MAXIMA_INICIAL
		lanzador.tinta.frascos = Tinta.FRASCOS_INICIALES
		lanzador.tinta.rellenar_barra()


## Avanza fotogramas hasta que la tecla lleve `seg` s REALES pulsada (con tope de fotogramas por si algo la cancela).
func _mantener_hasta(seg: float) -> void:
	var n: int = 0
	while lanzador.modo_lanzar and lanzador.t_mantener < seg and n < 600:
		await process_frame
		n += 1


## Los HechizoVivo que cuelgan del lanzador ahora mismo.
func _vivos() -> Array:
	var r: Array = []
	for n in lanzador.get_children():
		if n is HechizoVivo:
			r.append(n)
	return r


## ¿Hay un rótulo flotante (Label3D) con ese texto en el mundo?
func _hay_rotulo(texto: String) -> bool:
	for n in lanzador.mundo.get_children():
		if n is Label3D and (n as Label3D).text == texto:
			return true
	return false


func _hay_rotulo_en_cualquier_sitio(texto: String) -> bool:
	for n in lanzador.mundo.find_children("*", "Label3D", true, false):
		if (n as Label3D).text == texto:
			return true
	return false


func _suelo_llano(c: Vector2i, n0: int) -> bool:
	return Terreno3D.en_mapa(c) and not Terreno3D.es_agua(c) and not Terreno3D.bloqueada(c) and Terreno3D.altura_en(c) == n0


func _buscar_claro(r: int) -> bool:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(r, alto - r):
		for x in range(r, ancho - r):
			var c := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(c)
			var bien: bool = true
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if not _suelo_llano(c + Vector2i(dx, dy), n0):
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(c - desde).length() < dmejor:
				dmejor = Vector2(c - desde).length()
				mejor = c
	if mejor.x < 0:
		return false
	colocar_jugador(mejor)
	_libre = mejor
	return true


func _pos_celda(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _celda_a(dir: Vector3, n: int) -> Vector2i:
	return celda_jugador() + Vector2i(int(round(dir.x)), int(round(dir.z))) * n


func _goblin(p: Vector3, mira: Vector3 = Vector3(0, 0, 1)) -> Combate3D:
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = mira
	g.health = 100.0
	g.vida_max = 100.0
	_goblins.append(g)
	return g


func _quitar(g: Node) -> void:
	if g != null and is_instance_valid(g):
		if g is Combate3D and (g as Combate3D).pj != null and is_instance_valid((g as Combate3D).pj):
			(g as Combate3D).pj.queue_free()
		g.queue_free()
	_goblins.erase(g)


func _mirar(dir: Vector3) -> void:
	jugador.set("_mirada", dir)
	(jugador.get("pj") as Pj3D).mirar(dir, 1.0)


## F por el camino real: pulsada 2 fotogramas y soltada. Devuelve cuánta tinta se premió con ese golpe (suma de la señal).
func _golpear() -> float:
	_premios.clear()
	_tecla(KEY_F, true)
	await avanzar(2)
	_tecla(KEY_F, false)
	await avanzar_s(0.9)
	var suma: float = 0.0
	for p in _premios:
		suma += float(p[1])
	return suma


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	jugador.tinta.reaccion_premiada.connect(func(t: String, c: float) -> void: _premios.append([t, c]))
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
		(n as Combate3D).position = Vector3(-500.0, 0.0, -500.0)
	var hay: bool = _buscar_claro(4)
	if not hay:
		hay = _buscar_claro(3)
	_ok("0 hay un claro llano donde probar", hay)
	if not hay:
		return
	await avanzar(40)

	# ================================================================================================================
	#  C2 · el orden de los glifos (puro: sin lanzar)
	# ================================================================================================================
	var fuego: RuneData = _rune("fire")
	var sin_orden: Hechizo = Hechizo.construir(fuego, {"flecha": 1, "repeticion": 1}, 1.0)
	_ok("C2 sin orden la receta es un multiconjunto: orden vacío, ni ráfaga ni late", sin_orden.orden_glifos.is_empty() and not sin_orden.rafaga and not sin_orden.late)
	var f_r: Hechizo = Hechizo.construir(fuego, {"flecha": 1, "repeticion": 1}, 1.0, false, ["flecha", "repeticion"])
	var r_f: Hechizo = Hechizo.construir(fuego, {"flecha": 1, "repeticion": 1}, 1.0, false, ["repeticion", "flecha"])
	_ok("C2 el orden de dibujo se conserva en el Hechizo", f_r.orden_glifos == ["flecha", "repeticion"] and r_f.orden_glifos == ["repeticion", "flecha"], str(f_r.orden_glifos))
	_ok("C2 flecha → repetición marca RÁFAGA en fila (intervalo %.2f s, sin abanico ni reparto lateral)" % Hechizo.INTERVALO_RAFAGA,
		f_r.rafaga and is_equal_approx(f_r.intervalo_copias, Hechizo.INTERVALO_RAFAGA) and is_equal_approx(f_r.dispersion, 0.0) and is_equal_approx(f_r.separacion, 0.0) and f_r.copias == 2,
		"rafaga %s · intervalo %.2f · dispersión %.1f" % [f_r.rafaga, f_r.intervalo_copias, f_r.dispersion])
	_ok("C2 repetición → flecha NO es ráfaga y deja el abanico de siempre (idéntico a sin orden)", not r_f.rafaga and is_equal_approx(r_f.intervalo_copias, 0.0)
		and is_equal_approx(r_f.dispersion, sin_orden.dispersion) and is_equal_approx(r_f.separacion, sin_orden.separacion) and r_f.dispersion > 0.0, "dispersión %.1f" % r_f.dispersion)
	_ok("C2 el orden no toca nada más (daño, tinta, recarga, semiejes) en ninguno de los dos", is_equal_approx(f_r.dano, sin_orden.dano) and is_equal_approx(f_r.coste_tinta, sin_orden.coste_tinta)
		and is_equal_approx(f_r.recarga, sin_orden.recarga) and f_r.semiejes.is_equal_approx(sin_orden.semiejes) and is_equal_approx(r_f.dano, sin_orden.dano))
	var b_p: Hechizo = Hechizo.construir(_rune("earth"), {"barrera": 1, "pulso": 1}, 1.0, false, ["barrera", "pulso"])
	var p_b: Hechizo = Hechizo.construir(_rune("earth"), {"barrera": 1, "pulso": 1}, 1.0, false, ["pulso", "barrera"])
	var b_p_sin: Hechizo = Hechizo.construir(_rune("earth"), {"barrera": 1, "pulso": 1}, 1.0)
	_ok("C2 barrera → pulso marca LATIR: nace a tamaño completo (escala_nace 1)", b_p.late and is_equal_approx(b_p.escala_nace, 1.0) and b_p.crece > 0.0 and b_p.solidez > 0.0,
		"late %s · escala_nace %.2f" % [b_p.late, b_p.escala_nace])
	_ok("C2 pulso → barrera NO late: nace pequeña y crece, como hoy (igual que sin orden)", not p_b.late and is_equal_approx(p_b.escala_nace, b_p_sin.escala_nace) and p_b.escala_nace < 1.0,
		"escala_nace %.2f" % p_b.escala_nace)
	var sola: Hechizo = Hechizo.construir(fuego, {"flecha": 1}, 1.0, false, ["flecha"])
	_ok("C2 sin la otra mitad del par no pasa nada (ᛇ sola, ᚠ sola)", not sola.rafaga and not Hechizo.construir(fuego, {"repeticion": 1}, 1.0, false, ["repeticion"]).rafaga)
	var alias: Hechizo = Hechizo.construir(fuego, {"altura": 1}, 1.0, false, ["levitacion"])
	_ok("C2 los alias se resuelven (ᛏ «levitacion» = altura) y lo desconocido no entra en el orden", alias.orden_glifos == ["altura"] and Hechizo.construir(fuego, {}, 1.0, false, ["no_existe"]).orden_glifos.is_empty())
	# Compatibilidad: el golden se construye SIN orden y los campos de la tabla no cambian.
	var d_sin: Dictionary = sin_orden.a_diccionario()
	var d_con: Dictionary = Hechizo.construir(fuego, {"flecha": 1, "repeticion": 1}, 1.0, false, ["repeticion", "flecha"]).a_diccionario()
	_ok("C2 compatibilidad: el diccionario del Hechizo es idéntico con el par que no cambia nada", str(d_sin) == str(d_con))
	# Receta3D
	var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in ["flecha", "levitacion", "repeticion"]:
		receta.apply(g)
	_ok("C2 Receta3D guarda el orden de dibujo (con alias resueltos) y los contadores siguen siendo el multiconjunto", receta.orden == ["flecha", "altura", "repeticion"] and int(receta.contadores.get("altura", 0)) == 1,
		str(receta.orden))
	_ok("C2 y el Hechizo de la receta lo lleva y marca ráfaga", receta.hechizo(fuego).orden_glifos == ["flecha", "altura", "repeticion"] and receta.hechizo(fuego).rafaga)
	var receta2 := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in ["repeticion", "flecha"]:
		receta2.apply(g)
	_ok("C2 la caché de la receta distingue el orden (misma bolsa, otro hechizo)", receta2.hechizo(fuego).rafaga == false and receta2._clave() != Lanzador3D.Receta3D.new(Vector2.RIGHT)._clave())
	# Grimorio.resumen_pagina
	_preparar("fuego", ["flecha", "repeticion"])
	var res: Dictionary = lanzador.resumen_pagina(0)
	_ok("C2 Grimorio.resumen_pagina lleva orden_glifos en el orden de dibujo", res.get("orden_glifos", []) == ["flecha", "repeticion"] and (res["hechizo"] as Hechizo).rafaga, str(res.get("orden_glifos")))
	_preparar("fuego", ["repeticion", "flecha"])
	res = lanzador.resumen_pagina(0)
	_ok("C2 y cambia al dibujar al revés (resumen distinto, sin ráfaga)", res.get("orden_glifos", []) == ["repeticion", "flecha"] and not (res["hechizo"] as Hechizo).rafaga, str(res.get("orden_glifos")))
	# Lanzar de verdad: la ráfaga sale una copia tras otra; el abanico, a la vez.
	var nacidos: Dictionary = {}
	var t_rafaga: Array = []
	_preparar("fuego", ["flecha", "repeticion"])
	var t_ini: float = reloj.t
	_ok("C2 (lanzar) la ráfaga se lanza", lanzador.lanzar_pagina_ya(0, jugador.position, ESTE))
	var vigilar: float = 0.0
	while vigilar < 1.2:
		for v in _vivos():
			if not nacidos.has(v.get_instance_id()):
				nacidos[v.get_instance_id()] = true
				t_rafaga.append(reloj.t - t_ini)
		vigilar += await avanzar_s(0.0334)
	_ok("C2 (lanzar) ráfaga: salen 2 copias, no a la vez: separadas ≈ %.2f s" % Hechizo.INTERVALO_RAFAGA, t_rafaga.size() == 2 and (t_rafaga[1] - t_rafaga[0]) > 0.08 and (t_rafaga[1] - t_rafaga[0]) < 0.25, str(t_rafaga))
	nacidos.clear()
	var t_abanico: Array = []
	_preparar("fuego", ["repeticion", "flecha"])
	await avanzar_s(0.5)
	t_ini = reloj.t
	_ok("C2 (lanzar) el abanico se lanza", lanzador.lanzar_pagina_ya(0, jugador.position, ESTE))
	vigilar = 0.0
	while vigilar < 0.6:
		for v in _vivos():
			if not nacidos.has(v.get_instance_id()):
				nacidos[v.get_instance_id()] = true
				t_abanico.append(reloj.t - t_ini)
		vigilar += await avanzar_s(0.0334)
	_ok("C2 (lanzar) abanico: las 2 copias salen a la vez, como siempre", t_abanico.size() == 2 and absf(t_abanico[1] - t_abanico[0]) < 0.05, str(t_abanico))
	await avanzar_s(1.5)
	# Latir (barrera → pulso): sin el latido de HechizoVivo (pendiente) sale entera y quieta; no debe romper nada.
	_preparar("tierra", ["barrera", "pulso"])
	_ok("C2 (lanzar) barrera → pulso (late) se lanza sin romper nada", lanzador.lanzar_pagina_ya(0, jugador.position + SUR * 2.5 * Terreno3D.casilla, SUR))
	await avanzar_s(1.0)

	# ================================================================================================================
	#  C1 · sobrecarga de página
	# ================================================================================================================
	_ok("C1 las constantes: 0,8 s · G 1,5 · tinta ×2 · temblor 0,05", is_equal_approx(Lanzador3D.T_SOBRECARGA, 0.8) and is_equal_approx(Lanzador3D.G_SOBRECARGA, 1.5)
		and is_equal_approx(Lanzador3D.TINTA_SOBRECARGA, 2.0) and is_equal_approx(Lanzador3D.TEMBLOR_SOBRECARGA, 0.05))
	var este := ESTE
	_raton(_pantalla_de(_punto(este, 2.5)))
	await avanzar(2)
	# --- C1a · mantener más de 0,8 s ---
	_preparar("fuego", ["flecha"])
	var tinta0: float = _tinta()
	_tecla(KEY_1, true)
	await avanzar(3)
	_ok("C1a mantener 1 entra en el modo rápido y aún no hay sobrecarga", lanzador.modo_lanzar and lanzador._rapido and not bool(lanzador._preparado.get("sobrecarga", false)))
	var coste: float = lanzador.tinta.coste_efectivo(float((lanzador._preparado["hechizo"] as Hechizo).coste_tinta), "fuego")
	_ok("C1a hay anillo de carga en el indicador y va llenándose", lanzador._apuntado != null and lanzador._apuntado.anillo_carga != null and lanzador._apuntado.carga_dibujada > 0.0 and lanzador._apuntado.carga_dibujada < 1.0,
		"carga %.2f" % (lanzador._apuntado.carga_dibujada if lanzador._apuntado != null else -1.0))
	await _mantener_hasta(0.4)
	var a_medias: float = lanzador._apuntado.carga_dibujada
	_ok("C1a a los 0,4 s el anillo va por la mitad y sin pulso", absf(a_medias - 0.5) < 0.12 and not lanzador._apuntado.carga_completa and lanzador._apuntado.pulsos_carga == 0, "%.2f" % a_medias)
	await _mantener_hasta(Lanzador3D.T_SOBRECARGA + 0.1)
	_ok("C1a pasados 0,8 s s el anillo está lleno, cambia de color y da UN pulso", lanzador._apuntado.carga_dibujada >= 0.999 and lanzador._apuntado.carga_completa and lanzador._apuntado.pulsos_carga == 1,
		"carga %.2f · pulsos %d" % [lanzador._apuntado.carga_dibujada, lanzador._apuntado.pulsos_carga])
	var mat_anillo: ShaderMaterial = (lanzador._apuntado.anillo_carga.mesh as PlaneMesh).material as ShaderMaterial
	_ok("C1a el anillo lista es dorado (no el de en curso)", (mat_anillo.get_shader_parameter("color") as Color).is_equal_approx(Apuntado3D.COLOR_CARGA_LISTA))
	_ok("C1a la página queda marcada sobrecargada y la barra de páginas late", bool(lanzador._preparado.get("sobrecarga", false)) and lanzador._page_hud != null and bool(lanzador._page_hud.get("_sobre_lista")))
	var h_prev: Hechizo = lanzador.hechizo_de(lanzador._preparado)
	_ok("C1a la previsión ya ve Hechizo.potencia = G_SOBRECARGA (1,5)", is_equal_approx(h_prev.potencia, 1.5), "%.2f" % h_prev.potencia)
	var potencia_vista: float = 0.0
	_tecla(KEY_1, false)
	var rotulo_visto: bool = false
	var t_esp: float = 0.0
	var gasto_a: float = 0.0          # se mide en el primer fotograma tras el cobro: la tinta vuelve a regenerarse 1,2 s después
	while t_esp < 1.6:
		for v in _vivos():
			potencia_vista = maxf(potencia_vista, (v.h as Hechizo).potencia)
		rotulo_visto = rotulo_visto or _hay_rotulo_en_cualquier_sitio(Lanzador3D.ROTULO_SOBRECARGA)
		t_esp += await avanzar_s(0.0334)
		if gasto_a == 0.0 and tinta0 - _tinta() > 0.1:
			gasto_a = tinta0 - _tinta()
	_ok("C1a soltar cobra el DOBLE de tinta (%.1f × 2)" % coste, absf(gasto_a - coste * 2.0) < 0.6, "gastó %.2f, esperado %.2f" % [gasto_a, coste * 2.0])
	_ok("C1a el HechizoVivo que sale lleva potencia 1,5", is_equal_approx(potencia_vista, 1.5), "%.2f" % potencia_vista)
	_ok("C1a sale el rótulo «¡Sobrecarga!»", rotulo_visto)
	_ok("C1a al soltar se apaga el arco de la página y el modo", not lanzador.modo_lanzar and not bool(lanzador._page_hud.get("_sobre_lista")))
	await avanzar_s(1.0)

	# --- C1b · soltar antes de 0,8 s: normal ---
	_preparar("fuego", ["flecha"])
	tinta0 = _tinta()
	_tecla(KEY_1, true)
	await avanzar(3)
	await _mantener_hasta(0.3)
	var t_antes: float = lanzador.t_mantener
	_tecla(KEY_1, false)
	potencia_vista = 0.0
	rotulo_visto = false
	t_esp = 0.0
	var gasto_b: float = 0.0
	while t_esp < 1.0:
		for v in _vivos():
			potencia_vista = maxf(potencia_vista, (v.h as Hechizo).potencia)
		rotulo_visto = rotulo_visto or _hay_rotulo_en_cualquier_sitio(Lanzador3D.ROTULO_SOBRECARGA)
		t_esp += await avanzar_s(0.0334)
		if gasto_b == 0.0 and tinta0 - _tinta() > 0.1:
			gasto_b = tinta0 - _tinta()
	_ok("C1b (mantenida %.2f s < 0,8) sale normal: tinta ×1 (%.1f)" % [t_antes, coste], absf(gasto_b - coste) < 0.6, "gastó %.2f, esperado %.2f" % [gasto_b, coste])
	_ok("C1b y con potencia 1,0, sin rótulo", is_equal_approx(potencia_vista, 1.0) and not rotulo_visto, "potencia %.2f" % potencia_vista)
	await avanzar_s(1.5)

	# --- C1c · sin tinta para el doble ---
	_preparar("fuego", ["flecha"])
	coste = lanzador.tinta.coste_efectivo(float(lanzador.resumen_pagina(0)["hechizo"].coste_tinta), "fuego")
	lanzador.tinta.frascos = 0
	lanzador.tinta.maxima = coste * 1.3          # cabe un hechizo y no dos; el máximo también impide que regenere hasta poder pagar el doble
	lanzador.tinta.actual = lanzador.tinta.maxima
	lanzador.feedback_text = ""
	tinta0 = _tinta()
	_tecla(KEY_1, true)
	await avanzar(3)
	_ok("C1c con tinta para uno solo se entra en el modo", lanzador.modo_lanzar and lanzador._rapido)
	await _mantener_hasta(Lanzador3D.T_SOBRECARGA + 0.1)
	_ok("C1c sin tinta para el doble no se sobrecarga y avisa «Sin tinta para sobrecargar»", not bool(lanzador._preparado.get("sobrecarga", false)) and lanzador.feedback_text == Lanzador3D.AVISO_SIN_TINTA_SOBRECARGA,
		"«%s»" % lanzador.feedback_text)
	_ok("C1c y el anillo no se completa a dorado", not lanzador._apuntado.carga_completa and lanzador._apuntado.pulsos_carga == 0)
	_tecla(KEY_1, false)
	potencia_vista = 0.0
	rotulo_visto = false
	t_esp = 0.0
	gasto_b = 0.0
	while t_esp < 1.0:
		for v in _vivos():
			potencia_vista = maxf(potencia_vista, (v.h as Hechizo).potencia)
		rotulo_visto = rotulo_visto or _hay_rotulo_en_cualquier_sitio(Lanzador3D.ROTULO_SOBRECARGA)
		t_esp += await avanzar_s(0.0334)
		if gasto_b == 0.0 and tinta0 - _tinta() > 0.1:
			gasto_b = tinta0 - _tinta()
	_ok("C1c sale NORMAL: tinta ×1 y potencia 1,0, sin rótulo", absf(gasto_b - coste) < 0.6 and is_equal_approx(potencia_vista, 1.0) and not rotulo_visto, "gastó %.2f de %.2f · potencia %.2f" % [gasto_b, coste, potencia_vista])
	lanzador.tinta.maxima = Tinta.MAXIMA_INICIAL
	lanzador.tinta.frascos = Tinta.FRASCOS_INICIALES
	await avanzar_s(1.0)

	# --- C1d · el libro de siempre (cast_page) no sobrecarga ---
	_preparar("fuego", ["flecha"])
	lanzador.cast_page(0)
	_ok("C1d cast_page entra en el modo de siempre (no rápido)", lanzador.modo_lanzar and not lanzador._rapido)
	await avanzar_s(1.5)
	_ok("C1d aunque pase de 0,8 s no hay sobrecarga ni anillo", not lanzador._preparado.has("sobrecarga") and (lanzador._apuntado == null or lanzador._apuntado.anillo_carga == null) and is_zero_approx(lanzador.t_mantener))
	lanzador._cancelar_modo()
	await avanzar(2)
	# lanzar_ahora directo sin la marca: coste normal
	_preparar("fuego", ["flecha"])
	tinta0 = _tinta()
	lanzador.lanzar_pagina_ya(0, jugador.position, ESTE)
	_ok("C1d lanzar_pagina_ya (libro/pruebas) cobra ×1", absf((tinta0 - _tinta()) - coste) < 0.6, "gastó %.2f" % (tinta0 - _tinta()))
	await avanzar_s(1.5)

	# ================================================================================================================
	#  C4 · tope de barreras vivas
	# ================================================================================================================
	_ok("C4 MAX_BARRERAS_VIVAS es 3", Lanzador3D.MAX_BARRERAS_VIVAS == 3)
	lanzador.barreras_vivas.clear()
	var direcciones: Array = [ESTE, OESTE, NORTE, SUR]
	var linajes: Array = []
	for i in range(4):
		_preparar("tierra", ["barrera"])
		lanzador.cooldown_left[0] = 0.0
		var origen: Vector3 = jugador.position + (direcciones[i] as Vector3) * 2.5 * Terreno3D.casilla
		var salio: bool = lanzador.lanzar_pagina_ya(0, origen, direcciones[i])
		await avanzar(3)
		if lanzador.barreras_vivas.size() > 0:
			linajes.append((lanzador.barreras_vivas.back() as Dictionary)["linaje"])
		if i < 3:
			_ok("C4 la barrera %d sale y hay %d vivas" % [i + 1, i + 1], salio and lanzador.barreras_vivas.size() == i + 1, "salió %s · vivas %d" % [salio, lanzador.barreras_vivas.size()])
	var propias := func(l: Variant) -> int:
		var n: int = 0
		for s in lanzador._solideces_v2:
			if is_instance_valid(s) and s.linaje == l and not (s as Node).is_queued_for_deletion():
				n += 1
		return n
	_ok("C4 la cuarta barrera sale y SIGUEN 3 vivas (la lista no pasa del tope)", lanzador.barreras_vivas.size() == 3, str(lanzador.barreras_vivas.size()))
	_ok("C4 la más antigua se disolvió (su SolidezV2 se va) y las otras tres siguen", linajes.size() == 4 and int(propias.call(linajes[0])) == 0 and int(propias.call(linajes[1])) > 0
		and int(propias.call(linajes[2])) > 0 and int(propias.call(linajes[3])) > 0, "propias %s" % str(linajes.map(func(l: Variant) -> int: return int(propias.call(l)))))
	_ok("C4 rótulo «Se disuelve» sobre la vieja", _hay_rotulo_en_cualquier_sitio(Lanzador3D.ROTULO_DISUELVE))
	_ok("C4 la lista de la más antigua a la más reciente: ya no está la primera", not lanzador.barreras_vivas.any(func(b: Dictionary) -> bool: return b["linaje"] == linajes[0]))
	# una que murió sola no cuenta para el tope
	for s in lanzador._solideces_v2:
		if is_instance_valid(s) and s.linaje == linajes[1]:
			(s as Node).queue_free()
	await avanzar(3)
	_preparar("tierra", ["barrera"])
	var quinta: bool = lanzador.lanzar_pagina_ya(0, jugador.position + (ESTE + NORTE) * 2.5 * Terreno3D.casilla, ESTE)       # un sitio libre: la tierra de las anteriores se queda construida aunque su SolidezV2 se disuelva
	await avanzar(3)
	_ok("C4 una barrera que ya se rompió deja sitio sin disolver ninguna otra (siguen 3, la 3.ª y la 4.ª intactas)", quinta and lanzador.barreras_vivas.size() == 3 and int(propias.call(linajes[2])) > 0 and int(propias.call(linajes[3])) > 0,
		"salió %s · vivas %d · propias %s · aviso «%s»" % [quinta, lanzador.barreras_vivas.size(), str(linajes.map(func(l: Variant) -> int: return int(propias.call(l)))), lanzador.feedback_text])
	await avanzar_s(0.5)

	# ================================================================================================================
	#  C5 · el golpe F devuelve tinta
	# ================================================================================================================
	_ok("C5 las constantes: +5 y +10", is_equal_approx(GolpeCuerpo.TINTA_GOLPE, 5.0) and is_equal_approx(GolpeCuerpo.TINTA_GOLPE_ESCUDO, 10.0))
	_buscar_claro(3)
	await avanzar(40)
	_mirar(ESTE)
	await avanzar(3)
	lanzador.tinta.maxima = Tinta.MAXIMA_INICIAL
	# --- sin nadie delante: 0 ---
	lanzador.tinta.actual = 30.0
	var premio: float = await _golpear()
	_ok("C5 un golpe al aire no da tinta", is_zero_approx(premio), str(_premios))
	# --- goblin sin escudo: +5 ---
	lanzador.tinta.actual = 30.0
	var g1: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var t_antes_g: float = _tinta()
	premio = await _golpear()
	_ok("C5 el golpe que acierta a un goblin da +5 (señal «golpe»)", is_equal_approx(premio, 5.0) and _premios.size() == 1 and _premios[0][0] == GolpeCuerpo.TIPO_TINTA_GOLPE, str(_premios))
	_ok("C5 y la barra sube de verdad (≥ +5)", _tinta() - t_antes_g >= 5.0 - 0.001, "%.2f → %.2f" % [t_antes_g, _tinta()])
	_quitar(g1)
	await avanzar_s(0.9)
	# --- escudo entero de frente: lo para, 0 ---
	lanzador.tinta.actual = 30.0
	var g_esc: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	Escudo3D.equipar(g_esc, false)
	premio = await _golpear()
	_ok("C5 contra un escudo entero (el golpe se para en él) no da tinta", is_zero_approx(premio), str(_premios))
	_quitar(g_esc)
	await avanzar_s(0.9)
	# --- escudo quemado: +10 ---
	lanzador.tinta.actual = 30.0
	var g_q: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var esc_q: Escudo3D = Escudo3D.equipar(g_q, false)
	esc_q.estado = "quemado"
	t_antes_g = _tinta()
	premio = await _golpear()
	_ok("C5 con el escudo QUEMADO el golpe da +10 (señal «golpe_escudo»)", is_equal_approx(premio, 10.0) and _premios.size() == 1 and _premios[0][0] == GolpeCuerpo.TIPO_TINTA_GOLPE_ESCUDO, str(_premios))
	_ok("C5 y la barra sube de verdad (≥ +10)", _tinta() - t_antes_g >= 10.0 - 0.001, "%.2f → %.2f" % [t_antes_g, _tinta()])
	_quitar(g_q)
	await avanzar_s(0.9)
	# --- escudo roto: +10 ---
	lanzador.tinta.actual = 30.0
	var g_r: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	var esc_r: Escudo3D = Escudo3D.equipar(g_r, false)
	esc_r.estado = "roto"
	premio = await _golpear()
	_ok("C5 con el escudo ROTO también +10", is_equal_approx(premio, 10.0), str(_premios))
	_quitar(g_r)
	await avanzar_s(0.9)
	# --- muñeco: no se farmea ---
	lanzador.tinta.actual = 30.0
	var g_m: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	g_m.premia_tinta = false
	premio = await _golpear()
	_ok("C5 un muñeco/diana (premia_tinta false) no da tinta", is_zero_approx(premio), str(_premios))
	_quitar(g_m)
	await avanzar_s(0.9)
	# --- barra llena: no pasa del máximo y no hay premio ---
	lanzador.tinta.actual = lanzador.tinta.maxima
	var g_l: Combate3D = _goblin(_pos_celda(_celda_a(ESTE, 1)), OESTE)
	premio = await _golpear()
	_ok("C5 con la barra llena no pasa del máximo (no hay premio que pintar)", is_zero_approx(premio) and _tinta() <= lanzador.tinta.maxima + 0.001, "%.2f/%.2f" % [_tinta(), lanzador.tinta.maxima])
	_quitar(g_l)
	# --- el HUD pinta «+5» y «¡Escudo roto! +10» ---
	var hud: HudEoW = null
	for n in get_nodes_in_group("hud_eow"):
		hud = n as HudEoW
	_ok("C5 hay un HudEoW en la escena", hud != null)
	if hud != null:
		var antes_n: int = hud._tinta.get_parent().get_child_count()
		jugador.tinta.reaccion_premiada.emit(GolpeCuerpo.TIPO_TINTA_GOLPE, 5.0)
		jugador.tinta.reaccion_premiada.emit(GolpeCuerpo.TIPO_TINTA_GOLPE_ESCUDO, 10.0)
		jugador.tinta.reaccion_premiada.emit("hundido", 20.0)
		var textos: Array = []
		for c in hud._tinta.get_parent().get_children():
			if c is Label:
				textos.append((c as Label).text)
		_ok("C5 el HUD rotula «+5», «¡Escudo roto! +10» y sigue con «¡Hundido! +20»", textos.has("+5") and textos.has("¡Escudo roto! +10") and textos.has("¡Hundido! +20"), str(textos) + " · hijos antes %d" % antes_n)
	await avanzar_s(0.5)
	print("Comprobaciones: %d" % _comprobaciones)
