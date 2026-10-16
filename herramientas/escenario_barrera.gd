extends "res://herramientas/escenario_base.gd"
## Escenario 12 · barrera-burbuja: la flecha de un goblin arquero contra la burbuja del jugador. Lo escribe el Juego (16/10).
##
## Con la escena entera: el jugador lanza «agua + barrera» (camino real del jugador) y un goblin real hecho arquero suelta su flecha con
## `_soltar_flecha()` (lo único colocado a mano: la IA se apaga para que dispare cuando yo digo). Se espera: la flecha revienta la burbuja en
## su fachada, el jugador no pierde vida, la burbuja se libera y sale «barrera_revienta» en el PlayLog; y sin burbuja la misma flecha SÍ hiere.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_barrera.gd

const DESDE := Vector2i(4, 26)                         ## hierba al norte del río, como en los otros escenarios


func _escenario() -> void:
	await cargar()
	# El Bosque no trae arqueros (están en otros niveles): se usa un goblin REAL y se le dice que lo es. `_soltar_flecha` no mira nada más
	# que el jugador, así que la flecha que se mide es la de verdad (Tween, VEL_FLECHA, _flecha_llega, recibir_dano).
	var goblins: Array = get_nodes_in_group("combate3d")
	_ok("0 la escena tiene goblins", not goblins.is_empty())
	if goblins.is_empty():
		return
	var arquero: Node3D = goblins[0] as Node3D
	arquero.set("arquero", true)
	arquero.set_physics_process(false)                 # que no dispare ni se mueva solo
	colocar_jugador(DESDE)
	var pj: Vector3 = jugador.position
	arquero.global_position = pj + Vector3(4.0, 0.0, 0.0)
	arquero.set("jugador", jugador)
	await avanzar(2)
	_ok("1 hay línea libre entre el arquero y el jugador", Terreno3D.linea_libre(arquero.position, jugador.position))

	# --- Sin burbuja: la flecha hiere (referencia) ---
	var v0: float = float(jugador.get("vida"))
	arquero.call("_soltar_flecha")
	await avanzar_s(2.0)
	var v1: float = float(jugador.get("vida"))
	_ok("2 sin burbuja la flecha hiere (%.0f → %.0f)" % [v0, v1], v1 < v0)

	# --- Con burbuja: la para y revienta ---
	jugador.set("vida", 100.0)
	colocar_jugador(DESDE)
	_ok("3 el hechizo agua + barrera sale", lanzar("agua", ["barrera"], Vector3.RIGHT))
	await avanzar(2)
	var b: Lanzador3D.Campo = lanzador._barrera_activa
	_ok("3 hay una burbuja viva", b != null and is_instance_valid(b) and b.burbuja)
	if b == null or not is_instance_valid(b):
		return
	var antes: int = eventos("barrera_revienta").size()
	var v2: float = float(jugador.get("vida"))
	arquero.call("_soltar_flecha")
	await avanzar_s(2.0)
	_ok("4 la burbuja ha reventado y se ha liberado", not is_instance_valid(b))
	_ok("4 el jugador no pierde vida (%.0f)" % float(jugador.get("vida")), is_equal_approx(float(jugador.get("vida")), v2))
	var ev: Array = eventos("barrera_revienta")
	_ok("5 el PlayLog tiene barrera_revienta {elemento: agua}", ev.size() == antes + 1 and String((ev[ev.size() - 1] as Dictionary).get("elemento", (ev[ev.size() - 1] as Dictionary).get("datos", {}).get("elemento", ""))) == "agua", str(ev.slice(maxi(ev.size() - 1, 0))))
	_ok("5 ya no hay barrera activa", lanzador._barrera_activa == null or not is_instance_valid(lanzador._barrera_activa))

	# --- Una flecha más, ya sin burbuja, vuelve a herir ---
	arquero.call("_soltar_flecha")
	await avanzar_s(2.0)
	_ok("6 sin burbuja otra vez, la siguiente flecha hiere", float(jugador.get("vida")) < v2)
