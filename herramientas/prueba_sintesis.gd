extends SceneTree
## F3 de PLAN_BASE_DATOS (29/10, Juego): síntesis, mejoras, defensa, protecciones, pigmentos como objetos y ropa bordada, por API y sin ventana.
## Comprueba: (1) cada receta de la tabla (las 29 filas) es o no posible como dice su `requiere` (bolsa vacía = ninguna; bolsa rica = las que se pueden sin gastar un épico que no sea
## ancla; el resto falla SOLO por «raro» y con un épico a mano sale); (2) `sugerir` nunca gasta un épico que no sea ancla; (3) `hacer` quita lo justo (lo que sobra no vuelve), da lo que
## dice, sube la mejora, cobra el oro, respeta el tope y no destruye nada si lo que da no cabe; (4) `se_conoce` en sus seis formas y que lo descubierto queda para siempre;
## (5) el bordado consume la prenda y da la bordada, que se dibuja con la base y trae `inmune` y `defensa`; (6) la defensa y la fórmula de `Dano`; (7) `aplicar_todas` es idempotente
## (también con el libro, que fija el nivel de juego); (8) los consumibles nuevos (antídoto, frescor, abrigo, poción grande) y sus cuentas atrás; (9) un pigmento-objeto activa el
## pigmento de la tinta; (10) guardar y cargar conserva mejoras, recetas conocidas y lo derivado; (11) la hoguera existe como señal; (12) el «hecho cuando» del plan.
## NUNCA toca `user://partidas/`: el guardado va a una carpeta de prueba que se borra al acabar. Sin escena.
##   godot --headless --path . --script res://herramientas/prueba_sintesis.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_sintesis

const CARPETA: String = "user://prueba_sintesis/"
const EPICOS: Array = ["nucleo_eco", "geoda_resonante", "savia_elemental"]

var _fallos: int = 0


class JugadorFalso extends Node:
	var vida: float = 50.0
	var muerto: bool = false
	var tinta: Tinta = null
	var veneno: bool = true
	var bebidas: Array = []

	func curar(c: float) -> void:
		vida += c

	func usar_pocion(id: String = "pocion") -> bool:
		bebidas.append(id)
		return true

	func curar_estado(estado: String) -> bool:
		if estado == "veneno" and veneno:
			veneno = false
			return true
		return false

	func tiene_estado(estado: String) -> bool:
		return estado == "veneno" and veneno


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_nuevo()
	_recetas_una_a_una()
	_sugerir()
	_hacer()
	_no_cabe()
	_se_conoce()
	_bordado()
	_defensa()
	_idempotente()
	_consumibles()
	_pigmentos()
	_guardado()
	_hoguera_y_hecho_cuando()
	_limpiar()
	_nuevo()
	Repertoire.reset_to_p0()
	Repertoire.max_pages = 0
	Repertoire.max_sigils_per_page = 0
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Partida nueva: singletons vacíos y sin protecciones.
func _nuevo() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Partida.recetas_conocidas = []
	Partida.tinta = null
	Sintesis.estados_zona = []
	Consumibles.limpiar_protecciones()
	Mejoras.aplicar_todas()


## Una bolsa rica: 20 de cada ingrediente común, un épico de cada, la ropa base y oro de sobra. Se escribe directo en `items` (la capacidad no es lo que se mide aquí).
func _bolsa_rica() -> void:
	var e: Estado = Estado.i()
	e.capacidad = 500
	e.oro = 999
	for id in Objetos.DATOS:
		var c: String = Objetos.categoria_bd(String(id))
		if ["hongo", "planta", "raiz", "mineral", "animal"].has(c):
			e.items[String(id)] = 20 if Objetos.calidad(String(id)) == Objetos.CALIDAD_COMUN else 2
	for id in ["capa", "capucha", "tunica"]:
		e.items[id] = 1


## El oráculo de la prueba, escrito aparte de `Sintesis`: ¿alcanza la bolsa rica, SIN gastar un épico que no sea ancla, para el `requiere` de la fila?
func _alcanza_sin_epicos(r: Dictionary) -> bool:
	var e: Estado = Estado.i()
	for par in (r["requiere"] as Array):
		var t: PackedStringArray = String(par).split(">=")
		var suma: int = 0
		for id in e.items:
			var o: Dictionary = BD.objeto(String(id))
			if String(o["calidad"]) != "comun" and String(id) != String(r["ancla"]):
				continue
			if (o["etiquetas"] as Array).has(t[0]):
				suma += int(o["potencia"]) * (1 if String(id) == String(r["ancla"]) and String(o["calidad"]) != "comun" else int(e.items[id]))
		if suma < t[1].to_int():
			return false
	return true


