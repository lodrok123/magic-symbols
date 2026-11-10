extends "res://herramientas/escenario_base.gd"
## GAMEFEEL TERCERA TANDA, LOTE 2 · B1 INPUT MAP Y REMAPEO (2/11; docs/REVISION_GAMEFEEL_30-10.md §9; nucleo/controles.gd, project.godot [input], presentacion/ui/menu_pausa.gd).
## Primero, sin escena: cada acción existe en el InputMap CON la tecla de fábrica que dice project.godot (se mira ANTES de que `Controles.registrar()` pueda rellenar nada), el evento de cada tecla antigua
## casa con su acción, el remapeo (mochila → K), el intercambio con una tecla ocupada, lo que no se puede asignar, guardar/recargar el .cfg ([controles]) y «Restaurar».
## Luego, sobre la escena real del Bosque: las teclas antiguas hacen lo mismo que antes (mover con WASD y flechas, F golpe, I/J/Esc, R cambia de consumible, T libro, Esc pausa), y tras remapear
## responde la tecla nueva y no la vieja; y la pantalla Controles del MenuPausa (abrir, elegir fila, esperar tecla, Esc cancela, intercambio con «no_puedes», Restaurar, Volver, también en modo Ajustes).
## Usa un .cfg de prueba (`user://ajustes_prueba_input_map.cfg`): no toca `user://ajustes.cfg`.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_input_map.gd

const AJUSTES: String = "user://ajustes_prueba_input_map.cfg"

## Lo que DEBE decir project.godot: acción → teclas de fábrica (la primera es la principal).
const ESPERADAS: Dictionary = {
	"mover_adelante": [KEY_W, KEY_UP], "mover_atras": [KEY_S, KEY_DOWN], "mover_izquierda": [KEY_A, KEY_LEFT], "mover_derecha": [KEY_D, KEY_RIGHT],
	"correr": [KEY_SHIFT], "saltar": [KEY_SPACE], "voltereta": [KEY_CTRL], "golpe": [KEY_F], "interactuar": [KEY_E],
	"usar_consumible": [KEY_Q], "cambiar_consumible": [KEY_R], "lanzar_objeto": [KEY_G], "mochila": [KEY_I], "misiones": [KEY_J], "libro": [KEY_T],
	"pagina_1": [KEY_1], "pagina_2": [KEY_2], "pagina_3": [KEY_3],
	"pausa": [KEY_ESCAPE], "pestana_anterior": [KEY_Q], "pestana_siguiente": [KEY_E],
}

var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


func _ev(k: Key, pulsada: bool = true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = pulsada
	return ev


func _veda() -> void:
	OS.delay_msec(Sfx.VEDA_MS + 30)


func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(AJUSTES)
	return c


func _escenario() -> void:
	MenuPausa.RUTA_AJUSTES = AJUSTES
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AJUSTES))
	await _sin_escena()
	await _en_la_escena()
	Controles.restaurar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AJUSTES))
	print("COMPROBACIONES: %d" % _comprobaciones)


# ---------------------------------------------------------------------------------------------------------------------
#  Sin escena
# ---------------------------------------------------------------------------------------------------------------------

