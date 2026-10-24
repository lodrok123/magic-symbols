extends "res://herramientas/escenario_base.gd"
## PIEZAS DE LOS MAPAS ABIERTOS AL ESTILO EoW (23/10; docs/PLAN_BOSQUE_EOW.md §8). Headless, con la escena de verdad (PruebaCueva):
## 1 · Gramática: jarron, caja, salida, entrada y puerta con llave se leen; lo mal escrito avisa y no tumba nada.
## 2 · Zonas: `mezcla=` (defecto = el de siempre), `nombre=`, `rotulo=`; presets de luz `cueva` y `santuario`.
## 3 · Rompibles: se rompen con un hechizo real, un empujón, una explosión y un golpe; botín por zona; restos; flag; no reaparecen.
## 4 · Mezcla de luz: la sala cambia en menos de 1 s y una zona con `mezcla=5` tarda de verdad.
## 5 · Rótulo de entrada: sale la primera vez y no se repite (flag de «ya visto»).
## 6 · Puerta con llave de verdad: sin llave avisa, con llave pero lejos no abre, con llave y delante abre; `gasta` y `abierto`.
## 7 · El diario: cada evento lleva la zona del jugador; el cruce de zona lo apunta.
## 8 · Salida y entrada: no se dispara al aparecer; nivel que no existe = aviso sin romper; viaje de verdad (fundido, flags, oro y vida persisten, entrada con nombre mirando hacia dentro);
##     entrada que no existe = aviso y la jugadora se queda donde nace.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_mapa_abierto.gd

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const FUEGO: String = "res://nucleo/fire_rune.tres"
const AGUA: String = "res://nucleo/water_rune.tres"
const T_VIAJE_MAX_S: float = 90.0
const DESTINO_PROPIO: String = "Cueva:desde_bosque"
const CELDA_ENTRADA: Vector2i = Vector2i(4, 17)

