extends "res://herramientas/escenario_base.gd"
## GAMEFEEL, TAREAS S2 y U5-U8 (31/10): rareza, cofres, pista Ãƒâ€šÃ‚Â«[E]Ãƒâ€šÃ‚Â», mochila llena, bÃƒÆ’Ã‚Â¡lsamo y barras con peso. Nada cambia reglas.
##   S2  AvisoObjeto.mostrar suena segÃƒÆ’Ã‚Âºn la calidad (comÃƒÆ’Ã‚Âºn Ãƒâ€šÃ‚Â«recogerÃƒâ€šÃ‚Â», ÃƒÆ’Ã‚Â©pico Ãƒâ€šÃ‚Â«logro_brilloÃƒâ€šÃ‚Â», legendario Ãƒâ€šÃ‚Â«logro_aciertoÃƒâ€šÃ‚Â»; Ãƒâ€šÃ‚Â«raroÃƒâ€šÃ‚Â» ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Ãƒâ€šÃ‚Â«logro_pistaÃƒâ€šÃ‚Â» queda en la tabla aunque la calidad aÃƒÆ’Ã‚Âºn no exista);
##       recolectable_3d y botin_objeto_3d ya no suenan por su cuenta (una sola vez en total); Ãƒâ€šÃ‚Â«explosionÃƒâ€šÃ‚Â» y Ãƒâ€šÃ‚Â«piraÃƒâ€šÃ‚Â» a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢6 dB.
##   U5  cofre_3d.gd: Ãƒâ€šÃ‚Â«creakÃƒâ€šÃ‚Â» al anticipar y Ãƒâ€šÃ‚Â«cofre_tapaÃƒâ€šÃ‚Â» (ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢10 dB) al girar la tapa; los cofres de las ramas del Bosque 01 avisan el logro Ãƒâ€šÃ‚Â«cofre_abiertoÃƒâ€šÃ‚Â».
##   U6  PistaProximidad + PistaInteraccion: Ãƒâ€šÃ‚Â«[E] Recoger / Hablar / AbrirÃƒâ€šÃ‚Â» al acercarse y fuera al alejarse; con ACTIVA = false tambiÃƒÆ’Ã‚Â©n sale (es informaciÃƒÆ’Ã‚Â³n).
##   U7  Ãƒâ€šÃ‚Â«no_puedesÃƒâ€šÃ‚Â» (ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢14) con la mochila llena (recolectable, botÃƒÆ’Ã‚Â­n, pociÃƒÆ’Ã‚Â³n del suelo de Jugabilidad3D); el bÃƒÆ’Ã‚Â¡lsamo suena Ãƒâ€šÃ‚Â«escudo_golpeÃƒâ€šÃ‚Â» al absorber y Ãƒâ€šÃ‚Â«escudo_rotoÃƒâ€šÃ‚Â» al agotarse.
##   U8  BarraHud: franja fantasma + flash al perder vida, pulso al curar; el frasco destella al recargarse con tÃƒÆ’Ã‚Â³nico. Con ACTIVA = false nada de eso, pero los sonidos sÃƒÆ’Ã‚Â­.
## Los sonidos se miran con `Sfx.REGISTRAR` / `CONTEO` (headless no se oye nada).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_interfaz_u5_u8.gd


## Un Lanzador3D de mentira: lo que miran AvisoObjeto, Recolectable3D y Cofre3D (grupo Ãƒâ€šÃ‚Â«spellcasterÃƒâ€šÃ‚Â», `jugador`, `avisar`, `_aviso`).
class FakeLanz extends Node:
	var jugador: Node3D = null
	var _aviso: Label = Label.new()
	var avisos: Array = []

	func avisar(txt: String, _c: Color = Color.WHITE, _b: Color = Color.WHITE, _s: float = 1.0) -> void:
		avisos.append(txt)


## La maqueta de mentira de las escenas de reglas: solo guarda a la jugadora y sabe dar el centro de una celda.
class FakeM extends Node:
	var _jugador: Pj3D = null

	func _centro_celda(_c: Vector2i, y: float) -> Vector3:
		return Vector3(0.0, y, 0.0)


class JugadorFalso extends Node:
	var vida: float = 100.0
	var muerto: bool = false
	var bloqueado: bool = false
	var tinta: Tinta = null
	var mundo: Node = null
	var lanz: Node = null

	func curar(c: float) -> void:
		vida = minf(Estado.i().vida_max, vida + c)

	func usar_pocion() -> bool:
		return true


func _pausa() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 40)                    # la veda cuenta con el reloj de pared
	await avanzar(1)


func _ultimo(nombre: String) -> Dictionary:
	for i in range(Sfx.ULTIMOS.size() - 1, -1, -1):
		if String(Sfx.ULTIMOS[i]["nombre"]) == nombre:
			return Sfx.ULTIMOS[i]
	return {}


func _db(nombre: String) -> float:
	return float(_ultimo(nombre).get("db", 99.0))


func _total_sonidos() -> int:
	var n: int = 0
	for k in Sfx.CONTEO:
		n += int(Sfx.CONTEO[k])
	return n


func _tecla_q() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	return ev


## Un objeto de DATOS de la calidad pedida ("" si no hay).
func _objeto_de_calidad(cal: String) -> String:
	var ids: Array = Objetos.DATOS.keys()
	ids.sort()
	for id in ids:
		if Objetos.calidad(String(id)) == cal:
			return String(id)
	return ""


func _llenar_mochila() -> void:
	Estado.nuevo()
	var n: int = 0
	while Estado.i().agregar("seta", 99) > 0 and n < 2000:
		n += 1
	var k: int = 0
	for id in ["baya", "flor", "raiz", "alga", "musgo", "pocion"]:
		while Estado.i().agregar(String(id), 99) > 0 and k < 2000:
			k += 1


