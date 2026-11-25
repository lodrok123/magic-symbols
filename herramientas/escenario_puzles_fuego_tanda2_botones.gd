extends "res://herramientas/escenario_puzles_fuego_tanda2.gd"
## Segunda pasada de los puzles de la segunda tanda del laboratorio de fuego (20/11/2026): el botón `!` y la placa `@` de cada sala. Es el mismo escenario con `modo = "botones"`; razones y cómo se corre, en
## escenario_puzles_fuego_tanda2.gd.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_tanda2_botones.gd


func _init() -> void:
	modo = "botones"