var _z: Puzle3D = null
var _zonas: Zonas3D = null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	_gramatica()
	_zonas_texto()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_zonas = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	_ok("0 Puzle3D monta la Cueva sin avisos (jarrones, salida, entrada y puerta con llave incluidos)", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	_ok("0 Zonas3D de la Cueva sin avisos", _zonas != null and _zonas.avisos.is_empty(), str(_zonas.avisos) if _zonas != null else "")
	if _z == null or _zonas == null:
		return
	await _rotulo()
	await _rompibles()
	await _mezcla()
	await _puerta()
	await _diario()
	await _salida_entrada()


# ---------------------------------------------------------------------------------------------------------------------
func _gramatica() -> void:
	var t: String = "\n".join([
		"; pieza j1 jarron 3 3 botin=oro",
		"; pieza j2 jarron 4 3 botin=pocion cantidad=2 alto=si",
		"; pieza j3 caja 5 3 botin=seta pequena=si",
		"; pieza j4 jarron 6 3 botin=oro_falso",
		"; pieza s1 salida 7 3 a=Cueva:desde_bosque celdas=7,3..8,3 modo=usar marca=no",
		"; pieza s2 salida 9 3 a=sin_dos_puntos",
		"; pieza e1 entrada 10 3 mira=n",
		"; pieza e2 entrada 11 3 mira=x",
		"; pieza d1 puerta 12 3 llave=a.b.c gasta=si abierto=a.b.d",
		"; puzle p1 cuando=j1.roto hace=flag.poner(a.b.c)",
		"; puzle p2 cuando=j1.roto si=j2.entero hace=s1.usar",
		"; puzle p3 cuando=s1.usada hace=j3.romper",
		"; pieza j5 jarron 3 5 celdas=3,5+4,5+5,5 botin=zona modelo=caja",
		"; pieza s3 salida 7 5 escena=PruebaCueva entrada=desde_bosque",
		"; pieza c1 cofre 9 5 da=oro:30+seta_asada:2",
		"; pieza c2 cofre 10 5 da=oro:0",
		"; pieza d2 puerta 12 5 llave=a.b.c flag=a.b.d",
	])
	var r: Dictionary = Puzle3D.parsear(t)
	var piezas: Array = r["piezas"]
	var avisos: Array = r["avisos"]
	var ids: Array = []
	for p in piezas:
		ids.append((p as Puzle3D.Pieza).id)
	_ok("1 se leen las 6 piezas bien escritas y las 4 del diseño del Bosque 01 v01 (celdas+botin=zona+modelo=caja, escena=+entrada=, da=, flag=)", ids == ["j1", "j2", "j3", "s1", "e1", "d1", "j5", "s3", "c1", "d2"], str(ids))
	_ok("1 y las tres mal escritas, más el `da=oro:0`, avisan (botin raro, destino sin «:», mira inválido, cantidad 0)", avisos.size() == 4, str(avisos))
	var j2: Puzle3D.Pieza = piezas[1]
	_ok("1 jarron: botin, cantidad y alto leídos", String(j2.p["botin"]) == "pocion" and float(j2.p["cantidad"]) == 2.0 and bool(j2.p["alto"]))
	var s1: Puzle3D.Pieza = piezas[3]
	_ok("1 salida: destino, celdas, modo y marca leídos", String(s1.p["a"]) == "Cueva:desde_bosque" and (s1.p["celdas"] as Array).size() == 2 and String(s1.p["modo"]) == "usar" and not bool(s1.p["marca"]))
	var d1: Puzle3D.Pieza = piezas[5]
	_ok("1 puerta: llave, gasta y abierto leídos", String(d1.p["llave"]) == "a.b.c" and bool(d1.p["gasta"]) and String(d1.p["abierto"]) == "a.b.d")
	_ok("1 las tres reglas con jarron.roto, jarron.entero, salida.usada y las acciones usar y romper se leen", (r["reglas"] as Array).size() == 3)
	_ok("1 la entrada no lleva más clave que `mira`", Puzle3D.CLAVES["entrada"].keys() == ["mira"])
	var j5: Puzle3D.Pieza = piezas[6]
	_ok("1 jarron: celdas (3), botin=zona y modelo=caja leídos", (j5.p["celdas"] as Array).size() == 3 and String(j5.p["botin"]) == "zona" and String(j5.p["modelo"]) == "caja")
	_ok("1 salida con escena= y entrada= leída; `PruebaCueva` se resuelve al nivel `Cueva`", String((piezas[7] as Puzle3D.Pieza).p["escena"]) == "PruebaCueva" and Niveles.nivel_de("PruebaCueva") == "Cueva" and Niveles.nivel_de("Cueva") == "Cueva" and Niveles.nivel_de("PruebaBosque01_v01") == "Bosque_01_v01")
	var da: Array = (piezas[8] as Puzle3D.Pieza).p["da"]
	_ok("1 cofre da=oro:30+seta_asada:2 se lee como lista", da.size() == 2 and String(da[0]["que"]) == "oro" and int(da[1]["n"]) == 2 and String(da[1]["que"]) == "seta_asada")
	_ok("1 puerta con `flag=` (otro nombre de abierto=) leída", String((piezas[9] as Puzle3D.Pieza).p["flag"]) == "a.b.d")
	_ok("1 botin=zona toma el perfil de la zona: tirada baja = nada, media = oro, alta = poción", Rompible3D.botin_de_perfil("bosque", 0.1) == "nada" and Rompible3D.botin_de_perfil("bosque", 0.6) == "oro" and Rompible3D.botin_de_perfil("bosque", 0.95) == "pocion"
		and Rompible3D.botin_de_perfil("zona_x", 0.0, "", "campamento") == "nada" and Rompible3D.botin_de_perfil("bosque", 0.5, "", "campamento") == "oro")


func _zonas_texto() -> void:
	var z := Zonas3D.new()
	z.leer_texto("\n".join([
		"; zona 0,0..3,3 bosque",
		"; zona 4,0..7,3 cueva mezcla=0.5 rotulo=La_Cueva_Hueca",
		"; zona 8,0..11,3 agua mezcla=5 nombre=lago_norte",
		"; zona 12,0..15,3 santuario mezcla=-2",
		"; zona 16,0..19,3 ruinas mezcla=abc",
		"; zona 20,0..23,3 fuego nombre=con-guion",
		"; zona 24,0..27,3 bosque mezcla=5 id=linde titulo=La_linde_del_arroyo botin=campamento",
	]))
	_ok("2 alias del diseño del Bosque 01 v01: id= es nombre=, titulo= es rotulo=, botin=<fila> se guarda", String(z.zonas[6]["nombre"]) == "linde" and String(z.zonas[6]["rotulo"]) == "La linde del arroyo" and z.botin_en(Vector2i(25, 1)) == "campamento" and z.botin_en(Vector2i(1, 1)) == "")
	_ok("2 sin `mezcla` vale el de siempre (T_CAMBIO %.1f s)" % Zonas3D.T_CAMBIO, absf(float(z.zonas[0]["mezcla"]) - Zonas3D.T_CAMBIO) < 0.001 and absf(Zonas3D.T_CAMBIO - 1.5) < 0.001)
	_ok("2 `mezcla=0.5` y `mezcla=5` se leen", absf(float(z.zonas[1]["mezcla"]) - 0.5) < 0.001 and absf(float(z.zonas[2]["mezcla"]) - 5.0) < 0.001)
	_ok("2 `rotulo` lleva espacios por cada «_»", String(z.zonas[1]["rotulo"]) == "La Cueva Hueca" and String(z.zonas[0]["rotulo"]) == "")
	_ok("2 `nombre` y, sin él, el nombre de la luz", String(z.zonas[2]["nombre"]) == "lago_norte" and String(z.zonas[0]["nombre"]) == "bosque" and z.nombre_en(Vector2i(9, 1)) == "lago_norte" and z.luz_en(Vector2i(9, 1)) == "agua")
	_ok("2 una mezcla negativa o no numérica avisa y se queda en la de siempre (también un nombre con guion: no es un id)", z.avisos.size() == 3 and absf(float(z.zonas[3]["mezcla"]) - Zonas3D.T_CAMBIO) < 0.001 and absf(float(z.zonas[4]["mezcla"]) - Zonas3D.T_CAMBIO) < 0.001, str(z.avisos))
	_ok("2 existen los presets de luz `cueva` y `santuario`", LuzZona3D.ZONAS.has("cueva") and LuzZona3D.ZONAS.has("santuario") and LuzZona3D.ORDEN.has("santuario"))
	var cu: Dictionary = LuzZona3D.ZONAS["cueva"]
	var sa: Dictionary = LuzZona3D.ZONAS["santuario"]
	var bo: Dictionary = LuzZona3D.ZONAS["bosque"]
	_ok("2 cueva: sol casi apagado y ambiente bajo (más oscura que el bosque)", float(cu["sol_energia"]) <= 0.4 and float(cu["ambiente_energia"]) < float(bo["ambiente_energia"]) and float(cu["sol_energia"]) < float(bo["sol_energia"]))
	var sc: Color = sa["sol_color"]
	var aa: Color = sa["ambiente_arriba"]
	_ok("2 santuario: verdoso (el verde manda) y oscuro (menos luz que el bosque)", sc.g > sc.r and sc.g > sc.b and aa.g > aa.r and aa.g > aa.b and float(sa["sol_energia"]) < float(bo["sol_energia"]) and (sa["ambiente_abajo"] as Color).get_luminance() < (bo["ambiente_abajo"] as Color).get_luminance())
	z.free()


# ---------------------------------------------------------------------------------------------------------------------
func _rotulo() -> void:
	_ok("5 al empezar en la boca de la Cueva sale su rótulo «La Cueva»", _zonas.rotulos_mostrados == ["La Cueva"], str(_zonas.rotulos_mostrados))
	var flag: String = "cueva.rotulo.1_11_visto"
	_ok("5 queda apuntado en la flag de «ya visto» (%s)" % flag, Flags.i().tiene(flag), str(Flags.i().nombres("cueva.rotulo")))
	colocar_jugador(Vector2i(4, 4))                  # C2: sin rótulo
	await avanzar_s(0.3)
	colocar_jugador(Vector2i(4, 14))                 # otra vez C1
	await avanzar_s(0.3)
	_ok("5 al volver a entrar en la zona NO se repite", _zonas.rotulos_mostrados.size() == 1)
	Flags.i().quitar(flag)
	colocar_jugador(Vector2i(4, 4))
	await avanzar_s(0.3)
	colocar_jugador(Vector2i(4, 14))
	await avanzar_s(0.3)
	_ok("5 sin la flag de «ya visto» vuelve a salir (la flag es lo que manda)", _zonas.rotulos_mostrados.size() == 2 and Flags.i().tiene(flag))
	var capa: Node = root.get_node_or_null(RotuloZona3D.NOMBRE)
	var l: Label = capa.get_child(0) as Label if capa != null and capa.get_child_count() > 0 else null
	_ok("5 el rótulo está en pantalla con su texto", l != null and l.text == "La Cueva")
	_ok("5 las zonas sin `rotulo=` no sacan nada (C2 y C3)", _zonas.zona_en(Vector2i(4, 4))["rotulo"] == "" and _zonas.zona_en(Vector2i(11, 4))["rotulo"] == "")


# ---------------------------------------------------------------------------------------------------------------------
func _rompibles() -> void:
	var fuego: RuneData = load(FUEGO) as RuneData
	var j_a: Rompible3D = _z.nodo("jarron_c1a") as Rompible3D
	var j_b: Rompible3D = _z.nodo("jarron_c1b") as Rompible3D
	var j_c: Rompible3D = _z.nodo("jarron_c6a") as Rompible3D
	var j_d: Rompible3D = _z.nodo("jarron_c6b") as Rompible3D
	_ok("3 los cuatro jarrones del mapa están montados", j_a != null and j_b != null and j_c != null and j_d != null)
	if j_a == null or j_b == null or j_c == null or j_d == null:
		return
	_ok("3 un jarrón entero tapa su casilla, está en el grupo `rompible` y reacciona a un hechizo", Terreno3D.bloqueada(Vector2i(1, 13)) and j_a.is_in_group("rompible") and j_a.spell_reacts(fuego) and not j_a.roto_ya)
	_ok("3 el modelo se ve (el jarrón de verdad, o la caja de reserva)", j_a.get_node_or_null("modelo") != null and (j_a.get_node("modelo") as Node3D).visible)
	# Tabla por zona, sin azar.
	_ok("3 tabla por zona: bosque 3..8 de oro, ruinas 6..14, cueva 5..12; fila de defecto si la zona no existe", Rompible3D.oro_de("bosque", 0.0) == 3 and Rompible3D.oro_de("bosque", 0.99999) == 8
		and Rompible3D.oro_de("ruinas", 0.0) == 6 and Rompible3D.oro_de("cueva", 0.99999) == 12 and Rompible3D.oro_de("zona_que_no_existe", 0.0) == 2
		and Rompible3D.fila_de("zona_que_no_existe") == Rompible3D.BOTIN_DEFECTO and Rompible3D.fila_de("nombre_raro", "cueva") == Rompible3D.BOTIN_ZONA["cueva"])
	_ok("3 el botín válido: oro, pocion, nada o un objeto que existe", Rompible3D.botin_valido("oro") and Rompible3D.botin_valido("pocion") and Rompible3D.botin_valido("nada") and Rompible3D.botin_valido("seta") and not Rompible3D.botin_valido("espada_de_fuego"))
	# 1 · Un hechizo de verdad (agua desde el norte, por la columna 8) rompe el jarrón de la poción.
	colocar_jugador(Vector2i(8, 16))
	await avanzar_s(0.3)
	Rompible3D.tirada_forzada = 0.99                 # sin esquirla: el botín es lo de la tabla
	var antes_poc: int = Estado.i().cuenta("pocion")
	var salio: bool = lanzar_a_celda("agua", ["flecha"], Vector2i(8, 14), Vector2i(8, 16))        # la flecha viaja 2 casillas: el jarrón está justo al alcance
	await avanzar_s(1.5)
	_ok("3 un hechizo lanzado de verdad rompe el jarrón (botin=pocion)", salio and j_b.roto_ya, "salió=%s" % salio)
	if not j_b.roto_ya:
		j_b.on_spell_hit(load(AGUA) as RuneData)     # si el proyectil no llegó, el contrato directo
		await avanzar_s(0.2)
	_ok("3 al romperse libera la casilla, esconde el modelo y deja %d restos" % Rompible3D.N_TROZOS, not Terreno3D.bloqueada(Vector2i(8, 14)) and not (j_b.get_node("modelo") as Node3D).visible and j_b.n_restos() == Rompible3D.N_TROZOS)
	_ok("3 botin=pocion suelta la poción de la zona (cueva: 1)", j_b.soltado.size() == 1 and String(j_b.soltado[0]["que"]) == "pocion" and int(j_b.soltado[0]["n"]) == 1, str(j_b.soltado))
	_ok("3 la zona que decidió el botín es la de su casilla (cueva)", j_b.zona == "cueva", j_b.zona)
	var suelto: Node = maqueta.get_node_or_null("Botin_pocion")
	_ok("3 la poción queda en el suelo, sin coger todavía", suelto != null and Estado.i().cuenta("pocion") == antes_poc)
	colocar_jugador(Vector2i(8, 14))
	await avanzar_s(0.5)
	_ok("3 pasando cerca se coge: +1 poción en la mochila", Estado.i().cuenta("pocion") == antes_poc + 1)
	_ok("3 la flag `cueva.rompible.jarron_c1b` recuerda que se rompió", Flags.i().tiene(Rompible3D.flag_de("Cueva", "jarron_c1b")) and Rompible3D.flag_de("Cueva", "jarron_c1b") == "cueva.rompible.jarron_c1b")
	var oro_antes: int = Estado.i().oro
	var restos: int = j_b.n_restos()
	j_b.on_spell_hit(fuego)
	j_b.golpear()
	await avanzar_s(0.2)
	_ok("3 no reaparece ni vuelve a soltar nada si se le golpea otra vez", j_b.soltado.size() == 1 and j_b.n_restos() == restos and Estado.i().oro == oro_antes)
	# 2 · Una explosión rompe el de oro de C6; el oro está dentro del rango de la zona y se coge.
	Rompible3D.tirada_forzada = 0.99
	j_c.recibir_explosion(j_c.global_position)
	await avanzar_s(0.2)
	var n_oro: int = int(j_c.soltado[0]["n"]) if not j_c.soltado.is_empty() else -1
	_ok("3 una explosión lo rompe y el oro cae en el rango de la zona (ruinas, 6..14): %d" % n_oro, j_c.roto_ya and j_c.zona == "ruinas" and String(j_c.soltado[0]["que"]) == "oro" and n_oro >= 6 and n_oro <= 14, j_c.zona)
	colocar_jugador(Vector2i(17, 11))
	await avanzar_s(0.5)
	_ok("3 el oro se coge pasando cerca (%d monedas)" % n_oro, Estado.i().oro == oro_antes + n_oro)
	# 3 · Un empujón (viento) lo rompe: el jarrón alto de C6, con esquirla forzada: el material extra de la cueva.
	Rompible3D.tirada_forzada = 0.0
	j_d.push(Vector3.RIGHT, 1.0)
	await avanzar_s(0.2)
	Rompible3D.tirada_forzada = Rompible3D.PROB_FORZADA_NINGUNA
	var mineral: String = Objetos.mineral_de("jarron", "romper")
	_ok("3 un empujón lo rompe; en las ruinas (mineral 0,15) y con tirada ganadora suelta además `%s`" % mineral, j_d.roto_ya and mineral != "" and j_d.soltado.size() == 2 and String(j_d.soltado[1]["que"]) == mineral, str(j_d.soltado))
	colocar_jugador(Vector2i(10, 12))
	await avanzar_s(0.5)
	_ok("3 la esquirla también se coge", Estado.i().cuenta(mineral) == 1)
	# 4 · Una caja con objeto y cantidad (fuera del mapa: por código), un jarrón vacío y un golpe cuerpo a cuerpo.
	var caja := Rompible3D.new()
	caja.name = "caja_prueba"
	caja.preparar(Vector2i(6, 18), "caja", "seta", 3, false, "Cueva", maqueta)
	maqueta.add_child(caja)
	var vacio := Rompible3D.new()
	vacio.name = "vacio_prueba"
	vacio.preparar(Vector2i(7, 18), "jarron", "nada", 0, false, "Cueva", maqueta)
	maqueta.add_child(vacio)
	await avanzar(2)
	var setas_antes: int = Estado.i().cuenta("seta")
	caja.golpear(jugador.position)
	vacio.receive_damage(5.0)
	await avanzar_s(0.2)
	_ok("3 una caja con botin=seta cantidad=3 suelta 3 setas y un jarrón `nada` no suelta nada", caja.roto_ya and caja.soltado.size() == 1 and int(caja.soltado[0]["n"]) == 3 and vacio.roto_ya and vacio.soltado.is_empty())
	colocar_jugador(Vector2i(6, 18))
	await avanzar_s(0.5)
	_ok("3 las 3 setas se cogen", Estado.i().cuenta("seta") == setas_antes + 3)
	# La Cueva tiene sus piezas en la tabla de señales: una regla puede reaccionar a un jarrón roto.
	_ok("3 la pieza jarron emite `roto` y tiene las condiciones roto/entero y la acción romper", Puzle3D.SENALES.has("jarron") and Puzle3D.CONDICIONES["caja"].has("entero") and Puzle3D.ACCIONES["jarron"].has("romper"))


# ---------------------------------------------------------------------------------------------------------------------
func _sol_color() -> Color:
	return (maqueta.get("_sol") as DirectionalLight3D).light_color


func _dist_color(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _mezcla() -> void:
	colocar_jugador(Vector2i(4, 14))
	await avanzar_s(1.2)
	var cueva: Color = LuzZona3D.ZONAS["cueva"]["sol_color"]
	var fuego: Color = LuzZona3D.ZONAS["cueva_lava"]["sol_color"]       # C3 (24/10): su luz es `cueva_lava`, la variante azul de la Cueva (antes `fuego`, naranja)
	_ok("4 en C1 la luz es la de la cueva", _dist_color(_sol_color(), cueva) < 0.02)
	_ok("4 las zonas de la Cueva mezclan en 0,8 s (≤ 1 s)", absf(float(_zonas.zona_en(Vector2i(11, 4))["mezcla"]) - 0.8) < 0.001)
	colocar_jugador(Vector2i(11, 4))
	await avanzar_s(0.3)
	var a_mitad: float = _dist_color(_sol_color(), fuego)
	_ok("4 a los 0,3 s de entrar en C3 la luz va a medias (%.3f de distancia al fuego)" % a_mitad, a_mitad > 0.03 and a_mitad < _dist_color(cueva, fuego))
	await avanzar_s(0.8)
	_ok("4 a 1,1 s ya es la del fuego", _dist_color(_sol_color(), fuego) < 0.02)
	# Una zona exterior con mezcla lenta (5 s), declarada la última para que mande en C6.
	_zonas.agregar(Rect2i(10, 11, 8, 8), "agua", {"mezcla": 5.0})
	var agua: Color = LuzZona3D.ZONAS["agua"]["sol_color"]
	colocar_jugador(Vector2i(12, 14))
	await avanzar_s(1.2)
	_ok("4 con `mezcla=5` a 1,2 s la luz AÚN no ha llegado (%.3f)" % _dist_color(_sol_color(), agua), _dist_color(_sol_color(), agua) > 0.03)
	await avanzar_s(4.2)
	_ok("4 y a 5,4 s sí", _dist_color(_sol_color(), agua) < 0.02)
	_zonas.zonas.pop_back()
	colocar_jugador(Vector2i(4, 14))
	await avanzar_s(1.2)


# ---------------------------------------------------------------------------------------------------------------------
func _puerta() -> void:
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_llave") as Puzle3D.PuertaPuzle
	_ok("6 la puerta de C6 está montada con su llave (flag cueva.c4.llave), sin gastarla", puerta != null and puerta.llave == "cueva.c4.llave" and not puerta.gasta and puerta.flag_abierto == "cueva.c6.puerta")
	if puerta == null:
		return
	var centro: Vector3 = Terreno3D.centro_de(Vector2i(18, 16), Terreno3D.y_pies(Vector2i(18, 16)))
	var cerca := Vector3(centro.x + 1.7, centro.y, centro.z)       # pegada a la puerta: a 1,7 u de su centro (se TOCA a partir de PuertaPuzle.ALCANCE_TOQUE)
	_ok("6 empieza cerrada y sin la llave", not puerta.abierta and not Flags.i().tiene("cueva.c4.llave"))
	# Sin llave: llegar a ella solo avisa.
	var pj: Node3D = jugador.get("pj") as Node3D
	pj.position = cerca
	jugador.position = cerca
	await avanzar_s(0.5)
	var aviso: Label = lanzador.get("_aviso") as Label
	_ok("6 sin la llave, tocarla avisa «Hace falta una llave» y NO se abre", not puerta.abierta and puerta.intentos_sin_llave > 0 and aviso != null and aviso.text == Puzle3D.PuertaPuzle.TXT_SIN_LLAVE, "intentos=%d" % puerta.intentos_sin_llave)
	# Con la llave pero lejos: no se abre sola (antes la regla la abría en cuanto se abría el cofre).
	colocar_jugador(Vector2i(12, 14))                # dentro de C6, lejos de la puerta (y sin pisar C4, que se cierra)
	await avanzar_s(0.3)
	Flags.i().poner("cueva.c4.llave")
	await avanzar_s(0.6)
	_ok("6 con la llave pero lejos de la puerta, sigue cerrada", not puerta.abierta and Terreno3D.bloqueada(Vector2i(18, 16)))
	_ok("6 intentar abrir desde lejos tampoco vale", not puerta.intentar(true) and not puerta.abierta)
	# Con la llave y delante: se abre sola al tocarla.
	pj.position = cerca
	jugador.position = cerca
	await avanzar_s(0.5)
	_ok("6 con la llave y delante de la puerta, se abre", puerta.abierta and not Terreno3D.bloqueada(Vector2i(18, 16)))
	_ok("6 `gasta=no`: la llave sigue puesta y `abierto` recuerda la puerta abierta", Flags.i().tiene("cueva.c4.llave") and Flags.i().tiene("cueva.c6.puerta"))
	# Una puerta con `gasta=si`, abierta con la tecla E desde una casilla de distancia (más lejos de lo que se TOCA, dentro de lo que vale E).
	var pg := Puzle3D.PuertaPuzle.new()
	pg.name = "puerta_prueba"
	pg.preparar(Vector2i(7, 14), "", maqueta)
	(maqueta.get("_props") as Node).add_child(pg)
	pg.configurar_llave("cueva.prueba.llave", true, "cueva.prueba.abierta")
	Flags.i().poner("cueva.prueba.llave")
	colocar_jugador(Vector2i(7, 15))
	await avanzar_s(0.5)
	_ok("6 a una casilla de distancia con la llave NO se abre sola (hace falta pulsar E)", not pg.abierta and pg.distancia_jugadora() > Puzle3D.PuertaPuzle.ALCANCE_TOQUE and pg.distancia_jugadora() <= Puzle3D.PuertaPuzle.ALCANCE_USAR, "d=%.2f" % pg.distancia_jugadora())
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar(2)
	var por_tecla: bool = pg.abierta
	if not por_tecla:
		pg.intentar(true)                            # si la tecla no llegó por el hilo de entrada de las pruebas, lo mismo que hace
		await avanzar(2)
	_ok("6 pulsando E delante de la puerta se abre", pg.abierta)
	if not por_tecla:
		_aviso("6 la tecla E de verdad no llegó a la puerta en headless: se probó con intentar(true), que es lo que ella llama")
	_ok("6 `gasta=si` quita la llave al abrir y `abierto` queda puesta", not Flags.i().tiene("cueva.prueba.llave") and Flags.i().tiene("cueva.prueba.abierta"))
	var pg2 := Puzle3D.PuertaPuzle.new()
	pg2.name = "puerta_prueba2"
	pg2.preparar(Vector2i(7, 14), "", maqueta)
	(maqueta.get("_props") as Node).add_child(pg2)
	pg2.configurar_llave("cueva.prueba.llave", true, "cueva.prueba.abierta")
	await avanzar(2)
	_ok("6 con `abierto` ya puesta (partida cargada) la puerta nace abierta aunque no haya llave", pg2.abierta and not Terreno3D.bloqueada(Vector2i(7, 14)))
	pg.queue_free()
	pg2.queue_free()
	colocar_jugador(Vector2i(4, 14))


# ---------------------------------------------------------------------------------------------------------------------
func _diario() -> void:
	colocar_jugador(Vector2i(11, 4))                 # C3: zona de fuego
	await avanzar_s(0.4)
	_ok("7 PlayLog.zona es el nombre de la zona del jugador (fuego)", PlayLog.zona == "fuego" and _zonas.nombre_actual == "fuego", PlayLog.zona)
	volcar("prueba_zona", {"x": 1})
	var ev: Array = eventos("prueba_zona")
	_ok("7 un evento cualquiera del diario lleva la zona en la que está el jugador", ev.size() == 1 and String((ev[0] as Dictionary).get("zona", "")) == "fuego", str(ev))
	colocar_jugador(Vector2i(12, 14))                # C6: ruinas
	await avanzar_s(0.4)
	volcar("prueba_zona", {"x": 2})
	ev = eventos("prueba_zona")
	_ok("7 al cambiar de zona los eventos nuevos llevan la nueva (ruinas)", ev.size() == 2 and String((ev[1] as Dictionary).get("zona", "")) == "ruinas", str(ev))
	var cruces: Array = eventos("zona")
	var ultimo: Dictionary = cruces.back() if not cruces.is_empty() else {}
	_ok("7 el cruce de zona se apunta con la zona de la que se viene y el tiempo que se pasó en ella", String(ultimo.get("anterior", "")) == "fuego" and ultimo.has("segundos"), str(ultimo))
	# Un rompible apunta la zona de su botín sin pisar la del jugador.
	var rotos: Array = eventos("rompible_roto")
	_ok("7 los rompibles rotos están en el diario con la zona del botín aparte (`zona_botin`) y la del jugador en `zona`", rotos.size() >= 4 and (rotos[0] as Dictionary).has("zona_botin") and (rotos[0] as Dictionary).has("zona"), str(rotos.size()))
	colocar_jugador(Vector2i(4, 14))
	await avanzar_s(0.4)


# ---------------------------------------------------------------------------------------------------------------------
func _celda_de(j: Node3D) -> Vector2i:
	return Terreno3D.celda_de(j.position)


func _refrescar() -> void:
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null


func _esperar_viaje() -> float:
	var max_alfa: float = 0.0
	var pared: int = Time.get_ticks_msec()
	while not Niveles.en_curso and Time.get_ticks_msec() - pared < 3000:       # la salida mira a la jugadora cada 0,1 s
		await process_frame
	while Niveles.en_curso and float(Time.get_ticks_msec() - pared) < T_VIAJE_MAX_S * 1000.0:
		max_alfa = maxf(max_alfa, Niveles.alfa_fundido(self))
		await process_frame
	return max_alfa


func _salida_entrada() -> void:
	var entrada_n: Node = _z.nodo("desde_bosque")
	var salida_n: SalidaNivel3D = _z.nodo("a_bosque") as SalidaNivel3D
	_ok("8 la Cueva tiene la entrada `desde_bosque` (4,17) y la salida `a_bosque` hacia Bosque_01_v01:boca_cueva", entrada_n != null and salida_n != null and salida_n.destino == "Bosque_01_v01:boca_cueva" and salida_n.celdas.size() == 3)
	_ok("8 la tabla de niveles tiene Bosque_01, Cueva y Bosque_01_v01 (24/10: ya con su escena)", Niveles.ESCENAS.has("Bosque_01") and Niveles.existe("Cueva") and Niveles.ESCENAS.has("Bosque_01_v01") and Niveles.existe("Bosque_01_v01"))
	var ent: SalidaNivel3D.EntradaNivel3D = entrada_n as SalidaNivel3D.EntradaNivel3D
	var dir: Vector3 = ent.direccion_mirada() if ent != null else Vector3.ZERO
	var norte: Vector3 = Terreno3D.centro_de(CELDA_ENTRADA + Vector2i(0, -1), 0.0) - Terreno3D.centro_de(CELDA_ENTRADA, 0.0)
	norte.y = 0.0
	_ok("8 sin `mira`, la entrada mira hacia dentro (al norte: allí hay suelo y al sur una pared)", ent != null and ent.dir_celda() == Vector2i(0, -1) and dir.dot(norte.normalized()) > 0.95)
	# Nivel que no existe todavía: avisa y no rompe. (24/10: el Bosque 01 v01 ya existe; la boca de la Cueva apunta, solo en esta prueba, a un nivel que no está en la tabla.)
	salida_n.destino = "Bosque_99:boca_cueva"
	colocar_jugador(Vector2i(4, 16))
	await avanzar_s(0.4)
	_ok("8 la salida nace armada si la jugadora no está encima (4,16 no es salida)", salida_n.armada and salida_n.veces == 0)
	colocar_jugador(Vector2i(4, 18))                 # pisa la boca
	await avanzar_s(0.4)
	_ok("8 pisar la boca hacia un nivel que no existe avisa por consola y en pantalla, sin cargar nada", salida_n.veces == 1 and not Niveles.en_curso and Niveles.ultimo_aviso.contains("todavía no existe") and current_scene == null, Niveles.ultimo_aviso)
	var aviso: Label = lanzador.get("_aviso") as Label
	_ok("8 y el aviso de pantalla dice que ese camino aún no lleva a ningún sitio", aviso != null and aviso.text == Niveles.TXT_SIN_NIVEL, aviso.text if aviso != null else "")
	await avanzar_s(0.4)
	_ok("8 sigue en la misma escena sin dispararse otra vez mientras no salga de la boca (se desarma)", salida_n.veces == 1 and not salida_n.armada)
	_ok("8 un destino mal escrito también avisa y no viaja", not Niveles.ir_a(maqueta, "SinDosPuntos") and not Niveles.en_curso)
	# Una salida programada a la propia Cueva: no se dispara al aparecer encima, se arma al apartarse, y al pisarla viaja de verdad.
	var viaje := SalidaNivel3D.new()
	viaje.name = "salida_prueba"
	var celda_s: Vector2i = Vector2i(6, 14)
	colocar_jugador(celda_s)
	viaje.preparar([celda_s], DESTINO_PROPIO, SalidaNivel3D.MODO_PISAR, false, maqueta)
	(maqueta.get("_props") as Node).add_child(viaje)
	await avanzar_s(0.5)
	_ok("8 una salida que nace con la jugadora encima NO se dispara (llegar junto a una salida no te devuelve)", viaje.veces == 0 and not viaje.armada and not Niveles.en_curso)
	colocar_jugador(Vector2i(4, 14))
	await avanzar_s(0.4)
	_ok("8 al apartarse se arma", viaje.armada)
	# Lo que debe viajar: oro, mochila, flags, vida.
	Estado.i().dar_oro(37)
	Estado.i().agregar("seta_asada", 2)
	Flags.i().poner("cueva.prueba.marca")
	# Un cofre con `da=`: al abrirse da su botín (oro y objetos) y avisa; la sala C4 «ya limpia» no se repuebla al volver.
	var cf := Puzle3D.CofrePuzle.new()
	cf.da = [{"que": "oro", "n": 30}, {"que": "seta_asada", "n": 2}]
	var oro_cf: int = Estado.i().oro
	var asadas_cf: int = Estado.i().cuenta("seta_asada")
	var dado: Array = cf.dar_botin()
	_ok("8 un cofre con da= da el oro y los objetos de su lista", dado.size() == 2 and Estado.i().oro == oro_cf + 30 and Estado.i().cuenta("seta_asada") == asadas_cf + 2, str(dado))
	cf.free()
	var goblins_c4: int = 0
	for g in maqueta.find_children("*", "Combate3D", true, false):
		var cg: Vector2i = Terreno3D.celda_de((g as Combate3D).casa)
		if cg.x >= 19 and cg.y <= 8:
			goblins_c4 += 1
	_ok("8 antes de limpiar C4 hay goblins en la sala (%d)" % goblins_c4, goblins_c4 >= 2)
	Flags.i().poner("cueva.c4.limpia")
	jugador.set("vida", 55.0)
	var oro: int = Estado.i().oro
	var vieja: Node = maqueta
	var seta_asadas: int = Estado.i().cuenta("seta_asada")
	colocar_jugador(celda_s)
	var max_alfa: float = await _esperar_viaje()
	await avanzar_s(0.3)
	_refrescar()
	_ok("8 pisar la salida carga el nivel: otra escena, y la vieja se ha ido", maqueta != null and maqueta != vieja and not is_instance_valid(vieja) and jugador != null)
	if jugador == null:
		return
	_ok("8 hubo fundido a negro de verdad (alfa máximo %.2f)" % max_alfa, max_alfa > 0.95)
	_ok("8 y se levantó al llegar (ya no queda el velo)", Niveles.alfa_fundido(self) < 0.0 and not Niveles.en_curso)
	var mira: Vector3 = jugador.call("mirada")
	_ok("8 la jugadora aparece en la entrada con nombre (4,17)", _celda_de(jugador) == CELDA_ENTRADA, str(_celda_de(jugador)))
	_ok("8 mirando hacia dentro (norte)", mira.dot(norte.normalized()) > 0.9, str(mira))
	_ok("8 el oro, la mochila, las flags y la vida persisten", Estado.i().oro == oro and Estado.i().cuenta("seta_asada") == seta_asadas and Flags.i().tiene("cueva.prueba.marca") and absf(float(jugador.get("vida")) - 55.0) < 0.01, "oro=%d vida=%s" % [Estado.i().oro, str(jugador.get("vida"))])
	_ok("8 su punto de reaparición es la entrada", Terreno3D.celda_de(jugador.get("puntos_inicio")) == CELDA_ENTRADA)
	# El nivel nuevo recuerda lo hecho: jarrones rotos siguen rotos (sin botín ni efecto), puerta abierta, rótulo sin repetir.
	var z2: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var zo2: Zonas3D = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	var ja: Rompible3D = z2.nodo("jarron_c1b") as Rompible3D if z2 != null else null
	var jn: Rompible3D = z2.nodo("jarron_c1a") as Rompible3D if z2 != null else null
	_ok("8 en la escena nueva los jarrones que ya se rompieron nacen rotos (solo restos), sin botín", ja != null and ja.roto_ya and ja.soltado.is_empty() and ja.n_restos() == Rompible3D.N_TROZOS and not Terreno3D.bloqueada(Vector2i(8, 14)))
	_ok("8 y el que no se rompió sigue entero", jn != null and not jn.roto_ya and Terreno3D.bloqueada(Vector2i(1, 13)))
	var pu2: Puzle3D.PuertaPuzle = z2.nodo("puerta_llave") as Puzle3D.PuertaPuzle if z2 != null else null
	_ok("8 la puerta de C6 que se abrió sigue abierta (`abierto=cueva.c6.puerta`)", pu2 != null and pu2.abierta and not Terreno3D.bloqueada(Vector2i(18, 16)))
	await avanzar_s(0.5)
	var goblins_despues: int = 0
	for g2 in maqueta.find_children("*", "Combate3D", true, false):
		var cg2: Vector2i = Terreno3D.celda_de((g2 as Combate3D).casa)
		if cg2.x >= 19 and cg2.y <= 8 and not (g2 as Combate3D).is_queued_for_deletion():
			goblins_despues += 1
	var cofre_llave: Node = z2.nodo("cofre_llave") if z2 != null else null
	var cerrojo_c4: Node = z2.nodo("entrada_c4") if z2 != null else null
	_ok("8 con la sala C4 ya limpia (flag) los goblins NO se repueblan al volver, el cofre de la llave está y el cerrojo no la cierra", goblins_despues == 0 and cofre_llave != null and not bool(cofre_llave.get("es_oculto")) and cerrojo_c4 != null and not bool(cerrojo_c4.get("cerrado")), "goblins=%d" % goblins_despues)
	_ok("8 el rótulo «La Cueva» no vuelve a salir al llegar (ya visto)", zo2 != null and zo2.rotulos_mostrados.is_empty())
	_ok("8 el diario sigue el mismo recorrido: `transicion` e `inicio_nivel`, sin una segunda `inicio_partida`", eventos("transicion").size() == 1 and eventos("inicio_nivel").size() == 1 and eventos("inicio_partida").size() == 1, "%d/%d/%d" % [eventos("transicion").size(), eventos("inicio_nivel").size(), eventos("inicio_partida").size()])
	_ok("8 y el diario apunta la zona nueva (cueva) tras llegar", PlayLog.zona == "cueva", PlayLog.zona)
	# Entrada que no existe: avisa y la jugadora se queda donde nace.
	_z = z2
	var alerta: String = ""
	Niveles.ultimo_aviso = ""
	_ok("8 un viaje a una entrada que no existe empieza (el nivel sí existe)", Niveles.ir_a(maqueta, "Cueva:no_hay_esta_entrada"))
	await _esperar_viaje()
	await avanzar_s(0.3)
	_refrescar()
	alerta = Niveles.ultimo_aviso
	_ok("8 sin la entrada pedida avisa en consola y la jugadora se queda donde nace (la S)", alerta.contains("no_hay_esta_entrada") and jugador != null and _celda_de(jugador) == CELDA_ENTRADA and not Niveles.en_curso, alerta)
