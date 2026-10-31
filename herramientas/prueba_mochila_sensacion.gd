extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, TAREA M (31/10; presentacion/ui/menu_pestanas.gd, hud_eow.gd, barra_hud.gd, jugador/jugador_3d.gd, nucleo/sfx.gd): la mochila y los consumibles se oyen y se ven.
## Sobre la escena real del Bosque (menú del lanzador, HUD y jugadora de verdad). Los sonidos se cuentan con `Sfx.REGISTRAR` (headless no se oye nada); los movimientos, mirando que su Tween
## esté vivo y dónde acaba cada cosa. Entre dos sonidos iguales se espera más que la veda de 70 ms (`_pausa`), si no el segundo no suena.
##   1 abrir con I: 1 «bolsa» (−10 dB) y tween vivo, pop del hueco elegido;  2 mover 3 veces: 3 «ui_tick», el aro se desliza y acaba sobre el hueco 3;
##   3 Enter sobre un consumible: «ui_equipar», pop del hueco, destello del círculo, los 20 huecos son los mismos;  4 Enter sobre un material: «no_puedes» a −14 dB y el hueco tiembla;
##   5 objeto nuevo con el menú abierto: pop y brillo del hueco nuevo, mismas instancias; el oro cuenta hacia el valor nuevo con «moneda»;  6 pestañas: «pagina» y entrada desde un lado;
##   7 cerrar: «bolsa» otra vez;  8 Q con la vida llena: «no_puedes», sin «pocion», el círculo tiembla;  9 Q con la vida baja: «pocion» al empezar y «pocion_fin» + destello verde + pulso al acabar;
##   10 un golpe cancela el trago: «no_puedes»;  11 R: «ui_tick» y el icono gira;  12 ACTIVA = false: sin pops, deslizamientos ni destellos, pero con todos los sonidos;
##   13 con el libro abierto, I no abre la mochila; la J abre con «libro_abre»;  14 los .wav nuevos existen y `Sonidos` delega en `Sfx.play_ui`.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_mochila_sensacion.gd

var _menu: MenuPestanas = null
var _hud: HudEoW = null
var _j: Jugador3D = null


func _tecla_ev(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	return ev


## Espera más que la veda de Sfx entre dos sonidos iguales (reloj de pared: la veda usa `Time.get_ticks_msec`).
func _pausa() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 30)
	await avanzar(1)


func _indice(id: String) -> int:
	for i in range(_menu.pilas().size()):
		if String(_menu.pilas()[i][0]) == id:
			return i
	return -1


func _viva(t: Tween) -> bool:
	return t != null and t.is_valid()


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	_j = _jugadora(Vector2i(11, 33))
	_menu = lanzador.menu
	_hud = _j.hud_eow
	_ok("0 hay menú, HUD y jugadora de verdad", _menu != null and _hud != null and _j.pj != null)
	if _menu == null or _hud == null:
		return
	Sensacion3D.ACTIVA = true
	Sfx.REGISTRAR = true
	var e: Estado = Estado.i()
	e.capacidad = 8
	e.oro = 0
	e.agregar("lavanda", 1)
	e.agregar("nucleo_eco", 1)
	e.agregar("seta", 3)
	e.agregar("pocion", 3)
	e.agregar("tonico_tinta", 1)
	await avanzar(2)
	await _caso_abrir()
	await _caso_navegar()
	await _caso_equipar()
	await _caso_material()
	await _caso_nuevo()
	await _caso_pestanas()
	await _caso_cerrar()
	await _caso_beber_lleno()
	await _caso_beber()
	await _caso_cancelar()
	await _caso_r()
	await _caso_apagada()
	await _caso_libro()
	_caso_audio()
	Sensacion3D.ACTIVA = true
	Sfx.REGISTRAR = false
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- 1 · abrir ----------------------------------------------------------------------------------------------------------
func _caso_abrir() -> void:
	Sfx.vaciar_registro()
	_menu._input(_tecla_ev(KEY_I))
	_ok("1 la tecla I abre la mochila y pausa", _menu.abierta and paused)
	_ok("1 suena UNA «bolsa»", Sfx.veces("bolsa") == 1, str(Sfx.CONTEO))
	_ok("1 la bolsa suena a −10 dB", is_equal_approx(float(Sfx.ULTIMOS.back()["db"]), -10.0), str(Sfx.ULTIMOS.back()))
	_ok("1 el tween de apertura está vivo y corriendo", _viva(_menu._tween) and _menu._tween.is_running())
	var h: BolsaUI.Hueco = _menu.hueco(_menu.elegido())
	_ok("1 el hueco elegido hace pop (tween vivo, escala 1,15 al empezar)", _viva(h.tween_pop) and h.scale.x > 1.1, str(h.scale))
	await avanzar(12)
	_ok("1 el pop acaba en escala 1", h.scale.is_equal_approx(Vector2.ONE), str(h.scale))
	_ok("1 los 20 huecos existen", _menu._huecos.size() == 20 and _menu._anillo != null)