func _sin_escena() -> void:
	# --- 1 · project.godot define todas las acciones con su tecla ---
	var todas_estan: bool = true
	var mal: PackedStringArray = []
	for id in ESPERADAS:
		var quiere: Array = ESPERADAS[id]
		if not InputMap.has_action(id):
			todas_estan = false
			mal.append(String(id) + " (falta)")
			continue
		var tiene: Array = Controles.teclas(id)
		if tiene != quiere:
			todas_estan = false
			mal.append("%s %s ≠ %s" % [id, str(tiene), str(quiere)])
	_ok("1 las %d acciones están en el InputMap de project.godot con su tecla de fábrica" % ESPERADAS.size(), todas_estan, ", ".join(mal))
	_ok("1 Controles lista %d acciones remapeables y %d fijas" % [Controles.ACCIONES.size(), Controles.FIJAS.size()], Controles.ACCIONES.size() == 18 and Controles.FIJAS.size() == 3)
	var fabrica_ok: bool = true
	for id in Controles.ids():
		if Controles.de_fabrica(id) != (ESPERADAS[id] as Array):
			fabrica_ok = false
	_ok("1 la tabla de fábrica de Controles coincide con project.godot", fabrica_ok)
	Controles.registrar()
	var igual: bool = true
	for id in ESPERADAS:
		if Controles.teclas(id) != (ESPERADAS[id] as Array):
			igual = false
	_ok("1 registrar() no cambia lo que ya estaba definido", igual)

	# --- 2 · el evento de cada tecla antigua casa con su acción (y con ninguna otra remapeable) ---
	var casan: bool = true
	var cruces: PackedStringArray = []
	for id in Controles.ids():
		for k in (ESPERADAS[id] as Array):
			var ev := _ev(k as Key)
			if not ev.is_action(id):
				casan = false
				cruces.append("%s no casa con %s" % [OS.get_keycode_string(k as Key), id])
			for otra in Controles.ids():
				if otra != id and ev.is_action(otra):
					casan = false
					cruces.append("%s casa también con %s" % [OS.get_keycode_string(k as Key), otra])
	_ok("2 cada tecla antigua casa con su acción y solo con ella", casan, ", ".join(cruces))
	_ok("2 Escape es «pausa»; Q y E siguen sirviendo de pestañas", _ev(KEY_ESCAPE).is_action("pausa") and _ev(KEY_Q).is_action("pestana_anterior") and _ev(KEY_E).is_action("pestana_siguiente"))
	_ok("2 con Mayús puesto la tecla sigue casando (como el viejo keycode ==)", _con_mayus(KEY_E).is_action("interactuar"))
	_ok("2 una tecla sin acción no casa con nada", not _ev(KEY_X).is_action("mochila") and not _ev(KEY_X).is_action("interactuar") and not _ev(KEY_X).is_action("golpe"))
	# Por el camino real (Input.parse_input_event): el estado de la acción sigue a la tecla.
	# (Input acumula los eventos y los aplica al final del fotograma: hay que dejar pasar uno entre `parse_input_event` y la lectura.)
	_tecla(KEY_W, true)
	await avanzar(1)
	_ok("2 W pulsada → mover_adelante pulsada (Input.is_action_pressed)", Input.is_action_pressed("mover_adelante") and not Input.is_action_pressed("mover_atras"))
	_tecla(KEY_W, false)
	_tecla(KEY_RIGHT, true)
	await avanzar(1)
	_ok("2 → pulsada → mover_derecha pulsada", Input.is_action_pressed("mover_derecha") and not Input.is_action_pressed("mover_adelante"))
	_tecla(KEY_RIGHT, false)
	await avanzar(1)
	_ok("2 soltadas, ninguna sigue pulsada", not Input.is_action_pressed("mover_adelante") and not Input.is_action_pressed("mover_derecha"))

	# --- 3 · remapear «mochila» a K ---
	var r: Dictionary = Controles.remapear("mochila", KEY_K)
	_ok("3 remapear(mochila, K) vale y no intercambia nada", bool(r["ok"]) and String(r["intercambio"]) == "")
	_ok("3 mochila = [K]", Controles.teclas("mochila") == [KEY_K])
	_ok("3 I ya no es «mochila» y K sí", not _ev(KEY_I).is_action("mochila") and _ev(KEY_K).is_action("mochila"))
	_ok("3 está marcada como modificada y las demás no", Controles.modificada("mochila") and not Controles.modificada("misiones"))

	# --- 4 · guardar y recargar el .cfg ---
	_ok("4 MenuPausa.guardar_ajustes() escribe el archivo", MenuPausa.guardar_ajustes() and FileAccess.file_exists(AJUSTES))
	var c: ConfigFile = _cfg()
	_ok("4 [controles] lleva mochila = [K]", c.has_section_key("controles", "mochila") and c.get_value("controles", "mochila") == [KEY_K])
	_ok("4 y SOLO lo que difiere de fábrica", c.get_section_keys("controles").size() == 1, str(c.get_section_keys("controles")))
	Controles.poner_teclas("mochila", [KEY_I])                 # «arranque nuevo»: las teclas vuelven al InputMap de fábrica
	_ok("4 (preparación) mochila vuelve a I en memoria", Controles.teclas("mochila") == [KEY_I])
	_ok("4 cargar_ajustes() encuentra el archivo", MenuPausa.cargar_ajustes())
	_ok("4 y recupera mochila = K (aplicado al arrancar)", Controles.teclas("mochila") == [KEY_K] and _ev(KEY_K).is_action("mochila") and not _ev(KEY_I).is_action("mochila"))

	# --- 5 · Restaurar ---
	Controles.restaurar()
	MenuPausa.guardar_ajustes()
	_ok("5 Restaurar vuelve la mochila a I (y K ya no)", Controles.teclas("mochila") == [KEY_I] and _ev(KEY_I).is_action("mochila") and not _ev(KEY_K).is_action("mochila"))
	_ok("5 y el .cfg ya no lleva [controles]", not _cfg().has_section("controles"))

	# --- 6 · intercambio con una tecla ocupada ---
	r = Controles.remapear("misiones", KEY_I)
	_ok("6 remapear(misiones, I) intercambia con «mochila»", bool(r["ok"]) and String(r["intercambio"]) == "mochila")
	_ok("6 misiones = [I] y mochila = [J] (la otra recibe la antigua)", Controles.teclas("misiones") == [KEY_I] and Controles.teclas("mochila") == [KEY_J])
	_ok("6 ninguna tecla repetida entre acciones remapeables", _sin_repetidas())
	# Una acción con dos teclas conserva la segunda: mover_adelante → S intercambia con mover_atras.
	r = Controles.remapear("mover_adelante", KEY_S)
	_ok("6 mover_adelante → S intercambia con mover_atras", String(r["intercambio"]) == "mover_atras")
	_ok("6 mover_adelante = [S, ↑] (conserva la flecha) y mover_atras = [W, ↓]", Controles.teclas("mover_adelante") == [KEY_S, KEY_UP] and Controles.teclas("mover_atras") == [KEY_W, KEY_DOWN],
		"%s %s" % [str(Controles.teclas("mover_adelante")), str(Controles.teclas("mover_atras"))])
	_ok("6 sigue sin haber repetidas", _sin_repetidas())
	Controles.restaurar()
	_ok("6 Restaurar lo deja todo como de fábrica", _todo_de_fabrica())

	# --- 7 · lo que no se puede asignar ---
	var no_vale: bool = true
	for k in [KEY_F1, KEY_F12, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_NONE]:
		if bool(Controles.remapear("golpe", k)["ok"]):
			no_vale = false
	_ok("7 F1-F12, Escape, Enter y «ninguna» no se pueden asignar (y golpe sigue en F)", no_vale and Controles.teclas("golpe") == [KEY_F])
	_ok("7 una acción que no existe tampoco", not bool(Controles.remapear("inventada", KEY_K)["ok"]))
	_ok("7 asignar la misma tecla que ya tiene es válido y no cambia nada", bool(Controles.remapear("golpe", KEY_F)["ok"]) and _todo_de_fabrica())
	# Shift y Ctrl se pueden asignar (correr y voltereta los usan de fábrica).
	_ok("7 Mayús y Ctrl son asignables", Controles.asignable(KEY_SHIFT) and Controles.asignable(KEY_CTRL))

	# --- 8 · un archivo con basura no rompe el arranque ---
	var sucio := ConfigFile.new()
	sucio.set_value("controles", "mochila", "no es una lista")
	sucio.set_value("controles", "misiones", [KEY_F5])
	sucio.set_value("controles", "libro", [KEY_B])
	sucio.set_value("controles", "inventada", [KEY_Z])
	sucio.save(AJUSTES)
	MenuPausa.cargar_ajustes()
	_ok("8 lo inválido se ignora y lo válido vale", Controles.teclas("mochila") == [KEY_I] and Controles.teclas("misiones") == [KEY_J] and Controles.teclas("libro") == [KEY_B])
	Controles.restaurar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AJUSTES))


