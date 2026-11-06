extends SceneTree
## 6/11 (bloque A2 de docs/PROPUESTAS_COMBATE_2026-11-06.md): DEBILIDADES POR PIEZA DE MAPA, NO POR DEFECTO. Decisión de Pablo: ningún elemento es más fuerte que otro; los goblins ya no son
## débiles al agua ni resisten el fuego salvo en el Bosque (nivel inicial, que se queda como estaba).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_debilidades_pieza.gd
## Comprueba:
##   1. un goblin suelto (mundo sin nivel o de otro nivel: la Gruta) sale SIN debilidad ni resistencia,
##   2. una pieza `vigia ... debil=rayo resiste=agua` se las pone a los enemigos de sus casillas (y solo a ellos), y el daño lo nota (rayo ×1,5, agua ×0,75),
##   3. en una escena con el defecto del Bosque (nivel Bosque, Bosque_01, Bosque_01_v01, Bosque_02) los goblins son débiles al agua y resisten el fuego,
##   4. la pieza SOBRESCRIBE el defecto del Bosque (y con solo `debil=` se conserva la resistencia del nivel),
##   5. la gramática: un elemento que no existe avisa y descarta la pieza; el rombo de la cabeza se repinta con el color de la nueva debilidad.

class FalsoLanzador extends Node:
	var jugador: Node3D = null

const S: float = 2.3
const LADO: int = 16
const BOSQUE_FUENTE: String = "extends Mundo3D\nvar nivel: String = \"%s\"\n"

var _fallos: int = 0
var _jugador: Jugador3D = null
var _lanz: FalsoLanzador = null
var _cuerpo_jugador: Node3D = null
var _mundo_neutro: Mundo3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_gramatica()
	_montar_terreno()
	_goblin_suelto()
	await _pieza_fija()
	_defecto_del_bosque()
	await _pieza_sobrescribe_el_bosque()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar_terreno() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			f += "#" if borde else "."
			if borde:
				bloq[Vector2i(x, y)] = true
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo_neutro = Mundo3D.new()
	root.add_child(_mundo_neutro)
	_jugador = Jugador3D.new()
	_jugador.pj = Pj3D.new()
	_mundo_neutro.add_child(_jugador.pj)
	_cuerpo_jugador = Node3D.new()
	_cuerpo_jugador.position = _centro(1, 1)
	_mundo_neutro.add_child(_cuerpo_jugador)
	_lanz = FalsoLanzador.new()
	_lanz.jugador = _cuerpo_jugador
	_lanz.add_to_group("player")
	root.add_child(_lanz)


func _centro(cx: int, cy: int) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(cx, cy)), (cy + 0.5) * S)


## Un mundo (Mundo3D) con una propiedad `nivel`, como la maqueta de verdad (`PruebaTest2.nivel`): lo único que mira `Combate3D.debilidad_defecto_de`.
func _mundo_de_nivel(nivel: String) -> Mundo3D:
	var s := GDScript.new()
	s.source_code = BOSQUE_FUENTE % nivel
	s.reload()
	var m: Mundo3D = s.new() as Mundo3D
	root.add_child(m)
	return m


func _goblin(mundo: Mundo3D, tipo: String, cx: int, cy: int) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior" if tipo == "guerrero" else "goblin_archer"
	modelo.position = _centro(cx, cy)
	mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = _centro(cx, cy)
	g.casa = g.position
	return g


func _levantar(mundo: Mundo3D, texto: String) -> Puzle3D:
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(mundo, "", texto)
	return z


func _espera(s: float) -> void:
	await create_timer(s).timeout


# --- 5 · gramática -------------------------------------------------------------------------------------------------------

