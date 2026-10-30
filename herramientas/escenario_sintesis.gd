extends "res://herramientas/escenario_base.gd"
## ESCENARIO SÍNTESIS (F3 de PLAN_BASE_DATOS, 29/10, Juego): la HOGUERA de verdad, en la escena de jugabilidad (PruebaJugabilidad3D.tscn, con sus braseros y el Jugador3D real).
## Comprueba: (1) un brasero APAGADO no hace nada con E; (2) encendido, a distancia, tampoco; (3) encendido y a su lado, E emite `hoguera_abierta`, la partida se GUARDA (en una
## carpeta de prueba, nunca en user://partidas/) y se abre la síntesis con `donde = hoguera`; (4) con bayas y helecho en la bolsa se hace una poción en la hoguera y el guardado de
## después la lleva; (5) la hoguera no deja hacer lo del alquimista; (6) la defensa de las mejoras entra en `Jugador3D.recibir_dano` de verdad (suelo del 20 %) y la ropa suma la suya.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_sintesis.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd escenario_sintesis
## Qué NO prueba: la interfaz (la pestaña «Síntesis» es del Pipeline y no existe aún) ni el resto de niveles (solo Jugabilidad3D conecta `hoguera_abierta`).

const RUTA: String = "res://escenas/PruebaJugabilidad3D.tscn"
const CARPETA: String = "user://escenario_sintesis/"

var _abiertas: Array = []        ## `donde` de cada `sintesis_abierta` que llegó
var _celdas: Array = []          ## celdas de cada `hoguera_abierta`


func _limpiar() -> void:
	var dir_abs: String = ProjectSettings.globalize_path(CARPETA)
	if DirAccess.dir_exists_absolute(dir_abs):
		for f in DirAccess.get_files_at(dir_abs):
			DirAccess.remove_absolute(dir_abs.path_join(f))
		DirAccess.remove_absolute(dir_abs)


