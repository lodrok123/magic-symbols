extends "res://nivel_base.gd"

## TEST 2: LABORATORIO DE ELEMENTOS (40 x 40).
##
## Un mapa grande pensado para PROBAR CADA ELEMENTO por separado y sacar conclusiones:
## seis cámaras, una por elemento, y cada una pide usar SU elemento para superar la prueba.
## La puerta del norte (X) solo se abre con las seis pruebas superadas.
## Se empieza con TODOS los sellos y glifos (es un laboratorio, no una progresión).
##
##              +----------- SALIDA (E) tras la puerta (X) -----------+
##   FUEGO      |                                                     |   VIENTO
##   telaraña + setos que       PLAZA: goblins (W, A) con IA,           fogatas (F) -> canal de agua
##   cierran el paso; tótem     plantas reactivas (s f q)               -> antorchas (T) en la isla:
##   de fuego (j) al fondo                                              el viento lleva la llama
##   AGUA                                                               RAYO
##   barrera de fuego (B) en                                            tótem de rayo (i): tiende
##   el hueco; tótem de agua (k)                                        el puente (b) sobre el río
##   TIERRA                     ALDEA: inicio (S), puestos con su       HIELO
##   foso de agua y PLACA DE    tendero al norte (n librera,            río de 4 casillas: hay que
##   PESO (K): solo la pisa un  Q alquimista), guardabosques (M),       congelar un camino (4 casillas
##   bloque de tierra creado    dummy (D)                               heladas como mínimo)
##
## LETRA K (de nivel_base.gd) = placa de peso (el jugador NO la activa: hace falta un bloque de tierra
## creado con el sello TIERRA, o un bloque empujable, encima).
##
## PARA SACAR CONCLUSIONES: cada prueba superada se apunta en PlayLog con los segundos que
## costó ("prueba", {elemento, segundos}). En docs/TEST2_CONCLUSIONES.md están las
## preguntas a responder mientras se juega.

const MAPA_TEST2: PackedStringArray = [
	"########################################",
	"#.......z....###........###....~~~gggg##",
	"#.......z....###...E....###....~~~gggg##",
	"#.......z.l..###........###..F.~~~gTgg##",
	"#.......z....###........###....~~~gggg##",
	"#...j...z....###........###....~~~gggg##",
	"#.......z....r.####X#####....F.~~~gTgg##",
	"#.......z....#............#....~~~gggg##",
	"#.......z....#.......q....#....~~~gggg##",
	"#.......z..h.#........A...#..F.~~~gTgg##",
	"#.......z....#............#....~~~gggg##",
	"##############..W.........##############",
	"#.......#....#............#....~.......#",
	"#.......#....#.........A..#....~.......#",
	"#.......#....#.#..........#..i.~.......#",
	"#.......#....#....W.....#.#....~.......#",
	"#...k...B......................b.......#",
	"#.......B....#........#...#....~.......#",
	"#.......#....#...#........#....~.......#",
	"#.......#....#..........f.#....~.......#",
	"#.......#....#.s..........#....~.......#",
	"#.......#....#............#....~.......#",
	"##############......q.....##############",
	"#........~~..#............#...~~~~.....#",
	"#........~~..#..f......s..#...~~~~.....#",
	"#........~~..#............#...~~~~.....#",
	"#.####...~~..#............#...~~~~.....#",
	"#.#......~~..#.....M......#...~~~~.....#",
	"#.#......~~..#............#...~~~~.....#",
	"#.#......~~..#............#...~~~~.....#",
	"#.#.K....~~...................~~~~.....#",
	"#.#......~~..#.n......Q...#...~~~~.....#",
	"#.#......~~..#............#...~~~~.....#",
	"#.#......~~..#............#...~~~~.....#",
	"#.####...~~..#............#...~~~~.....#",
	"#........~~..#..........D.#...~~~~.....#",
	"#........~~..#.....S......#...~~~~.....#",
	"#........~~..#............#...~~~~.....#",
	"#........~~..#............#...~~~~.....#",
	"########################################",
]

const ORDEN_PRUEBAS: Array = ["fuego", "agua", "tierra", "viento", "rayo", "hielo"]
const PISTA_PRUEBA: Dictionary = {
	"fuego": "quema la telaraña y los setos; enciende el tótem",
	"agua": "apaga la barrera de fuego; moja el tótem",
	"tierra": "cruza el foso y crea un bloque de tierra sobre la placa",
	"viento": "el viento recoge la llama y la lleva a las antorchas",
	"rayo": "electrifica el tótem para tender el puente",
	"hielo": "congela un camino sobre el río (4 casillas)",
}
const COLOR_PRUEBA: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "tierra": Color(0.8, 0.62, 0.35),
	"viento": Color(0.8, 0.95, 0.85), "rayo": Color(1.0, 0.95, 0.4), "hielo": Color(0.7, 0.95, 1.0),
}
## Dónde va el rótulo de cada cámara (en su entrada).
const ROTULOS: Dictionary = {
	"fuego": Vector2i(11, 6), "agua": Vector2i(11, 16), "tierra": Vector2i(11, 30),
	"viento": Vector2i(28, 6), "rayo": Vector2i(28, 16), "hielo": Vector2i(28, 30),
}
const ZONA_HIELO: Rect2i = Rect2i(30, 23, 4, 16)      ## el río de la cámara de hielo
const HIELO_NECESARIO: int = 4