func _con_mayus(k: Key) -> InputEventKey:
	var ev: InputEventKey = _ev(k)
	ev.shift_pressed = true
	return ev


func _sin_repetidas() -> bool:
	var vistas: Dictionary = {}
	for id in Controles.ids():
		for k in Controles.teclas(id):
			if vistas.has(k):
				return false
			vistas[k] = id
	return true


func _todo_de_fabrica() -> bool:
	for id in ESPERADAS:
		if Controles.teclas(id) != (ESPERADAS[id] as Array):
			return false
	return true


# ---------------------------------------------------------------------------------------------------------------------
#  Sobre la escena real
# ---------------------------------------------------------------------------------------------------------------------

func _en_la_escena() -> void:
	Controles.restaurar()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	current_scene = maqueta
	Sfx.REGISTRAR = true
	var j: Jugador3D = jugador as Jugador3D
	var menu: MenuPestanas = lanzador.menu
	var hud: HudEoW = j.hud_eow
	var p: MenuPausa = lanzador.pausa
	_ok("9 hay menú con pestañas, HUD y pausa de verdad", menu != null and hud != null and p != null)
	if menu == null or hud == null or p == null:
		return
	var e: Estado = Estado.i()
	e.capacidad = 8
	e.agregar("pocion", 2)
	e.agregar("tonico_tinta", 1)
	await avanzar(4)

	# --- 9 · mover: WASD y flechas hacen lo mismo que antes ---
	var w: Vector2 = await _empuje(KEY_W)
	var arriba: Vector2 = await _empuje(KEY_UP)
	var s: Vector2 = await _empuje(KEY_S)
	var abajo: Vector2 = await _empuje(KEY_DOWN)
	var a: Vector2 = await _empuje(KEY_A)
	var izq: Vector2 = await _empuje(KEY_LEFT)
	var d: Vector2 = await _empuje(KEY_D)
	var der: Vector2 = await _empuje(KEY_RIGHT)
	_ok("9 W y ↑ mueven a la jugadora igual", w.length() > 0.5 and w.dot(arriba) > 0.95, "%s %s" % [str(w), str(arriba)])
	_ok("9 S y ↓ igual, y en sentido contrario a W", s.length() > 0.5 and s.dot(abajo) > 0.95 and s.dot(w) < -0.95)
	_ok("9 A y ← igual, y D y → igual y opuestos", a.length() > 0.5 and a.dot(izq) > 0.95 and d.length() > 0.5 and d.dot(der) > 0.95 and a.dot(d) < -0.95)
	# Remapear «mover_derecha» a L: D deja de mover, L mueve donde movía D, → sigue moviendo (segunda tecla).
	Controles.remapear("mover_derecha", KEY_L)
	var l: Vector2 = await _empuje(KEY_L)
	var d2: Vector2 = await _empuje(KEY_D)
	var der2: Vector2 = await _empuje(KEY_RIGHT)
	_ok("9 tras remapear mover_derecha a L: L mueve donde movía D", l.length() > 0.5 and l.dot(d) > 0.95, str(l))
	_ok("9 y D ya no mueve", d2.length() < 0.1, str(d2))
	_ok("9 y → sigue moviendo (conserva su segunda tecla)", der2.length() > 0.5 and der2.dot(d) > 0.95)
	Controles.restaurar()

	# --- 10 · golpe cuerpo a cuerpo: F ---
	await avanzar(20)
	_tecla(KEY_F, true)
	await avanzar(2)
	var pego: bool = j.golpeando()
	_tecla(KEY_F, false)
	_ok("10 F inicia el golpe cuerpo a cuerpo", pego)
	await avanzar(30)
	Controles.remapear("golpe", KEY_G)
	_tecla(KEY_F, true)
	await avanzar(2)
	var pego_f: bool = j.golpeando()
	_tecla(KEY_F, false)
	await avanzar(30)
	_tecla(KEY_G, true)
	await avanzar(2)
	var pego_g: bool = j.golpeando()
	_tecla(KEY_G, false)
	_ok("10 remapeado el golpe a G: F ya no pega y G sí", not pego_f and pego_g, "F %s · G %s" % [str(pego_f), str(pego_g)])
	Controles.restaurar()
	await avanzar(30)

	# --- 11 · mochila: I abre, Esc cierra, J abre en misiones ---
	await get_root_pausa_libre()
	menu._input(_ev(KEY_I))
	_ok("11 I abre la mochila y pausa", menu.abierta and paused)
	menu._input(_ev(KEY_ESCAPE))
	_ok("11 Esc cierra la mochila", not menu.abierta and not paused)
	await avanzar(12)
	menu._input(_ev(KEY_J))
	_ok("11 J abre en Misiones", menu.abierta and menu.pestana == MenuPestanas.INDICE_MISIONES)
	menu._input(_ev(KEY_J))
	_ok("11 y otra J la cierra", not menu.abierta)
	await avanzar(12)
	Controles.remapear("mochila", KEY_K)
	menu._input(_ev(KEY_I))
	var abre_i: bool = menu.abierta
	menu._input(_ev(KEY_K))
	_ok("11 remapeada la mochila a K: I no abre y K sí", not abre_i and menu.abierta)
	menu._input(_ev(KEY_ESCAPE))
	await avanzar(12)
	Controles.restaurar()

	# --- 12 · consumibles: R cambia, Q usa ---
	hud.consumibles.equipar("pocion")
	await avanzar(2)
	_veda()
	hud._input(_ev(KEY_R))
	var tras_r: String = hud.consumibles.equipado()
	_ok("12 R cambia de consumible", tras_r != "pocion", tras_r)
	hud.consumibles.equipar("pocion")
	Controles.remapear("cambiar_consumible", KEY_V)
	hud._input(_ev(KEY_R))
	var con_r: String = hud.consumibles.equipado()
	hud._input(_ev(KEY_V))
	_ok("12 remapeado a V: R ya no cambia y V sí", con_r == "pocion" and hud.consumibles.equipado() != "pocion", "%s → %s" % [con_r, hud.consumibles.equipado()])
	Controles.restaurar()

	# --- 13 · el libro: T ---
	hud.consumibles.equipar("pocion")
	_ok("13 (preparación) el libro empieza cerrado", not lanzador.libro_abierto())
	root.push_input(_ev(KEY_T))
	await avanzar(3)
	_ok("13 T abre el libro", lanzador.libro_abierto())
	root.push_input(_ev(KEY_T))
	await avanzar(3)
	_ok("13 y otra T lo cierra", not lanzador.libro_abierto())
	await avanzar(10)

	# --- 14 · la pausa: Esc ---
	root.push_input(_ev(KEY_ESCAPE))
	await avanzar(2)
	_ok("14 Esc abre la pausa", p.abierta and paused)

	# --- 15 · la pantalla Controles ---
	await _pantalla_controles(p)
	if p.abierta:
		p.cerrar()
	await avanzar(12)

	# --- 16 · …y también desde Ajustes del menú principal (modo sin partida) ---
	var a2: MenuPausa = MenuPausa.new()
	a2.sin_partida = true
	root.add_child(a2)
	a2.abrir()
	_ok("16 en modo Ajustes la fila «Controles» se ve", a2.ids_visibles().has("controles"))
	a2.fila = a2._indice("controles")
	a2.accion()
	_ok("16 y abre la pantalla Controles", a2.en_controles and a2._panel_ctrl.visible and not a2._panel.visible)
	a2._input(_ev(KEY_ESCAPE))
	_ok("16 Esc vuelve a la lista de Ajustes (sin cerrarlos)", not a2.en_controles and a2.abierta and a2._panel.visible)
	a2.cerrar()
	a2.queue_free()
	await avanzar(12)
	_ok("16 el árbol no queda en pausa", not paused)
	Sfx.REGISTRAR = false


