extends "res://herramientas/escenario_puzles_fuego.gd"
## Escenario 14.6 · segunda pasada del LABORATORIO DE FUEGO: botón `!` y placa `@` de cada sala + el cortafuegos de F4 (16/10, Juego).
## Es el mismo escenario con `modo = "botones"`; las razones y cómo se corre, en escenario_puzles_fuego.gd.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_puzles_fuego_botones.gd


func _init() -> void:
	modo = "botones"
