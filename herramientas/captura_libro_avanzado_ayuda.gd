extends SceneTree

## CAPTURA DEL LIBRO AVANZADO CON LA AYUDA DE DIBUJO (22/11, Juego). CON ventana (hace falta renderizar):
##   <godot> --path E:\magic-symbols --resolution 1280x720 --script res://herramientas/captura_libro_avanzado_ayuda.gd
## Carga LabLibroAvanzado y guarda en docs/capturas/libro_avanzado/:
##   ayuda_1_reposo.png         el libro abierto: la chuleta con la guía de trazo junto a cada runa (punto de inicio y flecha)
##   ayuda_2_glifo_elegido.png  un glifo elegido en la chuleta: su línea de pie dice qué hace
##   ayuda_3_trazo.png          a medio dibujar el sello de AGUA en la zona de sellos (el trazo rectificado en vivo, con la pluma)

const DIR: String = "res://docs/capturas/libro_avanzado"


func _init() -> void:
	var escena: PackedScene = load("res://laboratorios/LabLibroAvanzado.tscn")
	var lab: Node = escena.instantiate()
	root.add_child(lab)
	# Varios fotogramas: el libro abre con animación, la lámina tarda en cargar y la chuleta se escribe con su barrido.
	for i in range(150):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var libro: Control = lab.get("_libro")
	_foto("ayuda_1_reposo")

	var glifos: PackedStringArray = Repertoire.active_sigils()
	var elegido: String = "viaja" if glifos.has("viaja") else (glifos[0] if not glifos.is_empty() else "")
	libro.elegir_glifo(elegido)
	for i in range(10):
		await process_frame
	_foto("ayuda_2_glifo_elegido")
	libro.elegir_glifo("")

	# El sello de agua, tal como lo pide su guía, dibujado al 65 % dentro de la zona de sellos.
	var av: Dictionary = libro._av()
	var zona: Dictionary = av["zona_sellos"]
	var centro: Vector2 = libro._on_page(zona["centro"])
	var lado: float = libro._lam(float(zona["radio"])) * 1.1
	var origen: Vector2 = centro - Vector2(lado, lado) * 0.5
	var lineas: Array = TrazosRectos.guia_polilineas(TrazosRectos.texto_guia("agua", true))
	var denso := PackedVector2Array()
	for p_i in range((lineas[0] as PackedVector2Array).size() - 1):
		var a: Vector2 = origen + (lineas[0] as PackedVector2Array)[p_i] * lado
		var b: Vector2 = origen + (lineas[0] as PackedVector2Array)[p_i + 1] * lado
		for s in range(12):
			denso.append(a.lerp(b, float(s) / 12.0))
	var hasta: int = int(float(denso.size()) * 0.65)
	libro._begin_stroke(denso[0])
	for i in range(1, hasta):
		libro._add_point(denso[i])
		await process_frame
	for i in range(6):
		await process_frame
	_foto("ayuda_3_trazo")
	print("glifo elegido: %s · trazo de agua: %d de %d puntos" % [elegido, hasta, denso.size()])
	quit(0)


func _foto(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var ruta: String = DIR.path_join(nombre + ".png")
	var err: int = img.save_png(ruta)
	print("captura %s -> %s (%dx%d)" % [("guardada" if err == OK else "ERROR %d" % err), ruta, img.get_width(), img.get_height()])
