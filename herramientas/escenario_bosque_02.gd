extends "res://herramientas/prueba_bosque_02_recorrido.gd"
## ESCENARIO BOSQUE 02 (Juego, 3/11): lo que NO es la resolubilidad (esa es `prueba_bosque_02_recorrido.gd`, de la que reutiliza los instrumentos): las zonas y el viaje de ida y vuelta a la Cueva.
##  1 · Las zonas: diez líneas `; zona`, sin avisos; cada región con su luz, su mezcla (5 s los exteriores, ≤ 1 s las salas) y su nombre; el rótulo de la primera vez sale una sola vez.
##  2 · Se juega un trozo de verdad (braseros y cofre de la linde, tronco-puente, pasillo de la Cueva con tronco y setos quemados, telaraña y tótem de fuego de las ruinas) y se sale por la boca
##      de la Cueva (34,36): carga la Cueva (aparece en `desde_bosque`), y su salida `a_bosque` (3..5,18) devuelve al Bosque 02 en su `boca_cueva` (33,36).
##  3 · Se conserva TODO lo resuelto: las flags, el cofre de la linde nace abierto (sin repetir el botín), el tronco-puente sigue tumbado, el tronco y los setos no vuelven, la telaraña quemada tampoco,
##      el tótem de fuego vuelve despierto, los braseros-guía vuelven encendidos, la misión conserva su progreso y Puzle3D monta sin avisos.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_bosque_02.gd

var zonas: Zonas3D = null
const T_VIAJE_MAX_S: float = 90.0


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	Niveles.viajes.clear()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_refrescar()
	reglas.set("volver_al_menu", false)
	lanzador.tinta = null
	_curar()
	await _zonas()
	await _ida_y_vuelta()


func _refrescar() -> void:
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	reglas = maqueta.get_node_or_null("Reglas")
	z = maqueta.get_node_or_null("Puzles") as Puzle3D
	zonas = maqueta.get_node_or_null("Zonas3D") as Zonas3D


func _esperar_viaje() -> void:
	var pared: int = Time.get_ticks_msec()
	while not Niveles.en_curso and Time.get_ticks_msec() - pared < 4000:
		await process_frame
	while Niveles.en_curso and float(Time.get_ticks_msec() - pared) < T_VIAJE_MAX_S * 1000.0:
		await process_frame
	await avanzar_s(0.6)
	_refrescar()


# ---------------------------------------------------------------------------------------------------------------------
#  1 · Zonas
# ---------------------------------------------------------------------------------------------------------------------

func _zonas() -> void:
	_ok("Z1.1 el mapa declara 11 líneas de zona (con el sendero norte, 13/11) y todas se leen sin aviso", zonas != null and zonas.zonas.size() == 11 and zonas.avisos.is_empty(), "%d zonas, avisos %s" % [zonas.zonas.size() if zonas != null else -1, str(zonas.avisos) if zonas != null else ""])
	# [casilla, luz, mezcla, nombre]
	var esperado: Array = [
		[Vector2i(7, 44), "bosque", 5.0, "linde"], [Vector2i(19, 45), "bosque", 5.0, "bosque_denso"], [Vector2i(33, 37), "ruinas", 1.0, "boca_cueva"], [Vector2i(21, 28), "atardecer", 5.0, "pradera"],
		[Vector2i(8, 21), "ruinas", 5.0, "plaza_oeste"], [Vector2i(19, 21), "ruinas", 5.0, "ruinas_este"], [Vector2i(30, 20), "agua", 5.0, "estanque"], [Vector2i(32, 27), "fuego", 1.0, "campamento"],
		[Vector2i(8, 28), "santuario", 1.0, "santuario"], [Vector2i(8, 35), "ruinas", 1.0, "escondite"], [Vector2i(24, 3), "bosque", 5.0, "sendero_norte"]]
	var mal: Array = []
	for e in esperado:
		var zn: Dictionary = zonas.zona_en(e[0] as Vector2i)
		if String(zn.get("luz", "")) != String(e[1]) or not is_equal_approx(float(zn.get("mezcla", -1.0)), float(e[2])) or String(zn.get("nombre", "")) != String(e[3]):
			mal.append("%s → %s" % [str(e[0]), str({"luz": zn.get("luz"), "mezcla": zn.get("mezcla"), "nombre": zn.get("nombre")})])
	_ok("Z1.2 cada región tiene su luz, su mezcla (5 s los exteriores, ≤ 1 s las salas) y su nombre", mal.is_empty(), str(mal))
	_ok("Z1.3 el rótulo de la linde salió al empezar, una sola vez", (zonas.rotulos_mostrados as Array).count("La linde del arroyo") <= 1, str(zonas.rotulos_mostrados))
	# Hay que MOVER a la jugadora a pie para que sondee la zona: se la lleva a la pradera y de vuelta
	await caminar(Vector2i(12, 44), "Z1.4")
	await avanzar_s(1.0)
	_ok("Z1.4 la jugadora en la linde: zona «linde» y luz «bosque»", zonas.nombre_actual == "linde" and String((zonas.actual as Dictionary).get("luz", "")) == "bosque", zonas.nombre_actual)


# ---------------------------------------------------------------------------------------------------------------------
#  2 y 3 · Ida y vuelta a la Cueva
# ---------------------------------------------------------------------------------------------------------------------

