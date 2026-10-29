extends "res://herramientas/escenario_base.gd"
## Escenario del LABORATORIO DE GEOMETRÍAS (laboratorios/LabGeometrias3D.tscn), sin ventana (29/10, Juego):
##   0 la escena carga, el lab cuelga de ella con sus ocho carriles y sus carteles;
##   1 Espacio lanza los ocho a la vez: salen todos, cada uno con su nombre de receta; el muro nace por delante del carril;
##   2 los modificadores se suman a todos (Numpad), Mayús resta, Numpad 0 los quita, y el HUD y los carteles lo dicen;
##   3 Tab cambia de elemento y se vuelve a lanzar con él; Retroceso borra la sala; Intro repite solo.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_lab_geometrias.gd

const RUTA_LAB: String = "res://laboratorios/LabGeometrias3D.tscn"

var lab: Node = null


func _tecla_lab(k: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	ev.shift_pressed = shift
	lab._unhandled_input(ev)


func _vivos() -> int:
	return maqueta.find_children("*", "HechizoVivo", true, false).size()


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	await avanzar(5)
	_ok("0 el laboratorio cuelga de la escena y se ha iniciado", lab != null and lab.get("tiempo") != null and lab.get("_l") != null)
	if lab == null or lab.get("_l") == null:
		return
	var n_carriles: int = LabGeometrias3D.CARRILES.size()
	_ok("0 ocho carriles con su cartel", n_carriles == 8 and (lab.get("_carteles") as Array).size() == n_carriles)
	_ok("0 Espacio no salta", jugador.get("salto_activo") == false)

	# --- 1 · los ocho a la vez ---
	var vivos0: int = _vivos()
	_tecla_lab(KEY_SPACE)
	var ultimas: Array = lab.get("ultimas")
	var salieron: int = ultimas.filter(func(u): return int(u["n"]) > 0).size()
	_ok("1 Espacio lanza los ocho y salen todos", ultimas.size() == n_carriles and salieron == n_carriles, str(ultimas.map(func(u): return "%s:%d" % [u["nombre"], u["n"]])))
	var formas: Dictionary = {}
	for u in ultimas:
		formas["%s %s" % [u["semiejes"], (u["glifos"] as Dictionary).has("flecha")]] = true
	_ok("1 son ocho geometrías distintas (semiejes y si viaja)", formas.size() == n_carriles, str(formas.keys()))
	await avanzar(3)
	_ok("1 hay hechizos vivos en la sala", _vivos() > vivos0, "%d → %d" % [vivos0, _vivos()])
	var hz: Hechizo = (lab.call("receta_de", 6) as Lanzador3D.Receta3D).hechizo(lab.call("runa"))
	_ok("1 el muro nace donde apuntas (en_punto)", hz != null and hz.en_punto)
	await avanzar_s(2.0)

	# --- 2 · modificadores ---
	_tecla_lab(KEY_BACKSPACE)
	await avanzar(3)
	var glifos: Array = Sigils.GLIFOS_V2.keys()
	var i_rep: int = glifos.find("repeticion")
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_rep])
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_rep])
	var mods: Dictionary = lab.get("modificadores")
	_ok("2 dos pulsaciones: repetición ×2", int(mods.get("repeticion", 0)) == 2, str(mods))
	var todos: bool = true
	for i in range(n_carriles):
		var g: Dictionary = lab.call("glifos_de", i)
		var base: Dictionary = LabGeometrias3D.CARRILES[i][2]
		if int(g.get("repeticion", 0)) != int(base.get("repeticion", 0)) + 2:
			todos = false
		for k in base:
			if int(g.get(k, 0)) != int(base[k]) + int(mods.get(k, 0)):
				todos = false
	_ok("2 se suman a la geometría de cada carril (sin quitarle la suya)", todos)
	_ok("2 el HUD lo dice", String(lab.call("texto_hud")).contains("×2"), String(lab.call("texto_hud")))
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_rep], true)
	_ok("2 Mayús resta", int((lab.get("modificadores") as Dictionary).get("repeticion", 0)) == 1)
	var i_crece: int = glifos.find("pulso")
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_crece])
	_tecla_lab(KEY_SPACE)
	ultimas = lab.get("ultimas")
	_ok("2 con repetición y crecer salen los ocho", ultimas.filter(func(u): return int(u["n"]) > 0).size() == n_carriles,
		str(ultimas.map(func(u): return "%s:%d" % [u["nombre"], u["n"]])))
	await avanzar_s(1.5)
	_tecla_lab(KEY_KP_0)
	_ok("2 Numpad 0 quita los modificadores", (lab.get("modificadores") as Dictionary).is_empty())

	# --- 3 · elemento, borrar, repetir ---
	_tecla_lab(KEY_BACKSPACE)
	await avanzar(3)
	var e0: String = lab.get("elemento")
	_tecla_lab(KEY_TAB)
	_ok("3 Tab cambia de elemento", String(lab.get("elemento")) != e0, "%s → %s" % [e0, lab.get("elemento")])
	for e in LabRecetas3D.ELEMENTOS:
		lab.call("poner_elemento", e)
		_tecla_lab(KEY_SPACE)
		ultimas = lab.get("ultimas")
		var ok_n: int = ultimas.filter(func(u): return int(u["n"]) > 0).size()
		var rechazados: Array = ultimas.filter(func(u): return int(u["n"]) <= 0).map(func(u): return u["nombre"])
		if rechazados.is_empty():
			_ok("3 %s: salen los ocho" % e, ok_n == n_carriles)
		else:
			print("AVISO   3 %s: no salen %s (el juego los rechaza: %s)" % [e, rechazados, ultimas.filter(func(u): return int(u["n"]) <= 0).map(func(u): return u["aviso"])])
			_ok("3 %s: sale al menos la mitad" % e, ok_n >= n_carriles / 2, str(rechazados))
		await avanzar_s(1.0)
		_tecla_lab(KEY_BACKSPACE)
		await avanzar(3)
	_ok("3 Retroceso deja la sala sin hechizos", _vivos() == 0, str(_vivos()))
	var t0: int = int(lab.get("lanzadas"))
	_tecla_lab(KEY_KP_ENTER)
	await avanzar_s(LabGeometrias3D.T_AUTO * 2.0 + 0.3)
	_ok("3 Intro repite solo cada T_AUTO s", int(lab.get("lanzadas")) >= t0 + 2, "%d → %d" % [t0, int(lab.get("lanzadas"))])
	_tecla_lab(KEY_KP_ENTER)
	_ok("3 y otra vez Intro lo para", lab.get("auto") == false)
	lab.call("borrar_sala")
	await avanzar_s(1.0)
	await _caso_solidos()
	await _caso_pulso_contacto()


