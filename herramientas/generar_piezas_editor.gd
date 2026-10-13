@tool
extends EditorScript

## Ejecutar con Archivo → Ejecutar (Ctrl+Shift+X) con este script abierto: regenera poc_25d/piezas/*.tscn (ver GeneradorPiezas).

func _run() -> void:
	var n: int = GeneradorPiezas.generar_todas()
	print("Piezas generadas: ", n, " en ", GeneradorPiezas.CARPETA)
