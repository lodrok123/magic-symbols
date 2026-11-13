extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, TAREA D (1/11; presentacion/sensacion_3d.gd `ping_debil` / `golpe_sordo`, enemigos/combate_3d.gd `golpe`): el ping de debilidad.
## Sobre la escena real del Bosque, con --fixed-fps 30 y `Sfx.REGISTRAR` (headless no se oye nada):
##   1 golpe a su debilidad: suena `ping_debil` y la capa «FlashDebil» (blanco al ALFA_FLASH_DEBIL) está visible UN fotograma y oculta al siguiente;
##   2 golpe normal: ni ping, ni sordo, ni flash;
##   3 golpe a lo que resiste: `golpe_sordo`, sin ping y sin flash;
##   4 cuatro débiles golpeados en el mismo fotograma: UN flash (veda de 120 ms) y cuatro peticiones de ping; `Sfx` tiene su propia veda de 70 ms por nombre, así que suena UNA vez
##     (documentado: un área sobre un grupo débil suena un solo ping, no una ráfaga); pasada la veda de 120 ms, otro golpe vuelve a destellar;
##   5 `ACTIVA` = false: sin flash, pero los sonidos (ping y sordo) quedan;
##   6 `ALFA_FLASH_DEBIL` = 0: sin flash y con ping.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_ping_debil.gd


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	Sfx.REGISTRAR = true
	# 13/11: desde el bloque E (1324d0a5, E2, 6/11) las reacciones fuertes (aturdido del rayo, prendido del fuego…) suenan un tintineo que REUTILIZA el sonido
	# «ping_debil» con otro tono (`FeedbackReaccion3D.SONIDO`, pendiente de sonido propio). Esta prueba mide el ping de DEBILIDAD (tarea D): se apaga ese feedback.
	var feedback_antes: bool = FeedbackReaccion3D.ACTIVO
	FeedbackReaccion3D.ACTIVO = false
	await avanzar(20)
	await _caso_debil()
	await _caso_normal()
	await _caso_resiste()
	await _caso_area()
	await _caso_apagada()
	await _caso_alfa_cero()
	FeedbackReaccion3D.ACTIVO = feedback_antes
	Sfx.REGISTRAR = false
	print("COMPROBACIONES: %d" % _comprobaciones)


func _runa(el: String) -> RuneData:
	var runas: Dictionary = {"fuego": "fire", "agua": "water", "rayo": "lightning", "hielo": "ice", "tierra": "earth", "viento": "wind"}
	return load("res://nucleo/%s_rune.tres" % runas[el]) as RuneData


## Un goblin quieto con debilidad al agua y resistencia al fuego (el rayo no es ni lo uno ni lo otro).
func _bicho(c: Vector2i) -> Combate3D:
	var g: Combate3D = _goblin(c)
	g.debil = "agua"
	g.resiste = "fuego"
	return g


func _capa() -> CanvasLayer:
	return root.get_node_or_null("FlashDebil") as CanvasLayer


func _flash_visible() -> bool:
	var c: CanvasLayer = _capa()
	return c != null and c.visible


func _veces(nombre: String) -> int:
	return Sfx.veces(nombre)


## Deja pasar las vedas de reloj (70 ms del sonido, 120 ms del flash) y que la capa esté oculta.
func _pausa() -> void:
	OS.delay_msec(int(Sensacion3D.VEDA_FLASH_DEBIL * 1000.0) + 60)
	await avanzar(2)


func _golpear(g: Combate3D, el: String) -> void:
	g.on_spell_hit(_runa(el), Vector3(-1, 0, 0))


# --- 1 · débil -------------------------------------------------------------------------------------------------------
func _caso_debil() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _bicho(Vector2i(9, 33))
	await avanzar(3)
	await _pausa()
	Sfx.vaciar_registro()
	var f0: int = int(Sensacion3D.cuenta["flash_debil"])
	_golpear(g, "agua")
	_ok("1 suena `ping_debil`", _veces("ping_debil") == 1, str(Sfx.CONTEO))
	_ok("1 la capa «FlashDebil» está visible en el fotograma del golpe", _flash_visible())
	var c: CanvasLayer = _capa()
	var r: ColorRect = c.get_node("R") as ColorRect if c != null else null
	_ok("1 ... es un blanco al ALFA_FLASH_DEBIL (%.2f)" % Sensacion3D.ALFA_FLASH_DEBIL, r != null and r.color.is_equal_approx(Color(1, 1, 1, Sensacion3D.ALFA_FLASH_DEBIL)), str(r.color if r != null else null))
	_ok("1 ... a pantalla completa y por encima del juego", r != null and r.anchor_right == 1.0 and r.anchor_bottom == 1.0 and c.layer >= 20)
	await avanzar(1)
	_ok("1 y está oculta al fotograma siguiente", not _flash_visible())
	await avanzar(3)
	_ok("1 y sigue oculta", not _flash_visible())
	_ok("1 un solo flash contado", int(Sensacion3D.cuenta["flash_debil"]) == f0 + 1)
	_ok("1 no suena el sordo", _veces("golpe_sordo") == 0)
	_limpiar()
	await avanzar(3)


# --- 2 · normal ------------------------------------------------------------------------------------------------------
func _caso_normal() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _bicho(Vector2i(9, 33))
	await avanzar(3)
	await _pausa()
	Sfx.vaciar_registro()
	var f0: int = int(Sensacion3D.cuenta["flash_debil"])
	_golpear(g, "rayo")
	await avanzar(1)
	_ok("2 golpe normal (rayo): ni ping ni sordo", _veces("ping_debil") == 0 and _veces("golpe_sordo") == 0, str(Sfx.CONTEO))
	_ok("2 ... ni flash", int(Sensacion3D.cuenta["flash_debil"]) == f0 and not _flash_visible())
	var g2: Combate3D = _bicho(Vector2i(9, 35))
	g2.debil = ""
	g2.resiste = ""
	await avanzar(3)
	g2.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 0.0)
	await avanzar(1)
	_ok("2 el golpe F tampoco", _veces("ping_debil") == 0 and _veces("golpe_sordo") == 0 and int(Sensacion3D.cuenta["flash_debil"]) == f0)
	_limpiar()
	await avanzar(3)