func _escenario() -> void:
	_limpiar()
	Partida.carpeta = CARPETA
	Partida.ranura_actual = 1
	Partida.continuar = false
	Flags.nuevo()
	Misiones.nuevo()
	Partida.recetas_conocidas = []
	await cargar(RUTA, false)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	Sintesis.i().sintesis_abierta.connect(func(donde: String) -> void: _abiertas.append(donde))
	var braseros: Array = []
	for r in (maqueta.get("_reactivos") as Array):
		if is_instance_valid(r) and (r.tipo == "brasero" or r.tipo == "fogata"):
			braseros.append(r)
	_ok("0 la escena trae braseros", braseros.size() >= 1, str(braseros.size()))
	if braseros.is_empty():
		return
	var b: Reactivo3D = braseros[0]
	b.hoguera_abierta.connect(func(c: Vector2i) -> void: _celdas.append(c))
	var e: Estado = Estado.i()
	e.capacidad = 8
	e.oro = 0
	e.items = {"baya": 4, "helecho": 2}
	var ruta: String = CARPETA + "ranura_1.json"

	# 1 · apagado
	if b.is_lit:
		b.apagar_llama()
	colocar_jugador(b.celda + Vector2i(0, 1))
	await avanzar(5)
	_tecla(KEY_E, true)
	_tecla(KEY_E, false)
	await avanzar(5)
	_ok("1 un brasero apagado no es una hoguera: ni señal ni guardado", _celdas.is_empty() and _abiertas.is_empty() and not FileAccess.file_exists(ruta))

	# 2 · encendido pero lejos
	b.encender_llama()
	await avanzar(5)
	_ok("2 el brasero arde", b.is_lit)
	colocar_jugador(b.celda + Vector2i(0, 6))
	await avanzar(5)
	_tecla(KEY_E, true)
	_tecla(KEY_E, false)
	await avanzar(5)
	_ok("2 encendido pero lejos, E no hace nada", _celdas.is_empty() and not FileAccess.file_exists(ruta))

	# 3 · encendido y al lado
	colocar_jugador(b.celda + Vector2i(0, 1))
	await avanzar(5)
	_tecla(KEY_E, true)
	_tecla(KEY_E, false)
	await avanzar(5)
	_ok("3 E junto a la llama emite hoguera_abierta con la casilla de la pieza", _celdas == [b.celda], str(_celdas))
	_ok("3 se abre la síntesis con donde = hoguera", _abiertas == ["hoguera"], str(_abiertas))
	_ok("3 la partida se guarda en la carpeta de prueba", FileAccess.file_exists(ruta))
	var d1: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta)) if FileAccess.file_exists(ruta) else {}
	_ok("3 el guardado trae la bolsa y el punto de la hoguera", (d1.get("bolsa", {}) as Dictionary).get("items", {}) == {"baya": 4.0, "helecho": 2.0} and String((d1.get("meta", {}) as Dictionary).get("punto", "")).ends_with("%d_%d" % [b.celda.x, b.celda.y]),
		str(d1.get("meta", {})))
	_ok("3 no toca user://partidas/ de verdad", Partida.carpeta == CARPETA)

	# 4 · la poción en la hoguera
	var hoguera: Array[String] = Sintesis.conocidas("hoguera")
	_ok("4 la hoguera enseña la poción y no las mejoras", hoguera.has("pocion") and not hoguera.has("vida_1"))
	var el: Dictionary = Sintesis.sugerir("pocion")
	_ok("4 «Sugerir» llena la poción con bayas y helecho", bool(Sintesis.puede("pocion", el, "hoguera")["ok"]), str(el))
	_ok("4 «Hacer» da la poción y gasta los ingredientes", Sintesis.hacer("pocion", el, "hoguera") and e.cuenta("pocion") == 1 and e.cuenta("baya") + e.cuenta("helecho") == 3, str(e.items))
	_ok("5 la mejora de vida es del alquimista: en la hoguera no se hace", not Sintesis.hacer("vida_1", {"baya": 6, "cristal_tierra": 1}, "hoguera"))
	_tecla(KEY_E, true)
	_tecla(KEY_E, false)
	await avanzar(5)
	var d2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta)) if FileAccess.file_exists(ruta) else {}
	_ok("4 el guardado siguiente lleva la poción", ((d2.get("bolsa", {}) as Dictionary).get("items", {}) as Dictionary).get("pocion", 0) == 1.0 and _celdas.size() == 2, str((d2.get("bolsa", {}) as Dictionary).get("items", {})))

	# 6 · la defensa de verdad
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 100.0
	j._t_inv = 0.0
	j.recibir_dano(10.0)
	var sin_def: float = 100.0 - j.vida
	_ok("6 sin defensa un golpe de 10 hiere 10", is_equal_approx(sin_def, 10.0), str(sin_def))
	Mejoras.subir("defensa")
	Mejoras.subir("defensa")
	j.vida = 100.0
	j._t_inv = 0.0
	j.recibir_dano(10.0)
	_ok("6 con DEF 2 hiere 8", is_equal_approx(100.0 - j.vida, 8.0), str(100.0 - j.vida))
	j.vida = 100.0
	j._t_inv = 0.0
	j.recibir_dano(3.0)
	_ok("6 el suelo del 20 %: un golpe de 3 con DEF 2 hiere 1", is_equal_approx(100.0 - j.vida, 1.0), str(100.0 - j.vida))
	j.pj.poner_ropa("capa_escarcha")
	await avanzar(2)
	_ok("6 la capa de escarcha se pone aunque no esté en ropa.json (dibuja la capa) y suma DEF 1 e inmunidad al frío", j.pj.ropa_puesta().has("capa_escarcha") and is_equal_approx(j.defensa_total(), 3.0) and j.inmune_a("frio") and not j.inmune_a("calor"),
		"%s %s" % [str(j.pj.ropa_puesta()), str(j.defensa_total())])
	j.vida = 100.0
	j._t_inv = 0.0
	j.recibir_dano(10.0)
	_ok("6 con DEF 3 un golpe de 10 hiere 7", is_equal_approx(100.0 - j.vida, 7.0), str(100.0 - j.vida))
	j.pj.quitar_ropa("capa_escarcha")

	Partida.carpeta = Partida.CARPETA_DEFECTO
	_limpiar()
