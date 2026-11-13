extends SceneTree
## C1 punto 2 (2/11, lote 3 de la auditoría del 24/10): UN SOLO NOMBRE POR REACCIÓN entre `Combate3D` y `Mundo3D`.
## Sin ventana: godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_catalogo_reacciones.gd
##
## Qué comprueba:
##   A. PRUEBA DE IGUALDAD (como HC1-HC3 con `Hechizo`): una batería de escenarios fijos (6 elementos × 4 estados previos del goblin, la quemadura que
##      se acaba, muerte ardiendo, contacto con llama, empujón, hundimiento, y los tres reactivos de siempre) captura la SECUENCIA de reacciones que sale
##      de cada uno (`Mundo3D.reaccion`) y la compara con `GOLDEN`, que se sacó de `main` ANTES de unificar los nombres. Si una constante cambia un nombre, falla.
##   B. UN SOLO CATÁLOGO: `Mundo3D.REACCIONES` es la lista y las constantes `Mundo3D.R_*` son sus nombres; coincide con la tabla del Pipeline (`ReaccionesVfx3D.CATALOGO`);
##      las 7 reacciones del contrato del enemigo (`Combate3D.REACCIONES`) se traducen a un aviso del catálogo con `Mundo3D.AVISO_DE_CONTRATO` (sin nombres huérfanos).
##   C. NOMBRES ESCRITOS A MANO: ningún .gd de la lógica (enemigos, objetos, mundo, magia, nucleo) pasa a `avisar_reaccion` / `_reaccionar` / `_avisar` un literal que no sea
##      del catálogo, ni uno que ya tenga constante (se usa `Mundo3D.R_*`). Y se MIDE quién emite `apagado_viento`: nadie (el viento lleva la llama, no la apaga).
##   D. Medido, no arreglado (decisión de Pablo): al acabarse la quemadura de un goblin VIVO se emite `consumido` y la tabla del Pipeline lo dibuja como ceniza.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const COL_AGUA: Array = [6, 7]
const Y_FILAS: Array = [3, 4, 5, 6, 7, 8]
const CARPETAS_LOGICA: Array = ["enemigos", "objetos", "mundo", "magia", "nucleo", "jugador", "escenas"]

## Sacado de `main` (34112d15) antes de tocar nada: escenario -> reacciones en orden, separadas por coma.
const GOLDEN: Dictionary = {
	"golpe fuego sobre seco": "prendido,empujado",
	"golpe agua sobre seco": "mojado,empujado",
	"golpe hielo sobre seco": "congelado,empujado",
	"golpe rayo sobre seco": "electrocutado,empujado,aturdido",
	"golpe viento sobre seco": "",
	"golpe tierra sobre seco": "empujado",
	"golpe fuego sobre mojado": "secado,empujado",
	"golpe agua sobre mojado": "empujado",
	"golpe hielo sobre mojado": "congelado,empujado",
	"golpe rayo sobre mojado": "electrocutado,empujado,aturdido",
	"golpe viento sobre mojado": "",
	"golpe tierra sobre mojado": "empujado",
	"golpe fuego sobre ardiendo": "empujado",
	"golpe agua sobre ardiendo": "apagado_agua,cegado,mojado,empujado",
	"golpe hielo sobre ardiendo": "apagado_agua,congelado,empujado",
	"golpe rayo sobre ardiendo": "electrocutado,empujado,aturdido",
	"golpe viento sobre ardiendo": "",
	"golpe tierra sobre ardiendo": "empujado",
	"golpe fuego sobre congelado": "prendido,empujado",
	"golpe agua sobre congelado": "mojado,empujado",
	"golpe hielo sobre congelado": "empujado",
	"golpe rayo sobre congelado": "electrocutado,roto,empujado,aturdido",
	"golpe viento sobre congelado": "roto",
	"golpe tierra sobre congelado": "roto,empujado",
	"cadena fuego-agua-fuego": "prendido,apagado_agua,cegado,mojado,secado",
	"se acaba la quemadura": "consumido",
	"muere ardiendo": "consumido",
	"prender por contacto dos veces": "prendido",
	# 13/11: era «mojado». Desde el bloque A2 (713e3781, 6/11) el goblin ya no nace débil al agua: sin debilidad el golpe de agua no le da el hitstop largo ni lo
	# demás de «débil», y en los 10 pasos el mojado de 0,05 s se seca de verdad (comprobado: con `debil = "agua"` vuelve a salir solo «mojado»).
	"mojar dos veces y secarse": "mojado,secado",
	"congelar y descongelarse": "congelado,derretido",
	"dos rayos": "electrocutado,aturdido,electrocutado",
	"empujon": "empujado",
	"seto prende, se apaga, prende y se consume": "prendido,apagado_agua,prendido,consumido",
	"seto mojable": "mojado,secado",
	"fogata enciende, apaga con agua, enciende y se apaga por regla": "prendido,apagado_agua,prendido,consumido",
	"empujado al agua honda": "empujado,hundido",
}

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fx: Vfx3D = null
var _fallos: int = 0
var _emitidas: Array = []
var _puesto: int = 0
var _capturado: Dictionary = {}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_escenarios_goblin()
	_escenarios_tiempo()
	_escenarios_reactivos()
	await _hundimiento()
	_igualdad()
	_catalogo_unico()
	_literales()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			if borde:
				f += "#"
				bloq[Vector2i(x, y)] = true
			elif COL_AGUA.has(x) and Y_FILAS.has(y):
				f += "~"
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_mundo.reaccion.connect(func(n: String, p: Vector3, nd: Node) -> void: _emitidas.append([n, p, nd]))
	_fx = Vfx3D.new()
	root.add_child(_fx)
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 12.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)