func _lanz(con_jugador: bool = true) -> FakeLanz:
	var lz := FakeLanz.new()
	lz.add_to_group("spellcaster")
	root.add_child(lz)
	if con_jugador:
		var j := Node3D.new()
		root.add_child(j)
		lz.jugador = j
	return lz


func _quitar_lanz(lz: FakeLanz) -> void:
	if lz.jugador != null and is_instance_valid(lz.jugador):
		lz.jugador.free()
	lz.free()


func _escenario() -> void:
	Sfx.REGISTRAR = true
	Sfx.AJUSTES.clear()
	Sfx.vaciar_registro()
	Sensacion3D.ACTIVA = true
	PistaProximidad.reiniciar()
	Terreno3D.datos_propios = true                      # un suelo de mentira: las plantas sueltas preguntan por la letra de su casilla
	Terreno3D.mapa = PackedStringArray(["........", "........", "........", "........", "........"])

	await _s2_calidad()
	await _u5_cofres()
	await _u6_pista()
	await _u7_llena_y_balsamo()
	await _u8_barras()
	Terreno3D.datos_propios = false
	Terreno3D.mapa = PackedStringArray()
	await _u6_escena()

	Sensacion3D.ACTIVA = true
	Repertoire.reset_to_p0()
	Sfx.AJUSTES.clear()
	PistaProximidad.reiniciar()
	Sfx.REGISTRAR = false


# ---------------------------------------------------------------------------------------------------------------------
#  S2 Ãƒâ€šÃ‚Â· rareza y bajadas
# ---------------------------------------------------------------------------------------------------------------------

func _s2_calidad() -> void:
	_ok("S2 Ãƒâ€šÃ‚Â«explosionÃƒâ€šÃ‚Â» baja a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢6 dB", is_equal_approx(float(Sfx.CATALOGO["explosion"]["db"]), -6.0))
	_ok("S2 Ãƒâ€šÃ‚Â«piraÃƒâ€šÃ‚Â» baja a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢6 dB", is_equal_approx(float(Sfx.CATALOGO["pira"]["db"]), -6.0))
	_ok("S2 Ãƒâ€šÃ‚Â«cofre_tapaÃƒâ€šÃ‚Â» estÃƒÆ’Ã‚Â¡ en el catÃƒÆ’Ã‚Â¡logo a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢10 dB y su wav existe", Sfx.CATALOGO.has("cofre_tapa") and is_equal_approx(float(Sfx.CATALOGO["cofre_tapa"]["db"]), -10.0) and ResourceLoader.exists(Sfx.CARPETA + "cofre_tapa.wav"))
	var tabla: Dictionary = AvisoObjeto.SONIDO_CALIDAD
	var nombres: Dictionary = {}
	for k in tabla:
		nombres[String(tabla[k])] = true
	_ok("S2 la tabla tiene cuatro calidades con cuatro sonidos distintos (comÃƒÆ’Ã‚Âºn, raro, ÃƒÆ’Ã‚Â©pico, legendario)", tabla.size() == 4 and nombres.size() == 4, str(tabla))
	_ok("S2 comÃƒÆ’Ã‚Âºn Ãƒâ€šÃ‚Â«recogerÃƒâ€šÃ‚Â», raro Ãƒâ€šÃ‚Â«logro_pistaÃƒâ€šÃ‚Â», ÃƒÆ’Ã‚Â©pico Ãƒâ€šÃ‚Â«logro_brilloÃƒâ€šÃ‚Â», legendario Ãƒâ€šÃ‚Â«logro_aciertoÃƒâ€šÃ‚Â»",
		tabla["comun"] == "recoger" and tabla["raro"] == "logro_pista" and tabla["epico"] == "logro_brillo" and tabla["legendario"] == "logro_acierto")
	var todos_en_catalogo: bool = true
	for k in tabla:
		todos_en_catalogo = todos_en_catalogo and Sfx.CATALOGO.has(String(tabla[k]))
	_ok("S2 los cuatro sonidos estÃƒÆ’Ã‚Â¡n en el catÃƒÆ’Ã‚Â¡logo", todos_en_catalogo)

	var lz: FakeLanz = _lanz()
	for cal in [Objetos.CALIDAD_COMUN, Objetos.CALIDAD_EPICO, Objetos.CALIDAD_LEGENDARIO]:
		var id: String = _objeto_de_calidad(String(cal))
		_ok("S2 hay un objeto de calidad %s para probar" % cal, id != "")
		if id == "":
			continue
		Sfx.vaciar_registro()
		await _pausa()
		AvisoObjeto.mostrar(lz, id, 1)
		var esperado: String = String(tabla[cal])
		_ok("S2 %s (%s): suena Ãƒâ€šÃ‚Â«%sÃƒâ€šÃ‚Â» y solo ese" % [cal, id, esperado], Sfx.veces(esperado) == 1 and _total_sonidos() == 1, str(Sfx.CONTEO))
	_ok("S2 sin lanzador el aviso no suena", true)
	Sfx.vaciar_registro()
	await _pausa()
	AvisoObjeto.mostrar(null, "seta", 1)
	_ok("S2 sin lanzador (nadie ve el aviso) no suena nada", _total_sonidos() == 0, str(Sfx.CONTEO))

	# Una planta comÃƒÆ’Ã‚Âºn: UN sonido en total (Ãƒâ€šÃ‚Â«recogerÃƒâ€šÃ‚Â»), nada de logro_brillo.
	Estado.nuevo()
	var r := Recolectable3D.new()
	r.preparar(Vector2i(2, 2), "", 0.0, null, "seta")
	root.add_child(r)
	await avanzar(1)
	Sfx.vaciar_registro()
	await _pausa()
	var cogida: bool = r.recoger()
	_ok("S2 planta comÃƒÆ’Ã‚Âºn: se coge", cogida)
	_ok("S2 planta comÃƒÆ’Ã‚Âºn: suena UNA vez Ãƒâ€šÃ‚Â«recogerÃƒâ€šÃ‚Â» y nada mÃƒÆ’Ã‚Â¡s (ni logro_brillo)", Sfx.veces("recoger") == 1 and Sfx.veces("logro_brillo") == 0 and _total_sonidos() == 1, str(Sfx.CONTEO))
	r.free()

	# El botÃƒÆ’Ã‚Â­n del suelo, lo mismo.
	var mundo := Node3D.new()
	root.add_child(mundo)
	var b: BotinObjeto3D = BotinObjeto3D.soltar(mundo, null, "baya", 1, Vector3.ZERO)
	await avanzar(1)
	Sfx.vaciar_registro()
	await _pausa()
	var cogido: bool = b.recoger()
	_ok("S2 botÃƒÆ’Ã‚Â­n comÃƒÆ’Ã‚Âºn: se coge", cogido)
	_ok("S2 botÃƒÆ’Ã‚Â­n comÃƒÆ’Ã‚Âºn: suena UNA vez Ãƒâ€šÃ‚Â«recogerÃƒâ€šÃ‚Â» y nada mÃƒÆ’Ã‚Â¡s", Sfx.veces("recoger") == 1 and Sfx.veces("logro_brillo") == 0 and _total_sonidos() == 1, str(Sfx.CONTEO))

	# Con ACTIVA = false los sonidos siguen.
	Sensacion3D.ACTIVA = false
	Sfx.vaciar_registro()
	await _pausa()
	AvisoObjeto.mostrar(lz, "seta", 1)
	_ok("S2 ACTIVA=false: el aviso comÃƒÆ’Ã‚Âºn sigue sonando Ãƒâ€šÃ‚Â«recogerÃƒâ€šÃ‚Â»", Sfx.veces("recoger") == 1, str(Sfx.CONTEO))
	Sensacion3D.ACTIVA = true
	mundo.free()
	_quitar_lanz(lz)


