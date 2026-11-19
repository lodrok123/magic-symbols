extends "res://herramientas/escenario_puzles_fuego_nuevos.gd"
## Tercera pasada de los puzles NUEVOS del laboratorio de fuego (18/11/2026): la regla del barril pequeño contra el muro agrietado de F10 (dejado, lanzado al suelo, lanzado contra el muro, en diagonal). Es el
## mismo escenario con `modo = "muro"`; cada caso recarga el laboratorio. Se corre a 20, 30 y 60 fotogramas por segundo (el choque contra el muro depende de lo que avanza el barril en un fotograma):
##   godot --headless --fixed-fps 20 --path . --script res://herramientas/escenario_puzles_fuego_nuevos_muro.gd


func _init() -> void:
	modo = "muro"