func _recetas_una_a_una() -> void:
	var filas: int = BD.recetas().size()
	_ok("1 la tabla trae 29 recetas", filas == 29, str(filas))
	# Bolsa vacía: ninguna sale (todas piden algo).
	var ninguna: bool = true
	for id in BD.recetas():
		if bool(Sintesis.puede(String(id), Sintesis.sugerir(String(id)))["ok"]):
			ninguna = false
	_ok("1 con la bolsa vacía no sale ninguna receta", ninguna)
	# Bolsa rica.
	_bolsa_rica()
	var mal: PackedStringArray = []
	var con_epico: PackedStringArray = []
	for id in BD.recetas():
		var r: Dictionary = BD.recetas()[id]
		var sug: Dictionary = Sintesis.sugerir(String(id))
		var p: Dictionary = Sintesis.puede(String(id), sug)
		var esperado: bool = _alcanza_sin_epicos(r)
		if bool(p["ok"]) != esperado:
			mal.append("%s (sale=%s, dice la tabla=%s)" % [id, p["ok"], esperado])
		if not esperado:
			# Debe fallar SOLO por «raro» (el épico) y con uno a mano ya sale.
			var falta: Dictionary = p["falta"]
			if falta.keys() != ["raro"]:
				mal.append("%s falla por %s, no solo por raro" % [id, str(falta)])
			var el: Dictionary = sug.duplicate()
			el["nucleo_eco"] = 1
			if not bool(Sintesis.puede(String(id), el)["ok"]):
				mal.append("%s no sale ni con un núcleo de eco" % id)
			con_epico.append(String(id))
	_ok("1 las 29 recetas son posibles justo como dice su requiere", mal.is_empty(), str(mal))
	_ok("1 las únicas que piden un épico a mano son las de raro sin ancla", con_epico.size() == 3 or con_epico.size() == 2, str(con_epico))
	# Los límites de una receta concreta: pocion = vital>=3.
	Estado.nuevo()
	Estado.i().items = {"baya": 5, "seta_asada": 3}
	_ok("1 pocion: 2 bayas se quedan cortas (falta vital 1)", Sintesis.puede("pocion", {"baya": 2})["falta"] == {"vital": 1})
	_ok("1 pocion: 3 bayas bastan", bool(Sintesis.puede("pocion", {"baya": 3})["ok"]))
	_ok("1 pocion: 2 setas asadas (vital 4) bastan y sobran", bool(Sintesis.puede("pocion", {"seta_asada": 2})["ok"]))
	_ok("1 pocion: el calor de la seta asada no estorba, pero no cuenta para vital más de lo que vale", Sintesis.totales({"seta_asada": 2}) == {"vital": 4, "calor": 4})
	_ok("1 elegir más de lo que llevas no vale (bolsa)", Sintesis.puede("pocion", {"baya": 6})["motivo"] == "bolsa" and Sintesis.puede("pocion", {"baya": 6})["no_hay"] == {"baya": 1})
	_ok("1 una receta que no existe no se puede", Sintesis.puede("no_existe", {})["motivo"] == "receta")
	_ok("1 en la hoguera no se hacen las del alquimista", Sintesis.puede("pocion_grande", {"baya": 3}, "hoguera")["motivo"] == "lugar" and Sintesis.puede("pocion", {"baya": 3}, "hoguera")["ok"])
	# El ancla.
	Estado.i().items = {"helecho": 1, "baya": 4, "lavanda": 3}
	_ok("1 infusion de brezo: sin el helecho elegido falta el ancla", Sintesis.puede("infusion_brezo", {"baya": 4, "lavanda": 1})["ancla_falta"] == "helecho")
	_ok("1 infusion de brezo: con el helecho (que también suma vital) sale", bool(Sintesis.puede("infusion_brezo", {"helecho": 1, "baya": 3, "lavanda": 1})["ok"]))
	Estado.i().items = {"baya": 4, "lavanda": 3}
	_ok("1 el ancla debe estar también en la bolsa", Sintesis.puede("infusion_brezo", {"helecho": 1, "baya": 3, "lavanda": 1})["ancla_falta"] == "helecho")
	# El oro.
	Estado.i().items = {"baya": 6, "seta_humeda": 3, "raiz": 4, "cristal_tierra": 2}
	Estado.i().oro = 5
	var p20: Dictionary = Sintesis.puede("vida_1", {"baya": 6, "cristal_tierra": 1})
	_ok("1 vida_1 cuesta 20 de oro: con 5 faltan 15", p20["oro_falta"] == 15 and p20["motivo"] == "oro" and p20["falta"].is_empty(), str(p20))
	Estado.i().oro = 20
	_ok("1 con 20 de oro sale", bool(Sintesis.puede("vida_1", {"baya": 6, "cristal_tierra": 1})["ok"]))


func _sugerir() -> void:
	_bolsa_rica()
	var e: Estado = Estado.i()
	var gasto_epico: PackedStringArray = []
	var no_ok: PackedStringArray = []
	for id in BD.recetas():
		var r: Dictionary = BD.recetas()[id]
		var sug: Dictionary = Sintesis.sugerir(String(id))
		for obj in sug:
			if Objetos.calidad(String(obj)) != Objetos.CALIDAD_COMUN and String(obj) != String(r["ancla"]):
				gasto_epico.append("%s gasta %s" % [id, obj])
			if int(sug[obj]) > e.cuenta(String(obj)):
				no_ok.append("%s pide más %s de los que hay" % [id, obj])
		if String(r["ancla"]) != "" and e.cuenta(String(r["ancla"])) > 0 and int(sug.get(String(r["ancla"]), 0)) != 1 and Objetos.calidad(String(r["ancla"])) != "comun":
			no_ok.append("%s no pone el ancla" % id)
	_ok("2 sugerir NUNCA gasta un épico o legendario que no sea el ancla", gasto_epico.is_empty(), str(gasto_epico))
	_ok("2 sugerir nunca elige más de lo que hay y pone el ancla épica", no_ok.is_empty(), str(no_ok))
	# Lo más barato: la poción con bayas (potencia 1) antes que setas asadas (potencia 2).
	e.items = {"baya": 5, "seta_asada": 5, "helecho": 5}
	var s: Dictionary = Sintesis.sugerir("pocion")
	_ok("2 sugerir elige lo de menos potencia primero (3 unidades de potencia 1, nada de seta asada)", s.get("seta_asada", 0) == 0 and Sintesis.totales(s).get("vital", 0) == 3, str(s))
	# Con menos de lo necesario devuelve la parcial.
	e.items = {"baya": 2}
	var parcial: Dictionary = Sintesis.sugerir("pocion")
	_ok("2 si no alcanza devuelve lo que hay (parcial) y puede dice que falta", parcial == {"baya": 2} and Sintesis.puede("pocion", parcial)["falta"] == {"vital": 1}, str(parcial))
	# Un épico en la bolsa que sube la etiqueta no se toca.
	e.items = {"savia_elemental": 2, "baya": 2}
	_ok("2 con savia elemental (vital 5) en la bolsa y solo 2 bayas, la poción no se la gasta", Sintesis.sugerir("pocion") == {"baya": 2})


