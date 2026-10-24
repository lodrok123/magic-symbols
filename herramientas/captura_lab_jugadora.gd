extends SceneTree
## CAPTURAS del laboratorio de la jugadora (24/10; laboratorios/LabJugadora3D.tscn): para CADA clip una HOJA DE CONTACTO (8 fotogramas repartidos por igual, de
## izquierda a derecha y de arriba abajo, vista tres cuartos; la jugadora nueva a la izquierda y, si el clip sale de un modelo fuente, ese modelo con el clip ORIGINAL a la
## derecha; si la fuente no tiene malla se dibuja su esqueleto), y una hoja de la CABEZA en reposo (Idle) a 1,0 / 0,9 / 0,8 / 0,75 de frente (arriba) y con la cámara del juego
## (abajo, ampliada ×2,4 sin suavizar). También escribe `medidas.txt` con los peores saltos de giro de cada clip (nuevo y fuente). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_lab_jugadora.gd -- <carpeta> [secciones: clips,cabeza] [filtro de clips, separados por coma]
## Por defecto la carpeta es res://docs/capturas/lab_jugadora.

const ESCENA: String = "res://laboratorios/LabJugadora3D.tscn"
const FOTOGRAMAS: int = 8
const COLUMNAS: int = 4
const RECORTE_CLIP: Rect2i = Rect2i(320, 130, 640, 480)    ## de la foto de 1280 × 720: los dos personajes, de la suela a la coronilla
const DIST_CLIP: float = 3.2
const VISTA_CLIP: Vector2 = Vector2(40.0, 12.0)            ## giro y elevación (grados): tres cuartos
const CABEZAS: Array = [1.0, 0.9, 0.8, 0.75]
const RECORTE_FRENTE: Rect2i = Rect2i(460, 70, 360, 560)
const DIST_FRENTE: float = 2.4
const RECORTE_JUEGO: Rect2i = Rect2i(565, 280, 150, 233)   ## el personaje a tamaño del juego (≈ 120 px de alto) con margen; se amplía a RECORTE_FRENTE
const ESPERA: int = 4

