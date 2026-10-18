extends "res://herramientas/escenario_base.gd"
## Escenario 12 · barrera (solidez V2): la flecha de un goblin arquero contra el volumen con solidez del jugador. (R3: antes, la burbuja de la Fase 12.) Lo escribe el Juego (16/10).
##
## Con la escena entera: el jugador lanza «agua + barrera» (camino real del jugador) y un goblin real hecho arquero suelta su flecha con
## `_soltar_flecha()` (lo único colocado a mano: la IA se apaga para que dispare cuando yo digo). Se espera: el volumen para la flecha y
## aguanta el golpe, el jugador no pierde vida, al agotarse el aguante se deshace; y sin volumen la misma flecha SÍ hiere.
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

	# --- Con solidez: la para y aguanta ---
	# R3 (17/10): «agua + barrera» ya no abre una burbuja que revienta (Fase 12): con la receta V2 es la propiedad `solidez` de un volumen
	# (aquí la esfera base, agua, en la casilla de la mano). Bloquea la flecha y AGUANTA el golpe: pierde `DANO_FLECHA` de aguante y sigue en pie
	# hasta agotarlo. La burbuja que revienta con reacción (vapor, charco, absorbe) queda como mecanismo sin receta (ver el diario de R3).
	jugador.set("vida", 100.0)
	colocar_jugador(DESDE)
	_ok("3 el hechizo agua + barrera sale", lanzar("agua", ["barrera"], Vector3.RIGHT))
	await avanzar(2)
	var s: Lanzador3D.SolidezV2 = lanzador._solideces_v2.back() if not lanzador._solideces_v2.is_empty() else null
	_ok("3 hay un volumen con solidez vivo", s != null and is_instance_valid(s))
	if s == null or not is_instance_valid(s):
		return
	var aguante0: float = s.aguante
	var v2: float = float(jugador.get("vida"))
	arquero.call("_soltar_flecha")
	await avanzar_s(0.8)                                # la flecha llega en medio segundo; el agua dura 2 s (VIDA_MIN_SOLIDEZ_V2)
	_ok("4 el volumen sigue en pie tras una flecha (aguante %.1f → %.1f)" % [aguante0, s.aguante], is_instance_valid(s) and absf((aguante0 - s.aguante) - Combate3D.DANO_FLECHA) < 0.001)
	_ok("4 el jugador no pierde vida (%.0f)" % float(jugador.get("vida")), is_equal_approx(float(jugador.get("vida")), v2))

	# --- Cuando se agota (o caduca), la misma flecha vuelve a herir ---
	for _i in range(6):
		if not is_instance_valid(s) or s.is_queued_for_deletion():
			break
		arquero.call("_soltar_flecha")
		await avanzar_s(2.0)
	_ok("5 tras varias flechas el volumen se ha deshecho", not is_instance_valid(s) or s.is_queued_for_deletion())
	var v3: float = float(jugador.get("vida"))
	arquero.call("_soltar_flecha")
	await avanzar_s(2.0)
	_ok("6 sin volumen otra vez, la siguiente flecha hiere (%.0f → %.0f)" % [v3, float(jugador.get("vida"))], float(jugador.get("vida")) < v3)