# ---------------------------------------------------------------------------------------------------------------------
#  U5 Ãƒâ€šÃ‚Â· cofres
# ---------------------------------------------------------------------------------------------------------------------

func _cofre_sintetico() -> Node3D:
	var pieza := Node3D.new()
	var asa := Node3D.new()
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "cofre_cuerpo"
	cuerpo.mesh = BoxMesh.new()
	var tapa := Node3D.new()
	tapa.name = "cofre_tapa"
	asa.add_child(cuerpo)
	asa.add_child(tapa)
	pieza.add_child(asa)
	return pieza


func _u5_cofres() -> void:
	var pieza: Node3D = _cofre_sintetico()
	root.add_child(pieza)
	await avanzar(2)
	var c: Cofre3D = Cofre3D.en(pieza)
	_ok("5 el cofre sintÃƒÆ’Ã‚Â©tico tiene controlador y estÃƒÆ’Ã‚Â¡ cerrado", c != null and c.estado_nombre() == &"cerrado")
	if c == null:
		return
	Sfx.vaciar_registro()
	await _pausa()
	var abre: bool = c.abrir()
	_ok("5 abrir(): arranca", abre)
	_ok("5 al anticipar suena Ãƒâ€šÃ‚Â«creakÃƒâ€šÃ‚Â» (y aÃƒÆ’Ã‚Âºn no la tapa)", Sfx.veces("creak") == 1 and Sfx.veces("cofre_tapa") == 0, str(Sfx.CONTEO))
	await avanzar(int(ceil(Cofre3D.T_ANTICIPA * 30.0)) + 6)
	_ok("5 al girar la tapa suena Ãƒâ€šÃ‚Â«cofre_tapaÃƒâ€šÃ‚Â» a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢10 dB", Sfx.veces("cofre_tapa") == 1 and is_equal_approx(_db("cofre_tapa"), -10.0), str(Sfx.CONTEO))
	_ok("5 y Ãƒâ€šÃ‚Â«creakÃƒâ€šÃ‚Â» no se repite", Sfx.veces("creak") == 1)
	await avanzar(40)
	_ok("5 el cofre acaba abierto", c.esta_abierto())
	pieza.free()

	# Los cofres de las ramas del Bosque 01 avisan el logro como los del puzle.
	var mundo := Mundo3D.new()
	root.add_child(mundo)
	await avanzar(1)
	var vistos: Array = []
	mundo.logro.connect(func(nombre: String, _p: Vector3, _n: Node) -> void: vistos.append(nombre))
	Estado.nuevo()
	Misiones.nuevo()
	var b01: Node = load("res://escenas/bosque_01_3d.gd").new()
	var cofre := Node3D.new()
	root.add_child(cofre)
	b01._cofres[2] = cofre
	b01.call("_al_abrir_cofre", 2)
	_ok("5 Bosque 01: el cofre de una rama avisa Ãƒâ€šÃ‚Â«cofre_abiertoÃƒâ€šÃ‚Â»", vistos.count("cofre_abierto") == 1, str(vistos))
	b01.call("_al_abrir_cofre", 2)
	_ok("5 Bosque 01: el botÃƒÆ’Ã‚Â­n (y el aviso) se da una sola vez", vistos.count("cofre_abierto") == 1, str(vistos))
	b01.free()
	cofre.free()
	mundo.free()
	await avanzar(1)


