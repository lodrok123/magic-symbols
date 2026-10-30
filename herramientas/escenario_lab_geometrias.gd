extends "res://herramientas/escenario_base.gd"
## Escenario del LABORATORIO DE GEOMETRÍAS (laboratorios/LabGeometrias3D.tscn), sin ventana (29/10, Juego; rehecho el 30/10 con los quince carriles):
##   0 la escena carga, el lab cuelga de ella con sus quince carriles (base + 1 glifo de cada tipo), sus carteles y sus dianas;
##   1 Espacio lanza los quince a la vez con dianas nuevas: salen todos; las dianas de la flecha, el perforar, el rebote y el buscar reciben el golpe;
##   2 el panel se suma a todos (Numpad), Mayús resta, Numpad 0 lo vacía, y el HUD y los carteles lo dicen;
##   3 Tab cambia de elemento y se vuelve a lanzar con él; Retroceso borra la sala y repone las dianas; Intro repite solo;
##   4 los sólidos con ᛁ construyen con perfil; 5 el pulso de una flecha sale de la pared que toca.
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


func _carril(nombre: String) -> int:
	for i in range(LabGeometrias3D.CARRILES.size()):
		if String((LabGeometrias3D.CARRILES[i] as Dictionary)["nombre"]) == nombre:
			return i
	return -1


## Las dianas del carril `i` que han perdido vida.
func _tocadas(i: int) -> int:
	var n: int = 0
	for d in lab.get("dianas"):
		var cb: Variant = (d as Dictionary)["combate"]
		if int((d as Dictionary)["carril"]) == i and (not is_instance_valid(cb) or (cb as Combate3D).muerto or (cb as Combate3D).health < (cb as Combate3D).vida_max):
			n += 1
	return n


func _n_dianas() -> int:
	var n: int = 0
	for i in range(LabGeometrias3D.CARRILES.size()):
		n += (lab.call("celdas_diana", i) as Array).size()
	return n


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	await avanzar(5)
	_ok("0 el laboratorio cuelga de la escena y se ha iniciado", lab != null and lab.get("tiempo") != null and lab.get("_l") != null)
	if lab == null or lab.get("_l") == null:
		return
	var n_carriles: int = LabGeometrias3D.CARRILES.size()
	_ok("0 quince carriles con su cartel", n_carriles == 15 and (lab.get("_carteles") as Array).size() == n_carriles)
	var propios: Dictionary = {}
	for cr in LabGeometrias3D.CARRILES:
		for g in (cr as Dictionary)["glifos"]:
			propios[g] = true
	_ok("0 entre todos los carriles está cada glifo de Sigils.GLIFOS", propios.size() == Sigils.GLIFOS.size(), str(propios.keys()))
	_ok("0 cada casilla de diana tiene su goblin quieto", (lab.get("dianas") as Array).size() == _n_dianas() and _n_dianas() == 17
		and (lab.get("dianas") as Array).all(func(d): return (d["combate"] as Combate3D).quieto), "%d dianas" % (lab.get("dianas") as Array).size())
	_ok("0 Espacio no salta", jugador.get("salto_activo") == false)
	_ok("0 el cartel del perforar dice que lleva flecha y su valor", String((lab.get("_carteles") as Array)[_carril("Perforar")].text).contains("lleva flecha")
		and String((lab.get("_carteles") as Array)[_carril("Perforar")].text).contains("perfora 1"), String((lab.get("_carteles") as Array)[_carril("Perforar")].text))

	# --- 1 · los quince a la vez, con sus dianas ---
	var vivos0: int = _vivos()
	var antes: Array = (lab.get("dianas") as Array).map(func(d): return d["combate"])
	_tecla_lab(KEY_SPACE)
	var ultimas: Array = lab.get("ultimas")
	var salieron: int = ultimas.filter(func(u): return int(u["n"]) > 0).size()
	_ok("1 Espacio lanza los quince y salen todos", ultimas.size() == n_carriles and salieron == n_carriles, str(ultimas.map(func(u): return "%s:%d" % [u["nombre"], u["n"]])))
	var nuevas: Array = (lab.get("dianas") as Array).map(func(d): return d["combate"])
	_ok("1 las dianas son nuevas en cada tanda (y la de la flecha, que aún vuela, está sana; un haz ya habrá dado a la suya)", nuevas.size() == antes.size()
		and nuevas.all(func(c): return not antes.has(c)) and _tocadas(_carril("Flecha")) == 0)
	await avanzar(3)
	_ok("1 hay hechizos vivos en la sala", _vivos() > vivos0, "%d → %d" % [vivos0, _vivos()])
	var hz: Hechizo = (lab.call("receta_de", _carril("Barrera")) as Lanzador3D.Receta3D).hechizo(lab.call("runa"))
	_ok("1 la barrera ya no es apuntable (30/10): nace en el lanzador, sin en_punto (la tierra y el hielo sí, por ser sólidos quietos)", hz != null and (hz.en_punto == hz.solido_quieto))
	await avanzar_s(3.0)
	var resumen: PackedStringArray = []
	for i in range(n_carriles):
		resumen.append("%s %d/%d" % [LabGeometrias3D.CARRILES[i]["nombre"], _tocadas(i), (lab.call("celdas_diana", i) as Array).size()])
	print("DIANAS TOCADAS (fuego, sin panel): ", ", ".join(resumen))
	_ok("1 la flecha da a su diana", _tocadas(_carril("Flecha")) == 1)
	_ok("1 el perforar atraviesa: le da a más de una diana", _tocadas(_carril("Perforar")) >= 2, str(_tocadas(_carril("Perforar"))))
	_ok("1 la base sola (esfera en la mano) no llega a su diana", _tocadas(_carril("Base")) == 0)
	_ok("1 el rebote vuelve de la pared y da a la diana de detrás", _tocadas(_carril("Rebote")) == 1)
	_ok("1 el buscar gira hacia la diana fuera del eje", _tocadas(_carril("Buscar")) == 1)

	# --- 2 · el panel ---
	_tecla_lab(KEY_BACKSPACE)
	await avanzar(3)
	var glifos: Array = Sigils.GLIFOS.keys()
	var i_x: int = glifos.find("linea_x")
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_x])
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_x])
	var mods: Dictionary = lab.get("modificadores")
	_ok("2 dos pulsaciones: ᛁ ×2 en la base", int(mods.get("linea_x", 0)) == 2, str(mods))
	var todos: bool = true
	for i in range(n_carriles):
		var g: Dictionary = lab.call("glifos_de", i)
		var propio: Dictionary = (LabGeometrias3D.CARRILES[i] as Dictionary)["glifos"]
		for k in Sigils.GLIFOS:
			if int(g.get(k, 0)) != int(propio.get(k, 0)) + int(mods.get(k, 0)):
				todos = false
	_ok("2 cada carril = base + su glifo propio", todos)
	_ok("2 el carril de Línea X lleva tres (2 de la base + el suyo)", int((lab.call("glifos_de", _carril("Línea X (ancho)")) as Dictionary).get("linea_x", 0)) == 3)
	_ok("2 el HUD lo dice", String(lab.call("texto_hud")).contains("×2"), String(lab.call("texto_hud")))
	_tecla_lab(LabGeometrias3D.TECLAS_MODIFICADOR[i_x], true)
	_ok("2 Mayús resta", int((lab.get("modificadores") as Dictionary).get("linea_x", 0)) == 1)
	_tecla_lab(KEY_SPACE)
	ultimas = lab.get("ultimas")
	_ok("2 con ᛁ en la base salen los quince", ultimas.filter(func(u): return int(u["n"]) > 0).size() == n_carriles,
		str(ultimas.map(func(u): return "%s:%d" % [u["nombre"], u["n"]])))
	await avanzar_s(1.5)
	_tecla_lab(KEY_KP_0)
	_ok("2 Numpad 0 vacía el panel", (lab.get("modificadores") as Dictionary).is_empty())

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
			_ok("3 %s: salen los quince" % e, ok_n == n_carriles)
		else:
			print("AVISO   3 %s: no salen %s (el juego los rechaza: %s)" % [e, rechazados, ultimas.filter(func(u): return int(u["n"]) <= 0).map(func(u): return u["aviso"])])
			_ok("3 %s: sale al menos la mitad" % e, ok_n >= n_carriles / 2, str(rechazados))
		await avanzar_s(1.0)
		_tecla_lab(KEY_BACKSPACE)
		await avanzar(3)
	_ok("3 Retroceso deja la sala sin hechizos", _vivos() == 0, str(_vivos()))
	_ok("3 y con todas las dianas sanas", (lab.get("dianas") as Array).size() == _n_dianas()
		and (lab.get("dianas") as Array).all(func(d): return is_instance_valid(d["combate"]) and (d["combate"] as Combate3D).health == (d["combate"] as Combate3D).vida_max))
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