func _suelo(cx: float, cz: float) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(int(cx), int(cz))), (cz + 0.5) * S)


## Un hueco libre distinto cada vez (columnas 2-5 y 8-11, filas 3-8).
func _hueco() -> Vector3:
	var cols: Array = [2, 3, 4, 5, 8, 9, 10, 11]
	var i: int = _puesto
	_puesto += 1
	return _suelo(float(cols[i % cols.size()]), float(3 + (i / cols.size()) % 6))


func _goblin(p: Vector3) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = "goblin_warrior"
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.health = 100000.0
	g.vida_max = 100000.0
	return g


func _pasos(g: Combate3D, n: int) -> void:
	for _i in range(n):
		if is_instance_valid(g):
			g._physics_process(DT)


func _h(archivo: String) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), {})


func _runa(tags: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for g in tags:
		t.append(String(g))
	r.tags = t
	return r


## Las reacciones que salieron de `nodo`, en orden, como «a,b,c».
func _firma(nodo: Node) -> String:
	var l: PackedStringArray = []
	for e in _emitidas:
		if e[2] == nodo:
			l.append(String(e[0]))
	return ",".join(l)


func _apunta(clave: String, nodo: Node) -> void:
	_capturado[clave] = _firma(nodo)


func _escenarios_goblin() -> void:
	var elementos: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "viento": "wind", "tierra": "earth"}
	for previo in ["seco", "mojado", "ardiendo", "congelado"]:
		for el in elementos.keys():
			var g := _goblin(_hueco())
			match previo:
				"mojado":
					g.mojado = 5.0
				"ardiendo":
					g.quemando = 5.0
				"congelado":
					g.congelado = 5.0
			_emitidas.clear()
			g.golpe(_h(String(elementos[el])), Vector3(1, 0, 0))
			_pasos(g, 3)
			_apunta("golpe %s sobre %s" % [el, previo], g)


