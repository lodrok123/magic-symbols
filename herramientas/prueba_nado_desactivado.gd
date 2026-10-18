extends "res://herramientas/escenario_base.gd"
## Escenario · NADO DESACTIVADO (Juego, 16/10, decisión de Pablo): nadar se salta los puzles del tronco, así que `Jugador3D.nado_permitido` es false y el agua
## se comporta como una pared al ANDAR hacia ella. Con el interruptor en true el nado sigue funcionando (y las pruebas del agua lo usan).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_nado_desactivado.gd
## Tramo: el río del Bosque 01 acaba en (6,13); al sur, (6,14) es suelo. Se anda de (6,15) hacia el norte, hacia el agua.

const RUTA: String = "res://escenas/PruebaBosque01.tscn"
const ORILLA: Vector2i = Vector2i(6, 15)
const AGUA: Vector2i = Vector2i(6, 13)


func _escenario() -> void:
	await cargar(RUTA, true)
	await avanzar_s(1.0)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).muerto = true                      # que nada moleste en el paseo
	_ok("1 el interruptor está apagado por defecto", not Jugador3D.nado_permitido)
	_ok("2 la casilla (6,13) es agua de la que se nada", Terreno3D.se_nada(AGUA), String(Terreno3D.letra_de(AGUA)))
	_ok("2 y la (6,14) es suelo", Terreno3D.pisable(Vector2i(6, 14), 0, false, 0, false))

	colocar_jugador(ORILLA)
	await avanzar_s(2.0)
	await mover_hacia(Vector2i(6, 11), 6.0, 0.5)             # a través del agua, en línea recta hacia el norte
	_ok("3 andando hacia el agua con el nado apagado, no se nada", not jugador.nadando, str(celda_jugador()))
	_ok("3 y el jugador se queda en la orilla (no pasa de la casilla 14)", celda_jugador().y >= 14, str(celda_jugador()))

	Jugador3D.nado_permitido = true
	colocar_jugador(ORILLA)
	await avanzar_s(2.0)
	await mover_hacia(Vector2i(6, 12), 6.0, 0.6)
	_ok("4 con el interruptor encendido sí se entra al agua y se nada", jugador.nadando or celda_jugador().y <= 13, "nadando %s en %s" % [str(jugador.nadando), str(celda_jugador())])
	Jugador3D.nado_permitido = false