# ---------------------------------------------------------------------------------------------------------------------
#  U6 Ãƒâ€šÃ‚Â· la pista Ãƒâ€šÃ‚Â«[E]Ãƒâ€šÃ‚Â»
# ---------------------------------------------------------------------------------------------------------------------

func _u6_pista() -> void:
	PistaProximidad.reiniciar()
	Estado.nuevo()
	var lz: FakeLanz = _lanz()
	var r := Recolectable3D.new()
	r.preparar(Vector2i(3, 3), "", 0.0, null, "seta")
	root.add_child(r)
	r.global_position = Vector3(10.0, 0.0, 10.0)
	lz.jugador.global_position = Vector3(10.0 + Recolectable3D.ALCANCE * 0.5, 0.0, 10.0)
	await avanzar(4)
	var pista: PistaInteraccion = PistaProximidad.pista()
	_ok("6 el gestor se monta solo", pista != null)
	if pista == null:
		return
	_ok("6 recolectable a mano: la pista dice Ãƒâ€šÃ‚Â«[E] RecogerÃƒâ€šÃ‚Â»", PistaProximidad.accion_actual() == "Recoger" and pista.visible and pista.texto_accion() == "Recoger" and pista.texto_tecla() == "E", PistaProximidad.accion_actual())
	await avanzar(8)
	_ok("6 y se ve del todo (fundido hecho)", pista.modulate.a > 0.95, str(pista.modulate.a))

	lz.jugador.global_position = Vector3(10.0 + Recolectable3D.ALCANCE + 4.0, 0.0, 10.0)
	await avanzar(4)
	_ok("6 al alejarse deja de ofrecerse", PistaProximidad.accion_actual() == "")
	await avanzar(int(ceil(PistaInteraccion.T_FUNDIDO_S * 30.0)) + 4)
	_ok("6 y la pista se esconde", not pista.visible, "visible=%s a=%.2f" % [pista.visible, pista.modulate.a])

	# InformaciÃƒÆ’Ã‚Â³n, no sensaciÃƒÆ’Ã‚Â³n: con ACTIVA = false tambiÃƒÆ’Ã‚Â©n aparece.
	Sensacion3D.ACTIVA = false
	lz.jugador.global_position = Vector3(10.0 + 0.4, 0.0, 10.0)
	await avanzar(4)
	_ok("6 ACTIVA=false: la pista aparece igual", PistaProximidad.accion_actual() == "Recoger" and pista.visible)
	Sensacion3D.ACTIVA = true

	# Al interactuar (coger) desaparece.
	var cogida: bool = r.recoger()
	await avanzar(4)
	_ok("6 al cogerla la pista ya no la ofrece", cogida and PistaProximidad.accion_actual() == "")
	await avanzar(int(ceil(PistaInteraccion.T_FUNDIDO_S * 30.0)) + 4)
	_ok("6 y se esconde", not pista.visible)
	r.free()

	# Con dos plantas a mano solo la mÃƒÆ’Ã‚Â¡s cercana ofrece (como la E).
	var r1 := Recolectable3D.new()
	r1.preparar(Vector2i(3, 3), "", 0.0, null, "seta")
	var r2 := Recolectable3D.new()
	r2.preparar(Vector2i(4, 3), "", 0.0, null, "seta")
	root.add_child(r1)
	root.add_child(r2)
	r1.global_position = Vector3(10.0, 0.0, 10.0)
	r2.global_position = Vector3(11.0, 0.0, 10.0)
	lz.jugador.global_position = Vector3(10.2, 0.0, 10.0)
	_ok("6 dos a mano: la mÃƒÆ’Ã‚Â¡s cercana ofrece, la otra no", r1.accion_pista() == "Recoger" and r2.accion_pista() == "")
	r1.free()
	r2.free()

	# NPC del Bosque 3D (escena de reglas), con la maqueta de mentira.
	var fm := FakeM.new()
	root.add_child(fm)
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.position = Vector3(50.0, 0.0, 50.0)
	fm._jugador = pj
	var npc := Pj3D.new()
	root.add_child(npc)
	npc.position = Vector3(50.0 + Bosque3D.ALCANCE_HABLAR * 0.5, 0.0, 50.0)
	var bosque := Bosque3D.new()
	bosque.m = fm
	bosque.process_mode = Node.PROCESS_MODE_DISABLED
	bosque.registrar_npc("guardabosques", npc)
	root.add_child(bosque)
	bosque.add_to_group(PistaProximidad.GRUPO)
	await avanzar(4)
	_ok("6 NPC a mano (Bosque3D): Ãƒâ€šÃ‚Â«[E] HablarÃƒâ€šÃ‚Â»", PistaProximidad.accion_actual() == "Hablar" and pista.visible, PistaProximidad.accion_actual())
	bosque._t_oferta = 5.0
	await avanzar(3)
	_ok("6 con la oferta del guardabosques en pie, la E compra: Ãƒâ€šÃ‚Â«[E] ComprarÃƒâ€šÃ‚Â»", PistaProximidad.accion_actual() == "Comprar", PistaProximidad.accion_actual())
	bosque._t_oferta = 0.0
	bosque._t_habla = 2.0
	await avanzar(3)
	_ok("6 mientras habla (ha interactuado) la pista se aparta", PistaProximidad.accion_actual() == "")
	bosque._t_habla = 0.0
	pj.position = Vector3(50.0 + Bosque3D.ALCANCE_HABLAR + 3.0, 0.0, 50.0)
	await avanzar(3)
	_ok("6 NPC lejos: sin pista", PistaProximidad.accion_actual() == "")
	await avanzar(int(ceil(PistaInteraccion.T_FUNDIDO_S * 30.0)) + 4)
	_ok("6 NPC lejos: pista escondida", not pista.visible)

	# Jugabilidad3D: el mismo contrato.
	bosque.free()
	var jug := Jugabilidad3D.new()
	jug.m = fm
	jug.process_mode = Node.PROCESS_MODE_DISABLED
	jug.registrar_npc("librera", npc)
	root.add_child(jug)
	jug.add_to_group(PistaProximidad.GRUPO)
	pj.position = Vector3(50.0, 0.0, 50.0)
	await avanzar(4)
	_ok("6 NPC a mano (Jugabilidad3D): Ãƒâ€šÃ‚Â«[E] HablarÃƒâ€šÃ‚Â»", PistaProximidad.accion_actual() == "Hablar", PistaProximidad.accion_actual())
	jug.free()

	# Cofres y alquimista del Bosque 01.
	var b01: Node = load("res://escenas/bosque_01_3d.gd").new()
	b01.m = fm
	var pieza: Node3D = _cofre_sintetico()
	root.add_child(pieza)
	pieza.position = Vector3(50.0 + 1.0, 0.0, 50.0)
	await avanzar(2)
	b01._cofres[2] = pieza
	root.add_child(b01)
	b01.remove_from_group(PistaProximidad.GRUPO)
	b01.add_to_group(PistaProximidad.GRUPO)
	_ok("6 Bosque 01: cofre cerrado a mano ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Ãƒâ€šÃ‚Â«AbrirÃƒâ€šÃ‚Â»", b01.call("accion_pista") == "Abrir", str(b01.call("accion_pista")))
	b01._entregado[2] = true
	_ok("6 Bosque 01: cofre ya entregado ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ nada", b01.call("accion_pista") == "")
	b01._entregado[2] = false
	pj.position = Vector3(50.0 + 20.0, 0.0, 50.0)
	_ok("6 Bosque 01: cofre lejos ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ nada", b01.call("accion_pista") == "")
	b01._cofres[2] = null
	pj.position = Vector3(50.0, 0.0, 50.0)
	b01._npc = npc
	npc.position = Vector3(50.5, 0.0, 50.0)
	_ok("6 Bosque 01: el alquimista a mano ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Ãƒâ€šÃ‚Â«HablarÃƒâ€šÃ‚Â»", b01.call("accion_pista") == "Hablar")
	b01._t_habla = 2.0
	_ok("6 Bosque 01: mientras habla se aparta", b01.call("accion_pista") == "")
	b01._npc = null
	b01.free()
	pieza.free()
	pj.free()
	npc.free()
	fm.free()
	_quitar_lanz(lz)
	await avanzar(3)
	PistaProximidad.reiniciar()


