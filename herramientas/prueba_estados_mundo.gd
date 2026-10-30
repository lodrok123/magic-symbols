extends SceneTree
## F4 de PLAN_BASE_DATOS (29/10, Juego): LOS ESTADOS DEL MUNDO (calor, frío, veneno, humedad, oscuridad, tormenta, vendaval), sin escena. Comprueba:
##   (1) la tabla `estados_mundo.tsv` trae las columnas numéricas que lee el código;  (2) `EstadoZona3D` lee las líneas `; zona … estado=…` del mapa (la última declarada manda, los
##   dinámicos se suman, una nube da `veneno`) y avisa al cruzar de zona (y rellena `Sintesis.estados_zona`);  (3) el AGUANTE de la jugadora baja y sube con los números de la tabla y a 0 quita
##   vida;  (4) la PROTECCIÓN por consumible, por prenda, por estar mojada y por un brasero;  (5) el suelo: el mojado se seca en 6 s con calor, se hiela solo en 5 s con frío y el hielo dura 1/3 o casi
##   no caduca (también el del agua);  (6) la NUBE DE VENENO envenena, el viento la mueve y la dispersa, el fuego la consume, y los inmunes (antídoto, capucha) no se envenenan;  (7) la TORMENTA solo
##   cae en casillas mojadas cercanas;  (8) el VENDAVAL empuja salvo tras un muro y cambia de dirección;  (9) `factor_persiste`, `viento_zona`, `iluminar`/`iluminada`;  (10) `a_dic`/`desde_dic`
##   (y la sección `mundo` de la partida);  (11) los enemigos: inmunes por tipo, aguante, envenenar y oscuridad;  (12) la gramática de Puzle3D: `nube_veneno` y `zona.poner(…)`.
##   godot --headless --path . --script res://herramientas/prueba_estados_mundo.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_estados_mundo

const LADO: int = 30

var _fallos: int = 0
var _raiz: Node3D = null
var _pjs: Array = []                     ## los PjFalso (no cuelgan de nadie: se liberan al final)


## La prenda de mentira: dice que te protege de lo que le pidas.
class PjFalso extends Pj3D:
	var protege: Array = []
	func inmune_a(estado: String) -> bool:
		return protege.has(estado)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_raiz = Node3D.new()
	root.add_child(_raiz)
	_mundo_llano()
	_tabla()
	var ez: EstadoZona3D = _zonas()
	_aguante_y_proteccion(ez)
	_suelo()
	_nube(ez)
	_tormenta(ez)
	_vendaval(ez)
	_hechizos(ez)
	_guardado(ez)
	_enemigos(ez)
	_gramatica()
	_limpiar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _limpiar() -> void:
	for p in _pjs:
		if is_instance_valid(p):
			(p as Node).free()
	_raiz.free()
	NubeVeneno3D.vivas.clear()
	Terreno3D.estados.limpiar()
	Consumibles.limpiar_protecciones()
	Mundo3D.apagar_luces()
	Sintesis.estados_zona = []


## Un mapa llano de LADO×LADO con borde de pared y un muro suelto en (9, 10).
func _mundo_llano() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			if borde or (x == 9 and y == 10):
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	Terreno3D.estados.limpiar()
	Consumibles.limpiar_protecciones()
	Mundo3D.apagar_luces()