func _hacer() -> void:
	var e: Estado = Estado.i()
	var senal: Array = []
	var h := func(id: String) -> void: senal.append(id)
	Sintesis.i().hecha.connect(h)
	# Una poción de bayas y helecho, con lo que sobra gastado.
	Estado.nuevo()
	e = Estado.i()
	e.items = {"baya": 3, "helecho": 2, "seta": 1}
	_ok("3 pocion con 2 bayas + 1 helecho: sale", Sintesis.hacer("pocion", {"baya": 2, "helecho": 1}, "hoguera"))
	_ok("3 quita justo lo elegido y da 1 poción", e.items == {"baya": 1, "helecho": 1, "seta": 1, "pocion": 1}, str(e.items))
	_ok("3 la señal hecha avisa", senal == ["pocion"], str(senal))
	e.items = {"seta_asada": 3}
	Sintesis.hacer("pocion", {"seta_asada": 2})
	_ok("3 lo que sobra de potencia NO se devuelve (2 setas asadas para vital 3: se gastan las dos)", e.items == {"seta_asada": 1, "pocion": 1}, str(e.items))
	_ok("3 una receta imposible no toca la bolsa", not Sintesis.hacer("pocion", {"seta_asada": 1}) and e.items == {"seta_asada": 1, "pocion": 1})
	# Una mejora: cobra oro y sube un nivel.
	Estado.nuevo()
	e = Estado.i()
	e.oro = 50
	e.items = {"baya": 8, "cristal_tierra": 1, "seta": 3}
	var el: Dictionary = Sintesis.sugerir("vida_1")
	_ok("3 vida_1 se sugiere solo con la bolsa", bool(Sintesis.puede("vida_1", el)["ok"]), str(el))
	var oro_antes: int = e.oro
	_ok("3 hacer vida_1 sube la mejora", Sintesis.hacer("vida_1", el, "alquimista") and e.nivel("vida_max") == 1)
	_ok("3 la vida máxima pasa de 100 a 120", is_equal_approx(e.vida_max, 120.0), str(e.vida_max))
	_ok("3 cobró los 20 de oro y quitó los ingredientes", e.oro == oro_antes - 20 and e.cuenta("baya") + e.cuenta("seta") < 11, "oro %d items %s" % [e.oro, str(e.items)])
	_ok("3 en la hoguera no se hace (es del alquimista) y no cuesta nada", not Sintesis.hacer("vida_1", el, "hoguera") and e.oro == oro_antes - 20)
	# El tope.
	var antes_items: Dictionary
	for _i in range(4):
		Mejoras.subir("vida_max")
	_ok("3 la mejora llega a su tope (5 niveles, 200 de vida)", e.nivel("vida_max") == 5 and is_equal_approx(e.vida_max, 200.0))
	_ok("3 en el tope no sube más", not Mejoras.subir("vida_max") and e.nivel("vida_max") == 5)
	e.items = {"baya": 8, "cristal_tierra": 1}
	e.oro = 100
	antes_items = e.items.duplicate()
	var p: Dictionary = Sintesis.puede("vida_1", {"baya": 6, "cristal_tierra": 1})
	_ok("3 con la mejora en su tope la receta dice «tope» y no se hace", p["motivo"] == "tope" and not Sintesis.hacer("vida_1", {"baya": 6, "cristal_tierra": 1}) and e.items == antes_items and e.oro == 100)
	_ok("3 las que ganan otros sistemas no se compran", not Mejoras.subir("tinta_jefe") and not Mejoras.subir("no_existe"))
	# Una mejora con ancla épica (vida_3 pide savia elemental).
	Estado.nuevo()
	e = Estado.i()
	e.oro = 100
	e.mejoras = {"vida_max": 2}
	e.items = {"savia_elemental": 1, "baya": 10, "seta_humeda": 4}
	var el3: Dictionary = Sintesis.sugerir("vida_3")
	_ok("3 vida_3 con savia elemental de ancla: se sugiere y sale", el3.get("savia_elemental", 0) == 1 and Sintesis.hacer("vida_3", el3) and e.nivel("vida_max") == 3 and e.cuenta("savia_elemental") == 0, str(el3))
	# Mejoras cuyo efecto es la bolsa: «bolsa_1» por la receta, y la compra de hoy por Estado.subir_capacidad.
	Estado.nuevo()
	e = Estado.i()
	Estado.i().subir_capacidad(4)
	_ok("3 Estado.subir_capacidad pasa por la mejora (8 → 12, nivel 1)", e.capacidad == 12 and e.nivel("capacidad") == 1)
	e.subir_capacidad(100)
	_ok("3 y respeta el tope de la tabla (20)", e.capacidad == 20 and e.nivel("capacidad") == 3)
	Sintesis.i().hecha.disconnect(h)


