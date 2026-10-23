extends "res://herramientas/escenario_base.gd"
## BLOQUE 4 de la revisión EoW (23/10): ¿se nota la SOMBRA REDUCIDA de los árboles? NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_bloque4_eow.gd -- [carpeta] [escena]
## La misma toma (mundo en pausa) con la sombra de la copia reducida (lo de serie) y con la de la malla entera (como antes), y la diferencia
## media entre las dos imágenes y en la peor celda de 32 × 32 px.

var _dir: String = "res://docs/capturas/bloque4_eow"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	await cargar(a[1] if a.size() > 1 else RUTA_BOSQUE)
	if maqueta == null:
		return
	_ocultar_ui(root)
	var nom: String = (a[1] if a.size() > 1 else RUTA_BOSQUE).get_file().get_basename()
	await avanzar_s(1.0)
	paused = true
	await avanzar(5)
	var reducida: Image = root.get_viewport().get_texture().get_image()
	reducida.save_png(_dir.path_join(nom + "_sombra_reducida.png"))
	var sombras: Array = maqueta.find_children("lote_*_sombra", "MultiMeshInstance3D", true, false)
	var originales: Array = []
	for s in sombras:
		(s as Node3D).visible = false
		var original: GeometryInstance3D = (s as Node).get_parent().get_node_or_null(String((s as Node).name).trim_suffix("_sombra")) as GeometryInstance3D
		if original != null:
			original.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			originales.append(original)
	await avanzar(5)
	var entera: Image = root.get_viewport().get_texture().get_image()
	entera.save_png(_dir.path_join(nom + "_sombra_entera.png"))
	var media: float = 0.0
	var peor: float = 0.0
	var n: int = 0
	for cy in range(0, entera.get_height() - 32, 32):
		for cx in range(0, entera.get_width() - 32, 32):
			var s: float = 0.0
			for y in range(cy, cy + 32, 4):
				for x in range(cx, cx + 32, 4):
					var c1: Color = reducida.get_pixel(x, y)
					var c2: Color = entera.get_pixel(x, y)
					s += (absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b)) / 3.0
			s /= 64.0
			media += s
			peor = maxf(peor, s)
			n += 1
	_ok("lotes con sombra reducida: %d" % sombras.size(), sombras.size() > 0)
	_aviso("diferencia entre sombra reducida y entera", "media %.4f · peor celda de 32 px %.4f" % [media / float(maxi(n, 1)), peor])
	paused = false


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