# --- 2 · navegar --------------------------------------------------------------------------------------------------------
func _caso_navegar() -> void:
	Sfx.vaciar_registro()
	_ok("2 el aro empieza sobre el hueco 0", _menu._anillo.visible and _menu._anillo.position.is_equal_approx(_menu.hueco(0).position))
	for k in range(3):
		await _pausa()
		_menu.mover(Vector2.RIGHT)
		if k == 0:
			_ok("2 al mover, el aro se desliza (tween vivo) y aún no ha llegado", _viva(_menu._tw_anillo) and not _menu._anillo.position.is_equal_approx(_menu.hueco(1).position),
				str(_menu._anillo.position))
	_ok("2 tres movimientos = tres «ui_tick»", Sfx.veces("ui_tick") == 3, str(Sfx.CONTEO))
	_ok("2 el tic va a −20 dB", is_equal_approx(float(Sfx.ULTIMOS.back()["db"]), -20.0))
	_ok("2 el hueco elegido es el 3", _menu.elegido() == 3)
	await avanzar(8)                                   # 0,08 s = 3 fotogramas a 30 fps
	_ok("2 el aro acaba sobre el hueco 3", _menu._anillo.position.is_equal_approx(_menu.hueco(3).position), "%s vs %s" % [_menu._anillo.position, _menu.hueco(3).position])
	_ok("2 el hueco ya no pinta su propio aro (lo pinta el control aparte)", _menu.hueco(3).sin_aro and _menu.hueco(3).elegido)
	_menu.mover(Vector2.RIGHT)                         # el borde: no cambia nada, no suena
	_ok("2 el icono del detalle funde al cambiar de objeto", _viva(_menu._detalle._tw_icono))


# --- 3 · equipar --------------------------------------------------------------------------------------------------------
func _caso_equipar() -> void:
	var antes: Array = _menu._huecos.duplicate()
	var i_t: int = _indice("tonico_tinta")
	await _pausa()
	_menu._elegir(i_t)
	await avanzar(4)
	_ok("3 el equipado de partida es la poción y el tónico no lo está", _hud.consumibles.equipado() == "pocion" and not bool(_menu.detalle()["equipado"]), _hud.consumibles.equipado())
	Sfx.vaciar_registro()
	await _pausa()
	_menu._input(_tecla_ev(KEY_ENTER))
	await avanzar(1)
	_ok("3 Enter sobre un consumible: suena «ui_equipar» (y a −12 dB)", Sfx.veces("ui_equipar") == 1 and is_equal_approx(float(Sfx.ULTIMOS.back()["db"]), -12.0), str(Sfx.CONTEO))
	_ok("3 y se equipa de verdad", _hud.consumibles.equipado() == "tonico_tinta" and bool(_menu.detalle()["equipado"]))
	_ok("3 el hueco del icono hace pop", _viva(_menu.hueco(i_t).tween_pop))
	_ok("3 el círculo del HUD destella (tween vivo y brillo > 0)", _viva(_hud._circulo.tween_destello) and _hud._circulo.fx_destello > 0.0, str(_hud._circulo.fx_destello))
	await avanzar(10)
	_ok("3 el destello se apaga en 0,2 s", is_equal_approx(_hud._circulo.fx_destello, 0.0))
	var mismas: bool = _menu._huecos.size() == antes.size()
	for k in range(antes.size()):
		if k < _menu._huecos.size() and antes[k] != _menu._huecos[k]:
			mismas = false
	_ok("3 los 20 huecos son las MISMAS instancias tras equipar (el refresco no los recrea)", mismas)
	_hud.consumibles.equipar("pocion")


