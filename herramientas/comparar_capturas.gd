extends SceneTree
## Compara dos carpetas de PNG pixel a pixel (26/11/2026): para cada archivo con el mismo nombre dice cuántos píxeles cambian, la diferencia máxima y la media.
##   godot --headless --path . --script res://herramientas/comparar_capturas.gd -- <carpeta_a> <carpeta_b> [umbral=0.02]
## `umbral` = diferencia por canal (0-1) a partir de la cual un píxel cuenta como distinto. Acaba con una línea «DIFERENTES: n» (archivos con más de un 0,5 % de píxeles distintos).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("uso: -- <carpeta_a> <carpeta_b> [umbral]")
		quit(2)
		return
	var umbral: float = float(args[2]) if args.size() > 2 else 0.02
	var distintos: int = 0
	for f in DirAccess.get_files_at(args[0]):
		if f.get_extension() != "png" or not FileAccess.file_exists(args[1].path_join(f)):
			continue
		var a: Image = Image.load_from_file(args[0].path_join(f))
		var b: Image = Image.load_from_file(args[1].path_join(f))
		if a == null or b == null or a.get_size() != b.get_size():
			print("%s: tamaños distintos" % f)
			distintos += 1
			continue
		var n: int = 0
		var maxd: float = 0.0
		var suma: float = 0.0
		for y in range(a.get_height()):
			for x in range(a.get_width()):
				var ca: Color = a.get_pixel(x, y)
				var cb: Color = b.get_pixel(x, y)
				var d: float = maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
				suma += d
				maxd = maxf(maxd, d)
				if d > umbral:
					n += 1
		var total: int = a.get_width() * a.get_height()
		var pct: float = 100.0 * float(n) / float(total)
		print("%-16s píxeles distintos %6d (%.3f %%) · diferencia máxima %.3f · media %.5f" % [f, n, pct, maxd, suma / float(total)])
		if pct > 0.5:
			distintos += 1
	print("DIFERENTES: %d" % distintos)
	quit(0)