## 4 · (29/10) los sólidos con ᛁ construyen (no son haz) y sus bloques siguen el perfil del volumen.
func _caso_solidos() -> void:
	lab.call("poner_elemento", "earth")
	var b0: int = lanzador._bloques.size()
	var rune: RuneData = lab.call("runa")
	for i in [1, 2]:                                           # Ancha y Larga
		var r: Lanzador3D.Receta3D = lab.call("receta_de", i)
		var hz: Hechizo = r.hechizo(rune)
		_ok("4 %s de tierra: no es haz y nace donde apuntas" % LabGeometrias3D.CARRILES[i][0], not hz.haz and hz.en_punto)
	_tecla_lab(KEY_SPACE)
	await avanzar_s(1.0)
	var filas: Dictionary = {}
	for b in lanzador._bloques:
		filas[(b["celda"] as Vector2i).y] = true
	_ok("4 la tierra ancha y la larga dejan bloques (filas 4–6 y 8)", lanzador._bloques.size() > b0 + 6 and filas.has(5) and filas.has(4) and filas.has(8), str(filas.keys()))
	var ctx: Dictionary = {"origen": Vector3(5.5, 0.0, 5.5) * Terreno3D.casilla, "dir": Vector3.RIGHT, "g": {"x": 1.1, "y": 0.1, "z": 0.1}}
	var centro: Dictionary = HechizoVivo.perfil_solido(Vector2i(5, 5), ctx)
	var borde: Dictionary = HechizoVivo.perfil_solido(Vector2i(5, 6), ctx)
	_ok("4 perfil: el bloque del centro, entero; el del borde, más estrecho, más bajo y hacia dentro", centro.is_empty() and not borde.is_empty()
		and (borde["escala"] as Vector3).x < 1.0 and (borde["escala"] as Vector3).y < 1.0 and (borde["desplaza"] as Vector3).z < 0.0, str(borde))
	_ok("4 una sola casilla no cambia", HechizoVivo.perfil_solido(Vector2i(5, 5), {"origen": ctx["origen"], "dir": Vector3.RIGHT, "g": {"x": 0.1, "y": 0.1, "z": 0.1}}).is_empty())
	lab.call("borrar_sala")
	await avanzar_s(0.5)


## 5 · (29/10) ᚱ + flecha que choca contra la pared: el pulso sale de la PARED (la superficie de contacto), no del volumen.
func _caso_pulso_contacto() -> void:
	var rune: RuneData = load("res://nucleo/fire_rune.tres")
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	r.apply("flecha")
	r.apply("raido")
	var c0 := Vector2i(2, 15)
	var o := Vector3((float(c0.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c0), (float(c0.y) + 0.5) * Terreno3D.casilla)
	var antes: Array = maqueta.find_children("Pulso", "Pulso3D", true, false)
	lanzador.lanzar_receta(r, rune, o, Vector3.LEFT)              # la pared del oeste está a 2 casillas
	var pulso: Pulso3D = null
	var t: float = 0.0
	while pulso == null and t < 4.0:
		t += await avanzar_s(0.1)
		for n in maqueta.find_children("Pulso", "Pulso3D", true, false):
			if not antes.has(n):
				pulso = n
	_ok("5 la flecha con ᚱ suelta su pulso al chocar", pulso != null, "%.1f s" % t)
	if pulso != null:
		_ok("5 el pulso sale de la pared que tocó (0, 15) y de la casilla de delante", pulso.origenes.has(Vector2i(0, 15)) and pulso.origenes.has(Vector2i(1, 15)), str(pulso.origenes))
	lab.call("borrar_sala")
	await avanzar_s(1.0)