# --- 4 · material -------------------------------------------------------------------------------------------------------
func _caso_material() -> void:
	await _pausa()
	_menu._elegir(_indice("seta"))
	Sfx.vaciar_registro()
	await _pausa()
	_menu._input(_tecla_ev(KEY_ENTER))
	var h: BolsaUI.Hueco = _menu.hueco(_menu.elegido())
	_ok("4 Enter sobre un material: suena «no_puedes» a −14 dB", Sfx.veces("no_puedes") == 1 and is_equal_approx(float(Sfx.ULTIMOS.back()["db"]), -14.0), str(Sfx.CONTEO))
	_ok("4 y no suena «ui_equipar»", Sfx.veces("ui_equipar") == 0)
	_ok("4 el hueco tiembla (tween vivo)", _viva(h.tween_tembl))
	await avanzar(8)
	_ok("4 y a los 0,15 s vuelve a su sitio", is_equal_approx(h.tembl_x, 0.0))


# --- 5 · objeto nuevo y oro ---------------------------------------------------------------------------------------------
func _caso_nuevo() -> void:
	var antes: Array = _menu._huecos.duplicate()
	var e: Estado = Estado.i()
	Sfx.vaciar_registro()
	e.agregar("baya", 1)
	await avanzar(1)
	var i_b: int = _indice("baya")
	_ok("5 la baya llegó a la mochila y al menú", i_b >= 0)
	var hb: BolsaUI.Hueco = _menu.hueco(i_b)
	_ok("5 el hueco nuevo tiene tween de pop", _viva(hb.tween_pop))
	_ok("5 y brilla (tween de brillo vivo, brillo > 0)", _viva(hb.tween_brillo) and hb.brillo > 0.0, str(hb.brillo))
	await avanzar(14)
	_ok("5 el brillo se apaga en ~0,4 s", is_equal_approx(hb.brillo, 0.0), str(hb.brillo))
	var mismas: bool = _menu._huecos.size() == antes.size()
	for k in range(antes.size()):
		if k < _menu._huecos.size() and antes[k] != _menu._huecos[k]:
			mismas = false
	_ok("5 los 20 huecos son las MISMAS instancias tras recibir un objeto", mismas)
	_ok("5 la cantidad de un objeto que ya estaba se actualiza en su hueco", _menu.hueco(_indice("seta")).cantidad == 3)
	await _pausa()
	e.oro = 130
	e.cambiado.emit()
	_ok("5 el oro sube: suena «moneda»", Sfx.veces("moneda") == 1, str(Sfx.CONTEO))
	_ok("5 el contador de oro tiene tween vivo y aún no marca el valor final", _viva(_menu._tw_oro) and _menu._oro.text != "130", _menu._oro.text)
	await avanzar(14)
	_ok("5 en 0,3 s el contador llega a 130", _menu._oro.text == "130", _menu._oro.text)
	_ok("5 y vuelve a escala 1 tras el pop", _menu._oro.scale.is_equal_approx(Vector2.ONE))
	Sfx.vaciar_registro()
	await _pausa()
	e.oro = 100                                     # bajar no suena
	e.cambiado.emit()
	await avanzar(14)
	_ok("5 bajar el oro no suena «moneda» y también cuenta (100)", Sfx.veces("moneda") == 0 and _menu._oro.text == "100", _menu._oro.text)
	e.quitar("baya")
	await avanzar(1)