# ---------------------------------------------------------------------------------------------------------------------
#  U7 Ãƒâ€šÃ‚Â· mochila llena y bÃƒÆ’Ã‚Â¡lsamo
# ---------------------------------------------------------------------------------------------------------------------

func _u7_llena_y_balsamo() -> void:
	_llenar_mochila()
	_ok("7 la mochila estÃƒÆ’Ã‚Â¡ llena para la prueba", Estado.i().agregar("seta", 1) <= 0)
	var lz: FakeLanz = _lanz()

	# Planta del suelo.
	var r := Recolectable3D.new()
	r.preparar(Vector2i(2, 2), "", 0.0, null, "seta")
	root.add_child(r)
	await avanzar(1)
	Sfx.vaciar_registro()
	await _pausa()
	var cogida: bool = r.recoger()
	_ok("7 recolectable con la mochila llena: no se coge y avisa", not cogida and lz.avisos.has("Mochila llena"))
	_ok("7 recolectable: suena Ãƒâ€šÃ‚Â«no_puedesÃƒâ€šÃ‚Â» a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢14 dB (y nada mÃƒÆ’Ã‚Â¡s)", Sfx.veces("no_puedes") == 1 and is_equal_approx(_db("no_puedes"), -14.0) and _total_sonidos() == 1, str(Sfx.CONTEO))
	r.free()

	# BotÃƒÆ’Ã‚Â­n del suelo: una sola vez por pieza aunque reintente.
	var mundo := Node3D.new()
	root.add_child(mundo)
	var b: BotinObjeto3D = BotinObjeto3D.soltar(mundo, null, "seta", 1, Vector3.ZERO)
	await avanzar(1)
	Sfx.vaciar_registro()
	await _pausa()
	var cogido: bool = b.recoger()
	_ok("7 botÃƒÆ’Ã‚Â­n con la mochila llena: no se coge", not cogido)
	_ok("7 botÃƒÆ’Ã‚Â­n: suena Ãƒâ€šÃ‚Â«no_puedesÃƒâ€šÃ‚Â» a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢14 dB", Sfx.veces("no_puedes") == 1 and is_equal_approx(_db("no_puedes"), -14.0), str(Sfx.CONTEO))
	await _pausa()
	b.recoger()
	_ok("7 botÃƒÆ’Ã‚Â­n: el reintento no repite el sonido (como el aviso)", Sfx.veces("no_puedes") == 1, str(Sfx.CONTEO))
	mundo.free()

	# PociÃƒÆ’Ã‚Â³n del suelo de Jugabilidad3D.
	var fm := FakeM.new()
	root.add_child(fm)
	var pj := Pj3D.new()
	root.add_child(pj)
	fm._jugador = pj
	var jug := Jugabilidad3D.new()
	jug.m = fm
	jug.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(jug)
	var nodo := Node3D.new()
	root.add_child(nodo)
	jug._botin = [{"nodo": nodo, "y": 0.0, "tipo": "pocion", "n": 1, "c": Vector2i.ZERO}]
	Sfx.vaciar_registro()
	await _pausa()
	jug._recoger(pj)
	jug._recoger(pj)
	jug._recoger(pj)
	_ok("7 Jugabilidad3D: pociÃƒÆ’Ã‚Â³n con la mochila llena ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Ãƒâ€šÃ‚Â«no_puedesÃƒâ€šÃ‚Â» una vez por visita", Sfx.veces("no_puedes") == 1 and is_equal_approx(_db("no_puedes"), -14.0) and jug._botin.size() == 1, str(Sfx.CONTEO))
	pj.position = Vector3(20.0, 0.0, 0.0)
	jug._recoger(pj)
	pj.position = Vector3.ZERO
	await _pausa()
	jug._recoger(pj)
	_ok("7 Jugabilidad3D: al volver a acercarse suena otra vez", Sfx.veces("no_puedes") == 2, str(Sfx.CONTEO))
	# Con sitio la coge y no suena.
	Estado.nuevo()
	await _pausa()
	jug._recoger(pj)
	_ok("7 Jugabilidad3D: con sitio la coge y no suena mÃƒÆ’Ã‚Â¡s", Sfx.veces("no_puedes") == 2 and jug._botin.is_empty() and Estado.i().cuenta("pocion") == 1, str(Sfx.CONTEO))
	jug.free()
	pj.free()
	fm.free()
	_quitar_lanz(lz)

	# ACTIVA = false: el sonido sigue.
	Sensacion3D.ACTIVA = false
	_llenar_mochila()
	var lz2: FakeLanz = _lanz()
	var r2 := Recolectable3D.new()
	r2.preparar(Vector2i(2, 2), "", 0.0, null, "seta")
	root.add_child(r2)
	await avanzar(1)
	Sfx.vaciar_registro()
	await _pausa()
	r2.recoger()
	_ok("7 ACTIVA=false: Ãƒâ€šÃ‚Â«no_puedesÃƒâ€šÃ‚Â» suena igual", Sfx.veces("no_puedes") == 1)
	Sensacion3D.ACTIVA = true
	r2.free()
	_quitar_lanz(lz2)

	# BÃƒÆ’Ã‚Â¡lsamo.
	Estado.nuevo()
	var c := Consumibles.new()
	var avisos: Array = []
	c.aviso.connect(func(t: String, _col: Color) -> void: avisos.append(t))
	c.escudo_t = 10.0
	Sfx.vaciar_registro()
	await _pausa()
	var abs1: bool = c.absorber(30.0)
	_ok("7 bÃƒÆ’Ã‚Â¡lsamo: absorbe el golpe entero (true) y el escudo se acaba", abs1 and c.escudo_t == 0.0 and not c.escudo_activo(), "escudo_t=%s" % c.escudo_t)
	_ok("7 bÃƒÆ’Ã‚Â¡lsamo: suena Ãƒâ€šÃ‚Â«escudo_golpeÃƒâ€šÃ‚Â»", Sfx.veces("escudo_golpe") == 1 and Sfx.veces("escudo_roto") == 0, str(Sfx.CONTEO))
	_ok("7 bÃƒÆ’Ã‚Â¡lsamo: el aviso de texto sigue igual", avisos.size() == 1 and String(avisos[0]).contains("absorbido"), str(avisos))
	await _pausa()
	var abs2: bool = c.absorber(30.0)
	_ok("7 bÃƒÆ’Ã‚Â¡lsamo gastado: no absorbe ni suena", not abs2 and Sfx.veces("escudo_golpe") == 1)
	var abs0: bool = Consumibles.new().absorber(0.0)
	_ok("7 sin escudo o con golpe 0: no absorbe", not abs0)
	c.escudo_t = 1.0
	await _pausa()
	c.actualizar(0.4)
	_ok("7 bÃƒÆ’Ã‚Â¡lsamo con tiempo: aÃƒÆ’Ã‚Âºn no suena nada nuevo", c.escudo_activo() and Sfx.veces("escudo_roto") == 0)
	c.actualizar(0.7)
	_ok("7 bÃƒÆ’Ã‚Â¡lsamo agotado: suena Ãƒâ€šÃ‚Â«escudo_rotoÃƒâ€šÃ‚Â» (una vez)", not c.escudo_activo() and Sfx.veces("escudo_roto") == 1 and Sfx.veces("escudo_golpe") == 1, str(Sfx.CONTEO))
	c.actualizar(0.5)
	_ok("7 y no se repite", Sfx.veces("escudo_roto") == 1)
	# Con el escudo ya gastado de un golpe no suena Ãƒâ€šÃ‚Â«rotoÃƒâ€šÃ‚Â».
	c.escudo_t = 5.0
	await _pausa()
	c.absorber(5.0)
	c.actualizar(1.0)
	_ok("7 absorber y luego dejar pasar el tiempo no suena Ãƒâ€šÃ‚Â«rotoÃƒâ€šÃ‚Â»", Sfx.veces("escudo_roto") == 1, str(Sfx.CONTEO))
	# ACTIVA = false: los sonidos sÃƒÆ’Ã‚Â­.
	Sensacion3D.ACTIVA = false
	c.escudo_t = 5.0
	Sfx.vaciar_registro()
	await _pausa()
	c.absorber(5.0)
	c.escudo_t = 0.1
	await _pausa()
	c.actualizar(0.2)
	_ok("7 ACTIVA=false: Ãƒâ€šÃ‚Â«escudo_golpeÃƒâ€šÃ‚Â» y Ãƒâ€šÃ‚Â«escudo_rotoÃƒâ€šÃ‚Â» suenan igual", Sfx.veces("escudo_golpe") == 1 and Sfx.veces("escudo_roto") == 1, str(Sfx.CONTEO))
	Sensacion3D.ACTIVA = true


