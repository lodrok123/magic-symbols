extends "res://herramientas/escenario_puzles_tierra.gd"
## Segunda pasada de los puzles de tierra (21/11/2026): el botón `!` y la placa `@` de cada sala. Es el mismo escenario con `modo = "botones"`; razones y cómo se corre, en escenario_puzles_tierra.gd.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_tierra_botones.gd


func _init() -> void:
	modo = "botones"