func _no_cabe() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.capacidad = 2
	e.items = {"pocion": 9, "baya": 10}                 # dos huecos llenos: 9 pociones (pila 9) y 10 bayas (pila 20)
	var avisos: Array = []
	var f := func(t: String) -> void: avisos.append(t)
	Sintesis.i().aviso.connect(f)
	var antes: Dictionary = e.items.duplicate()
	var ok: bool = Sintesis.hacer("pocion", {"baya": 3})
	_ok("3 si lo que da no cabe, no se hace y no se pierde nada", not ok and e.items == antes and avisos.size() == 1, "%s %s" % [str(e.items), str(avisos)])
	Sintesis.i().aviso.disconnect(f)
	e.capacidad = 3
	_ok("3 con un hueco libre sí", Sintesis.hacer("pocion", {"baya": 3}) and e.cuenta("pocion") == 10)


func _se_conoce() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Partida.recetas_conocidas = []
	Sintesis.estados_zona = []
	var e: Estado = Estado.i()
	var nuevas: Array = []
	var f := func(id: String) -> void: nuevas.append(id)
	Sintesis.i().descubierta.connect(f)
	_ok("4 siempre: la poción se conoce sin nada", Sintesis.conocidas().has("pocion") and Sintesis.conocidas("hoguera").has("pocion"))
	_ok("4 siempre no se apunta como descubierta", not Partida.recetas_conocidas.has("pocion") and nuevas.is_empty())
	# al tener los ingredientes
	_ok("4 al tener los ingredientes: el bálsamo no se conoce con la bolsa vacía", not Sintesis.conocidas().has("balsamo_protector"))
	e.items = {"colmillo_goblin": 2}                    # tierra 4, proteccion 4
	_ok("4 con 2 colmillos de goblin el bálsamo aparece", Sintesis.conocidas("hoguera").has("balsamo_protector") and nuevas == ["balsamo_protector"], str(nuevas))
	e.items = {}
	_ok("4 y se queda para siempre (lo descubierto viaja en recetas_conocidas)", Sintesis.conocidas().has("balsamo_protector") and Partida.recetas_conocidas.has("balsamo_protector"))
	_ok("4 no se avisa dos veces", nuevas.size() == 1)
	# flag
	_ok("4 flag: la poción grande no aparece sin su flag", not Sintesis.conocidas().has("pocion_grande"))
	Flags.i().poner("bosque1.alquimista.grande")
	_ok("4 flag: con la flag aparece (solo en el alquimista)", Sintesis.conocidas("alquimista").has("pocion_grande") and not Sintesis.conocidas("hoguera").has("pocion_grande"))
	# mejora
	_ok("4 mejora: Corazón II pide la I", not Sintesis.conocidas().has("vida_2"))
	Mejoras.subir("vida_max")
	_ok("4 mejora: tras la I aparece la II (y la III aún no)", Sintesis.conocidas().has("vida_2") and not Sintesis.conocidas().has("vida_3"))
	# tener
	_ok("4 tener: el bordado de escarcha pide llevar la capa", not Sintesis.conocidas().has("bordado_escarcha"))
	e.items = {"capa": 1}
	_ok("4 tener: con la capa en la bolsa aparece", Sintesis.conocidas().has("bordado_escarcha"))
	# zona
	_ok("4 zona: el frasco de frescor no se enseña antes de hacer falta", not Sintesis.conocidas().has("frescor"))
	Sintesis.estados_zona = ["frio"]
	_ok("4 zona: con frío no sale el de calor, sí la brasa embotellada", not Sintesis.conocidas().has("frescor") and Sintesis.conocidas().has("abrigo"))
	Sintesis.estados_zona = ["calor"]
	_ok("4 zona: pisando el calor aparece el frescor", Sintesis.conocidas("hoguera").has("frescor"))
	Sintesis.estados_zona = []
	_ok("4 zona: y se queda al salir", Sintesis.conocidas().has("frescor"))
	# Una condición mal escrita no se cumple.
	_ok("4 una condición que no se entiende no se cumple", not Sintesis.cumple_se_conoce("pocion", "cuando llueva"))
	Sintesis.i().descubierta.disconnect(f)
	# Las seis formas están todas en la tabla.
	var formas: Dictionary = {}
	for id in BD.recetas():
		var c: String = String(BD.recetas()[id]["se_conoce"])
		var forma: String = c if c == "siempre" or c == "al tener los ingredientes" else (c.split(":")[0] if c.contains(":") else "zona")
		formas[forma] = true
	_ok("4 la tabla usa las seis formas", formas.size() == 6, str(formas.keys()))