# ---------------------------------------------------------------------------------------------------------------------
#  U8 Ãƒâ€šÃ‚Â· barras con peso
# ---------------------------------------------------------------------------------------------------------------------

func _u8_barras() -> void:
	Sensacion3D.ACTIVA = true
	# --- La barra sola ---
	var barra := BarraHud.new()
	root.add_child(barra)
	barra.configurar("Vida", Color(0.3, 0.9, 0.4), 1.0)
	barra.peso_dano = true
	await avanzar(2)
	barra.poner_fraccion(0.5)
	await avanzar(1)
	_ok("8 daÃƒÆ’Ã‚Â±o: flash blanco activo", barra.flash_t > 0.0, str(barra.flash_t))
	await avanzar(3)
	_ok("8 daÃƒÆ’Ã‚Â±o: el flash se apaga a los 0,1 s", is_equal_approx(barra.flash_t, 0.0), str(barra.flash_t))
	_ok("8 daÃƒÆ’Ã‚Â±o: el relleno ya bajÃƒÆ’Ã‚Â³ y el fantasma sigue por encima", barra._mostrada < 0.6 and barra.fantasma > barra._mostrada + 0.05 and barra.fantasma > barra.fraccion, "relleno %.2f fantasma %.2f" % [barra._mostrada, barra.fantasma])
	# Tiempo hasta que el fantasma alcance el relleno, desde el golpe.
	var t: float = 0.0
	var frames: int = 0
	while barra.fantasma > barra.fraccion + 0.0005 and frames < 120:
		await avanzar(1)
		t += root.get_process_delta_time()
		frames += 1
	var total: float = t + 4.0 * root.get_process_delta_time()      # + los 4 fotogramas de antes (1 del golpe y 3 del flash)
	_ok("8 daÃƒÆ’Ã‚Â±o: el fantasma alcanza al relleno en ~0,65 s (espera 0,15 + 0,5)", total > 0.55 and total < 0.8, "%.2f s" % total)
	_ok("8 daÃƒÆ’Ã‚Â±o: baja mÃƒÆ’Ã‚Â¡s lento que el relleno (el relleno tardÃƒÆ’Ã‚Â³ <0,2 s)", BarraHud.T_FANTASMA_S > BarraHud.T_SUAVIZADO_S * 2.0)
	# La barra se queda tranquila al terminar.
	await avanzar(3)
	_ok("8 al terminar, sin proceso ni franja", not barra.is_processing() and is_equal_approx(barra.fantasma, barra.fraccion))

	# Curar: pulso. Una cura pequeÃƒÆ’Ã‚Â±a (la infusiÃƒÆ’Ã‚Â³n) no pulsa.
	barra.pulso_t = 0.0
	barra.poner_fraccion(0.8)
	_ok("8 curar (+30 %): el pulso se enciende", barra.pulso_t > 0.0, str(barra.pulso_t))
	await avanzar(20)
	barra.pulso_t = 0.0
	barra.poner_fraccion(0.81)
	_ok("8 una cura pequeÃƒÆ’Ã‚Â±a (+1 %) no pulsa", is_equal_approx(barra.pulso_t, 0.0))
	_ok("8 curar no deja franja fantasma ni flash", is_equal_approx(barra.fantasma, barra.fraccion) and is_equal_approx(barra.flash_t, 0.0))

	# Una barra sin peso (la tinta) no reacciona.
	var tinta := BarraHud.new()
	root.add_child(tinta)
	tinta.configurar("Tinta", Color(0.3, 0.5, 1.0), 1.0)
	tinta.poner_fraccion(0.2)
	await avanzar(1)
	_ok("8 barra sin peso (tinta): ni fantasma ni flash ni pulso", is_equal_approx(tinta.fantasma, tinta.fraccion) and is_equal_approx(tinta.flash_t, 0.0) and is_equal_approx(tinta.pulso_t, 0.0))
	tinta.poner_fraccion(0.9)
	_ok("8 barra sin peso: subir tampoco pulsa", is_equal_approx(tinta.pulso_t, 0.0))

	# Golpes seguidos: el fantasma no retrocede.
	barra.poner_fraccion(0.8)
	await avanzar(20)
	barra.poner_fraccion(0.6)
	await avanzar(6)
	var f1: float = barra.fantasma
	barra.poner_fraccion(0.4)
	await avanzar(1)
	_ok("8 dos golpes seguidos: el fantasma no salta hacia atrÃƒÆ’Ã‚Â¡s", barra.fantasma >= f1 - 0.2 and barra.fantasma > barra.fraccion, "%.2f -> %.2f" % [f1, barra.fantasma])
	await avanzar(40)
	_ok("8 y acaba alcanzando al relleno", is_equal_approx(barra.fantasma, barra.fraccion))

	# ACTIVA = false: sin fantasma, sin flash, sin pulso (es sensaciÃƒÆ’Ã‚Â³n).
	Sensacion3D.ACTIVA = false
	barra.poner_fraccion(0.2)
	await avanzar(1)
	_ok("8 ACTIVA=false: daÃƒÆ’Ã‚Â±o sin fantasma ni flash", is_equal_approx(barra.fantasma, barra.fraccion) and is_equal_approx(barra.flash_t, 0.0))
	barra.poner_fraccion(0.9)
	_ok("8 ACTIVA=false: curar sin pulso", is_equal_approx(barra.pulso_t, 0.0))
	Sensacion3D.ACTIVA = true
	barra.free()
	tinta.free()

	# --- El HUD de verdad ---
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.agregar("tonico_tinta", 3)
	var j := JugadorFalso.new()
	root.add_child(j)
	j.tinta = Tinta.new()
	j.tinta.partida = Estado.new()
	j.vida = e.vida_max
	var hud := HudEoW.new()
	hud.jugador = j
	root.add_child(hud)
	await avanzar(3)
	_ok("8 HUD: la barra de vida lleva peso y la de tinta no", hud._vida.peso_dano and not hud._tinta.peso_dano)
	_ok("8 HUD: al montar no hay flash ni fantasma", is_equal_approx(hud._vida.flash_t, 0.0) and is_equal_approx(hud._vida.fantasma, hud._vida.fraccion))
	j.vida = e.vida_max * 0.4
	await avanzar(2)
	_ok("8 HUD: perder vida deja fantasma por encima del relleno", hud._vida.fantasma > hud._vida._mostrada and hud._vida.fantasma > hud._vida.fraccion, "fantasma %.2f relleno %.2f" % [hud._vida.fantasma, hud._vida._mostrada])
	await avanzar(30)
	j.tinta.actual = 10.0
	await avanzar(2)
	_ok("8 HUD: gastar tinta no crea fantasma ni flash", is_equal_approx(hud._tinta.fantasma, hud._tinta.fraccion) and is_equal_approx(hud._tinta.flash_t, 0.0))
	j.vida = e.vida_max * 0.9
	await avanzar(2)
	_ok("8 HUD: curar de verdad (una cura grande) enciende el pulso de la barra de vida", hud._vida.pulso_t > 0.0, str(hud._vida.pulso_t))
	await avanzar(20)

	# TÃƒÆ’Ã‚Â³nico: destello del frasco.
	j.tinta.frascos = 1
	await avanzar(2)
	_ok("8 HUD: el frasco no destella en reposo", not hud._frascos.destello_activo())
	hud._input(_tecla_q())
	_ok("8 tÃƒÆ’Ã‚Â³nico: el frasco recargado destella (halo de color, no el blanco de vaciarse)", j.tinta.frascos == 2 and hud._frascos.destello_activo() and hud._frascos._recarga and hud._frascos._i_destello == 1, "frascos %d i=%d" % [j.tinta.frascos, hud._frascos._i_destello])
	await avanzar(int(ceil(HudEoW.Frascos.T_DESTELLO_S * 30.0)) + 4)
	_ok("8 tÃƒÆ’Ã‚Â³nico: el destello se apaga", not hud._frascos.destello_activo())
	j.tinta.frascos = 0
	j.tinta.frasco_gastado.emit()
	_ok("8 vaciar un frasco sigue con su destello de siempre (blanco)", hud._frascos.destello_activo() and not hud._frascos._recarga)
	await avanzar(int(ceil(HudEoW.Frascos.T_DESTELLO_S * 30.0)) + 4)

	# ACTIVA = false: la barra y el frasco no se animan; el tÃƒÆ’Ã‚Â³nico y la vida valen igual.
	Sensacion3D.ACTIVA = false
	j.vida = e.vida_max * 0.3
	await avanzar(2)
	_ok("8 HUD ACTIVA=false: perder vida sin fantasma ni flash", is_equal_approx(hud._vida.fantasma, hud._vida.fraccion) and is_equal_approx(hud._vida.flash_t, 0.0))
	j.vida = e.vida_max
	await avanzar(2)
	_ok("8 HUD ACTIVA=false: curar sin pulso", is_equal_approx(hud._vida.pulso_t, 0.0))
	j.tinta.frascos = 1
	await avanzar(2)
	hud._input(_tecla_q())
	_ok("8 HUD ACTIVA=false: el tÃƒÆ’Ã‚Â³nico recarga el frasco (regla igual) sin destello", j.tinta.frascos == 2 and not hud._frascos.destello_activo(), "frascos %d" % j.tinta.frascos)
	Sensacion3D.ACTIVA = true
	hud.queue_free()
	j.free()
	await avanzar(2)