## 4 · (29/10) los sólidos con ᛁ construyen (no son haz) y sus bloques siguen el perfil del volumen. Con ᛁ ×9 (30/10; antes ×2) en la base, el carril Base es una tierra ancha.
func _caso_solidos() -> void:
	lab.call("poner_elemento", "earth")
	lab.call("sumar", "linea_x", Sigils.GLIFOS_ANCHO_MURO_3_V2)      # 30/10: con la serie decreciente, tres filas de ancho piden 9 ᛁ (antes 2)
	var b0: int = lanzador._bloques.size()
	var rune: RuneData = lab.call("runa")
	var i_base: int = _carril("Base")
	var hz: Hechizo = (lab.call("receta_de", i_base) as Lanzador3D.Receta3D).hechizo(rune)
	_ok("4 la tierra con ᛁ ×2: no es haz y nace donde apuntas", not hz.haz and hz.en_punto)
	_tecla_lab(KEY_SPACE)
	await avanzar_s(1.0)
	var c_base: Vector2i = lab.call("celda_de", i_base)
	var filas: Dictionary = {}
	for b in lanzador._bloques:
		var c: Vector2i = b["celda"]
		if absi(c.y - c_base.y) <= 2 and c.x < 8:
			filas[c.y] = true
	_ok("4 la tierra ancha del carril Base deja bloques en tres filas", lanzador._bloques.size() > b0 + 2 and filas.has(c_base.y - 1) and filas.has(c_base.y) and filas.has(c_base.y + 1), str(filas.keys()))
	var ctx: Dictionary = {"origen": Vector3(5.5, 0.0, 5.5) * Terreno3D.casilla, "dir": Vector3.RIGHT, "g": {"x": 1.1, "y": 0.1, "z": 0.1}}
	var centro: Dictionary = HechizoVivo.perfil_solido(Vector2i(5, 5), ctx)
	var borde: Dictionary = HechizoVivo.perfil_solido(Vector2i(5, 6), ctx)
	_ok("4 perfil: el bloque del centro, entero; el del borde, más estrecho, más bajo y hacia dentro", centro.is_empty() and not borde.is_empty()
		and (borde["escala"] as Vector3).x < 1.0 and (borde["escala"] as Vector3).y < 1.0 and (borde["desplaza"] as Vector3).z < 0.0, str(borde))
	_ok("4 una sola casilla no cambia", HechizoVivo.perfil_solido(Vector2i(5, 5), {"origen": ctx["origen"], "dir": Vector3.RIGHT, "g": {"x": 0.1, "y": 0.1, "z": 0.1}}).is_empty())
	lab.call("limpiar")
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