func _gramatica() -> void:
	var bien: Dictionary = Puzle3D.parsear("; pieza v vigia 1 1 de=5,5 debil=rayo resiste=agua")
	_ok("5 `vigia ... debil=rayo resiste=agua` se lee sin avisos", (bien["piezas"] as Array).size() == 1 and (bien["avisos"] as Array).is_empty(), str(bien["avisos"]))
	if (bien["piezas"] as Array).size() == 1:
		var p: Puzle3D.Pieza = bien["piezas"][0]
		_ok("5 y guarda los dos elementos", String(p.p.get("debil", "")) == "rayo" and String(p.p.get("resiste", "")) == "agua", str(p.p))
	var mal: Dictionary = Puzle3D.parsear("; pieza v vigia 1 1 de=5,5 debil=pepino")
	_ok("5 un elemento que no existe avisa y la pieza se descarta (no se monta a medias)", (mal["piezas"] as Array).is_empty() and not (mal["avisos"] as Array).is_empty(), str(mal["avisos"]))


# --- 1 · goblin suelto ---------------------------------------------------------------------------------------------------

func _goblin_suelto() -> void:
	var g: Combate3D = _goblin(_mundo_neutro, "guerrero", 3, 3)
	_ok("1 goblin suelto en un mundo sin nivel: sin debilidad ni resistencia", g.debil == "" and g.resiste == "", "debil «%s» resiste «%s»" % [g.debil, g.resiste])
	var a: Combate3D = _goblin(_mundo_neutro, "arquero", 4, 3)
	_ok("1 el arquero tampoco", a.debil == "" and a.resiste == "")
	var gruta: Mundo3D = _mundo_de_nivel("GrutaBatida")
	var gg: Combate3D = _goblin(gruta, "guerrero", 3, 5)
	_ok("1 goblin de la Gruta (nivel con `nivel` pero sin fila en DEBILIDAD_GOBLIN_POR_NIVEL): sin debilidad", gg.debil == "" and gg.resiste == "")
	var hechizo_agua: Hechizo = Hechizo.construir(load("res://nucleo/water_rune.tres") as RuneData, {})
	_ok("1 sin debilidad el daño de agua es R = ×1", is_equal_approx(float(g.decidir_golpe(hechizo_agua)["mult"]), 1.0))


# --- 2 · la pieza fija la debilidad ----------------------------------------------------------------------------------------

func _pieza_fija() -> void:
	var dentro: Combate3D = _goblin(_mundo_neutro, "guerrero", 8, 8)
	var dentro2: Combate3D = _goblin(_mundo_neutro, "arquero", 9, 8)
	var fuera: Combate3D = _goblin(_mundo_neutro, "guerrero", 12, 12)
	var z: Puzle3D = _levantar(_mundo_neutro, "; pieza v vigia 1 1 de=8,8+9,8 debil=rayo resiste=agua")
	await _espera(0.3)
	_ok("2 la pieza se monta sin avisos", z.avisos.is_empty() and z.nodo("v") != null, str(z.avisos))
	_ok("2 los enemigos de sus casillas: débiles al rayo y resisten el agua", dentro.debil == "rayo" and dentro.resiste == "agua" and dentro2.debil == "rayo" and dentro2.resiste == "agua", "%s/%s %s/%s" % [dentro.debil, dentro.resiste, dentro2.debil, dentro2.resiste])
	_ok("2 el de fuera no se toca", fuera.debil == "" and fuera.resiste == "")
	var rayo: Hechizo = Hechizo.construir(load("res://nucleo/lightning_rune.tres") as RuneData, {"flecha": 1})
	var agua: Hechizo = Hechizo.construir(load("res://nucleo/water_rune.tres") as RuneData, {"flecha": 1})
	var hielo: Hechizo = Hechizo.construir(load("res://nucleo/ice_rune.tres") as RuneData, {"flecha": 1})
	_ok("2 y el daño lo nota: rayo ×1,5 · agua ×0,75 · hielo ×0,75 (resistir el agua es resistir el hielo) · el de fuera ×1",
		is_equal_approx(float(dentro.decidir_golpe(rayo)["mult"]), 1.5) and is_equal_approx(float(dentro.decidir_golpe(agua)["mult"]), 0.75) and is_equal_approx(float(dentro.decidir_golpe(hielo)["mult"]), 0.75) \
		and is_equal_approx(float(fuera.decidir_golpe(rayo)["mult"]), 1.0))
	var marca: Label3D = dentro.get("_marca_debil") as Label3D
	var col_rayo: Color = Combate3D.COLORES.get("rayo", Color.WHITE)
	_ok("5 el rombo de la cabeza se repinta con el color de la nueva debilidad", marca != null and marca.modulate.is_equal_approx(col_rayo), "rombo %s esperado %s" % [str(marca.modulate if marca != null else null), str(col_rayo)])