# ---------------------------------------------------------------------------------------------------------------------
#  U6 con la escena de verdad: el gestor lo monta el `iniciar` de las reglas del Bosque
# ---------------------------------------------------------------------------------------------------------------------

func _u6_escena() -> void:
	PistaProximidad.reiniciar()
	Estado.nuevo()
	Repertoire.activate_all()
	await cargar()
	if lanzador == null or jugador == null:
		_ok("6 escena: hay lanzador y jugador", false)
		return
	var regla: Node = null
	for n in get_nodes_in_group(PistaProximidad.GRUPO):
		if "_npcs" in n:
			regla = n
	_ok("6 escena: las reglas del nivel (Bosque3D) se apuntan a la pista en su iniciar", regla != null)
	_ok("6 escena: el gestor estÃƒÆ’Ã‚Â¡ montado", PistaProximidad.pista() != null)
	if regla == null or PistaProximidad.pista() == null:
		return
	var npcs: Dictionary = regla.get("_npcs")
	_ok("6 escena: el nivel tiene NPC", not npcs.is_empty())
	if npcs.is_empty():
		return
	var nombre: String = String(npcs.keys()[0])
	var npc: Pj3D = npcs[nombre]
	jugador.position = npc.position + Vector3(1.0, 0.0, 0.0)
	await avanzar(6)
	var pista: PistaInteraccion = PistaProximidad.pista()
	_ok("6 escena: junto a %s sale Ãƒâ€šÃ‚Â«[E] HablarÃƒâ€šÃ‚Â»" % nombre, PistaProximidad.accion_actual() == "Hablar" and pista.visible, PistaProximidad.accion_actual())
	jugador.position = npc.position + Vector3(Bosque3D.ALCANCE_HABLAR + 6.0, 0.0, 0.0)
	await avanzar(int(ceil(PistaInteraccion.T_FUNDIDO_S * 30.0)) + 8)
	_ok("6 escena: al alejarse desaparece", PistaProximidad.accion_actual() == "" and not pista.visible)
	PistaProximidad.reiniciar()
