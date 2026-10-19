extends SceneTree

## Regenera SOLO las escenas `arte/piezas/<id>.tscn` de los ids que se le pasan (el generador completo las sobrescribe todas
## y pisaría retoques a mano, como el cofre). Por qué hace falta: los niveles instancian `arte/piezas/<id>.tscn`, que llevan la
## malla horneada dentro; cambiar `meshy/piezas/<id>.glb` no basta, hay que volver a hornear la escena.
## Uso (lo hace GENERAR_ESCENAS_PIEZAS.cmd):  godot --headless --path . --script res://herramientas/generar_piezas_ids.gd -- arbol_redondo pino
func _initialize() -> void:
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	if ids.is_empty():
		print("Faltan ids. Ejemplo: -- arbol_redondo pino")
		quit(2)
		return
	var bien: int = 0
	for id in ids:
		if GeneradorPiezas.generar(id):
			print("OK ", id, " -> ", GeneradorPiezas.CARPETA, id, ".tscn")
			bien += 1
		else:
			print("FALLO ", id, " (sin modelo: ¿está en Pieza3D.MEDIDA y existe su .glb?)")
	print("Generadas: ", bien, " de ", ids.size())
	quit(0 if bien == ids.size() else 1)