func _bordado() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.oro = 100
	e.items = {"capa": 1, "seda": 3, "tunica": 1}
	var el: Dictionary = Sintesis.sugerir("bordado_escarcha")
	_ok("5 el bordado de escarcha se sugiere con la capa de ancla y la seda", el == {"capa": 1, "seda": 2}, str(el))
	_ok("5 se hace en el alquimista", Sintesis.hacer("bordado_escarcha", el, "alquimista"))
	_ok("5 consume la capa y 2 sedas, da la capa de escarcha y deja lo demás", e.items == {"seda": 1, "tunica": 1, "capa_escarcha": 1}, str(e.items))
	_ok("5 cobró 40 de oro", e.oro == 60)
	_ok("5 la bordada se dibuja con la base (base_de, existe, mismo .glb)", Ropa3D.base_de("capa_escarcha") == "capa" and Ropa3D.base_de("tunica_salamandra") == "tunica" and Ropa3D.base_de("capucha_musgo") == "capucha"
		and Ropa3D.existe("capa_escarcha") and Ropa3D.datos_de("capa_escarcha").get("glb") == "ropa_capa" and Ropa3D.datos_de("capucha_musgo").get("oculta") == ["pelo"])
	_ok("5 una prenda que no existe ni tiene base no se dibuja", not Ropa3D.existe("sombrero") and Ropa3D.base_de("capa") == "")
	_ok("5 efecto de la prenda: inmune y defensa salen de la tabla", Ropa3D.inmune_ids(["capa_escarcha"], "frio") and not Ropa3D.inmune_ids(["capa_escarcha"], "calor")
		and Ropa3D.inmune_ids(["capucha_musgo"], "veneno") and Ropa3D.inmune_ids(["tunica_salamandra"], "calor") and Ropa3D.defensa_ids(["capa_escarcha", "tunica_salamandra", "capa"]) == 2)
	_ok("5 la prenda base no da nada y la ranura sale del efecto", Ropa3D.defensa_ids(["capa"]) == 0 and not Ropa3D.inmune_ids(["capa"], "frio") and Ropa3D.ranura_de("capa_escarcha") == "exterior")
	# Los tres bordados de la tabla tienen su prenda en objetos.tsv de ropa con efecto.
	var bien: bool = true
	for id in ["bordado_escarcha", "bordado_salamandra", "bordado_musgo"]:
		var r: Dictionary = BD.receta(id)
		var bordada: String = String(r["da"]).split(":")[0]
		bien = bien and String(r["tipo"]) == "ropa" and Ropa3D.existe(bordada) and Ropa3D.defensa_ids([bordada]) == 1 and String(BD.objeto(bordada)["categoria"]) == "ropa"
	_ok("5 los tres bordados dan una prenda de ropa con DEF 1", bien)


func _defensa() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	_ok("6 sin mejora, la DEF es 0", is_equal_approx(e.defensa, 0.0))
	Mejoras.subir("defensa")
	Mejoras.subir("defensa")
	_ok("6 dos niveles de defensa = DEF 2", is_equal_approx(e.defensa, 2.0) and not Mejoras.subir("defensa"))
	# La fórmula de Dano que usa Jugador3D.recibir_dano: máx(0,2·D, D − DEF).
	_ok("6 un golpe de 10 con DEF 2 hiere 8", is_equal_approx(Dano.tras_defensa(10.0, e.defensa), 8.0))
	_ok("6 el suelo del 20 %: un golpe de 3 con DEF 2 hiere 1; uno de 2 hiere 0,4; uno de 10 con DEF 50 hiere 2", is_equal_approx(Dano.tras_defensa(3.0, 2.0), 1.0)
		and is_equal_approx(Dano.tras_defensa(2.0, 2.0), 0.4) and is_equal_approx(Dano.tras_defensa(10.0, 50.0), 2.0))
	var j: Jugador3D = Jugador3D.new()
	_ok("6 Jugador3D.defensa_total suma la de las mejoras (sin cuerpo, sin ropa)", is_equal_approx(j.defensa_total(), 2.0))
	_ok("6 y no es inmune a nada sin ropa ni consumible", not j.inmune_a("veneno") and not j.inmune_a("calor"))
	Consumibles.inmunidades["veneno"] = 5.0
	_ok("6 un antídoto activo lo hace inmune al veneno (y envenenar no hace nada)", j.inmune_a("veneno"))
	j.envenenar(5.0, 4.0)
	_ok("6 envenenar con inmunidad no deja veneno", not j.tiene_estado("veneno"))
	Consumibles.limpiar_protecciones()
	j.envenenar(5.0, 4.0)
	_ok("6 sin inmunidad el veneno entra y curar_estado lo quita", j.tiene_estado("veneno") and j.curar_estado("veneno") and not j.tiene_estado("veneno") and not j.curar_estado("veneno"))
	j.free()


