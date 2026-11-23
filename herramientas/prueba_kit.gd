extends SceneTree
## Kit de pruebas y costra de hielo (11.15) sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_kit.gd
## Comprueba: qué progresión se elige (forzada > kit > nivel > «todo»), que con el kit «pruebas» el Bosque no cierra nada del
## repertorio, que sin kit el Bosque sigue con «bosque», que el render recibe `hielo_desde` ANTES de helar, y que la costra
## se pone, avisa y se deshace en goblins y troncos.

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 6
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _agua_render: Object = null
	var kit: String = ""
	var nivel: String = "Bosque"
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_canal(c: Vector2i) -> bool:
		return _letra(c) == "-"
	func _liberar(c: Vector2i) -> void:
		_bloqueadas.erase(c)

class RenderFalso extends Object:
	var llamadas: Array = []
	var hielo_al_llamar: float = 0.0
	func hielo_desde(punto: Vector3) -> void:
		llamadas.append(punto)
		hielo_al_llamar = Terreno3D.agua_sim.hielo_en(punto) if Terreno3D.agua_sim != null else 0.0

class GoblinFalso extends Node3D:
	var congelado: float = 0.0

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _mundo(mapa: PackedStringArray) -> MundoFalso:
	var m := MundoFalso.new()
	m._mapa = mapa
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(6):
		for x in range(6):
			if mapa[y][x] == "#" or mapa[y][x] == "u" or mapa[y][x] == "~":
				m._bloqueadas[Vector2i(x, y)] = true
	return m


func _correr(sim: AguaSim3D, seg: float) -> void:
	for _i in range(int(seg * 60.0)):
		sim.paso(1.0 / 60.0)
		Lanzador3D.procesar_cambios_hielo()
		Lanzador3D.vigilar_presos()


func _initialize() -> void:
	await process_frame
	_progresion()
	_bosque()
	_demo()
	_demo_inicio()
	await _costras()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _progresion() -> void:
	var m := MundoFalso.new()
	_ok("1 sin mundo: «todo»", Lanzador3D.progresion_de(null) == "todo")
	_ok("1 sin kit: el nombre del nivel", Lanzador3D.progresion_de(m) == "Bosque")
	m.kit = ""
	_ok("1 kit vacío cuenta como sin kit", Lanzador3D.progresion_de(m) == "Bosque")
	m.kit = "pruebas"
	_ok("1 con kit: el kit manda sobre el nivel", Lanzador3D.progresion_de(m) == "pruebas")
	_ok("1 PROGRESION_FORZADA vacía (si no, esta prueba no vale)", Lanzador3D.PROGRESION_FORZADA == "")
	_ok("1 (22/11) sustituir_kit está vacío en el juego", Lanzador3D.sustituir_kit.is_empty())
	m.kit = "demo_inicio"
	Lanzador3D.sustituir_kit = {"demo_inicio": "pruebas"}
	_ok("1 (22/11) con la sustitución de los escenarios, «demo_inicio» se monta como «pruebas»", Lanzador3D.progresion_de(m) == "pruebas")
	Lanzador3D.sustituir_kit = {}
	_ok("1 (22/11) y sin ella, como «demo_inicio»", Lanzador3D.progresion_de(m) == "demo_inicio")
	m.free()