func _ida_y_vuelta() -> void:
	await _linde()
	await _arroyo()
	await _pasillo_cueva()
	# telaraña y tótem de fuego de las ruinas
	var tot: Array = reglas.get("_totems") as Array
	await disparar("fuego", ["flecha"], Vector2i(22, 21), Vector2i(22, 19), "V2.1")
	await esperar(func() -> bool: return _libre(Vector2i(22, 19)), 20.0)
	await disparar("fuego", ["flecha"], Vector2i(22, 20), Vector2i(22, 18), "V2.2")      # con la telaraña consumida aún disolviéndose (diario 347: ya no se come la flecha)
	var fuego: bool = await esperar(func() -> bool: return bool(tot[0].activo), 6.0)
	_ok("V2.3 el tótem de fuego despierta (flag `bosque02.totem.fuego`)", fuego and _flag("bosque02.totem.fuego"))
	# Foto de lo resuelto ANTES de salir
	var flags_antes: Array = Flags.i().nombres("bosque02.")
	var progreso_antes: Vector2i = Misiones.i().progreso("bosque_02")
	var oro: int = Estado.i().oro
	var vida: float = float(jugador.get("vida"))
	_ok("V2.4 antes de salir hay %d flags de bosque02 y la misión lleva %d/%d" % [flags_antes.size(), progreso_antes.x, progreso_antes.y], flags_antes.size() >= 8 and progreso_antes.x >= 2)
	var vieja: Node = maqueta
	await caminar(Vector2i(33, 36), "V2.5")
	await avanzar_s(0.5)
	_ok("V2.6 llegar junto a la boca no la dispara", not Niveles.en_curso and maqueta == vieja)
	colocar_jugador(Vector2i(34, 36))
	await _esperar_viaje()
	_ok("V2.7 pisar la boca carga la Cueva: otra escena y la del Bosque se ha ido", maqueta != vieja and not is_instance_valid(vieja) and String(maqueta.get("nivel")) == "Cueva" and jugador != null)
	if jugador == null or String(maqueta.get("nivel")) != "Cueva":
		return
	_ok("V2.8 la jugadora aparece en `desde_bosque` (4,17) de la Cueva, con el oro y la vida que llevaba", Terreno3D.celda_de(jugador.position) == Vector2i(4, 17) and Estado.i().oro == oro, "%s oro %d" % [str(Terreno3D.celda_de(jugador.position)), Estado.i().oro])
	_ok("V2.9 las flags del Bosque 02 siguen puestas dentro de la Cueva", Flags.i().nombres("bosque02.") == flags_antes)
	await avanzar_s(0.5)
	var vieja_cueva: Node = maqueta
	colocar_jugador(Vector2i(4, 18))
	await _esperar_viaje()
	_ok("V2.10 pisar la salida de la Cueva (3..5,18) devuelve al BOSQUE 02", maqueta != vieja_cueva and String(maqueta.get("nivel")) == "Bosque_02" and reglas != null and z != null)
	if reglas == null or z == null or jugador == null:
		return
	await avanzar_s(1.0)
	_ok("V2.11 la jugadora aparece en `boca_cueva` (33,36) del Bosque 02, con el oro", Terreno3D.celda_de(jugador.position) == Vector2i(33, 36) and Estado.i().oro == oro, str(Terreno3D.celda_de(jugador.position)))
	_ok("V2.12 el diario apunta los dos viajes (Bosque 02 → Cueva → Bosque 02)", Niveles.viajes.size() == 2 and String(Niveles.viajes[0]["a"]) == "Cueva" and String(Niveles.viajes[1]["a"]) == "Bosque_02" and String(Niveles.viajes[1]["entrada"]) == "boca_cueva")
	_ok("V2.13 Puzle3D de la escena nueva monta todo sin avisos", z.avisos.is_empty(), str(z.avisos))
	# --- TODO lo resuelto sigue resuelto ---
	_ok("V3.1 las flags de bosque02 son EXACTAMENTE las que eran (%d)" % flags_antes.size(), Flags.i().nombres("bosque02.") == flags_antes)
	var linde: Puzle3D.CofrePuzle = _cofre("cofre_linde")
	_ok("V3.2 el cofre de la linde nace ABIERTO (la flag manda) y no repite el botín", linde != null and linde.es_abierto and Estado.i().oro == oro)
	var tronco: TroncoPuente3D = reglas.get("_tronco_puente") as TroncoPuente3D
	await avanzar_s(1.0)
	_ok("V3.3 el tronco-puente sigue tumbado sobre el arroyo: las dos casillas del río se pisan", tronco != null and tronco.cayo and _libre(Vector2i(14, 43)) and _libre(Vector2i(15, 43)))
	_ok("V3.4 el tronco y los setos del pasillo no vuelven: (22,36), (26,36) y (27,36) libres", _libre(Vector2i(22, 36)) and _libre(Vector2i(26, 36)) and _libre(Vector2i(27, 36)))
	_ok("V3.5 la telaraña quemada del tótem de fuego no vuelve", _libre(Vector2i(22, 19)))
	var tot2: Array = reglas.get("_totems") as Array
	_ok("V3.6 el tótem de fuego vuelve DESPIERTO (se lee de su flag al montar); los otros dos, dormidos", bool(tot2[0].activo) and not bool(tot2[1].activo) and not bool(tot2[2].activo))
	_ok("V3.7 los tres braseros-guía vuelven encendidos y los dos de la linde, apagados", _braseros_guia_encendidos() and reglas.call("_braseros_encendidos") == 0)
	_ok("V3.8 la misión conserva su progreso (%d/%d) y no se redefine" % [progreso_antes.x, progreso_antes.y], Misiones.i().progreso("bosque_02") == progreso_antes)
	_ok("V3.9 hay camino a pie otra vez hasta la boca (34,36) desde la entrada", hay_camino(Vector2i(34, 36)))
	_ok("V3.10 el rótulo de la boca de la Cueva sale a la vuelta solo si no se había visto (la zona cuenta una vez)", (zonas.rotulos_mostrados as Array).count("La boca de la cueva") <= 1, str(zonas.rotulos_mostrados))