func _idempotente() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	Repertoire.max_sigils_per_page = 2
	Repertoire.max_pages = 3
	e.mejoras = {"vida_max": 2, "cura_pocion": 1, "defensa": 1, "velocidad": 1, "capacidad": 1, "huecos_glifo": 2, "paginas": 1, "frascos_tinta": 2}
	Mejoras.aplicar_todas()
	var foto1: Array = [e.vida_max, e.cura_pocion, e.defensa, e.vel_extra, e.capacidad, e.frascos_tinta, Repertoire.max_sigils_per_page, Repertoire.max_pages]
	Mejoras.aplicar_todas()
	Mejoras.aplicar_todas()
	var foto2: Array = [e.vida_max, e.cura_pocion, e.defensa, e.vel_extra, e.capacidad, e.frascos_tinta, Repertoire.max_sigils_per_page, Repertoire.max_pages]
	_ok("7 aplicar_todas tres veces deja lo mismo que una", foto1 == foto2, "%s %s" % [str(foto1), str(foto2)])
	_ok("7 los valores: vida 140, poción +10, DEF 1, velocidad +10, bolsa 12, libro 4 glifos y 4 páginas", foto1.slice(0, 5) == [140.0, 50.0, 1.0, 10.0, 12] and foto1[6] == 4 and foto1[7] == 4, str(foto1))
	# El nivel de juego vuelve a fijar el libro (otra sala): la mejora suma sobre la base nueva, no sobre la suma anterior.
	Repertoire.max_sigils_per_page = 3
	Repertoire.max_pages = 3
	Mejoras.aplicar_todas()
	_ok("7 si el nivel vuelve a fijar el libro, la base es la suya (3 + 2 = 5)", Repertoire.max_sigils_per_page == 5 and Repertoire.max_pages == 4)
	e.mejoras = {}
	Mejoras.aplicar_todas()
	_ok("7 sin mejoras todo vuelve a la base", is_equal_approx(e.vida_max, 100.0) and is_equal_approx(e.defensa, 0.0) and e.capacidad == 8 and Repertoire.max_sigils_per_page == 3 and Repertoire.max_pages == 3)
	# 0 = sin límite no se toca.
	Repertoire.max_sigils_per_page = 0
	e.mejoras = {"huecos_glifo": 3}
	Mejoras.aplicar_todas()
	_ok("7 un libro sin límite (0) sigue sin límite", Repertoire.max_sigils_per_page == 0)
	Repertoire.max_sigils_per_page = 0
	Repertoire.max_pages = 0
	# La tinta: frascos y colchón.
	Estado.nuevo()
	e = Estado.i()
	var t := Tinta.new()
	Partida.tinta = t
	_ok("7 sin mejoras hay 3 frascos y llenos", Tinta.frascos_max() == 3 and t.frascos == 3 and t.maxima_frascos() == 3)
	Mejoras.subir("frascos_tinta")
	_ok("7 la mejora frascos_tinta da un cuarto frasco, lleno", Tinta.frascos_max() == 4 and t.frascos == 4 and e.frascos_tinta == 4, "%d %d" % [t.frascos, e.frascos_tinta])
	t.frascos = 0
	_ok("7 los vacíos se cuentan contra el máximo nuevo", t.frascos_vacios() == 4 and t.recargar_frasco(10) == 4)
	e.mejoras["tinta_frasco"] = 2
	t.actual = 5.0
	t.frascos = 1
	t.gastar("x", 10.0)
	_ok("7 con «Frasco hondo» II, un frasco deja la barra en 120 (antes de cobrar): 120 − 10", is_equal_approx(t.actual, 110.0) and t.frascos == 0, str(t.actual))
	Partida.tinta = null


func _consumibles() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	Consumibles.limpiar_protecciones()
	var jf := JugadorFalso.new()
	jf.tinta = Tinta.new()
	var c := Consumibles.new()
	c.jugador = jf
	e.items = {"antidoto": 2, "frescor": 1, "abrigo": 1, "pocion_grande": 1}
	_ok("8 los consumibles nuevos están en la rueda", Objetos.CONSUMIBLES.has("antidoto") and Objetos.CONSUMIBLES.has("frescor") and Objetos.CONSUMIBLES.has("abrigo") and Objetos.CONSUMIBLES.has("pocion_grande"))
	_ok("8 el antídoto se usa: quita el veneno, protege 60 s y gasta una unidad", c.usar("antidoto") and not jf.veneno and Consumibles.protegido("veneno") and is_equal_approx(Consumibles.tiempo_proteccion("veneno"), 60.0) and e.cuenta("antidoto") == 1)
	_ok("8 con la protección puesta y sin veneno, otro antídoto no se gasta", not c.usar("antidoto") and e.cuenta("antidoto") == 1)
	c.actualizar(25.0)
	_ok("8 la protección cuenta atrás (25 s → quedan 35)", is_equal_approx(Consumibles.tiempo_proteccion("veneno"), 35.0))
	c.actualizar(40.0)
	_ok("8 y se acaba a los 60 s", not Consumibles.protegido("veneno") and Consumibles.tiempo_proteccion("veneno") == 0.0)
	_ok("8 el frasco de frescor da resistencia al calor 90 s (no al frío, no es inmunidad)", c.usar("frescor") and Consumibles.resiste("calor") and not Consumibles.protegido("calor") and not Consumibles.resiste("frio") and is_equal_approx(Consumibles.tiempo_proteccion("calor"), 90.0))
	_ok("8 la brasa embotellada, la del frío", c.usar("abrigo") and Consumibles.resiste("frio") and e.cuenta("abrigo") == 0)
	c.actualizar(89.0)
	_ok("8 a falta de 1 s sigue y luego no", Consumibles.resiste("calor"))
	c.actualizar(2.0)
	_ok("8 se acaba la resistencia", not Consumibles.resiste("calor") and not Consumibles.resiste("frio"))
	_ok("8 la poción grande se bebe pidiendo SU id al jugador", c.usar("pocion_grande") and jf.bebidas == ["pocion_grande"])
	e.items = {"pocion": 1}
	_ok("8 la poción de siempre se sigue bebiendo sin argumentos", c.usar("pocion") and jf.bebidas == ["pocion_grande", "pocion"])
	_ok("8 la cura de la tabla + la mejora «Poción más dulce»: 40 → 50, la grande 80 → 90", is_equal_approx(Mejoras.cura_de("pocion"), 40.0) and (func() -> bool:
		Mejoras.subir("cura_pocion")
		return is_equal_approx(Mejoras.cura_de("pocion"), 50.0) and is_equal_approx(Mejoras.cura_de("pocion_grande"), 90.0) and is_equal_approx(e.cura_pocion, 50.0)).call())
	Consumibles.limpiar_protecciones()
	jf.free()