# --- 3 · resiste -----------------------------------------------------------------------------------------------------
func _caso_resiste() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _bicho(Vector2i(9, 33))
	await avanzar(3)
	await _pausa()
	Sfx.vaciar_registro()
	var f0: int = int(Sensacion3D.cuenta["flash_debil"])
	_golpear(g, "fuego")
	_ok("3 resistente: suena `golpe_sordo`", _veces("golpe_sordo") == 1, str(Sfx.CONTEO))
	_ok("3 ... y no `ping_debil`", _veces("ping_debil") == 0)
	_ok("3 ... y sin flash", int(Sensacion3D.cuenta["flash_debil"]) == f0 and not _flash_visible())
	var db_ping: float = Sfx.db_de("ping_debil")
	var db_sordo: float = Sfx.db_de("golpe_sordo")
	_ok("3 los niveles del catálogo: ping −10 dB, sordo −12 dB", is_equal_approx(db_ping, -10.0) and is_equal_approx(db_sordo, -12.0), "%s %s" % [db_ping, db_sordo])
	_limpiar()
	await avanzar(3)


# --- 4 · área sobre cuatro débiles -----------------------------------------------------------------------------------
func _caso_area() -> void:
	_jugadora(Vector2i(11, 33))
	var bichos: Array = []
	for z in [29, 31, 35, 37]:
		bichos.append(_bicho(Vector2i(9, z)))
	await avanzar(3)
	await _pausa()
	Sfx.vaciar_registro()
	var f0: int = int(Sensacion3D.cuenta["flash_debil"])
	var p0: int = int(Sensacion3D.cuenta["ping_debil"])
	var t0: int = Time.get_ticks_msec()
	for b in bichos:
		_golpear(b, "agua")
	var ms: int = Time.get_ticks_msec() - t0
	_ok("4 cuatro golpes en %d ms (≤ 50)" % ms, ms <= 50)
	_ok("4 cuatro peticiones de ping", int(Sensacion3D.cuenta["ping_debil"]) == p0 + 4, str(int(Sensacion3D.cuenta["ping_debil"]) - p0))
	_ok("4 UN solo flash", int(Sensacion3D.cuenta["flash_debil"]) == f0 + 1, str(int(Sensacion3D.cuenta["flash_debil"]) - f0))
	_ok("4 `Sfx` aplica su veda de 70 ms por nombre: los cuatro pings son UN sonido (%d)" % _veces("ping_debil"), _veces("ping_debil") == 1)
	await avanzar(2)
	_ok("4 la capa se apagó", not _flash_visible())
	# pasada la veda de 120 ms, otro débil vuelve a destellar
	_golpear(bichos[0], "agua")
	_ok("4 dentro de la veda (< 120 ms) no hay otro flash", int(Sensacion3D.cuenta["flash_debil"]) == f0 + 1 and not _flash_visible())
	OS.delay_msec(int(Sensacion3D.VEDA_FLASH_DEBIL * 1000.0) + 30)
	await avanzar(1)
	_golpear(bichos[1], "agua")
	_ok("4 pasada la veda, otro flash", int(Sensacion3D.cuenta["flash_debil"]) == f0 + 2 and _flash_visible())
	await avanzar(1)
	_ok("4 ... de un fotograma", not _flash_visible())
	_limpiar()
	await avanzar(3)


# --- 5 · apagada -----------------------------------------------------------------------------------------------------
func _caso_apagada() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _bicho(Vector2i(9, 33))
	var h: Combate3D = _bicho(Vector2i(9, 35))
	await avanzar(3)
	await _pausa()
	Sensacion3D.ACTIVA = false
	Sfx.vaciar_registro()
	var f0: int = int(Sensacion3D.cuenta["flash_debil"])
	_golpear(g, "agua")
	_ok("5 ACTIVA = false: sin flash", int(Sensacion3D.cuenta["flash_debil"]) == f0 and not _flash_visible())
	_ok("5 ... pero el ping suena", _veces("ping_debil") == 1, str(Sfx.CONTEO))
	OS.delay_msec(Sfx.VEDA_MS + 40)
	_golpear(h, "fuego")
	_ok("5 ... y el sordo también", _veces("golpe_sordo") == 1, str(Sfx.CONTEO))
	Sensacion3D.ACTIVA = true
	_limpiar()
	await avanzar(3)


# --- 6 · alfa cero ---------------------------------------------------------------------------------------------------
func _caso_alfa_cero() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _bicho(Vector2i(9, 33))
	await avanzar(3)
	await _pausa()
	var alfa: float = Sensacion3D.ALFA_FLASH_DEBIL
	Sensacion3D.ALFA_FLASH_DEBIL = 0.0
	Sfx.vaciar_registro()
	var f0: int = int(Sensacion3D.cuenta["flash_debil"])
	_golpear(g, "agua")
	_ok("6 ALFA_FLASH_DEBIL = 0: sin flash y con ping", int(Sensacion3D.cuenta["flash_debil"]) == f0 and not _flash_visible() and _veces("ping_debil") == 1)
	Sensacion3D.ALFA_FLASH_DEBIL = alfa
	_limpiar()
	await avanzar(3)
