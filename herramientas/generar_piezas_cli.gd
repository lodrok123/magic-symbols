extends SceneTree

## godot --headless --path . --script res://poc_25d/herramientas/generar_piezas_cli.gd
func _initialize() -> void:
	var n: int = GeneradorPiezas.generar_todas()
	print("Piezas generadas: ", n, " en ", GeneradorPiezas.CARPETA)
	quit()