# --- 6 · pestañas -------------------------------------------------------------------------------------------------------
func _caso_pestanas() -> void:
	Sfx.vaciar_registro()
	_menu.cambiar_pestana(1)
	_ok("6 cambiar de pestaña: «pagina» a −14 dB", Sfx.veces("pagina") == 1 and is_equal_approx(float(Sfx.ULTIMOS.back()["db"]), -14.0), str(Sfx.CONTEO))
	_ok("6 el contenido entra desde 12 px a un lado (tween vivo)", _viva(_menu._tw_pagina) and is_equal_approx(_menu._cuerpo.position.x, MenuPestanas.CUERPO_POS.x + 12.0), str(_menu._cuerpo.position))
	await avanzar(8)
	_ok("6 y acaba en su sitio", is_equal_approx(_menu._cuerpo.position.x, MenuPestanas.CUERPO_POS.x))
	await _pausa()
	_menu.cambiar_pestana(0)
	_ok("6 volver entra desde el otro lado", is_equal_approx(_menu._cuerpo.position.x, MenuPestanas.CUERPO_POS.x - 12.0))
	await avanzar(8)


# --- 7 · cerrar ---------------------------------------------------------------------------------------------------------
func _caso_cerrar() -> void:
	Sfx.vaciar_registro()
	await _pausa()
	_menu._input(_tecla_ev(KEY_ESCAPE))
	_ok("7 cerrar suena «bolsa» (más grave)", not _menu.abierta and Sfx.veces("bolsa") == 1 and float(Sfx.ULTIMOS.back()["tono"]) < 0.9, str(Sfx.ULTIMOS.back()))
	_ok("7 el tween de cierre está vivo", _viva(_menu._tween))
	await avanzar(12)
	_ok("7 se oculta y el mundo se reanuda", not _menu._marco.visible and not paused)


# --- 8 · Q con la vida llena --------------------------------------------------------------------------------------------
func _caso_beber_lleno() -> void:
	_j.vida = Estado.i().vida_max
	_hud.consumibles.equipar("pocion")
	Sfx.vaciar_registro()
	await _pausa()
	var cuenta: int = Estado.i().cuenta("pocion")
	_hud._input(_tecla_ev(KEY_Q))
	_ok("8 Q con la vida llena: «no_puedes» a −14 dB", Sfx.veces("no_puedes") == 1 and is_equal_approx(float(Sfx.ULTIMOS.back()["db"]), -14.0), str(Sfx.CONTEO))
	_ok("8 y no suena «pocion»", Sfx.veces("pocion") == 0 and Sfx.veces("pocion_fin") == 0)
	_ok("8 no bebe ni gasta", _j._t_beber <= 0.0 and Estado.i().cuenta("pocion") == cuenta)
	_ok("8 el círculo del HUD tiembla (tween vivo)", _viva(_hud._circulo.tween_tembl))
	await avanzar(8)
	_ok("8 y vuelve a su sitio", is_equal_approx(_hud._circulo.fx_tembl, 0.0))