func _bosque() -> void:
	# Sin kit: el Bosque de siempre.
	var clave: String = Lanzador3D.aplicar_progresion("Bosque")
	_ok("2 sin kit: progresión «bosque»", clave == "bosque")
	_ok("2 sin kit: solo fuego y flecha, sin hielo", Repertoire.active_elements() == PackedStringArray(["fuego"]) \
			and Repertoire.active_sigils() == PackedStringArray(["flecha"]) and not Repertoire.element_active("hielo"))
	_ok("2 sin kit: una página", Repertoire.max_pages == 1)
	# Con kit: todo, hielo incluido.
	clave = Lanzador3D.aplicar_progresion("pruebas")
	_ok("3 con kit: progresión «pruebas»", clave == "pruebas")
	_ok("3 el repertorio tiene hielo", Repertoire.element_active("hielo"))
	_ok("3 seis sellos", Repertoire.active_elements().size() == 6, str(Repertoire.active_elements()))
	# R3 (17/10): `tamano` se retira (cada eje tiene su glifo), así que el kit de pruebas tiene ocho glifos y no nueve.
	# 30/10 (d534287c, base de datos F0–F4): el kit gana perforar, retorno, buscar y retardo: doce glifos.
	# Después entró ᛒ suelo (PROGRESIONES["pruebas"] lleva 13): trece glifos.
	_ok("3 trece glifos (sin tamano, con suelo)", Repertoire.active_sigils().size() == 13 and Repertoire.active_sigils().has("suelo") and not Repertoire.active_sigils().has("tamano"), str(Repertoire.active_sigils()))
	_ok("3 tres páginas, seis glifos por página", Repertoire.max_pages == 3 and Repertoire.max_sigils_per_page == 6)
	_ok("3 el libro de «pruebas» es el nuevo (16/10: el antiguo era un placeholder; ya no hay progresión con libro «»)", Repertoire.libro == "bosque")
	for k in Lanzador3D.PROGRESIONES:
		Lanzador3D.aplicar_progresion(String(k))
		_ok("3 la progresión «%s» usa el libro nuevo" % k, Repertoire.libro == "bosque", Repertoire.libro)
	Lanzador3D.aplicar_progresion("pruebas")
	# Lo que hace Bosque3D (solo desbloquear: agua al coger el sello, barrera al comprarla) no cierra ni cambia nada.
	var antes_e: PackedStringArray = Repertoire.active_elements()
	var antes_s: PackedStringArray = Repertoire.active_sigils()
	var nuevo_a: bool = Repertoire.unlock_element("agua")
	var nuevo_b: bool = Repertoire.unlock_sigil("barrera")
	_ok("4 Bosque3D con el kit: desbloquear agua/barrera no cambia nada", not nuevo_a and not nuevo_b \
			and Repertoire.active_elements() == antes_e and Repertoire.active_sigils() == antes_s)
	_ok("4 y siguen activos", Repertoire.sigil_active("barrera") and Repertoire.element_active("agua") and Repertoire.element_active("hielo"))
	# Y de vuelta: sin kit el Bosque vuelve a su progresión.
	Lanzador3D.aplicar_progresion("Bosque")
	_ok("5 sin kit otra vez: sin hielo", not Repertoire.element_active("hielo") and Repertoire.active_sigils().size() == 1)
	Lanzador3D.aplicar_progresion("todo")      # no dejamos la progresión del Bosque puesta para el resto


## 18/11 (Pablo): el kit de la demo, solo fuego, agua y tierra y seis glifos.
func _demo() -> void:
	var clave: String = Lanzador3D.aplicar_progresion("demo")
	_ok("13 demo: progresión «demo»", clave == "demo")
	var sellos: PackedStringArray = Repertoire.active_elements()
	_ok("13 demo: sellos exactamente fuego, agua y tierra", sellos.size() == 3 and sellos.has("fuego") and sellos.has("agua") and sellos.has("tierra"), str(sellos))
	_ok("13 demo: sin viento, hielo ni rayo", not Repertoire.element_active("viento") and not Repertoire.element_active("hielo") and not Repertoire.element_active("rayo"))
	var glifos: PackedStringArray = Repertoire.active_sigils()
	var esperados: Array = ["flecha", "linea", "barrera", "altura", "raido", "suelo"]
	var coinciden: bool = glifos.size() == esperados.size()
	for g in esperados:
		coinciden = coinciden and glifos.has(g)
	_ok("13 demo: glifos exactamente flecha, linea, barrera, altura, raido y suelo", coinciden, str(glifos))
	_ok("13 demo: tres páginas, seis glifos por página", Repertoire.max_pages == 3 and Repertoire.max_sigils_per_page == 6)
	_ok("13 demo: libro «bosque»", Repertoire.libro == "bosque", Repertoire.libro)
	var m := MundoFalso.new()
	m.kit = "demo"
	_ok("13 demo: con `kit = \"demo\"`, progresion_de devuelve «demo»", Lanzador3D.progresion_de(m) == "demo")
	m.free()
	Lanzador3D.aplicar_progresion("todo")