func _pigmentos() -> void:
	Estado.nuevo()
	var e: Estado = Estado.i()
	var mal: PackedStringArray = []
	var n: int = 0
	for id in BD.objetos():
		var o: Dictionary = BD.objeto(String(id))
		if String(o["uso"]) == "pigmento":
			n += 1
			if not Tinta.PIGMENTOS.has(String((o["efecto"] as Dictionary).get("pigmento", ""))):
				mal.append(String(id))
	_ok("9 los cinco objetos pigmento apuntan a pigmentos que existen en Tinta.PIGMENTOS", n == 5 and mal.is_empty(), "%d %s" % [n, str(mal)])
	var t := Tinta.new()
	e.items = {"pigmento_ocre": 2, "pigmento_eco": 1, "seta": 1}
	_ok("9 aplicar un pigmento gasta 1 unidad y activa el de la tinta", Sintesis.aplicar_pigmento("pigmento_ocre", t) and t.pigmento == "ocre_tumulo" and e.cuenta("pigmento_ocre") == 1 and t.tiempo_pigmento() > 59.0)
	_ok("9 el Azul de Eco: quita el recargo de ᚱ (raido) y de nada más", Sintesis.aplicar_pigmento("pigmento_eco", t) and t.pigmento == "azul_eco" and t.quita_recargo("raido") and not t.quita_recargo("pulso") and not t.quita_recargo(""))
	_ok("9 y sustituye al anterior (el ocre ya no rebaja)", is_equal_approx(t.coste_efectivo(20.0, "tierra"), 20.0) and is_equal_approx(t.mult_dano("fuego"), 1.0))
	_ok("9 sin unidades, o un objeto que no es pigmento, no se aplica", not Sintesis.aplicar_pigmento("pigmento_eco", t) and not Sintesis.aplicar_pigmento("seta", t) and e.cuenta("seta") == 1)
	_ok("9 sin tinta tampoco", not Sintesis.aplicar_pigmento("pigmento_ocre", null))
	var c := Consumibles.new()
	var jf := JugadorFalso.new()
	jf.tinta = Tinta.new()
	c.jugador = jf
	_ok("9 Consumibles.aplicar_pigmento lo hace con la tinta del jugador", c.aplicar_pigmento("pigmento_ocre") and jf.tinta.pigmento == "ocre_tumulo" and e.cuenta("pigmento_ocre") == 0)
	_ok("9 los pigmentos no entran en la rueda de R", not Objetos.CONSUMIBLES.has("pigmento_ocre"))
	jf.free()
	# Las recetas de pigmento dan el objeto.
	e.items = {"resina": 2, "flor_ardiente": 2}
	e.oro = 0
	var el: Dictionary = Sintesis.sugerir("pigmento_carmesi")
	_ok("9 la receta del pigmento carmesí da el objeto pigmento", Sintesis.hacer("pigmento_carmesi", el) and e.cuenta("pigmento_carmesi") == 1, str(e.items))


func _limpiar() -> void:
	var dir_abs: String = ProjectSettings.globalize_path(CARPETA)
	if DirAccess.dir_exists_absolute(dir_abs):
		for f in DirAccess.get_files_at(dir_abs):
			DirAccess.remove_absolute(dir_abs.path_join(f))
		DirAccess.remove_absolute(dir_abs)


