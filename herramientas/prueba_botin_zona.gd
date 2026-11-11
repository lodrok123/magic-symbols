extends SceneTree
## ARREGLOS DE BOTÍN (11/11, Juego; docs/REVISION_OBJETOS_SINTESIS.md §4 y §9.1):
##   1 · lobernos y canouros tienen tabla propia (pelaje y garra), no el colmillo de goblin; el chamán suelta a veces la gota de veneno
##   2 · el cofre pequeño da SIEMPRE oro y SIEMPRE un ingrediente (la poción, a veces)
##   3 · los jarrones ya no dan poción: dan un ingrediente de su zona
##   4 · las plantas del bosque son piezas de mapa (Objetos.PLANTAS) con su objeto y su modelo; Bosque_02 y la Cueva las colocan
##   5 · todo ingrediente nuevo tiene fuente y texto
##   godot --headless --path . --script res://herramientas/prueba_botin_zona.gd

const TIRADAS: int = 400
var _fallos: int = 0


func _initialize() -> void:
	_probar()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		_fallos += 1
	print(("OK    " if bien else "FALLO ") + nombre + ("  " + info if info != "" else ""))


func _que(tabla: String) -> Dictionary:
	var vistos: Dictionary = {}
	for _i in range(TIRADAS):
		for r in Botin.tirar(tabla):
			vistos[String(r["que"])] = int(vistos.get(String(r["que"]), 0)) + 1
	return vistos


func _probar() -> void:
	# 1 · animales y chamán
	var lob: Dictionary = _que("loberno")
	var can: Dictionary = _que("canouro")
	_ok("1 el loberno suelta oro siempre y pelaje (nunca colmillo de goblin)", int(lob.get("oro", 0)) == TIRADAS and lob.has("pelaje_loberno") and not lob.has("colmillo_goblin"), str(lob))
	_ok("1 el canouro suelta oro siempre y garra", int(can.get("oro", 0)) == TIRADAS and can.has("garra_canouro") and not can.has("colmillo_goblin"), str(can))
	var cha: Dictionary = _que("chaman")
	var p_gota: float = float(cha.get("gota_veneno", 0)) / float(TIRADAS)
	_ok("1 el chamán suelta gota de veneno ≈ 30 %", p_gota > 0.2 and p_gota < 0.4, "%.2f" % p_gota)
	# 2 · cofre pequeño
	var sin_ingrediente: int = 0
	var sin_oro: int = 0
	var pociones: int = 0
	for _i in range(TIRADAS):
		var lista: Array = Botin.tirar("cofre_pequeno")
		var hay_oro: bool = false
		var hay_ing: bool = false
		for r in lista:
			var q: String = String(r["que"])
			if q == "oro":
				hay_oro = true
			elif q == "pocion":
				pociones += 1
			elif Objetos.etiquetas(q).size() > 0:
				hay_ing = true
		sin_oro += 0 if hay_oro else 1
		sin_ingrediente += 0 if hay_ing else 1
	_ok("2 el cofre pequeño da siempre oro y siempre un ingrediente", sin_oro == 0 and sin_ingrediente == 0, "sin oro %d · sin ingrediente %d" % [sin_oro, sin_ingrediente])
	_ok("2 y a veces una poción (≈ 40 %)", pociones > TIRADAS * 0.3 and pociones < TIRADAS * 0.5, str(pociones))
	# 3 · jarrones
	var con_pocion: Array = []
	var sin_ing: Array = []
	for t in ["jarron_bosque", "jarron_ruinas", "jarron_cueva", "jarron_campamento", "jarron_clasico", "jarron_atardecer", "jarron_agua", "jarron_fuego", "jarron_hielo"]:
		var v: Dictionary = _que(t)
		if v.has("pocion"):
			con_pocion.append(t)
		var algo: bool = false
		for q in v:
			if Objetos.etiquetas(String(q)).size() > 0:
				algo = true
		if not algo:
			sin_ing.append(t)
	_ok("3 ningún jarrón de zona da poción", con_pocion.is_empty(), str(con_pocion))
	_ok("3 todos dan algún ingrediente de su zona", sin_ing.is_empty(), str(sin_ing))
	# 4 · plantas
	var mal: Array = []
	for pieza in ["flor", "raiz", "lavanda", "bayas", "helecho", "flor_silvestre"]:
		var base: String = String((Objetos.PLANTAS.get(pieza, {}) as Dictionary).get("base", ""))
		var modelo: String = String(BD.objeto(base).get("modelo", ""))
		if base == "" or not ResourceLoader.exists("res://arte/piezas/%s.tscn" % modelo):
			mal.append("%s → %s (%s)" % [pieza, base, modelo])
	_ok("4 las seis plantas del bosque son piezas con su objeto y un modelo que existe", mal.is_empty(), str(mal))
	_ok("4 la flor y la raíz se transforman con un elemento (fuego)", String(Objetos.PLANTAS["flor"]["tabla"].get("fuego", "")) == "flor_ardiente" and String(Objetos.PLANTAS["raiz"]["tabla"].get("fuego", "")) == "raiz_cenizas")
	const NUEVAS: Array = ["flor", "raiz", "lavanda", "bayas", "helecho", "flor_silvestre", "musgo", "helecho_cueva", "seta_palida"]
	for mapa in ["Bosque_02", "CuevaResonante"]:
		var texto: String = FileAccess.get_file_as_string("res://mundo/datos_nivel/mapas/%s.txt" % mapa)
		var r: Dictionary = Puzle3D.parsear(texto)
		var plantas: int = 0
		for pz in (r.get("piezas", []) as Array):
			if String(pz.tipo) in NUEVAS:
				plantas += 1
		var avisos: Array = []
		for a in (r.get("avisos", []) as Array):
			for t in NUEVAS:
				if String(a).contains(String(t)):
					avisos.append(a)
					break
		_ok("4 %s: las plantas se leen sin avisos" % mapa, plantas >= (12 if mapa == "Bosque_02" else 5) and avisos.is_empty(), "%d plantas · avisos %s" % [plantas, str(avisos)])
	# 5 · fuentes y textos
	var sin: Array = []
	for id in ["pelaje_loberno", "garra_canouro", "gota_veneno"]:
		if BD.fuentes_de(id).is_empty() or TextosObjetos.descripcion(id) == "":
			sin.append(id)
	_ok("5 pelaje, garra y gota de veneno tienen fuente y texto", sin.is_empty(), str(sin))
