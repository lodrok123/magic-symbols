class_name Controles
extends RefCounted

## B1 (tercera tanda, 2/11): las teclas del juego como ACCIONES del InputMap (definidas en project.godot [input]) y su remapeo.
## El código de juego pregunta por la acción (`event.is_action("mochila")`, `Input.is_action_pressed("correr")`), no por la tecla; así el menú Controles puede cambiarlas.
## Las teclas de depuración y laboratorio (F1-F12, laboratorios/, herramientas/) siguen con `KEY_` y NO están aquí. Ratón: apuntar (clic derecho) y lanzar (clic izquierdo) no se remapean.
## Las acciones FIJAS existen en el InputMap pero no se listan ni se remapean: `pausa` (Escape cancela y cierra en todas partes) y `pestana_anterior/siguiente` (Q/E dentro de la mochila).
## Remapeo: una acción con dos teclas de fábrica (mover: WASD y flechas) conserva la segunda; elegir una tecla que ya usa OTRA acción las INTERCAMBIA (la otra recibe la antigua principal).
## Guardado: `user://ajustes.cfg` (`MenuPausa.RUTA_AJUSTES`), sección [controles], solo las acciones que difieren de fábrica; `MenuPausa.cargar_ajustes()` lo aplica al arrancar.

## Las acciones que ve y remapea la jugadora, en el orden de la pantalla. «teclas»: las de fábrica (la primera es la principal).
const ACCIONES: Array = [
	{"id": "mover_adelante", "texto": "Mover arriba", "teclas": [KEY_W, KEY_UP]},
	{"id": "mover_atras", "texto": "Mover abajo", "teclas": [KEY_S, KEY_DOWN]},
	{"id": "mover_izquierda", "texto": "Mover a la izquierda", "teclas": [KEY_A, KEY_LEFT]},
	{"id": "mover_derecha", "texto": "Mover a la derecha", "teclas": [KEY_D, KEY_RIGHT]},
	{"id": "correr", "texto": "Correr", "teclas": [KEY_SHIFT]},
	{"id": "saltar", "texto": "Saltar", "teclas": [KEY_SPACE]},
	{"id": "voltereta", "texto": "Voltereta", "teclas": [KEY_CTRL]},
	{"id": "golpe", "texto": "Golpe cuerpo a cuerpo", "teclas": [KEY_F]},
	{"id": "interactuar", "texto": "Interactuar", "teclas": [KEY_E]},
	{"id": "usar_consumible", "texto": "Usar consumible", "teclas": [KEY_Q]},
	{"id": "cambiar_consumible", "texto": "Cambiar consumible", "teclas": [KEY_R]},
	{"id": "lanzar_objeto", "texto": "Lanzar objeto de la rueda", "teclas": [KEY_G]},     # 10/11: lanza el lanzable elegido hacia el ratón (`Lanzables`)
	{"id": "mochila", "texto": "Mochila", "teclas": [KEY_I]},
	{"id": "misiones", "texto": "Misiones", "teclas": [KEY_J]},
	{"id": "libro", "texto": "Libro de hechizos", "teclas": [KEY_T]},
	{"id": "pagina_1", "texto": "Hechizo / página 1", "teclas": [KEY_1]},
	{"id": "pagina_2", "texto": "Hechizo / página 2", "teclas": [KEY_2]},
	{"id": "pagina_3", "texto": "Hechizo / página 3", "teclas": [KEY_3]},
]
const FIJAS: Array = [
	{"id": "pausa", "texto": "Pausa / cancelar", "teclas": [KEY_ESCAPE]},
	{"id": "pestana_anterior", "texto": "Pestaña anterior", "teclas": [KEY_Q]},
	{"id": "pestana_siguiente", "texto": "Pestaña siguiente", "teclas": [KEY_E]},
]
const SECCION: String = "controles"


## Las ids de las acciones remapeables.
static func ids() -> Array:
	var r: Array = []
	for d in ACCIONES:
		r.append(String(d["id"]))
	return r


static func texto(id: String) -> String:
	for d in ACCIONES:
		if String(d["id"]) == id:
			return String(d["texto"])
	return id


static func de_fabrica(id: String) -> Array:
	for d in ACCIONES + FIJAS:
		if String(d["id"]) == id:
			return (d["teclas"] as Array).duplicate()
	return []


## Asegura que cada acción existe (project.godot ya las define; esto cubre un arranque sin ellas) y que tiene alguna tecla.
static func registrar() -> void:
	for d in ACCIONES + FIJAS:
		var id: String = String(d["id"])
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		if InputMap.action_get_events(id).is_empty():
			poner_teclas(id, d["teclas"] as Array)