# --- 9 · Q con la vida baja ---------------------------------------------------------------------------------------------
func _caso_beber() -> void:
	_j = _jugadora(Vector2i(11, 33))
	_j.vida = 40.0
	var cuenta: int = Estado.i().cuenta("pocion")
	Sfx.vaciar_registro()
	await _pausa()
	_hud._input(_tecla_ev(KEY_Q))
	_ok("9 Q con la vida baja empieza a beber", _j._t_beber > 0.0)
	_ok("9 «pocion» suena al empezar (y «pocion_fin» todavía no)", Sfx.veces("pocion") == 1 and Sfx.veces("pocion_fin") == 0, str(Sfx.CONTEO))
	var n: int = 0
	while _j._t_beber > 0.0 and n < 120:
		await process_frame
		n += 1
	_ok("9 el trago termina (%d fotogramas)" % n, _j._t_beber <= 0.0 and n < 120)
	_ok("9 «pocion_fin» suena al acabar, con el tono +15 %", Sfx.veces("pocion_fin") == 1 and is_equal_approx(float(Sfx.ULTIMOS.back()["tono"]), 1.15), str(Sfx.ULTIMOS.back()))
	_ok("9 cura 40 y gasta una poción", is_equal_approx(_j.vida, 80.0) and Estado.i().cuenta("pocion") == cuenta - 1, "%s · %d" % [_j.vida, Estado.i().cuenta("pocion")])
	var mats: Array = _j.pj._materiales
	_ok("9 la jugadora tiene materiales", mats.size() > 0)
	var m: StandardMaterial3D = mats[0] as StandardMaterial3D
	var verde: Color = Jugador3D.COLOR_DESTELLO_BEBER
	_ok("9 destello verde en sus materiales: emisión activa y del color", m.emission_enabled and Vector3(m.emission.r - verde.r, m.emission.g - verde.g, m.emission.b - verde.b).length() < 0.05, str(m.emission))
	_ok("9 con energía > 0 y el tween vivo", m.emission_energy_multiplier > 0.2 and _viva(_j._tw_destello_beber), str(m.emission_energy_multiplier))
	_ok("9 la barra de vida recibe el pulso", _hud._vida.pulso_t > 0.0, str(_hud._vida.pulso_t))
	var previa: Array = [_j._emision_destello_beber[0][1], _j._emision_destello_beber[0][3]] if _j._emision_destello_beber.size() > 0 else [false, 0.0]
	await avanzar(10)
	_ok("9 a los 0,2 s se apaga y devuelve la emisión que tenía", _j._emision_destello_beber.is_empty() and m.emission_enabled == bool(previa[0]) and is_equal_approx(m.emission_energy_multiplier, float(previa[1])),
		"%s %s" % [m.emission_enabled, m.emission_energy_multiplier])
	await avanzar(10)
	_ok("9 el pulso de la barra se acaba", is_equal_approx(_hud._vida.pulso_t, 0.0))


# --- 10 · un golpe cancela el trago -------------------------------------------------------------------------------------
func _caso_cancelar() -> void:
	_j.vida = 50.0
	_j._t_inv = 0.0
	await _pausa()
	_hud._input(_tecla_ev(KEY_Q))
	_ok("10 empieza otro trago", _j._t_beber > 0.0)
	await avanzar(3)
	Sfx.vaciar_registro()
	await _pausa()
	_j._t_inv = 0.0
	_j.recibir_dano(5.0, _j.position + Vector3(1, 0, 0))
	_ok("10 el golpe corta el trago", _j._t_beber <= 0.0)
	_ok("10 suena «no_puedes» y no «pocion_fin»", Sfx.veces("no_puedes") == 1 and Sfx.veces("pocion_fin") == 0, str(Sfx.CONTEO))
	_ok("10 el sonido en bucle de la poción se corta", _j._snd_beber == null)
	await avanzar(6)
	_j._t_inv = 0.0
	_j.vida = Estado.i().vida_max


# --- 11 · R -------------------------------------------------------------------------------------------------------------
func _caso_r() -> void:
	_j._t_beber = 0.0
	await avanzar(2)
	_hud.consumibles.equipar("pocion")
	Sfx.vaciar_registro()
	await _pausa()
	_hud._input(_tecla_ev(KEY_R))
	_ok("11 R cambia de consumible", _hud.consumibles.equipado() != "pocion", _hud.consumibles.equipado())
	_ok("11 y suena «ui_tick»", Sfx.veces("ui_tick") == 1, str(Sfx.CONTEO))
	_ok("11 el icono gira (tween vivo, ángulo −180° al empezar)", _viva(_hud._circulo.tween_giro) and is_equal_approx(_hud._circulo.fx_giro, -PI), str(_hud._circulo.fx_giro))
	await avanzar(8)
	_ok("11 y acaba derecho en 0,15 s", is_equal_approx(_hud._circulo.fx_giro, 0.0))
	_hud.consumibles.equipar("pocion")