func _centro(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


# ---------------------------------------------------------------------------------------------------------------------
func _tabla() -> void:
	var calor: Dictionary = BD.estado_mundo("calor")
	var frio: Dictionary = BD.estado_mundo("frio")
	var ven: Dictionary = BD.estado_mundo("veneno")
	_ok("1 calor: aguante −10/s, 2 de vida/s, rellena 20/s, el mojado se seca ×0,3, el hielo dura ×1/3, fuego ×1,5 y hielo ×0,5",
		float(calor["aguante_s"]) == -10.0 and float(calor["dano_s"]) == 2.0 and float(calor["rellena_s"]) == 20.0 and is_equal_approx(float(calor["secado_x"]), 0.3)
		and absf(float(calor["hielo_dura_x"]) - 1.0 / 3.0) < 0.001 and float(calor["fuego_x"]) == 1.5 and float(calor["hielo_x"]) == 0.5, str(calor))
	_ok("1 frío: aguante −8/s (×2 mojada), se hiela solo a los 5 s, brasero a ≤ 2 casillas, hielo ×1,5 y fuego ×0,7",
		float(frio["aguante_s"]) == -8.0 and float(frio["mojada_x"]) == 2.0 and float(frio["hiela_sola_s"]) == 5.0 and float(frio["brasero_casillas"]) == 2.0
		and float(frio["hielo_x"]) == 1.5 and float(frio["fuego_x"]) == 0.7)
	_ok("1 veneno: 2 de vida/s, sigue 3 s, el viento la dispersa en 8 s, el fuego la consume en 4 s a 1,5 casillas",
		float(ven["dano_s"]) == 2.0 and float(ven["sigue_s"]) == 3.0 and float(ven["dispersa_s"]) == 8.0 and float(ven["consume_s"]) == 4.0 and float(ven["consume_casillas"]) == 1.5)
	var osc: Dictionary = BD.estado_mundo("oscuridad")
	var tor: Dictionary = BD.estado_mundo("tormenta")
	var vend: Dictionary = BD.estado_mundo("vendaval")
	_ok("1 oscuridad: 4 casillas (ella) y 3 (ellos), ilumina 10 s a 3 casillas · tormenta: un rayo cada 6 s a ≤ 6, 60 s, rayo ×1,5 · vendaval: empuja 0,5 casillas/s, cambia cada 20 s, viento ×2",
		float(osc["vista_casillas"]) == 4.0 and float(osc["vista_enemigo_casillas"]) == 3.0 and float(osc["ilumina_s"]) == 10.0 and float(osc["ilumina_casillas"]) == 3.0
		and float(tor["rayo_cada_s"]) == 6.0 and float(tor["rayo_casillas"]) == 6.0 and float(tor["dura_s"]) == 60.0 and float(tor["rayo_x"]) == 1.5
		and float(vend["empuje"]) == 0.5 and float(vend["viento_cambia_s"]) == 20.0 and float(vend["viento_x"]) == 2.0)
	_ok("1 las columnas de texto siguen siendo texto y `-` es 0", String(calor["jugadora"]).begins_with("aguante baja") and float(BD.estado_mundo("resonancia")["aguante_s"]) == 0.0 and BD.errores().is_empty(), str(BD.errores()))


# ---------------------------------------------------------------------------------------------------------------------
func _zonas() -> EstadoZona3D:
	var ez := EstadoZona3D.new()
	_raiz.add_child(ez)
	ez.leer_texto("""; zona 0,0..9,9 volcan estado=calor
; zona 5,5..9,9 hielo estado=frio,oscuridad
; zona 20,0..25,5 bosque
; zona 0,20..4,24 bosque estado=lava_inventada
; zona 0,0..1,1 bosque
; zona 12,12..14,14 volcan estado=calor,veneno,humedad
esto no es una zona
; zona mal estado=calor""")
	_ok("2 `estado=` se lee de las mismas líneas `; zona`: calor en (3,3)", ez.estados_en(Vector2i(3, 3)) == ["calor"], str(ez.estados_en(Vector2i(3, 3))))
	_ok("2 manda la ÚLTIMA declarada: en (6,6) solo frío y oscuridad (no el calor de debajo)", ez.estados_en(Vector2i(6, 6)) == ["frio", "oscuridad"], str(ez.estados_en(Vector2i(6, 6))))
	_ok("2 una zona posterior SIN estados tapa la de debajo: (0,0) sin nada", ez.estados_en(Vector2i(0, 0)).is_empty())
	_ok("2 fuera de todas, nada", ez.estados_en(Vector2i(28, 28)).is_empty() and ez.estados_en(Vector2i(22, 2)).is_empty())
	_ok("2 un estado que no existe avisa y se descarta; una línea mala no rompe nada", ez.avisos.size() == 1 and ez.estados_en(Vector2i(2, 22)).is_empty(), str(ez.avisos))
	_ok("2 varios estados en la misma zona", ez.estados_en(Vector2i(13, 13)) == ["calor", "veneno", "humedad"], str(ez.estados_en(Vector2i(13, 13))))
	# dinámicos
	_ok("2 un dinámico se pone y vale en todo el mapa", ez.poner("tormenta", 60.0) and ez.estados_en(Vector2i(28, 28)) == ["tormenta"] and ez.estados_en(Vector2i(3, 3)) == ["calor", "tormenta"])
	_ok("2 y se quita", ez.quitar("tormenta") and ez.estados_en(Vector2i(28, 28)).is_empty() and not ez.quitar("tormenta"))
	ez.poner("oscuridad", 0.0, {"rect": Rect2i(25, 25, 3, 3)})
	_ok("2 con `rect` solo vale ahí", ez.estados_en(Vector2i(26, 26)) == ["oscuridad"] and ez.estados_en(Vector2i(10, 20)).is_empty())
	ez.quitar("oscuridad")
	_ok("2 el veneno no se pone a mano (es de las nubes) ni un estado inventado", not ez.poner("veneno") and not ez.poner("nada_de_nada"))
	var viejo: Array = ez.avisos.duplicate()
	ez.avisos.clear()
	_ok("2 `Mundo3D.estado_zona` delega y sin nodo devuelve []", Mundo3D.estado_zona(Vector2i(3, 3)) == ["calor"])
	ez.avisos = viejo
	# cruzar
	var quien := Node3D.new()
	_raiz.add_child(quien)
	ez.jugador = quien
	var cambios: Array = []
	ez.estado_zona_cambio.connect(func(entrando: Array, saliendo: Array) -> void: cambios.append([entrando, saliendo]))
	quien.position = _centro(Vector2i(3, 3))
	ez.avanzar(0.1)
	_ok("2 al entrar en calor sale `estado_zona_cambio([calor], [])` y se rellena Sintesis.estados_zona", cambios == [[["calor"], []]] and Sintesis.estados_zona == ["calor"], str(cambios) + str(Sintesis.estados_zona))
	ez.avanzar(0.1)
	_ok("2 quedarse quieto no avisa otra vez", cambios.size() == 1)
	quien.position = _centro(Vector2i(6, 6))
	ez.avanzar(0.1)
	_ok("2 pasar a frío+oscuridad avisa lo que entra y lo que sale", cambios.size() == 2 and cambios[1] == [["frio", "oscuridad"], ["calor"]] and Sintesis.estados_zona == ["frio", "oscuridad"], str(cambios))
	_ok("2 `Mundo3D.estados_jugadora` lee la celda de la jugadora", Mundo3D.estados_jugadora() == ["frio", "oscuridad"])
	quien.position = _centro(Vector2i(28, 28))
	ez.avanzar(0.1)
	_ok("2 y al salir de todo, nada y `Sintesis.estados_zona` vacía", cambios.size() == 3 and cambios[2] == [[], ["frio", "oscuridad"]] and Sintesis.estados_zona.is_empty())
	Sintesis.estados_zona = []
	ez.jugador = null
	quien.queue_free()
	return ez


# ---------------------------------------------------------------------------------------------------------------------
func _jugadora(c: Vector2i, protege: Array = []) -> Jugador3D:
	var j := Jugador3D.new()
	_raiz.add_child(j)
	j.mundo = _raiz
	j.position = _centro(c)
	if not protege.is_empty():
		var p := PjFalso.new()
		p.protege = protege
		_pjs.append(p)
		j.pj = p
	return j


func _pasos(j: Jugador3D, zona: Array, segundos: float, dt: float = 0.1) -> void:
	for _i in range(int(round(segundos / dt))):
		j._actualizar_aguante(dt, zona)


func _aguante_y_proteccion(ez: EstadoZona3D) -> void:
	# la cuenta pura
	var r: Dictionary = EstadoZona3D.paso_aguante(100.0, 1.0, ["calor"], {}, false)
	_ok("3 paso_aguante: calor baja 10 en 1 s", is_equal_approx(float(r["valor"]), 90.0) and bool(r["baja"]) and bool(r["en_zona"]) and float(r["dano"]) == 0.0, str(r))
	r = EstadoZona3D.paso_aguante(100.0, 1.0, ["frio"], {}, false)
	_ok("3 frío baja 8", is_equal_approx(float(r["valor"]), 92.0))
	r = EstadoZona3D.paso_aguante(100.0, 1.0, ["frio"], {}, true)
	_ok("3 frío y mojada baja el doble: 16", is_equal_approx(float(r["valor"]), 84.0))
	r = EstadoZona3D.paso_aguante(100.0, 1.0, ["calor"], {}, true)
	_ok("3 el calor no cuenta la mojada (×mojada_x es del frío)", is_equal_approx(float(r["valor"]), 90.0))
	r = EstadoZona3D.paso_aguante(5.0, 1.0, ["calor"], {}, false)
	_ok("3 a 0 quita 2 de vida por segundo", is_equal_approx(float(r["valor"]), 0.0) and is_equal_approx(float(r["dano"]), 2.0), str(r))
	r = EstadoZona3D.paso_aguante(30.0, 1.0, [], {}, false)
	_ok("3 fuera de todo sube 20/s (y no pasa de 100)", is_equal_approx(float(r["valor"]), 50.0) and not bool(r["en_zona"]) and is_equal_approx(float(EstadoZona3D.paso_aguante(95.0, 1.0, [], {}, false)["valor"]), 100.0))
	r = EstadoZona3D.paso_aguante(50.0, 1.0, ["calor"], {"calor": true}, false)
	_ok("3 protegida del calor no baja: se recupera", float(r["valor"]) > 50.0 and not bool(r["baja"]) and bool(r["en_zona"]), str(r))
	r = EstadoZona3D.paso_aguante(100.0, 1.0, ["calor", "frio"], {}, false)
	_ok("3 calor y frío a la vez suman: −18", is_equal_approx(float(r["valor"]), 82.0))
	r = EstadoZona3D.paso_aguante(100.0, 1.0, ["veneno", "oscuridad", "tormenta"], {}, false)
	_ok("3 veneno, oscuridad y tormenta no tocan el aguante", is_equal_approx(float(r["valor"]), 100.0) and not bool(r["en_zona"]))

	# la jugadora de verdad (sin cuerpo): 3 s de calor
	var j: Jugador3D = _jugadora(Vector2i(3, 3))
	var avisos: Array = []
	j.aguante_cambio.connect(func(v: float, a: bool) -> void: avisos.append([v, a]))
	_pasos(j, ["calor"], 3.0)
	_ok("3 Jugador3D: 3 s de calor sin protección → aguante 70", absf(j.aguante - 70.0) < 0.01, "%.2f" % j.aguante)
	_ok("3 y avisa a la barra (valor y activo)", not avisos.is_empty() and bool(avisos[avisos.size() - 1][1]) and absf(float(avisos[avisos.size() - 1][0]) - 70.0) < 0.2, str(avisos.slice(-2)))
	_ok("3 sin tocar la vida mientras queda aguante", is_equal_approx(j.vida, 100.0))
	_pasos(j, ["calor"], 9.0)
	var perdida: float = 100.0 - j.vida
	_ok("3 a 0 quita ≈ 2 de vida por segundo (12 s en total: 10 hasta vaciar + 2 → ≈ 4 de vida)", j.aguante == 0.0 and perdida >= 3.0 and perdida <= 4.01, "aguante %.2f, perdió %.2f" % [j.aguante, perdida])
	_pasos(j, [], 5.0)
	_ok("3 fuera de todo sube 20/s: en 5 s vuelve a 100", is_equal_approx(j.aguante, 100.0), "%.2f" % j.aguante)
	var apagada: bool = false
	j.aguante_cambio.connect(func(_v: float, a: bool) -> void: apagada = not a)
	_pasos(j, [], 0.2)
	_ok("3 con 100 y sin estado la barra se oculta (activo = false)", not j.aguante_activo)
	j.vida = 100.0
	j.aguante = 100.0
	_pasos(j, ["frio"], 2.0)
	_ok("3 frío: −16 en 2 s", absf(j.aguante - 84.0) < 0.01, "%.2f" % j.aguante)
	j.aguante = 100.0
	Terreno3D.estados.poner(Terreno3D.celda_de(j.position), "mojada", true)
	_pasos(j, ["frio"], 2.0)
	_ok("3 frío mojada (no existe «congelado» de personaje): el aguante baja el doble, −32 en 2 s", absf(j.aguante - 68.0) < 0.01, "%.2f" % j.aguante)

	# protección
	Terreno3D.estados.limpiar()
	Consumibles.limpiar_protecciones()
	j.aguante = 100.0
	_ok("4 sin nada, no estás protegida ni del calor ni del frío ni del veneno", not j.protegida("calor") and not j.protegida("frio") and not j.protegida("veneno"))
	Consumibles.resistencias["calor"] = 90.0
	_pasos(j, ["calor"], 3.0)
	_ok("4 el frescor (resiste=calor, 90 s) deja cruzar el calor sin perder aguante ni vida", j.protegida("calor") and j.aguante >= 100.0 - 0.01 and is_equal_approx(j.vida, 100.0), "%.2f" % j.aguante)
	Consumibles.limpiar_protecciones()
	Consumibles.resistencias["frio"] = 90.0
	_ok("4 el abrigo protege del frío, no del calor", j.protegida("frio") and not j.protegida("calor"))
	Consumibles.limpiar_protecciones()
	Consumibles.inmunidades["veneno"] = 60.0
	_ok("4 el antídoto (inmune=veneno) protege del veneno", j.protegida("veneno"))
	Consumibles.limpiar_protecciones()
	var jp: Jugador3D = _jugadora(Vector2i(3, 3), ["calor"])
	jp.aguante = 100.0
	_pasos(jp, ["calor"], 3.0)
	_ok("4 la túnica de salamandra (prenda `inmune=calor`) protege del calor, no del frío", jp.protegida("calor") and not jp.protegida("frio") and jp.aguante >= 99.99)
	# mojada / pisar agua
	_ok("4 una casilla seca no protege", not j.protegida("calor"))
	Terreno3D.estados.poner(Terreno3D.celda_de(j.position), "mojada", true)
	j.aguante = 100.0
	_pasos(j, ["calor"], 3.0)
	_ok("4 estar mojada (casilla mojada bajo los pies) protege del calor", j.protegida("calor") and not j.protegida("frio") and j.aguante >= 99.99, "%.2f" % j.aguante)
	Terreno3D.estados.limpiar()
	j.nadando = true
	_ok("4 nadar (pisar agua) también", j.protegida("calor"))
	j.nadando = false
	# brasero
	var b := Reactivo3D.new()
	b.preparar("brasero", Vector2i(3, 4), "", null, null)
	_raiz.add_child(b)
	b.is_lit = false
	j.refrescar_brasero()
	_ok("4 un brasero APAGADO a una casilla no protege del frío", not j.protegida("frio"))
	b.is_lit = true
	j.refrescar_brasero()
	_ok("4 encendido a 1 casilla, sí", j.protegida("frio") and not j.protegida("calor"))
	j.position = _centro(Vector2i(3, 8))
	j.refrescar_brasero()
	_ok("4 a 4 casillas ya no", not j.protegida("frio"))
	j.position = _centro(Vector2i(3, 6))
	j.refrescar_brasero()
	_ok("4 a 2 casillas aún (el radio es ≤ 2)", j.protegida("frio"))
	j.aguante = 50.0
	_pasos(j, ["frio"], 1.0)
	_ok("4 junto al brasero el aguante se rellena en el frío", j.aguante > 50.0, "%.2f" % j.aguante)
	b.is_lit = false
	b.queue_free()
	for x in [j, jp]:
		x.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _suelo() -> void:
	Terreno3D.estados.limpiar()
	ReaccionesSuelo3D.clasificar = func(_c: Vector2i) -> String: return "suelo"
	var zona := func(c: Vector2i) -> Array:
		if c.x < 10:
			return ["calor"]
		if c.x < 20:
			return ["frio"]
		return []
	var e := EstadosSuelo3D.new()
	var sin := EstadosSuelo3D.new()
	for est in [e, sin]:
		(est as EstadosSuelo3D).poner(Vector2i(1, 1), "mojada", true)
		(est as EstadosSuelo3D).poner(Vector2i(25, 1), "mojada", true)
	e.estado_zona_en = zona
	_pasar(e, 5.9)
	_ok("5 calor: a los 5,9 s el mojado aún está (se seca en 6)", e.tiene(Vector2i(1, 1), "mojada"))
	_pasar(e, 0.4)
	_ok("5 calor: pasados los 6 s se ha secado (20 s ÷ 3,3), fuera de la zona sigue", not e.tiene(Vector2i(1, 1), "mojada") and e.tiene(Vector2i(25, 1), "mojada"))
	_pasar(sin, 6.3)
	_ok("5 sin callback conectado todo es como siempre: a los 6 s sigue mojado", sin.tiene(Vector2i(1, 1), "mojada"))
	# hielo con caducidad
	e.poner(Vector2i(2, 2), "helada", true, 1.0, 20.0)
	e.poner(Vector2i(12, 2), "helada", true, 1.0, 20.0)
	e.poner(Vector2i(25, 2), "helada", true, 1.0, 20.0)
	_pasar(e, 7.0)
	_ok("5 el hielo dura 1/3 con calor (20 s → 6,7 s) y lo normal fuera", not e.tiene(Vector2i(2, 2), "helada") and e.tiene(Vector2i(25, 2), "helada"))
	_pasar(e, 14.0)
	_ok("5 en el frío el helado casi no caduca (a los 21 s sigue) y fuera de la zona sí", e.tiene(Vector2i(12, 2), "helada") and not e.tiene(Vector2i(25, 2), "helada"))
	# se hiela solo
	e.poner(Vector2i(14, 5), "mojada", true)
	e.poner(Vector2i(4, 5), "mojada", true)
	_pasar(e, 4.9)
	_ok("5 frío: a los 4,9 s el mojado aún no se ha helado", e.tiene(Vector2i(14, 5), "mojada") and not e.tiene(Vector2i(14, 5), "helada"))
	_pasar(e, 0.3)
	_ok("5 frío: a los 5 s se hiela sola (mojada → helada, escarcha de suelo)", not e.tiene(Vector2i(14, 5), "mojada") and e.tiene(Vector2i(14, 5), "helada") and e.es_escarcha(Vector2i(14, 5)))
	_ok("5 y en calor no se hiela", not e.tiene(Vector2i(4, 5), "helada"))
	# el hielo del agua
	var agua := AguaSim3D.new()
	agua.configurar(LADO, LADO, 3, 2.3, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	var ez: EstadoZona3D = EstadoZona3D.actual
	ez.zonas.clear()
	ez.leer_texto("; zona 0,0..9,9 volcan estado=calor\n; zona 10,0..19,9 hielo estado=frio")
	agua.factor_hielo_dura = EstadoZona3D.factor_hielo_dura
	for c in [Vector2i(2, 2), Vector2i(12, 2), Vector2i(25, 2)]:
		agua.helar_casilla(c, true)
	_ok("5 los tres hielos del agua nacen helados", agua.hielo_en(_centro(Vector2i(2, 2))) > -1.0e6 and agua.hielo_en(_centro(Vector2i(25, 2))) > -1.0e6)
	for _i in range(int(7.0 * 30.0)):
		agua.paso(1.0 / 30.0)
	_ok("5 el hielo del agua en calor se suelta a ≈ 6,7 s; fuera de la zona sigue", agua.hielo_en(_centro(Vector2i(2, 2))) < -1.0e6 and agua.hielo_en(_centro(Vector2i(25, 2))) > -1.0e6 and agua.hielo_en(_centro(Vector2i(12, 2))) > -1.0e6)
	for _i in range(int(14.0 * 30.0)):
		agua.paso(1.0 / 30.0)
	_ok("5 a los 21 s: el de fuera de la zona ya se soltó, el del frío sigue", agua.hielo_en(_centro(Vector2i(25, 2))) < -1.0e6 and agua.hielo_en(_centro(Vector2i(12, 2))) > -1.0e6)
	_ok("5 `Mundo3D.factor_hielo_dura`: calor 1/3, frío ×100, fuera 1", absf(Mundo3D.factor_hielo_dura(Vector2i(2, 2)) - 1.0 / 3.0) < 0.001 and Mundo3D.factor_hielo_dura(Vector2i(12, 2)) == 100.0 and Mundo3D.factor_hielo_dura(Vector2i(25, 2)) == 1.0)
	ez.zonas.clear()
	ReaccionesSuelo3D.clasificar = Callable()


func _pasar(e: EstadosSuelo3D, s: float) -> void:
	for _i in range(int(round(s / 0.1))):
		e.avanzar(0.1)


# ---------------------------------------------------------------------------------------------------------------------
func _runa(nombre: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % nombre) as RuneData


func _nube(ez: EstadoZona3D) -> void:
	Consumibles.limpiar_protecciones()
	var c0 := Vector2i(15, 15)
	var j: Jugador3D = _jugadora(c0)
	var n: NubeVeneno3D = NubeVeneno3D.crear(_raiz, _centro(c0), 30.0, 1.0, j)
	_ok("6 la nube se registra y una casilla bajo ella tiene `veneno`", NubeVeneno3D.vivas.has(n) and ez.estados_en(c0).has("veneno") and not ez.estados_en(Vector2i(22, 22)).has("veneno"), str(ez.estados_en(c0)))
	_ok("6 `Mundo3D.estado_zona` también", Mundo3D.estado_zona(c0).has("veneno"))
	n.avanzar(0.1)
	_ok("6 la nube envenena a la jugadora que está dentro", j.tiene_estado("veneno") and n.envenenadas > 0)
	var antes: float = j.vida
	_ok("6 con la fila `veneno` de la tabla: 2 de vida/s y 3 s de seguimiento", is_equal_approx(j._veneno_dps, 2.0) and j._veneno_t > 2.5 and j._veneno_t <= 3.0, "%.2f dps, %.2f s" % [j._veneno_dps, j._veneno_t])
	_ok("6 la vida no ha cambiado todavía (el pulso lo da el _process de la jugadora)", is_equal_approx(j.vida, antes))
	j.curar_estado("veneno")
	# inmunidades
	Consumibles.inmunidades["veneno"] = 60.0
	n.avanzar(0.1)
	_ok("6 el antídoto activo: la nube no la envenena", not j.tiene_estado("veneno") and j.protegida("veneno"))
	Consumibles.limpiar_protecciones()
	var jc: Jugador3D = _jugadora(c0, ["veneno"])
	n.jugador = jc
	n.avanzar(0.1)
	_ok("6 la capucha de musgo (prenda `inmune=veneno`): tampoco", not jc.tiene_estado("veneno"))
	n.jugador = j
	n.avanzar(0.1)
	_ok("6 sin protección vuelve a envenenar", j.tiene_estado("veneno"))
	j.curar_estado("veneno")
	j.position = _centro(Vector2i(22, 22))
	n.avanzar(0.1)
	_ok("6 fuera de la nube no envenena", not j.tiene_estado("veneno"))
	_ok("6 la nube reacciona al viento y al fuego, no al agua", n.spell_reacts(_runa("wind"), Vector3.RIGHT) and n.spell_reacts(_runa("fire"), Vector3.RIGHT) and not n.spell_reacts(_runa("water"), Vector3.RIGHT))
	# viento
	var x0: float = n.position.x
	n.on_spell_hit(_runa("wind"), Vector3(1, 0, 0))
	n.avanzar(1.2)
	_ok("6 el viento la empuja en su dirección (≈ +1,7 u) y la dispersa: su vida baja a 8 s", n.position.x - x0 > 1.4 and n.position.x - x0 < 1.9 and n.vida <= 8.0 and n.vida > 6.0, "dx %.2f, vida %.2f" % [n.position.x - x0, n.vida])
	n.avanzar(5.5)
	_ok("6 a los 6,7 s de soplo aún queda un resto de nube (< 1,5 s)", NubeVeneno3D.vivas.has(n) and n.vida > 0.0 and n.vida < 1.5, "%.2f" % n.vida)
	n.avanzar(1.5)
	_ok("6 …y a los 8 s se ha dispersado: ya no está registrada ni da `veneno`", not NubeVeneno3D.vivas.has(n) and not NubeVeneno3D.cubre(Vector2i(c0.x + 1, c0.y)))
	# fuego
	var n2: NubeVeneno3D = NubeVeneno3D.crear(_raiz, _centro(c0), 30.0, 1.0, j)
	n2.on_spell_hit(_runa("fire"), Vector3.RIGHT)
	_ok("6 el fuego la consume: su vida baja a 4 s", n2.ardiendo and n2.vida <= 4.0, "%.2f" % n2.vida)
	n2.avanzar(3.9)
	_ok("6 aún dura a los 3,9 s", NubeVeneno3D.vivas.has(n2))
	n2.avanzar(0.3)
	_ok("6 y a los 4 s se ha consumido", not NubeVeneno3D.vivas.has(n2))
	# fuego por el suelo, a 1,5 casillas
	var cerca: NubeVeneno3D = NubeVeneno3D.crear(_raiz, _centro(Vector2i(18, 15)), 30.0, 0.5, j)
	var lejos: NubeVeneno3D = NubeVeneno3D.crear(_raiz, _centro(Vector2i(26, 15)), 30.0, 0.5, j)
	Terreno3D.estados.poner(Vector2i(17, 15), "quemada", true)       # una casilla que prende
	_ok("6 una casilla que prende a ≤ 1,5 casillas quema la nube (4 s) y la lejana ni se entera", cerca.ardiendo and cerca.vida <= 4.0 and not lejos.ardiendo and lejos.vida > 20.0, "cerca %s %.1f, lejos %s" % [cerca.ardiendo, cerca.vida, lejos.ardiendo])
	cerca.retirar()
	lejos.retirar()
	Terreno3D.estados.limpiar()
	# permanente
	var perm: NubeVeneno3D = NubeVeneno3D.crear(_raiz, _centro(Vector2i(8, 20)), 0.0, 1.0)
	perm.avanzar(100.0)
	_ok("6 una nube con vida 0 es permanente hasta que el viento o el fuego la quiten", NubeVeneno3D.vivas.has(perm) and perm.permanente)
	perm.on_spell_hit(_runa("wind"), Vector3.RIGHT)
	_ok("6 …y el viento la deja mortal", not perm.permanente and perm.vida <= 8.0)
	perm.retirar()
	for x in [j, jc]:
		x.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _tormenta(ez: EstadoZona3D) -> void:
	Terreno3D.estados.limpiar()
	var quien := Node3D.new()
	_raiz.add_child(quien)
	quien.position = _centro(Vector2i(15, 15))
	ez.jugador = quien
	ez.rng.seed = 7
	ez.rayos.clear()
	_ok("7 sin casillas mojadas el rayo no cae en ningún sitio", ez.caer_rayo() == Vector2i(-1, -1))
	for c in [Vector2i(16, 15), Vector2i(17, 17), Vector2i(15, 10), Vector2i(28, 28), Vector2i(2, 2)]:
		Terreno3D.estados.poner(c, "mojada", true)
	Terreno3D.estados.poner(Vector2i(15, 14), "quemada", true)           # una casilla seca cerca: nunca
	var cerca: Array = [Vector2i(16, 15), Vector2i(17, 17), Vector2i(15, 10)]
	var todos_bien: bool = true
	var vistos: Dictionary = {}
	for _i in range(60):
		var c: Vector2i = ez.caer_rayo(6.0)
		vistos[c] = true
		todos_bien = todos_bien and cerca.has(c)
	_ok("7 el rayo solo cae en casillas MOJADAS a ≤ 6 casillas (nunca en las secas ni en las lejanas) y reparte", todos_bien and vistos.size() >= 2, str(vistos.keys()))
	_ok("7 deja la casilla `electrificada` 0,6 s (la descarga del charco)", Terreno3D.estados.tiene(ez.rayos[0], "electrificada") and absf(Terreno3D.estados.queda(ez.rayos[0], "electrificada") - 0.6) < 0.001)
	Terreno3D.estados.avanzar(0.7)
	_ok("7 y a los 0,7 s se acaba", Terreno3D.estados.cuantas("electrificada") == 0)
	# por el reloj: cada 6 s
	ez.rayos.clear()
	ez.poner("tormenta", 60.0)
	ez.avanzar(5.9)
	_ok("7 el rayo del reloj: a los 5,9 s aún no ha caído", ez.rayos.is_empty())
	ez.avanzar(0.2)
	_ok("7 a los 6 s cae uno", ez.rayos.size() == 1)
	ez.avanzar(6.0)
	_ok("7 y otro 6 s después", ez.rayos.size() == 2)
	var caidos: Array = []
	ez.rayo_cayo.connect(func(c: Vector2i) -> void: caidos.append(c))
	ez.avanzar(6.0)
	_ok("7 cada rayo emite `rayo_cayo` para el Pipeline", caidos.size() == 1)
	ez.avanzar(50.0)
	_ok("7 la tormenta dura 60 s y se acaba sola", not ez.dinamicos.has("tormenta") and ez.estados_en(Vector2i(28, 28)).is_empty())
	ez.jugador = null
	quien.queue_free()
	Terreno3D.estados.limpiar()


# ---------------------------------------------------------------------------------------------------------------------
func _vendaval(ez: EstadoZona3D) -> void:
	ez.zonas.clear()
	ez.poner("vendaval", 0.0, {"direccion": Vector2i(1, 0)})
	var c: Vector2i = Vector2i(10, 10)
	var v: Vector3 = ez.viento_en(c)
	_ok("8 el viento empuja 0,5 casillas/s hacia el este (1,15 u/s)", absf(v.x - 0.5 * Terreno3D.casilla) < 0.001 and v.z == 0.0, str(v))
	var j: Jugador3D = _jugadora(Vector2i(12, 10))
	j.en_suelo = true
	j.nadando = false
	var p: Vector3 = j._viento_paso(0.5, ["vendaval"])
	_ok("8 Jugador3D._viento_paso: la mueve ≈ 0,29 u en 0,5 s hacia el este", absf(p.x - 0.5 * 0.5 * Terreno3D.casilla) < 0.001 and p.z == 0.0, str(p))
	j.position = _centro(Vector2i(10, 10))
	_ok("8 hay un muro en (9,10): con viento del este, la casilla (10,10) está a resguardo y NO la empuja", Terreno3D.bloqueada(Vector2i(9, 10)) and j._viento_paso(0.5, ["vendaval"]) == Vector3.ZERO)
	ez.poner("vendaval", 0.0, {"direccion": Vector2i(-1, 0)})
	_ok("8 con viento del oeste la casilla de barlovento (11,10) está libre y la empuja hacia el oeste", j._viento_paso(0.5, ["vendaval"]).x < 0.0)
	ez.poner("vendaval", 0.0, {"direccion": Vector2i(1, 0)})
	j.position = _centro(Vector2i(12, 10))
	_ok("8 tres casillas más allá, sí", j._viento_paso(0.5, ["vendaval"]).x > 0.0)
	j.nadando = true
	_ok("8 nadando no la empuja", j._viento_paso(0.5, ["vendaval"]) == Vector3.ZERO)
	j.nadando = false
	j.en_suelo = false
	_ok("8 en el aire tampoco", j._viento_paso(0.5, ["vendaval"]) == Vector3.ZERO)
	j.en_suelo = true
	_ok("8 sin vendaval en la zona, nada", j._viento_paso(0.5, []) == Vector3.ZERO)
	# bloque de tierra: más alto a barlovento
	Terreno3D.alturas[Vector2i(11, 10)] = 1
	_ok("8 un bloque de tierra a barlovento también la resguarda", j._viento_paso(0.5, ["vendaval"]) == Vector3.ZERO)
	Terreno3D.alturas.erase(Vector2i(11, 10))
	# cambia cada 20 s
	var d0: Vector2i = ez.direccion_viento(c)
	ez.avanzar(19.9)
	_ok("8 a los 19,9 s la dirección es la misma", ez.direccion_viento(c) == d0)
	ez.avanzar(0.2)
	_ok("8 a los 20 s gira (este → sur)", ez.direccion_viento(c) == Vector2i(0, 1), str(ez.direccion_viento(c)))
	ez.quitar("vendaval")
	_ok("8 sin vendaval no hay viento", ez.viento_en(c) == Vector3.ZERO and ez.direccion_viento(c) == Vector2i.ZERO)
	j.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _hechizos(ez: EstadoZona3D) -> void:
	ez.zonas.clear()
	ez.dinamicos.clear()
	ez.leer_texto("""; zona 0,0..9,9 volcan estado=calor
; zona 10,0..19,9 hielo estado=frio
; zona 0,10..9,19 pantano estado=humedad
; zona 10,10..19,19 bosque""")
	var calor := Vector2i(2, 2)
	var frio := Vector2i(12, 2)
	var hum := Vector2i(2, 12)
	var fuera := Vector2i(12, 12)
	_ok("9 calor: fuego ×1,5, hielo ×0,5", is_equal_approx(Mundo3D.factor_persiste("fuego", calor), 1.5) and is_equal_approx(Mundo3D.factor_persiste("hielo", calor), 0.5))
	_ok("9 frío: hielo ×1,5, fuego ×0,7", is_equal_approx(Mundo3D.factor_persiste("hielo", frio), 1.5) and is_equal_approx(Mundo3D.factor_persiste("fuego", frio), 0.7))
	_ok("9 humedad: fuego ×0,7, rayo ×1,5", is_equal_approx(Mundo3D.factor_persiste("fuego", hum), 0.7) and is_equal_approx(Mundo3D.factor_persiste("rayo", hum), 1.5))
	_ok("9 fuera de todo y para el agua o la tierra: 1", Mundo3D.factor_persiste("fuego", fuera) == 1.0 and Mundo3D.factor_persiste("agua", calor) == 1.0 and Mundo3D.factor_persiste("tierra", frio) == 1.0)
	ez.poner("tormenta", 60.0)
	_ok("9 tormenta: rayo ×1,5 en todas partes (×2,25 en el pantano)", is_equal_approx(Mundo3D.factor_persiste("rayo", fuera), 1.5) and is_equal_approx(Mundo3D.factor_persiste("rayo", hum), 2.25))
	ez.quitar("tormenta")
	ez.poner("vendaval", 0.0, {"direccion": Vector2i(1, 0)})
	_ok("9 vendaval: el viento lanzado A FAVOR dura el doble; en contra o sin dirección, igual",
		is_equal_approx(Mundo3D.factor_persiste("viento", fuera, Vector3(1, 0, 0)), 2.0) and Mundo3D.factor_persiste("viento", fuera, Vector3(-1, 0, 0)) == 1.0 and Mundo3D.factor_persiste("viento", fuera) == 1.0)
	var vz: Vector3 = Mundo3D.viento_zona(fuera)
	_ok("9 `Mundo3D.viento_zona` = dirección × empuje × casilla; fuera del vendaval, cero", absf(vz.x - 1.15) < 0.001 and Mundo3D.viento_zona(fuera) == vz)
	ez.quitar("vendaval")
	_ok("9 sin vendaval, viento_zona es cero", Mundo3D.viento_zona(fuera) == Vector3.ZERO)
	# luz
	Mundo3D.apagar_luces()
	var c := Vector2i(5, 5)
	_ok("9 nada está iluminado de entrada", not Mundo3D.iluminada(c))
	Mundo3D.iluminar(c)
	_ok("9 iluminar(c) enciende c y su entorno de 3 casillas", Mundo3D.iluminada(c) and Mundo3D.iluminada(Vector2i(8, 5)) and Mundo3D.iluminada(Vector2i(7, 7)) and not Mundo3D.iluminada(Vector2i(9, 5)))
	Mundo3D.avanzar_iluminadas(9.9)
	_ok("9 dura 10 s", Mundo3D.iluminada(c))
	Mundo3D.avanzar_iluminadas(0.2)
	_ok("9 y luego se apaga", not Mundo3D.iluminada(c))
	Mundo3D.iluminar(c, 2.0)
	Mundo3D.iluminar(c, 1.0)
	Mundo3D.avanzar_iluminadas(1.5)
	_ok("9 volver a iluminar alarga, no acorta", Mundo3D.iluminada(c))
	Mundo3D.apagar_luces()


# ---------------------------------------------------------------------------------------------------------------------
func _guardado(ez: EstadoZona3D) -> void:
	ez.zonas.clear()
	for n in NubeVeneno3D.vivas.duplicate():
		(n as NubeVeneno3D).retirar()
	ez.dinamicos.clear()
	ez.poner("tormenta", 60.0)
	ez.avanzar(10.0)
	ez.poner("vendaval", 0.0, {"direccion": Vector2i(0, 1), "rect": Rect2i(3, 4, 5, 6)})
	var nube: NubeVeneno3D = NubeVeneno3D.crear(_raiz, _centro(Vector2i(7, 7)), 5.0, 1.5)
	nube.avanzar(1.0)
	var d: Dictionary = ez.a_dic()
	var viaje: Variant = JSON.parse_string(JSON.stringify(d))
	_ok("10 a_dic sobrevive a JSON: tormenta con ≈ 50 s, vendaval con rect y dirección, y la nube con su posición y vida",
		viaje is Dictionary and (viaje["dinamicos"]["tormenta"]["restante"] as float) > 49.0 and (viaje["dinamicos"]["tormenta"]["restante"] as float) < 50.1 and (viaje["nubes"] as Array).size() == 1, JSON.stringify(viaje))
	ez.dinamicos.clear()
	nube.retirar()
	_ok("10 (borrado todo)", ez.dinamicos.is_empty() and NubeVeneno3D.vivas.is_empty())
	ez.desde_dic(viaje as Dictionary)
	_ok("10 desde_dic recrea la tormenta con lo que le quedaba", ez.dinamicos.has("tormenta") and absf(float(ez.dinamicos["tormenta"]["restante"]) - 50.0) < 0.1 and not bool(ez.dinamicos["tormenta"]["sin_fin"]))
	_ok("10 …el vendaval con su rect y su dirección", ez.dinamicos.has("vendaval") and ez.dinamicos["vendaval"]["rect"] == Rect2i(3, 4, 5, 6) and ez.dinamicos["vendaval"]["direccion"] == Vector2i(0, 1) and bool(ez.dinamicos["vendaval"]["sin_fin"]))
	_ok("10 …y la nube, en su sitio, con su vida (4 s), su radio y envenenando a su casilla", NubeVeneno3D.vivas.size() == 1 and absf((NubeVeneno3D.vivas[0] as NubeVeneno3D).vida - 4.0) < 0.05 and (NubeVeneno3D.vivas[0] as NubeVeneno3D).radio == 1.5 and ez.estados_en(Vector2i(7, 7)).has("veneno"))
	_ok("10 un diccionario ilegible no rompe nada", _no_rompe(ez))
	for n in NubeVeneno3D.vivas.duplicate():
		(n as NubeVeneno3D).retirar()
	ez.dinamicos.clear()
	# la sección `mundo` de la partida
	Partida.mundo = {"Cueva": {"dinamicos": {}, "nubes": []}}
	var r: Dictionary = Partida.reunir(1, {"mundo": {"Bosque": viaje}, "aguante": 42.5, "vida": 77.0})
	_ok("10 Partida.reunir mete `extra.mundo` en la sección `mundo` sin perder la de otros niveles", (r["mundo"] as Dictionary).has("Bosque") and (r["mundo"] as Dictionary).has("Cueva") and (r["mundo"]["Bosque"]["dinamicos"] as Dictionary).has("tormenta"))
	_ok("10 y el aguante se guarda de verdad", is_equal_approx(float(r["jugadora"]["aguante"]), 42.5) and is_equal_approx(float(Partida.reunir(1, {})["jugadora"]["aguante"]), 100.0))
	Partida.mundo = {}


func _no_rompe(ez: EstadoZona3D) -> bool:
	ez.desde_dic({"dinamicos": {"tormenta": 5, "inventado": {"restante": 3}, "vendaval": {"restante": 3.0, "sin_fin": false, "direccion": "este"}}, "nubes": [3, {"pos": "x"}, {"pos": [1, 2]}]})
	return true


# ---------------------------------------------------------------------------------------------------------------------
func _enemigos(ez: EstadoZona3D) -> void:
	ez.zonas.clear()
	ez.dinamicos.clear()
	ez.leer_texto("; zona 0,0..9,9 volcan estado=calor\n; zona 10,0..19,9 hielo estado=frio\n; zona 20,0..29,9 cueva estado=oscuridad")
	var gob := Combate3D.new()
	var limo := Limo3D.new()
	var limo_f := Limo3D.new()
	limo_f.elemento = "fuego"
	var cha := Chaman3D.new()
	var gol := Golem3D.new()
	_ok("11 goblin: no es inmune a nada", not gob.inmune_a("veneno") and not gob.inmune_a("calor") and not gob.inmune_a("frio"))
	_ok("11 el limo y el chamán son inmunes al veneno; el gólem a veneno y calor", limo.inmune_a("veneno") and cha.inmune_a("veneno") and gol.inmune_a("veneno") and gol.inmune_a("calor") and not gol.inmune_a("frio"))
	_ok("11 el limo de fuego es inmune al calor; el limo sin teñir, no", limo_f.inmune_a("calor") and not limo.inmune_a("calor"))
	_ok("11 `envenenar`: el goblin sí (y se queda con lo más largo), el limo, el chamán y el gólem no", gob.envenenar(2.0, 3.0) and is_equal_approx(gob.envenenado, 3.0) and not limo.envenenar(2.0, 3.0) and not cha.envenenar(2.0, 3.0) and not gol.envenenar(2.0, 3.0) and limo.envenenado == 0.0)
	# aguante del enemigo en calor
	gob.position = _centro(Vector2i(3, 3))
	limo_f.position = _centro(Vector2i(3, 3))
	var perdido_antes: float = gob.health
	for _i in range(120):
		gob._aguante_zona(0.1)
		limo_f._aguante_zona(0.1)
	var perdida: float = perdido_antes - gob.health
	_ok("11 el goblin en el volcán se cansa igual: a 0 de aguante pierde ≈ 2 de vida/s (12 s → ≈ 4)", gob.aguante == 0.0 and perdida >= 3.0 and perdida <= 4.01, "aguante %.1f, perdió %.2f" % [gob.aguante, perdida])
	_ok("11 …y el limo de fuego ni se entera", limo_f.aguante == 100.0 and is_equal_approx(limo_f.health, limo_f.vida_max))
	gob.mojado = 5.0
	gob.aguante = 50.0
	gob._aguante_zona(1.0)
	_ok("11 mojado, el goblin está protegido del calor y se recupera", gob.protegido_de("calor") and gob.aguante > 50.0)
	gob.mojado = 0.0
	gob.aguante = 100.0
	gob.position = _centro(Vector2i(12, 3))
	gob._aguante_zona(1.0)
	_ok("11 en el frío baja 8", absf(gob.aguante - 92.0) < 0.01, "%.2f" % gob.aguante)
	gob.mojado = 3.0
	gob.aguante = 100.0
	gob._aguante_zona(1.0)
	_ok("11 …y mojado, 16", absf(gob.aguante - 84.0) < 0.01, "%.2f" % gob.aguante)
	gob.position = _centro(Vector2i(3, 25))
	gob.aguante = 40.0
	gob._aguante_zona(1.0)
	_ok("11 fuera de la zona sube 20/s", absf(gob.aguante - 60.0) < 0.01)
	# oscuridad
	gob.position = _centro(Vector2i(20, 5))
	var jug := Jugador3D.new()
	_raiz.add_child(jug)
	gob.jugador = jug
	jug.position = _centro(Vector2i(22, 5))
	_ok("11 oscuridad: ve a la jugadora a 2 casillas", gob._ve(20.0))
	jug.position = _centro(Vector2i(25, 5))
	_ok("11 oscuridad: a 5 casillas ya no la ve (solo ve a ≤ 3)", not gob._ve(20.0))
	Mundo3D.iluminar(Vector2i(25, 5))
	_ok("11 …salvo que la casilla de la jugadora esté iluminada (fuego, rayo, esporas)", gob._ve(20.0))
	Mundo3D.apagar_luces()
	gob.position = _centro(Vector2i(5, 5))
	jug.position = _centro(Vector2i(10, 5))
	_ok("11 sin oscuridad (calor) la ve a 5 casillas con su radio normal", gob._ve(20.0))
	for x in [gob, limo, limo_f, cha, gol]:
		(x as Node).free()
	jug.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _gramatica() -> void:
	var r: Dictionary = Puzle3D.parsear("""; pieza nb nube_veneno 4 4 vida=5 radio=1.5
; pieza col colmena 8 8
; puzle tormenta cuando=nb.disipada hace=zona.poner(tormenta,60) y=zona.quitar(vendaval)
; puzle viento cuando=col.arde hace=zona.poner(vendaval)""")
	_ok("12 la pieza `nube_veneno x y vida= radio=` y las acciones `zona.poner(…)` / `zona.quitar(…)` se leen sin avisos", (r["avisos"] as Array).is_empty() and (r["piezas"] as Array).size() == 2 and (r["reglas"] as Array).size() == 2, str(r["avisos"]))
	var acc: Array = (r["reglas"][0]["acciones"] as Array)
	_ok("12 zona.poner(tormenta,60) → acción poner, estado tormenta, 60 s; zona.quitar(vendaval) → quitar", acc.size() == 2 and acc[0]["accion"] == "poner" and acc[0]["estado"] == "tormenta" and acc[0]["args"] == [60.0] and acc[1]["accion"] == "quitar" and acc[1]["estado"] == "vendaval", str(acc))
	_ok("12 sin segundos vale", (r["reglas"][1]["acciones"][0]["args"] as Array).is_empty())
	var p: Dictionary = (r["piezas"][0] as Object).get("p") if (r["piezas"][0] as Object).get("p") != null else {}
	_ok("12 la pieza guarda `vida` y `radio`", float(p.get("vida", 0)) == 5.0 and float(p.get("radio", 0)) == 1.5, str(p))
	var mal: Array = []
	for linea in ["hace=zona.poner(veneno)", "hace=zona.poner(nada)", "hace=zona.poner(tormenta,x)", "hace=zona.cerrar(tormenta)", "hace=zona.poner", "hace=zona.poner(tormenta,60,5)", "hace=zona.quitar(tormenta,5)"]:
		var rm: Dictionary = Puzle3D.parsear("; pieza nb nube_veneno 4 4\n; puzle t cuando=nb.disipada " + linea)
		if (rm["avisos"] as Array).size() == 0:
			mal.append(linea)
	_ok("12 cada acción de zona mal escrita avisa (veneno, estado inventado, segundos no numéricos, acción inexistente, sin paréntesis, de más)", mal.is_empty(), str(mal))
	var res: Dictionary = Puzle3D.parsear("; pieza zona nube_veneno 4 4")
	_ok("12 «zona» es palabra reservada como «flag»", (res["avisos"] as Array).size() == 1 and (res["piezas"] as Array).is_empty())
	# ejecutar
	var ez: EstadoZona3D = EstadoZona3D.actual
	ez.dinamicos.clear()
	var pz := Puzle3D.new()
	pz._ejecutar({"id": "zona", "accion": "poner", "estado": "tormenta", "args": [60.0]})
	_ok("12 ejecutar zona.poner(tormenta,60) pone la tormenta 60 s", ez.dinamicos.has("tormenta") and float(ez.dinamicos["tormenta"]["restante"]) == 60.0)
	pz._ejecutar({"id": "zona", "accion": "poner", "estado": "vendaval", "args": []})
	_ok("12 sin segundos, un vendaval sin duración en la tabla dura hasta quitarlo", bool(ez.dinamicos["vendaval"]["sin_fin"]))
	pz._ejecutar({"id": "zona", "accion": "quitar", "estado": "tormenta", "args": []})
	_ok("12 zona.quitar la apaga", not ez.dinamicos.has("tormenta") and ez.dinamicos.has("vendaval"))
	ez.dinamicos.clear()
	pz.free()