var _carpeta: String = "res://docs/capturas/lab_jugadora"
var _lab: Node = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_carpeta = a[0]
	var secciones: PackedStringArray = (a[1] if a.size() > 1 else "clips,cabeza").split(",")
	var filtro: PackedStringArray = (a[2] if a.size() > 2 else "").split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	var gi: FileAccess = FileAccess.open(ProjectSettings.globalize_path(_carpeta).path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Estado.nuevo()
	root.size = Vector2i(1280, 720)
	_lab = (load(ESCENA) as PackedScene).instantiate()
	root.add_child(_lab)
	for _i in 10:
		await process_frame
	_lab.ocultar_interfaz(true)
	_lab.poner_pausa(true)
	if secciones.has("clips"):
		await _hojas_de_clips(filtro)
	if secciones.has("cabeza"):
		await _hoja_cabeza()
	if secciones.has("postura"):
		await _hoja_postura()
	quit()


## Idle, Walking, Running y el cast al frente sin y con la postura de la elfa (Pj3D.POSTURAS[chibi_elf]), a 0 % y 50 % del clip: una fila por clip, columnas sin/con/sin/con.
func _hoja_postura() -> void:
	_lab.mostrar_fuente(false)
	_lab.poner_pausa(true)
	var clips: Array = ["Idle", "Walking", "Running", "MageSoellCast003"]
	var an: int = RECORTE_FRENTE.size.x
	var al: int = RECORTE_FRENTE.size.y
	var hoja := Image.create_empty(an * 4, al * clips.size(), false, Image.FORMAT_RGB8)
	for r in range(clips.size()):
		_lab.elegir_clip_por_nombre(String(clips[r]))
		_lab.poner_pausa(true)
		_lab.vista(40.0, 8.0, DIST_FRENTE)
		for c in range(4):
			_lab.poner_postura_elfa(c % 2 == 1)
			_lab.poner_fraccion(0.0 if c < 2 else 0.5)
			var f: Image = await _foto()
			hoja.blit_rect(f, RECORTE_FRENTE, Vector2i(c * an, r * al))
	_lab.poner_postura_elfa(false)
	hoja.save_png(ProjectSettings.globalize_path(_carpeta).path_join("postura_elfa.png"))
	print("captura postura_elfa")


func _hojas_de_clips(filtro: PackedStringArray) -> void:
	var informe: String = "MEDIDAS POR CLIP (peores saltos de giro entre claves consecutivas de un hueso, en grados: nuevo = jugadora_base tras ClipsFamilia; fuente = el clip original)\n\n"
	var lista: Array = _lab.clips()
	_lab.mostrar_fuente(true)
	for i in range(lista.size()):
		var nombre: String = String((lista[i] as Dictionary)["nombre"])
		if not filtro.is_empty() and not filtro.has(nombre):
			continue
		_lab.elegir_clip_por_nombre(nombre)
		_lab.poner_pausa(true)
		_lab.vista(VISTA_CLIP.x, VISTA_CLIP.y, DIST_CLIP)
		var filas: int = int(ceil(float(FOTOGRAMAS) / float(COLUMNAS)))
		var hoja := Image.create_empty(RECORTE_CLIP.size.x * COLUMNAS, RECORTE_CLIP.size.y * filas, false, Image.FORMAT_RGB8)
		for k in range(FOTOGRAMAS):
			_lab.poner_fraccion(float(k) / float(FOTOGRAMAS))
			var foto: Image = await _foto()
			hoja.blit_rect(foto, RECORTE_CLIP, Vector2i((k % COLUMNAS) * RECORTE_CLIP.size.x, (k / COLUMNAS) * RECORTE_CLIP.size.y))
		hoja.save_png(ProjectSettings.globalize_path(_carpeta).path_join(nombre + ".png"))
		print("captura ", nombre, " (fuente: ", _lab.hay_fuente(), ", con malla: ", _lab.fuente_con_malla(), ")")
		var s: Dictionary = _lab.saltos_del_clip(i)
		informe += "%s  (%.2f s)\n" % [nombre, _lab.duracion()]
		informe += "  nuevo : %s\n" % _una_linea(s["nuevo"])
		informe += "  fuente: %s\n" % (_una_linea(s["fuente"]) if not (s["fuente"] as Array).is_empty() else "-")
	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path(_carpeta).path_join("medidas.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string(informe)
		f.close()


func _una_linea(l: Array) -> String:
	var partes: PackedStringArray = PackedStringArray()
	for d in l:
		var e: Dictionary = d
		partes.append("%s %.0f°@%s" % [String(e["hueso"]).replace("mixamorig_", ""), float(e["grados"]), "cierre" if bool(e["cierre"]) else str(int(e["k0"]))])
	return ", ".join(partes)


## La cabeza a 1,0 / 0,9 / 0,8 / 0,75 en reposo: fila de arriba de frente, fila de abajo con la cámara del juego.
func _hoja_cabeza() -> void:
	_lab.mostrar_fuente(false)
	_lab.elegir_clip_por_nombre("Idle")
	_lab.poner_pausa(true)
	_lab.poner_fraccion(0.0)
	var an: int = RECORTE_FRENTE.size.x
	var al: int = RECORTE_FRENTE.size.y
	var hoja := Image.create_empty(an * CABEZAS.size(), al * 2, false, Image.FORMAT_RGB8)
	for c in range(CABEZAS.size()):
		_lab._poner_cabeza(float(CABEZAS[c]), true)
		print("cabeza ", CABEZAS[c], ": %.2f alturas de cabeza" % _lab.alturas_de_cabeza())
		_lab.vista(0.0, 5.0, DIST_FRENTE)
		var f1: Image = await _foto()
		hoja.blit_rect(f1, RECORTE_FRENTE, Vector2i(c * an, 0))
		_lab.camara("juego")
		var f2: Image = await _foto()
		var rec: Image = f2.get_region(RECORTE_JUEGO)
		rec.resize(an, al, Image.INTERPOLATE_NEAREST)
		hoja.blit_rect(rec, Rect2i(0, 0, an, al), Vector2i(c * an, al))
	hoja.save_png(ProjectSettings.globalize_path(_carpeta).path_join("cabeza_idle.png"))
	print("captura cabeza_idle")
	_lab._poner_cabeza(1.0, true)


func _foto() -> Image:
	for _i in ESPERA:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()