# --- 12 · sin sensación: sin movimiento, con sonido ---------------------------------------------------------------------
func _caso_apagada() -> void:
	Sensacion3D.ACTIVA = false
	Sfx.vaciar_registro()
	var pop_menu: Tween = null
	_menu._input(_tecla_ev(KEY_I))
	var h: BolsaUI.Hueco = _menu.hueco(_menu.elegido())
	pop_menu = h.tween_pop
	_ok("12 apagada: abrir sigue sonando «bolsa» y abre", _menu.abierta and Sfx.veces("bolsa") == 1)
	_ok("12 apagada: el hueco elegido no hace pop", h.scale.is_equal_approx(Vector2.ONE))
	await _pausa()
	_menu.mover(Vector2.RIGHT)
	_ok("12 apagada: sigue sonando el «ui_tick»", Sfx.veces("ui_tick") == 1)
	_ok("12 apagada: el aro salta de golpe al hueco nuevo", _menu._anillo.position.is_equal_approx(_menu.hueco(_menu.elegido()).position))
	await _pausa()
	_menu._elegir(_indice("seta"))
	var tembl_antes: Tween = _menu.hueco(_menu.elegido()).tween_tembl
	await _pausa()
	_menu._input(_tecla_ev(KEY_ENTER))
	_ok("12 apagada: sigue sonando «no_puedes» sobre un material", Sfx.veces("no_puedes") == 1)
	_ok("12 apagada: el hueco no tiembla", _menu.hueco(_menu.elegido()).tween_tembl == tembl_antes and is_equal_approx(_menu.hueco(_menu.elegido()).tembl_x, 0.0))
	await _pausa()
	_menu._elegir(_indice("tonico_tinta"))
	var destello_antes: Tween = _hud._circulo.tween_destello
	await _pausa()
	_menu._input(_tecla_ev(KEY_ENTER))
	await avanzar(1)
	_ok("12 apagada: sigue sonando «ui_equipar» y equipa", Sfx.veces("ui_equipar") == 1 and _hud.consumibles.equipado() == "tonico_tinta")
	_ok("12 apagada: el círculo no destella", _hud._circulo.tween_destello == destello_antes and is_equal_approx(_hud._circulo.fx_destello, 0.0))
	_ok("12 apagada: el hueco del tónico no hace pop", _menu.hueco(_menu.elegido()).scale.is_equal_approx(Vector2.ONE))
	await _pausa()
	_menu.cambiar_pestana(1)
	_ok("12 apagada: «pagina» suena y el contenido no se desplaza", Sfx.veces("pagina") == 1 and is_equal_approx(_menu._cuerpo.position.x, MenuPestanas.CUERPO_POS.x))
	_menu.cambiar_pestana(0)
	Sfx.vaciar_registro()
	Estado.i().oro = 250
	Estado.i().cambiado.emit()
	_ok("12 apagada: sube el oro con «moneda» pero sin contar", Sfx.veces("moneda") == 1 and _menu._oro.text == "250", _menu._oro.text)
	# El destello de la jugadora y el pulso de la barra.
	_j.vida = 40.0
	_j._t_beber = 0.0
	_hud.consumibles.equipar("pocion")
	await _pausa()
	_hud._input(_tecla_ev(KEY_Q))
	_ok("12 apagada: (con el menú abierto el juego está en pausa: Q no bebe)", _j._t_beber <= 0.0)
	_menu.cerrar()
	await avanzar(12)
	Sfx.vaciar_registro()
	await _pausa()
	_hud._input(_tecla_ev(KEY_Q))
	_ok("12 apagada: bebe y suena «pocion»", _j._t_beber > 0.0 and Sfx.veces("pocion") == 1)
	var n: int = 0
	while _j._t_beber > 0.0 and n < 120:
		await process_frame
		n += 1
	var m: StandardMaterial3D = _j.pj._materiales[0] as StandardMaterial3D
	_ok("12 apagada: suena «pocion_fin»", Sfx.veces("pocion_fin") == 1)
	_ok("12 apagada: la jugadora no destella en verde", _j._emision_destello_beber.is_empty() and not _viva(_j._tw_destello_beber) and not (m.emission_enabled and m.emission.is_equal_approx(Jugador3D.COLOR_DESTELLO_BEBER)))
	_ok("12 apagada: la barra de vida no pulsa", is_equal_approx(_hud._vida.pulso_t, 0.0))
	Sensacion3D.ACTIVA = true