func _escenarios_tiempo() -> void:
	_emitidas.clear()
	var g := _goblin(_hueco())
	g.golpe(_h("fire"), Vector3.ZERO)
	_pasos(g, 30)
	g.golpe(_h("water"), Vector3.ZERO)
	g.golpe(_h("fire"), Vector3.ZERO)
	_apunta("cadena fuego-agua-fuego", g)

	var h := _goblin(_hueco())
	h.quemando = 0.1
	_pasos(h, 20)
	_apunta("se acaba la quemadura", h)

	var m := _goblin(_hueco())
	m.quemando = 5.0
	m.receive_damage(m.health + 1.0)
	_pasos(m, 5)
	_apunta("muere ardiendo", m)

	var c := _goblin(_hueco())
	c.prender_por_contacto()
	c.prender_por_contacto()
	_apunta("prender por contacto dos veces", c)

	var a := _goblin(_hueco())
	a.golpe(_h("water"), Vector3.ZERO)
	a.golpe(_h("water"), Vector3.ZERO)
	a.mojado = 0.05
	_pasos(a, 10)
	_apunta("mojar dos veces y secarse", a)

	var f := _goblin(_hueco())
	f.golpe(_h("ice"), Vector3.ZERO)
	_pasos(f, 5)
	f.congelado = 0.05
	_pasos(f, 10)
	_apunta("congelar y descongelarse", f)

	var r := _goblin(_hueco())
	r.golpe(_h("lightning"), Vector3.ZERO)
	r.golpe(_h("lightning"), Vector3.ZERO)
	_apunta("dos rayos", r)

	var e := _goblin(_hueco())
	e.push(Vector3(0, 0, 1), 200.0, true)
	_pasos(e, 40)
	_apunta("empujon", e)


func _escenarios_reactivos() -> void:
	_emitidas.clear()
	var seto := Reactivo3D.new()
	seto.preparar("seto", Vector2i(2, 2), "", _fx, null)
	seto.position = _suelo(2, 2)
	_mundo.add_child(seto)
	seto.on_spell_hit(_runa(["calor", "fuego"]))
	seto._process(0.1)
	seto.on_spell_hit(_runa(["agua", "frio"]))
	seto.on_spell_hit(_runa(["calor"]))
	seto._process(1000.0)
	_apunta("seto prende, se apaga, prende y se consume", seto)

	var humedo := Reactivo3D.new()
	humedo.preparar("seto", Vector2i(4, 2), "", _fx, null)
	humedo.position = _suelo(4, 2)
	humedo.papeles = PackedStringArray(["mojable"])
	_mundo.add_child(humedo)
	humedo.on_spell_hit(_runa(["agua"]))
	humedo.on_spell_hit(_runa(["agua"]))
	humedo._process(Reactivo3D.T_MOJADO + 1.0)
	humedo._process(1.0)
	_apunta("seto mojable", humedo)

	var fogata := Reactivo3D.new()
	fogata.preparar("fogata", Vector2i(8, 2), "", _fx, null)
	fogata.position = _suelo(8, 2)
	_mundo.add_child(fogata)
	fogata.on_spell_hit(_runa(["calor"]))
	fogata.on_spell_hit(_runa(["agua"]))
	fogata.on_spell_hit(_runa(["calor"]))
	fogata.apagar_llama()
	_apunta("fogata enciende, apaga con agua, enciende y se apaga por regla", fogata)


func _hundimiento() -> void:
	_emitidas.clear()
	var g := _goblin(Vector3(COL_AGUA[0] * S - 0.25, Terreno3D.alto_suelo, 5.5 * S))
	g.push(Vector3(1, 0, 0), 1500.0, true)
	_pasos(g, 120)
	_apunta("empujado al agua honda", g)
	await process_frame


func _igualdad() -> void:
	if GOLDEN.is_empty():
		for k in _capturado.keys():
			print("CAPTURA\t%s\t%s" % [k, _capturado[k]])
		_ok("A (sin GOLDEN: solo captura)", false, "%d escenarios" % _capturado.size())
		return
	var distintos: int = 0
	for k in GOLDEN.keys():
		var antes: String = String(GOLDEN[k])
		var ahora: String = String(_capturado.get(k, "<falta>"))
		if antes != ahora:
			distintos += 1
			_ok("A %s" % k, false, "antes [%s] ahora [%s]" % [antes, ahora])
	_ok("A los %d escenarios dan las mismas reacciones, en el mismo orden, que en main" % GOLDEN.size(), distintos == 0 and _capturado.size() == GOLDEN.size(), "%d distintos · %d capturados" % [distintos, _capturado.size()])


