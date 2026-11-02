extends SceneTree
## C1 punto 1 (2/11, lote 3 de la auditoría del 24/10, cambio 1): UN SOLO RELOJ DE ESTADOS. Se MIDE contra el código de hoy lo que la auditoría denunciaba:
##   · ¿corre el reloj en el juego real? `Mundo3D._process` llama a `EstadosSuelo3D.avanzar` (arregló el 27/10, diario 304-ish): aquí se comprueba con un Mundo3D en el árbol y fotogramas de verdad.
##   · ¿tiene `DURA` valores reales? Solo `mojada` (20 s); helada, electrificada, quemada y segada NO caducan (AVISO medido, decisión de Pablo).
##   · columna `al_caducar`: lo helado con caducidad se deshiela y deja la casilla mojada (`EstadosSuelo3D.AL_CADUCAR`); mojada se seca sin más.
##   · ¿cuántos relojes de 20 s lleva el hielo? Se listan los que quedan (AVISO medido).
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_reloj_estados.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Terreno3D.estados.limpiar()
	await _reloj_del_mundo()
	_dura_y_al_caducar()
	_relojes_del_hielo()
	Terreno3D.estados.limpiar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _reloj_del_mundo() -> void:
	var m := Mundo3D.new()
	root.add_child(m)
	var c := Vector2i(4, 4)
	Terreno3D.estados.poner(c, EstadosSuelo3D.MOJADA, true)
	var antes: float = Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)
	_ok("1 un Mundo3D en el árbol procesa cada fotograma (el reloj es su _process)", m.is_processing() and Mundo3D.actual == m)
	for _i in range(5):
		await process_frame
	var despues: float = Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)
	_ok("1 con fotogramas reales la casilla mojada gasta tiempo (sin llamar a avanzar a mano)", despues < antes - 0.05 and despues > 0.0, "%.3f → %.3f s" % [antes, despues])
	# Veinte segundos de partida a golpe de _process: la casilla se seca sola.
	for _i in range(210):
		m._process(0.1)
	_ok("1 a los 20 s de reloj del mundo la casilla mojada se seca sola", not Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA), str(Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)))
	# Fuera del árbol (sin Mundo3D) NO corre: es el reloj del nivel vivo, no un global.
	m.queue_free()
	await process_frame
	Terreno3D.estados.poner(c, EstadosSuelo3D.MOJADA, true)
	var q0: float = Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)
	for _i in range(5):
		await process_frame
	_ok("1 sin Mundo3D en el árbol nadie avanza el reloj (por eso las pruebas lo llaman a mano)", is_equal_approx(Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA), q0))
	Terreno3D.estados.limpiar()


func _dura_y_al_caducar() -> void:
	var d: Dictionary = EstadosSuelo3D.DURA
	_ok("2 DURA mojada = 20 s (lo mismo que AguaSim3D.SECA_EN)", is_equal_approx(float(d["mojada"]), 20.0) and is_equal_approx(float(d["mojada"]), AguaSim3D.SECA_EN))
	var sin_caducar: PackedStringArray = []
	for k in d.keys():
		if float(d[k]) <= 0.0:
			sin_caducar.append(String(k))
	_ok("2 MEDIDO (AVISO, decisión de Pablo): no caducan solos %s" % str(sin_caducar), sin_caducar.size() == 4 and sin_caducar.has("helada") and sin_caducar.has("quemada") and sin_caducar.has("electrificada") and sin_caducar.has("segada"))

	var e := EstadosSuelo3D.new()
	var c := Vector2i(2, 2)
	e.poner(c, EstadosSuelo3D.HELADA, true)
	e.avanzar(1000.0)
	_ok("3 una helada sin caducidad no caduca nunca (como hoy)", e.tiene(c, EstadosSuelo3D.HELADA))
	# al_caducar: helada con caducidad → deshiela y deja mojada (con la caducidad de mojada).
	var avisos: Array = []
	e.cambio.connect(func(p: Vector2i, est: String, si: bool) -> void: avisos.append([est, si]))
	e.poner(c, EstadosSuelo3D.HELADA, false)
	e.poner(c, EstadosSuelo3D.HELADA, true, 1.0, 2.0)
	avisos.clear()
	e.avanzar(1.9)
	_ok("3 la helada con caducidad sigue helada antes de tiempo", e.tiene(c, EstadosSuelo3D.HELADA) and not e.tiene(c, EstadosSuelo3D.MOJADA))
	e.avanzar(0.2)
	_ok("3 al_caducar: la helada se deshiela y la casilla queda MOJADA (con sus 20 s)", not e.tiene(c, EstadosSuelo3D.HELADA) and e.tiene(c, EstadosSuelo3D.MOJADA) and absf(e.queda(c, EstadosSuelo3D.MOJADA) - 20.0) < 0.5 and avisos.size() == 2, str(avisos))
	e.avanzar(25.0)
	_ok("3 y esa mojada se seca sin más (mojada no tiene fila en al_caducar)", not e.tiene(c, EstadosSuelo3D.MOJADA) and not e.tiene(c, EstadosSuelo3D.HELADA))
	# La escarcha: al deshelar deja de ser escarcha.
	e.aplicar(Vector2i(3, 3), "frio")
	_ok("3 el suelo que se hiela es escarcha", e.es_escarcha(Vector2i(3, 3)))


func _relojes_del_hielo() -> void:
	# AVISO medido: el hielo de 20 s lo cuentan varios sitios. Se anotan para que quien los junte sepa cuántos hay.
	var relojes: Dictionary = {
		"Lanzador3D.DURACION_HIELO (cuenta atrás por casilla; deshiela, quita la placa y suelta vapor; respeta hielo_permanente)": Lanzador3D.DURACION_HIELO,
		"AguaSim3D.DURA_HIELO (el hielo de agua de la simulación)": AguaSim3D.DURA_HIELO,
		"Hierba3D.ESCARCHA_S (solo aspecto: la escarcha de la hierba)": Hierba3D.ESCARCHA_S,
		"EstadosSuelo3D.DURA[helada] (el reloj oficial: hoy 0 = no caduca)": EstadosSuelo3D.DURA["helada"],
	}
	var de_20: int = 0
	for k in relojes.keys():
		print("      reloj del hielo · %s = %s s" % [k, str(relojes[k])])
		if is_equal_approx(float(relojes[k]), 20.0):
			de_20 += 1
	_ok("4 MEDIDO (AVISO): el hielo lleva 3 relojes de 20 s y el oficial a 0 (el Lanzador es del dueño de la magia: no se toca aquí)", de_20 == 3 and is_equal_approx(float(EstadosSuelo3D.DURA["helada"]), 0.0), "%d relojes de 20 s" % de_20)
