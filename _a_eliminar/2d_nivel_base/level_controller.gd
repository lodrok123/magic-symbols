extends Node

## Reinicio rápido de nivel (tecla R).
##
## Esto vivía en node_2d.gd (el nodo raíz), pero al añadir la pausa de
## victoria/derrota dejó de funcionar justo cuando más falta hace: un
## nodo en pausa no recibe ni _process ni _input, así que la R no
## llegaba a leerse.
##
## La solución es este nodo aparte con process_mode = ALWAYS (se pone
## en el editor, en Inspector > Node > Process > Mode). No se puede
## poner ALWAYS en el nodo raíz porque los hijos heredan ese modo por
## defecto y entonces NADA se pausaría: la pausa dejaría de existir.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		# Quitar la pausa ANTES de recargar es imprescindible: el flag
		# `paused` vive en el SceneTree, no en la escena, así que
		# sobrevive al cambio de escena. Sin esta línea, el nivel nuevo
		# arrancaría congelado y ya no habría forma de salir.
		get_tree().paused = false
		get_tree().reload_current_scene()