# --- 13 · el libro abierto ----------------------------------------------------------------------------------------------
func _caso_libro() -> void:
	_menu.cerrar()
	await avanzar(12)
	Sfx.vaciar_registro()
	lanzador.libro.set("is_open", true)
	_ok("13 el libro cuenta como abierto", lanzador.libro_abierto())
	await _pausa()
	_menu._input(_tecla_ev(KEY_I))
	_ok("13 con el libro abierto, I no abre la mochila", not _menu.abierta and not paused and Sfx.veces("bolsa") == 0)
	_menu._input(_tecla_ev(KEY_J))
	_ok("13 ... ni la J abre las misiones", not _menu.abierta and Sfx.veces("libro_abre") == 0)
	lanzador.libro.set("is_open", false)
	await _pausa()
	_menu._input(_tecla_ev(KEY_J))
	_ok("13 cerrado el libro, J abre Misiones con «libro_abre» (no con «bolsa»)", _menu.abierta and _menu.pestana_id() == "misiones" and Sfx.veces("libro_abre") == 1 and Sfx.veces("bolsa") == 0, str(Sfx.CONTEO))
	await _pausa()
	_menu._input(_tecla_ev(KEY_J))
	_ok("13 J otra vez cierra con «libro_cierra»", not _menu.abierta and Sfx.veces("libro_cierra") == 1, str(Sfx.CONTEO))
	await avanzar(12)
	await _pausa()
	_menu._input(_tecla_ev(KEY_I))
	_ok("13 y con el libro cerrado I abre otra vez", _menu.abierta)
	_menu.cerrar()
	await avanzar(12)


# --- 14 · audio ---------------------------------------------------------------------------------------------------------
func _caso_audio() -> void:
	for nombre in ["bolsa", "pocion", "pocion_fin", "recoger", "golpe_ui", "comprar", "ui_tick", "ui_equipar", "moneda", "no_puedes"]:
		var cfg: Dictionary = Sfx.CATALOGO.get(nombre, {})
		_ok("14 «%s» está en el catálogo y su archivo carga" % nombre, not cfg.is_empty() and load(Sfx.CARPETA + String((cfg["f"] as Array)[0])) is AudioStream)
	_ok("14 ui_tick: −20 dB, tono ±4 %", is_equal_approx(float(Sfx.CATALOGO["ui_tick"]["db"]), -20.0) and is_equal_approx(float(Sfx.CATALOGO["ui_tick"]["tono"]), 0.04))
	_ok("14 ui_equipar: −12 dB", is_equal_approx(float(Sfx.CATALOGO["ui_equipar"]["db"]), -12.0))
	_ok("14 pocion_fin: la poción con tono +15 %", Sfx.CATALOGO["pocion_fin"]["f"] == Sfx.CATALOGO["pocion"]["f"] and is_equal_approx(float(Sfx.CATALOGO["pocion_fin"]["pitch"]), 1.15))
	_ok("14 el bus «Interfaz» existe (play_ui lo crea) y envía a Master", AudioServer.get_bus_index(Sfx.BUS_INTERFAZ) >= 0 and AudioServer.get_bus_send(AudioServer.get_bus_index(Sfx.BUS_INTERFAZ)) == &"Master")
	Sfx.vaciar_registro()
	OS.delay_msec(Sfx.VEDA_MS + 30)
	Sonidos.play(null, "recoger")
	_ok("14 «Sonidos» delega en Sfx.play_ui (sin origen)", Sfx.veces("recoger") == 1, str(Sfx.CONTEO))
	OS.delay_msec(Sfx.VEDA_MS + 30)
	Sonidos.play(null, "golpe")
	_ok("14 el alias «golpe» va a «golpe_ui»", Sfx.veces("golpe_ui") == 1, str(Sfx.CONTEO))
	OS.delay_msec(Sfx.VEDA_MS + 30)
	Sfx.play_ui("ui_tick")
	Sfx.play_ui("ui_tick")
	_ok("14 la veda de 70 ms sigue valiendo para play_ui (dos tics seguidos = 1)", Sfx.veces("ui_tick") == 1, str(Sfx.CONTEO))
	Sfx.play_ui("no_existe")
	_ok("14 un nombre que no existe no rompe nada", true)