func get_root_pausa_libre() -> void:
	if paused:
		paused = false
	await avanzar(1)


func _pantalla_controles(p: MenuPausa) -> void:
	await avanzar(12)
	_veda()
	p.fila = p._indice("controles")
	p.accion()
	_ok("15 Enter en «Controles» abre la pantalla", p.en_controles and p._panel_ctrl.visible and not p._panel.visible and p.ctrl_fila == 0)
	_ok("15 tiene una fila por acción más «Restaurar» y «Volver»", p._ctrl_filas.size() == Controles.ACCIONES.size() + 2)
	var primera: String = (p._ctrl_filas[0]["tecla"] as Label).text
	_ok("15 la primera muestra «Mover arriba» con W / ↑", (p._ctrl_filas[0]["nombre"] as Label).text == "Mover arriba" and primera.contains("W") and primera.to_lower().contains("up"), primera)
	p._input(_ev(KEY_DOWN))
	_ok("15 ↓ baja de fila", p.ctrl_fila == 1)
	p.ctrl_fila = Controles.ids().find("mochila")
	p._refrescar_controles()
	_ok("15 la fila de la mochila dice I", (p._ctrl_filas[p.ctrl_fila]["tecla"] as Label).text == "I", (p._ctrl_filas[p.ctrl_fila]["tecla"] as Label).text)

	# Enter y pulsar una tecla libre.
	p._input(_ev(KEY_ENTER))
	_ok("15 Enter empieza a esperar la tecla (aviso y «…»)", p.capturando and (p._ctrl_filas[p.ctrl_fila]["tecla"] as Label).text == "…" and p.aviso_controles.contains("Mochila"))
	p._input(_ev(KEY_K))
	_ok("15 pulsar K asigna K a la mochila", not p.capturando and Controles.teclas("mochila") == [KEY_K] and (p._ctrl_filas[p.ctrl_fila]["tecla"] as Label).text == "K")
	_ok("15 y lo guarda en el .cfg", _cfg().has_section_key("controles", "mochila") and _cfg().get_value("controles", "mochila") == [KEY_K])

	# Esc cancela sin cambiar.
	p._input(_ev(KEY_ENTER))
	_ok("15 otra vez a esperar", p.capturando)
	p._input(_ev(KEY_ESCAPE))
	_ok("15 Esc cancela: no se asigna Escape, sigue K y se queda en Controles", not p.capturando and p.en_controles and Controles.teclas("mochila") == [KEY_K])

	# Una tecla que no se puede usar no asigna y sigue esperando.
	p._input(_ev(KEY_ENTER))
	p._input(_ev(KEY_F5))
	_ok("15 F5 no se puede asignar: sigue esperando y la mochila no cambia", p.capturando and Controles.teclas("mochila") == [KEY_K] and p.aviso_controles.contains("no se puede"))
	p._input(_ev(KEY_ESCAPE))

	# Intercambio con una tecla ocupada: «misiones» elige K (la de la mochila) → mochila recibe J.
	_veda()
	Sfx.vaciar_registro()
	p.ctrl_fila = Controles.ids().find("misiones")
	p._input(_ev(KEY_ENTER))
	p._input(_ev(KEY_K))
	_ok("15 elegir una tecla ocupada INTERCAMBIA (misiones = K, mochila = J)", Controles.teclas("misiones") == [KEY_K] and Controles.teclas("mochila") == [KEY_J])
	_ok("15 suena «no_puedes_ui» y el aviso lo dice", Sfx.veces("no_puedes_ui") == 1 and p.aviso_controles.contains("intercambiado"), "%d · %s" % [Sfx.veces("no_puedes_ui"), p.aviso_controles])
	_ok("15 sin teclas repetidas", _sin_repetidas())

	# Restaurar.
	p.ctrl_fila = Controles.ACCIONES.size()
	p._input(_ev(KEY_ENTER))
	_ok("15 «Restaurar» devuelve todo a las teclas de fábrica y lo guarda", _todo_de_fabrica() and not _cfg().has_section("controles"))

	# Volver.
	p.ctrl_fila = Controles.ACCIONES.size() + 1
	p._input(_ev(KEY_ENTER))
	_ok("15 «Volver» regresa a la lista principal con la pausa abierta", not p.en_controles and p._panel.visible and p.abierta)

	# Esc dentro de Controles vuelve; otro Esc cierra la pausa.
	p.fila = p._indice("controles")
	p.accion()
	p._input(_ev(KEY_ESCAPE))
	_ok("15 Esc en Controles vuelve a la lista (no cierra la pausa)", not p.en_controles and p.abierta)
	p._input(_ev(KEY_ESCAPE))
	_ok("15 y otro Esc cierra la pausa", not p.abierta)
	# La pausa que se cierra estando en Controles también vuelve a la lista (la próxima vez abre normal).
	await avanzar(12)
	p.abrir()
	p.fila = p._indice("controles")
	p.accion()
	p.cerrar()
	await avanzar(12)
	p.abrir()
	_ok("15 cerrar la pausa desde Controles: al reabrir se ve la lista principal", not p.en_controles and p._panel.visible and not p._panel_ctrl.visible)
