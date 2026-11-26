extends SceneTree
## Regresión: los atlas instalados deben conservar exactamente los PNG del GLB,
## y el horneado de la estalagmita no debe pintar las antiguas cuñas negras.
var fallos: int = 0

func comprobar(condicion: bool, nombre: String) -> void:
	print("OK " if condicion else "FALLO ", nombre)
	if not condicion: fallos += 1

func _initialize() -> void:
	var archivo := FileAccess.open("res://arte/rocas_lelu/sm_rocks_objects.glb", FileAccess.READ)
	archivo.seek(12)
	var largo_json: int = archivo.get_32()
	archivo.get_32()
	var datos: Dictionary = JSON.parse_string(archivo.get_buffer(largo_json).get_string_from_utf8())
	var largo_bin: int = archivo.get_32()
	archivo.get_32()
	var binario: PackedByteArray = archivo.get_buffer(largo_bin)
	var nombres: Dictionary = {
		"T_rocks_A_col": "rocas_albedo.png", "T_rocks_B_colors": "rocas_musgo_albedo.png",
		"T_rocks_C_col": "rocas_magma_albedo.png", "T_rocks_C_normal": "rocas_magma_normal.png",
		"T_rocks_C_roughtness": "rocas_magma_rough.png", "T_rocks_C_emissives": "rocas_magma_emisivo.png"
	}
	var revisadas: int = 0
	for imagen in datos.images:
		if not nombres.has(imagen.get("name", "")): continue
		var vista: Dictionary = datos.bufferViews[imagen.bufferView]
		var inicio: int = int(vista.get("byteOffset", 0))
		var png: PackedByteArray = binario.slice(inicio, inicio + int(vista.byteLength))
		for carpeta in ["res://arte/meshy/piezas/tex_rocas_est/", "res://arte/meshy/aprobacion3d/rocas_estilizadas/texturas/"]:
			var ruta: String = carpeta + nombres[imagen.name]
			comprobar(FileAccess.get_file_as_bytes(ruta) == png, "Atlas sin volteo ni conversión: " + ruta)
		revisadas += 1
	comprobar(revisadas == 6, "Los seis mapas del pack quedaron comprobados")
	var roca: Image = Image.load_from_file("res://arte/lostcave/texturas/M_Stalagmite_b_roca.png")
	comprobar(roca != null and not roca.is_empty(), "Horneado de estalagmita disponible")
	if roca != null:
		var minimo: float = 1.0
		for y in range(0, roca.get_height(), 4):
			for x in range(0, roca.get_width(), 4):
				minimo = minf(minimo, roca.get_pixel(x,y).get_luminance())
		comprobar(minimo > 0.1, "El color horneado no introduce cuñas negras; mínimo %.3f" % minimo)
	comprobar("M_Stalagmite_b" in TablaLostCave.ROCA_SIN_MASCARA_ATLAS, "Excepción de máscara reproducible en la tabla")
	print("TOTAL DE FALLOS: ", fallos)
	quit(1 if fallos else 0)