func _catalogo_unico() -> void:
	# B1 · el catálogo del Juego es el de la tabla del Pipeline, mismo orden.
	var igual: bool = Mundo3D.REACCIONES.size() == ReaccionesVfx3D.CATALOGO.size()
	for i in range(mini(Mundo3D.REACCIONES.size(), ReaccionesVfx3D.CATALOGO.size())):
		if Mundo3D.REACCIONES[i] != ReaccionesVfx3D.CATALOGO[i]:
			igual = false
	_ok("B1 Mundo3D.REACCIONES = ReaccionesVfx3D.CATALOGO, mismo orden", igual)
	# B2 · cada nombre del catálogo tiene su constante R_* y viceversa.
	var consts: Dictionary = {}
	var mapa: Dictionary = (_mundo.get_script() as Script).get_script_constant_map()
	for k in mapa.keys():
		if String(k).begins_with("R_"):
			consts[String(mapa[k])] = String(k)
	var sin_const: PackedStringArray = []
	for n in Mundo3D.REACCIONES:
		if not consts.has(n):
			sin_const.append(n)
	_ok("B2 cada reacción del catálogo tiene su constante Mundo3D.R_*", sin_const.is_empty() and consts.size() == Mundo3D.REACCIONES.size(), "sin constante: %s · constantes %d" % [str(sin_const), consts.size()])
	# B3 · el contrato del enemigo se traduce al catálogo, sin huérfanos.
	var huerfanas: PackedStringArray = []
	for c in Combate3D.REACCIONES:
		var aviso: String = String(Mundo3D.AVISO_DE_CONTRATO.get(c, ""))
		if aviso == "" or not Mundo3D.REACCIONES.has(aviso):
			huerfanas.append(c)
	_ok("B3 las 7 reacciones del contrato del enemigo tienen un aviso del catálogo", huerfanas.is_empty() and Mundo3D.AVISO_DE_CONTRATO.size() == Combate3D.REACCIONES.size(), "huérfanas: %s" % str(huerfanas))
	_ok("B4 el aviso de caer al agua de Combate3D es el del catálogo", Combate3D.AVISO_HUNDIDO == Mundo3D.R_HUNDIDO)


func _archivos(dir: String, salida: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			salida.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_archivos(dir.path_join(d), salida)


func _literales() -> void:
	var rx := RegEx.new()
	rx.compile("(?:avisar_reaccion|_reaccionar|_avisar|_apagar_fuente|avisos\\.append)\\(\\s*\"([a-z_]+)\"")
	var archivos: Array = []
	for c in CARPETAS_LOGICA:
		_archivos("res://" + c, archivos)
	var fuera: PackedStringArray = []
	var escritos: PackedStringArray = []
	var emisores_viento: PackedStringArray = []
	for ruta in archivos:
		var fa := FileAccess.open(String(ruta), FileAccess.READ)
		if fa == null:
			continue
		var txt: String = fa.get_as_text()
		fa.close()
		for m in rx.search_all(txt):
			var n: String = m.get_string(1)
			if not Mundo3D.REACCIONES.has(n):
				fuera.append("%s: %s" % [ruta, n])
			else:
				escritos.append("%s: %s" % [ruta, n])
		if ruta != "res://mundo/mundo_3d.gd" and txt.find("\"apagado_viento\"") >= 0:
			emisores_viento.append(String(ruta))
	_ok("C1 ningún literal fuera del catálogo en las llamadas de aviso", fuera.is_empty(), str(fuera))
	_ok("C2 ningún nombre del catálogo escrito a mano en las llamadas de aviso (se usa Mundo3D.R_*)", escritos.is_empty(), "%d: %s" % [escritos.size(), str(escritos.slice(0, 6))])
	_ok("C3 MEDIDO: nadie emite «apagado_viento» (el viento lleva la llama, no la apaga)", emisores_viento.is_empty(), str(emisores_viento))
	# D · medido: el fin de la quemadura de un goblin vivo avisa «consumido» y la tabla del Pipeline lo dibuja como ceniza.
	var fila: Dictionary = ReaccionesVfx3D.resolver("consumido", "goblin")
	_ok("D MEDIDO: la quemadura de un goblin vivo que se acaba emite «consumido» y el Pipeline lo dibuja como «%s»" % String(fila.get("vfx", "")),
		String(_capturado.get("se acaba la quemadura", "")) == "consumido" and String(fila.get("vfx", "")) == "ceniza")