## Los códigos de tecla de la acción (solo teclado), en el orden del InputMap.
static func teclas(id: String) -> Array:
	var r: Array = []
	if not InputMap.has_action(id):
		return r
	for ev in InputMap.action_get_events(id):
		var k := ev as InputEventKey
		if k == null:
			continue
		r.append(int(k.keycode) if k.keycode != KEY_NONE else int(k.physical_keycode))
	return r


## Sustituye las teclas de la acción. Los eventos llevan `keycode` (no `physical_keycode`), como los de project.godot.
static func poner_teclas(id: String, codigos: Array) -> void:
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	InputMap.action_erase_events(id)
	for c in codigos:
		var ev := InputEventKey.new()
		ev.keycode = int(c) as Key
		InputMap.action_add_event(id, ev)


## ¿Qué acción REMAPEABLE (distinta de `excepto`) usa esa tecla? "" si ninguna.
static func accion_de_tecla(codigo: int, excepto: String = "") -> String:
	for d in ACCIONES:
		var id: String = String(d["id"])
		if id != excepto and teclas(id).has(codigo):
			return id
	return ""


## Nombre legible de una tecla.
static func nombre_tecla(codigo: int) -> String:
	if codigo == KEY_NONE:
		return "—"
	return OS.get_keycode_string(codigo as Key)


## Todas las teclas de la acción como texto: «W / ↑».
static func texto_teclas(id: String) -> String:
	var partes: PackedStringArray = []
	for c in teclas(id):
		partes.append(nombre_tecla(int(c)))
	return " / ".join(partes) if not partes.is_empty() else "—"


## ¿Se puede asignar esta tecla? No las F1-F12 (depuración), ni Escape (cancela), Enter ni Intro del teclado (aceptan en los menús).
static func asignable(codigo: int) -> bool:
	if codigo == KEY_NONE or codigo == KEY_ESCAPE or codigo == KEY_ENTER or codigo == KEY_KP_ENTER:
		return false
	return not (codigo >= KEY_F1 and codigo <= KEY_F12)


## Pone `codigo` como tecla principal de `id`. Si otra acción remapeable la usaba, las intercambia (esa recibe la principal antigua de `id`).
## Devuelve {"ok": bool, "intercambio": id de la otra acción o ""}. No guarda en disco (eso lo hace quien llama, con `MenuPausa.guardar_ajustes()`).
static func remapear(id: String, codigo: int) -> Dictionary:
	if not ids().has(id) or not asignable(codigo):
		return {"ok": false, "intercambio": ""}
	var propias: Array = teclas(id)
	var antigua: int = int(propias[0]) if not propias.is_empty() else KEY_NONE
	if propias.has(codigo) and int(propias[0]) == codigo:
		return {"ok": true, "intercambio": ""}
	var otra: String = accion_de_tecla(codigo, id)
	var nuevas: Array = [codigo]
	for c in propias:
		if int(c) != codigo and int(c) != antigua:
			nuevas.append(int(c))               # la segunda tecla de fábrica (flechas) se conserva
	if otra != "":
		var suyas: Array = []
		for c in teclas(otra):
			var cc: int = antigua if int(c) == codigo else int(c)
			if cc != KEY_NONE and not suyas.has(cc):
				suyas.append(cc)
		nuevas.erase(antigua)
		poner_teclas(otra, suyas)
	poner_teclas(id, nuevas)
	return {"ok": true, "intercambio": otra}


## Vuelve todas las acciones a las teclas de fábrica.
static func restaurar() -> void:
	for d in ACCIONES + FIJAS:
		poner_teclas(String(d["id"]), d["teclas"] as Array)


## ¿Difiere la acción de su configuración de fábrica?
static func modificada(id: String) -> bool:
	return teclas(id) != de_fabrica(id)


## Escribe la sección [controles] en `c` (solo lo que difiere de fábrica; borra lo anterior).
static func escribir(c: ConfigFile) -> void:
	if c.has_section(SECCION):
		c.erase_section(SECCION)
	for id in ids():
		if modificada(id):
			c.set_value(SECCION, id, teclas(id))


## Aplica la sección [controles] de `c` (si la hay). Ignora lo que no sea una lista de teclas asignables.
static func leer(c: ConfigFile) -> void:
	registrar()
	if not c.has_section(SECCION):
		return
	for id in ids():
		if not c.has_section_key(SECCION, id):
			continue
		var v: Variant = c.get_value(SECCION, id)
		if not (v is Array):
			continue
		var codigos: Array = []
		for x in (v as Array):
			if (x is int) and asignable(int(x)):
				codigos.append(int(x))
		if not codigos.is_empty():
			poner_teclas(id, codigos)