# --- 3 · el defecto del Bosque ------------------------------------------------------------------------------------------------

func _defecto_del_bosque() -> void:
	var cx: int = 3
	for nivel in ["Bosque", "Bosque_01", "Bosque_01_v01", "Bosque_02"]:
		var m: Mundo3D = _mundo_de_nivel(nivel)
		var g: Combate3D = _goblin(m, "guerrero", cx, 10)
		cx += 1
		_ok("3 goblin en el nivel «%s»: débil agua, resiste fuego (como siempre)" % nivel, g.debil == "agua" and g.resiste == "fuego", "debil «%s» resiste «%s»" % [g.debil, g.resiste])
	_ok("3 la tabla por nivel lo dice: solo «Bosque» (prefijo)", Combate3D.DEBILIDAD_GOBLIN_POR_NIVEL.keys() == ["Bosque"] and String(Combate3D.DEBILIDAD_GOBLIN_POR_NIVEL["Bosque"]["debil"]) == "agua" and String(Combate3D.DEBILIDAD_GOBLIN_POR_NIVEL["Bosque"]["resiste"]) == "fuego")
	var agua: Hechizo = Hechizo.construir(load("res://nucleo/water_rune.tres") as RuneData, {})
	var fuego: Hechizo = Hechizo.construir(load("res://nucleo/fire_rune.tres") as RuneData, {})
	var gb: Combate3D = _goblin(_mundo_de_nivel("Bosque_02"), "guerrero", 8, 10)
	_ok("3 y el daño del Bosque no cambia: agua ×1,5 · fuego ×0,75", is_equal_approx(float(gb.decidir_golpe(agua)["mult"]), 1.5) and is_equal_approx(float(gb.decidir_golpe(fuego)["mult"]), 0.75))


# --- 4 · la pieza manda sobre el defecto del Bosque ----------------------------------------------------------------------------

func _pieza_sobrescribe_el_bosque() -> void:
	var m: Mundo3D = _mundo_de_nivel("Bosque_02")
	var a: Combate3D = _goblin(m, "guerrero", 3, 13)
	var b: Combate3D = _goblin(m, "guerrero", 5, 13)
	var c: Combate3D = _goblin(m, "guerrero", 7, 13)
	_ok("4 antes de la pieza, los tres tienen el defecto del Bosque", a.debil == "agua" and b.debil == "agua" and c.debil == "agua")
	var z: Puzle3D = _levantar(m, "; pieza p1 vigia 1 1 de=3,13 debil=rayo resiste=agua\n; pieza p2 vigia 2 1 de=5,13 debil=hielo")
	await _espera(0.3)
	_ok("4 la pieza sobrescribe el defecto: rayo / agua", a.debil == "rayo" and a.resiste == "agua", "%s/%s" % [a.debil, a.resiste])
	_ok("4 con solo `debil=` se conserva la resistencia del nivel (hielo / fuego)", b.debil == "hielo" and b.resiste == "fuego", "%s/%s" % [b.debil, b.resiste])
	_ok("4 el que ninguna pieza toca sigue con el defecto del Bosque", c.debil == "agua" and c.resiste == "fuego")
	_ok("4 sin avisos", z.avisos.is_empty(), str(z.avisos))