const GUARDADOS_T2: Array = [Vector2i(19, 33), Vector2i(19, 21), Vector2i(36, 30), Vector2i(36, 16)]
const SUELO_T2: Array = [
	["oro", 2, 2, 10], ["pocion", 2, 13, 1], ["oro", 5, 36, 10], ["oro", 37, 2, 10],
	["oro", 37, 13, 10], ["pocion", 37, 36, 1], ["oro", 36, 37, 10],
	["pocion", 17, 34, 1], ["oro", 21, 34, 5], ["oro", 14, 8, 5], ["oro", 24, 21, 5],
]

var _aguas_hielo: Array = []
var _hechas: Dictionary = {}
var _t_inicio: float = 0.0


func _mapa() -> PackedStringArray:
	return MAPA_TEST2


func _repertorio_inicial() -> void:
	Repertoire.aim_with_mouse = APUNTAR_CON_RATON
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 3


func _agua(cell: Vector2i) -> Node2D:
	var a: Node2D = super(cell)
	if ZONA_HIELO.has_point(cell):
		_aguas_hielo.append(a)
	return a


func _lista_props() -> Array:
	var l: Array = []
	var decor: Array = ["bush", "fern", "flowers", "lavender", "grass_clump", "groundcover",
		"rocks", "bush_berry", "cairn_deco"]
	var m: PackedStringArray = _mapa()
	for y in range(m.size()):
		for x in range(m[y].length()):
			if m[y][x] == "." and _hash(x, y, 3) % 8 == 0:
				l.append([decor[_hash(x, y, 5) % decor.size()], x, y])
	return l


func _celdas_guardado() -> Array:
	return GUARDADOS_T2


func _suelo_objetos() -> Array:
	return SUELO_T2


func _definir_encargos() -> void:
	var n: Npc = _rangers.get(Vector2i(19, 27))
	if n != null:
		misiones.definir(n, "Acabar con 3 goblins de la plaza", "matar", 3,
			["Los goblins de la plaza no dejan pasar a nadie hacia la puerta del norte.",
			"Cada uno tiene una debilidad: mira el rombo de color junto a su barra de vida."],
			{"centro": _at(Vector2i(19, 12)), "radio": 620.0})


func _extras_nivel() -> void:
	_t_inicio = Time.get_ticks_msec() / 1000.0
	if is_instance_valid(_llamas):
		_llamas.visible = false
	for k in ROTULOS:
		_rotulo(ROTULOS[k], k.to_upper() + "\n" + String(PISTA_PRUEBA[k]), COLOR_PRUEBA[k])
	_avisar("Laboratorio: supera las 6 pruebas de elemento")


## Un rótulo flotante en el mundo (sin arte todavía: ver docs/ASSETS_PENDIENTES.md).
func _rotulo(cell: Vector2i, texto: String, color: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(300.0, 60.0)
	l.position = _at(cell) + Vector2(-150.0, -140.0)
	l.z_index = 30
	add_child(l)


## --- Las seis pruebas ---

func _hielo_hecho() -> int:
	var n: int = 0
	for a in _aguas_hielo:
		if is_instance_valid(a) and bool(a.get("is_frozen")):
			n += 1
	return n


func _progreso() -> Dictionary:
	return {
		"fuego": 1.0 if _totems_activos.has("fuego") else 0.0,
		"agua": 1.0 if _totems_activos.has("agua") else 0.0,
		"tierra": 1.0 if (_placa_peso != null and _placa_peso.usado) else 0.0,
		"viento": float(_antorchas_encendidas()) / float(maxi(1, _antorchas.size())),
		"rayo": 1.0 if _puente_hecho else 0.0,
		"hielo": minf(1.0, float(_hielo_hecho()) / float(HIELO_NECESARIO)),
	}


func _actualizar_tareas() -> void:
	var p: Dictionary = _progreso()
	for k in p:
		if float(p[k]) >= 1.0 and not _hechas.get(k, false):
			_hechas[k] = true
			var seg: float = Time.get_ticks_msec() / 1000.0 - _t_inicio
			PlayLog.event("prueba", {"elemento": k, "segundos": snappedf(seg, 0.1)})
			Sonidos.play(self, "comprar", -4.0)
			_avisar("¡Prueba superada: %s!  (%d/6)" % [k.to_upper(), _hechas.size()])
	if is_instance_valid(_puerta_final) and _puerta_final.is_open and not _final_avisada:
		_final_avisada = true
		_avisar("¡Se abre la puerta del norte!")
	_refrescar_hud()


func _actualizar_llamas() -> void:
	pass


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var p: Dictionary = _progreso()
	var lineas: Array = []
	var hechas: int = 0
	for k in ORDEN_PRUEBAS:
		var v: float = float(p[k])
		if v >= 1.0:
			hechas += 1
		var extra: String = ""
		if k == "viento":
			extra = "  %d/%d" % [_antorchas_encendidas(), _antorchas.size()]
		elif k == "hielo":
			extra = "  %d/%d" % [mini(_hielo_hecho(), HIELO_NECESARIO), HIELO_NECESARIO]
		lineas.append("%s %s%s" % ["[x]" if v >= 1.0 else "[ ]", k.to_upper(), extra])
	_hud.text = "Oro: %d\nSellos: %s\nGlifos: %s  (huecos: %d)\n\nPRUEBAS  %d/6\n%s" % [
		_oro, ", ".join(Repertoire.active_elements()), ", ".join(Repertoire.active_sigils()),
		Repertoire.max_sigils_per_page, hechas, "\n".join(lineas)]
	if misiones != null:
		var t: String = misiones.texto_hud()
		if t != "":
			_hud.text += "\n\nENCARGOS\n" + t