func _guardado() -> void:
	_limpiar()
	Partida.carpeta = CARPETA
	Partida.ranura_actual = 1
	Partida.ruta_flags_v1 = CARPETA + "flags.json"
	Partida.ruta_misiones_v1 = CARPETA + "misiones.json"
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()
	Repertoire.reset_to_p0()
	Repertoire.max_sigils_per_page = 2
	Repertoire.max_pages = 3
	Partida.tinta = Tinta.new()
	Partida.recetas_conocidas = []
	var e: Estado = Estado.i()
	e.capacidad = 10                                     # 2 huecos regalados al empezar: son la base
	e.capacidad_base = 10
	Mejoras.subir("vida_max")
	Mejoras.subir("vida_max")
	Mejoras.subir("capacidad")
	Mejoras.subir("defensa")
	Mejoras.subir("huecos_glifo")
	Mejoras.subir("frascos_tinta")
	Mejoras.subir("tinta_frasco")
	e.items = {"colmillo_goblin": 2}
	Sintesis.conocidas()                                 # descubre el bálsamo (por los ingredientes) y las que piden una mejora ya subida (II, III...)
	var conocidas_antes: Array = Partida.recetas_conocidas.duplicate()
	_ok("10 antes de guardar: capacidad 14, vida 140, libro de 3 glifos, 4 frascos", e.capacidad == 14 and is_equal_approx(e.vida_max, 140.0) and Repertoire.max_sigils_per_page == 3 and Tinta.frascos_max() == 4
		and conocidas_antes.has("balsamo_protector") and conocidas_antes.has("vida_2") and not conocidas_antes.has("pocion"), "%d %s" % [e.capacidad, str(conocidas_antes)])
	_ok("10 se guarda", Partida.guardar(1, {"mapa_actual": "x", "punto": "x.1_1"}))
	# Otra partida, otra sala con su libro.
	Estado.nuevo()
	Partida.recetas_conocidas = []
	Partida.tinta = Tinta.new()
	_ok("10 tras el reinicio no queda nada", Estado.i().nivel("vida_max") == 0 and Estado.i().capacidad == 8 and Partida.recetas_conocidas.is_empty())
	Repertoire.max_sigils_per_page = 2             # el nivel de juego fija su libro al arrancar
	var d: Dictionary = Partida.cargar(1)
	e = Estado.i()
	_ok("10 se carga", not d.is_empty())
	_ok("10 las mejoras viajan", e.nivel("vida_max") == 2 and e.nivel("capacidad") == 1 and e.nivel("defensa") == 1 and e.nivel("huecos_glifo") == 1 and e.nivel("frascos_tinta") == 1, str(e.mejoras))
	_ok("10 lo derivado se recalcula al cargar: vida 140, DEF 1, bolsa 14 (base 10 + 4), 4 frascos", is_equal_approx(e.vida_max, 140.0) and is_equal_approx(e.defensa, 1.0) and e.capacidad == 14 and e.capacidad_base == 10 and Tinta.frascos_max() == 4,
		"%s %s %d" % [str(e.vida_max), str(e.defensa), e.capacidad])
	_ok("10 el libro: la base del nivel (2) + la mejora (1)", Repertoire.max_sigils_per_page == 3, str(Repertoire.max_sigils_per_page))
	_ok("10 las recetas conocidas viajan (y la bolsa)", Partida.recetas_conocidas == conocidas_antes and Sintesis.conocidas().has("balsamo_protector") and e.cuenta("colmillo_goblin") == 2, str(Partida.recetas_conocidas))
	_ok("10 la tinta cargada admite 4 frascos", Partida.tinta.maxima_frascos() == 4)
	var json: String = FileAccess.get_file_as_string(CARPETA + "ranura_1.json")
	_ok("10 el archivo lleva mejoras y recetas_conocidas", json.contains("\"recetas_conocidas\"") and json.contains("balsamo_protector") and json.contains("\"vida_max\""))
	_ok("10 la prueba no escribe en user://partidas/ (solo en su carpeta)", Partida.carpeta == CARPETA)
	Partida.carpeta = Partida.CARPETA_DEFECTO
	Partida.ruta_flags_v1 = Partida.RUTA_FLAGS_V1
	Partida.ruta_misiones_v1 = Partida.RUTA_MISIONES_V1
	Partida.tinta = null
	Repertoire.max_sigils_per_page = 0
	Repertoire.max_pages = 0


func _hoguera_y_hecho_cuando() -> void:
	var r := Reactivo3D.new()
	_ok("11 el Reactivo tiene la señal hoguera_abierta(celda)", r.has_signal("hoguera_abierta"))
	r.free()
	var jb := Jugabilidad3D.new()
	_ok("11 Jugabilidad3D tiene sintesis_abierta(donde)", jb.has_signal("sintesis_abierta"))
	jb.free()
	var donde: Array = []
	var f := func(d: String) -> void: donde.append(d)
	Sintesis.i().sintesis_abierta.connect(f)
	Sintesis.abrir("hoguera")
	Sintesis.abrir("alquimista")
	Sintesis.i().sintesis_abierta.disconnect(f)
	_ok("11 Sintesis.abrir avisa de dónde se abre", donde == ["hoguera", "alquimista"])
	# HECHO CUANDO: bayas y helecho -> poción en la hoguera; el alquimista sube la vida con vida_1.
	Estado.nuevo()
	Flags.nuevo()
	Partida.recetas_conocidas = []
	var e: Estado = Estado.i()
	e.capacidad = 8
	e.oro = 30
	e.items = {"baya": 6, "helecho": 2, "cristal_tierra": 1}
	var hoguera: Array[String] = Sintesis.conocidas("hoguera")
	_ok("12 en la hoguera se enseña la poción y no la mejora de vida", hoguera.has("pocion") and not hoguera.has("vida_1"))
	var el: Dictionary = Sintesis.sugerir("pocion")
	_ok("12 la hoguera hace la poción con bayas y helecho", Sintesis.hacer("pocion", el, "hoguera") and e.cuenta("pocion") == 1 and e.cuenta("baya") + e.cuenta("helecho") == 5, str(e.items))
	var alquimista: Array[String] = Sintesis.conocidas("alquimista")
	_ok("12 el alquimista enseña Corazón robusto I", alquimista.has("vida_1"))
	e.items["baya"] = 6
	var el2: Dictionary = Sintesis.sugerir("vida_1")
	_ok("12 y la hace: +20 de vida máxima, 20 de oro", Sintesis.hacer("vida_1", el2, "alquimista") and is_equal_approx(e.vida_max, 120.0) and e.oro == 10, "%s %d %s" % [str(e.vida_max), e.oro, str(e.items)])
	_ok("12 y ya se enseña la II", Sintesis.conocidas("alquimista").has("vida_2"))