## 22/11 (docs/PLAN_HECHIZOS_2026-11-22.md §2): el ARRANQUE de la demo. Las escenas de la ruta lo llevan, lo ganado (flags global.glifo.* / global.sello.*)
## vuelve en cada nivel, la hoja de grimorio suma una página encima, y los cofres aceptan `sello=`.
func _demo_inicio() -> void:
	var clave: String = Lanzador3D.aplicar_progresion("demo_inicio")
	_ok("14 demo_inicio: progresión «demo_inicio»", clave == "demo_inicio")
	_ok("14 demo_inicio: solo fuego", Repertoire.active_elements() == PackedStringArray(["fuego"]), str(Repertoire.active_elements()))
	_ok("14 demo_inicio: flecha y barrera", Repertoire.active_sigils() == PackedStringArray(["flecha", "barrera"]), str(Repertoire.active_sigils()))
	_ok("14 demo_inicio: dos páginas y dos glifos por página, libro «bosque»", Repertoire.max_pages == 2 and Repertoire.max_sigils_per_page == 2 and Repertoire.libro == "bosque",
		"%d páginas, %d huecos, %s" % [Repertoire.max_pages, Repertoire.max_sigils_per_page, Repertoire.libro])
	_ok("14 demo_inicio: capacidad del primer libro (4 y 6)", Repertoire.max_elementos == 4 and Repertoire.max_glifos == 6)
	# El techo de la demo cabe entero sobre el arranque: ningún glifo ni sello del kit «demo» choca con la capacidad.
	var techo: Dictionary = Lanzador3D.PROGRESIONES["demo"]
	var caben: bool = true
	for g in techo["glifos"]:
		Repertoire.unlock_sigil(String(g))
		caben = caben and Repertoire.sigil_active(String(g))
	for e in techo["sellos"]:
		Repertoire.unlock_element(String(e))
		caben = caben and Repertoire.element_active(String(e))
	_ok("14 todo lo del kit «demo» cabe en el libro de arranque", caben, str(Repertoire.active_sigils()))
	_ok("14 y un séptimo glifo (ᛉ) NO cabe: P3 aplazada", not Repertoire.unlock_sigil("permanencia"))
	# Las escenas de la ruta llevan el kit.
	for n in ["PruebaBosque01_v01", "PruebaBosque02", "PruebaCueva", "PruebaCuevaResonante", "PruebaMonteSumicio"]:
		var txt: String = FileAccess.get_file_as_string("res://escenas/%s.tscn" % n)
		_ok("15 %s lleva kit = \"demo_inicio\"" % n, txt.contains("kit = \"demo_inicio\"") and not txt.contains("kit = \"pruebas\""))
	_ok("15 el Pantano sigue con el techo («demo»)", FileAccess.get_file_as_string("res://escenas/PruebaPantano.tscn").contains("kit = \"demo\""))
	_ok("15 el cofre del corazón del Bosque 02 da ᛁ línea", FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/Bosque_02.txt").contains("cofre_corazon cofre 8 30 modelo=legendario glifo=linea"))
	# Lo ganado en otro nivel vuelve al montar el siguiente (Puzle3D._restaurar_glifos), sobre el arranque.
	Flags.i().poner(Puzle3D.FLAG_GLIFO_GANADO + "raido")
	Flags.i().poner(EncargoMarimanta.SELLO_GANADO + "agua")
	Lanzador3D.aplicar_progresion("demo_inicio")
	_ok("16 al montar un nivel, el arranque no trae ᚱ ni agua", not Repertoire.sigil_active("raido") and not Repertoire.element_active("agua"))
	var pz := Puzle3D.new()
	pz._restaurar_glifos()
	pz.free()
	_ok("16 y Puzle3D los devuelve (ᚱ del cofre, agua de Marimanta)", Repertoire.sigil_active("raido") and Repertoire.element_active("agua"))
	Flags.i().quitar(Puzle3D.FLAG_GLIFO_GANADO + "raido")
	Flags.i().quitar(EncargoMarimanta.SELLO_GANADO + "agua")
	# La hoja de grimorio (mejora `paginas`) suma una página encima de las 2 del arranque.
	var antes: int = int(Estado.i().mejoras.get("paginas", 0))
	Estado.i().mejoras["paginas"] = 1
	Mejoras.aplicar_todas(null, false)
	_ok("17 con una hoja de grimorio: 3 páginas", Repertoire.max_pages == 3, str(Repertoire.max_pages))
	Estado.i().mejoras["paginas"] = antes
	Mejoras.aplicar_todas(null, false)
	_ok("17 sin ella, vuelve a 2", Repertoire.max_pages == 2, str(Repertoire.max_pages))
	# `sello=` en los cofres: se acepta un elemento y se rechaza lo que no lo es.
	_ok("18 sello=tierra vale", bool(Puzle3D._valor("sello", "tierra")[0]))
	_ok("18 sello=barrera no vale (es un glifo)", not bool(Puzle3D._valor("sello", "barrera")[0]))
	Lanzador3D.aplicar_progresion("todo")


func _costras() -> void:
	var m := _mundo(["######", "#....#", "~~~~~~", "~~~~~~", "#....#", "######"])
	var rf := RenderFalso.new()
	# M3/M5: el Juego ya no llama al render por reflexión; avisa por Mundo3D.impacto y la maqueta (aquí, rf) escucha.
	var w := Mundo3D.new()
	root.add_child(w)
	w.impacto.connect(func(punto: Vector3, que: String, _r: float) -> void:
		if que == "hielo_desde":
			rf.hielo_desde(punto))
	var sim: AguaSim3D = Terreno3D.montar_agua_sim()
	var c := Vector2i(2, 2)
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.alto_agua)
	_correr(sim, 1.0)
	var tronco := Flotador3D.new()
	tronco.agua = sim
	root.add_child(tronco)
	tronco.global_position = p + Vector3(0.3, 0.0, 0.0)
	var dentro := GoblinFalso.new()
	dentro.add_to_group("combate3d")
	root.add_child(dentro)
	dentro.global_position = p + Vector3(-0.4, 0.0, 0.2)
	var orilla := GoblinFalso.new()
	orilla.add_to_group("combate3d")
	root.add_child(orilla)
	orilla.global_position = Terreno3D.centro_de(Vector2i(2, 1), 1.0)
	await physics_frame
	Lanzador3D.hechizo_sobre_agua("hielo", p)
	_ok("6 la presentación recibió hielo_desde (por Mundo3D.impacto) una vez, en el punto", rf.llamadas.size() == 1 and rf.llamadas[0].is_equal_approx(p))
	_ok("6 y se llamó ANTES de helar (ahí aún no había hielo)", rf.hielo_al_llamar == -INF, str(rf.hielo_al_llamar))
	_ok("6 la casilla quedó helada", sim.casilla_helada(c))
	# Costra en el goblin preso, no en el de la orilla.
	_ok("7 el goblin preso tiene costra", dentro.has_meta("costra_hielo") and is_instance_valid(dentro.get_meta("costra_hielo")))
	var costra_g: CostraHielo3D = dentro.get_meta("costra_hielo") as CostraHielo3D
	_ok("7 la costra cuelga del goblin", costra_g != null and costra_g.get_parent() == dentro)
	_ok("7 el de la orilla no tiene", not orilla.has_meta("costra_hielo"))
	_ok("7 recién hecho el hielo no avisa", costra_g._aviso_objetivo == 0.0)
	# El tronco: costra propia.
	await physics_frame
	_ok("8 el tronco está preso y con costra", tronco.freeze and tronco._costra != null and is_instance_valid(tronco._costra))
	var costra_t: CostraHielo3D = tronco._costra
	# Fracción del hielo.
	var f0: float = sim.fraccion_hielo_en(p)
	_ok("9 fraccion_hielo_en ≈ 1 al empezar", f0 > 0.95, "%.3f" % f0)
	_ok("9 −1 donde no hay hielo", sim.fraccion_hielo_en(Terreno3D.centro_de(Vector2i(2, 1), 1.0)) == -1.0)
	# Al 50 %: sin aviso. Al 90 % del tiempo: aviso (queda < 15 %).
	_correr(sim, AguaSim3D.DURA_HIELO * 0.5)
	_ok("10 a mitad de tiempo, sin aviso", costra_g._aviso_objetivo == 0.0, "fracción %.2f" % sim.fraccion_hielo_en(p))
	_correr(sim, AguaSim3D.DURA_HIELO * 0.4)
	var f1: float = sim.fraccion_hielo_en(p)
	_ok("10 quedando < 15 %: la costra avisa", f1 >= 0.0 and f1 < Lanzador3D.AVISO_HIELO and costra_g._aviso_objetivo == 1.0, "fracción %.2f" % f1)
	_ok("10 el goblin sigue preso", dentro.has_meta("preso_hielo") and dentro.congelado > 0.0)
	# Se suelta.
	_correr(sim, AguaSim3D.DURA_HIELO * 0.2)
	_ok("11 el hielo se soltó", not sim.casilla_helada(c))
	_ok("11 el goblin queda libre y sin marca", not dentro.has_meta("preso_hielo") and dentro.congelado == 0.0 and not dentro.has_meta("costra_hielo"))
	_ok("11 su costra se está deshaciendo (derretir)", costra_g._saliendo)
	await physics_frame
	_ok("11 el tronco vuelve a flotar y su costra se deshace", not tronco.freeze and costra_t._saliendo and tronco._costra == null)
	# Y la costra se borra sola tras su fundido.
	for _i in range(40):
		await process_frame
	await create_timer(0.5).timeout
	_ok("12 las costras acaban borrándose", not is_instance_valid(costra_g) and not is_instance_valid(costra_t))
	_ok("12 sin presos pendientes", Lanzador3D._presos.is_empty())
	rf.free()
