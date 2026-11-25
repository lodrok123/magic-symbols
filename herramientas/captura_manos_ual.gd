extends SceneTree
## CAPTURAS de cerca de la MANO DERECHA con los clips UAL en revisión (LabJugadora3D, 25/11, Pablo: «¿por qué los dedos están así?»). Para cada clip, 4 momentos
## (0, ¼, ½, ¾ de la duración) en tres filas: arriba el MANIQUÍ de Quaternius con el clip original (la referencia), en medio la jugadora con los dedos ALINEADOS
## (LabJugadora3D.alinear_dedos_ual = true) y abajo la jugadora SIN alinear (como estaba). Sin ropa, para que la capa no tape la mano. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_manos_ual.gd -- <carpeta> [clips separados por coma]
## Por defecto la carpeta es res://docs/capturas/ual_manos.

const ESCENA: String = "res://laboratorios/LabJugadora3D.tscn"
const SCRIPT_LAB: String = "res://laboratorios/lab_jugadora_3d.gd"
const CLIPS: String = "UAL_Reposo,UAL_Conjuro2Mantener,UAL_Conjuro3Soltar,UAL_PunoDirecto,UAL_Antorcha,UAL_GolpePecho,UAL_Interactuar,UAL_EspadaQuieta"
const MOMENTOS: Array = [0.0, 0.25, 0.5, 0.75]
const LADO: int = 300                          ## px de cada viñeta
const DIST_MANOS: float = 4.0                  ## distancia de la cámara a la mano, en largos de mano (muñeca → nudillo del corazón)
const ESPERA: int = 3

var _carpeta: String = "res://docs/capturas/ual_manos"
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_carpeta = a[0]
	var clips: PackedStringArray = (a[1] if a.size() > 1 else CLIPS).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	var gi: FileAccess = FileAccess.open(ProjectSettings.globalize_path(_carpeta).path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Estado.nuevo()
	root.size = Vector2i(1280, 720)
	var filas: Array = [{}, {}, {}]            # maniquí, alineado, sin alinear: {clip: [Image]}
	for pasada in range(2):
		var alinear: bool = pasada == 0
		(load(SCRIPT_LAB) as GDScript).set("alinear_dedos_ual", alinear)
		var lab: Node = (load(ESCENA) as PackedScene).instantiate()
		root.add_child(lab)
		for _i in ESPERA:
			await process_frame
		lab.call("ocultar_interfaz", true)
		lab.call("poner_ropa", false)
		_cam = Camera3D.new()
		_cam.fov = 30.0
		_cam.near = 0.005
		lab.add_child(_cam)
		_cam.current = true
		var pj: Pj3D = lab.call("jugadora")
		var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var fuentes: Array = lab.get("_fuentes")
		var f_ual: Dictionary = fuentes[fuentes.size() - 1]
		var sk_f: Skeleton3D = f_ual["sk"]
		for clip in clips:
			if not bool(lab.call("elegir_clip_por_nombre", clip)):
				print("FALTA ", clip)
				continue
			lab.call("poner_pausa", true)
			var fotos: Array = []
			var fotos_f: Array = []
			for m in MOMENTOS:
				lab.call("poner_fraccion", float(m))
				lab.call("mostrar_fuente", false)
				await process_frame
				fotos.append(await _foto_mano(sk, pj.global_position))
				if pasada == 0:
					lab.call("mostrar_fuente", true)
					pj.visible = false
					await process_frame
					fotos_f.append(await _foto_mano(sk_f, (f_ual["nodo"] as Node3D).global_position))
					pj.visible = true
			filas[1 + pasada][clip] = fotos
			if pasada == 0:
				filas[0][clip] = fotos_f
		lab.queue_free()
		await process_frame
	for clip in clips:
		if not (filas[1] as Dictionary).has(clip):
			continue
		var hoja := Image.create(LADO * MOMENTOS.size(), LADO * 3, false, Image.FORMAT_RGBA8)
		for fila in range(3):
			var fotos: Array = (filas[fila] as Dictionary)[clip]
			for c in range(fotos.size()):
				var f: Image = fotos[c]
				f.convert(Image.FORMAT_RGBA8)
				hoja.blit_rect(f, Rect2i(0, 0, LADO, LADO), Vector2i(c * LADO, fila * LADO))
		var ruta: String = ProjectSettings.globalize_path(_carpeta).path_join(clip + ".png")
		hoja.save_png(ruta)
		print("escrita ", ruta)
	quit()


## Foto de la mano derecha de `sk`, mirada desde el lado de fuera del cuerpo (centro del cuerpo en `cuerpo`), un poco por delante y por arriba.
func _foto_mano(sk: Skeleton3D, cuerpo: Vector3) -> Image:
	var p := func(n: String) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin
	var muneca: Vector3 = p.call("mixamorig_RightHand")
	var nudillo: Vector3 = p.call("mixamorig_RightHandMiddle1")
	var centro: Vector3 = p.call("mixamorig_RightHandMiddle2")
	var largo: float = muneca.distance_to(nudillo)
	var fuera: Vector3 = centro - cuerpo
	fuera.y = 0.0
	fuera = (fuera.normalized() if fuera.length() > 0.001 else Vector3.RIGHT) + Vector3(0.0, 0.35, 0.6)
	_cam.global_position = centro + fuera.normalized() * largo * DIST_MANOS
	_cam.look_at(centro, Vector3.UP)
	for _i in ESPERA:
		await process_frame
	var img: Image = root.get_texture().get_image()
	var recorte: Image = img.get_region(Rect2i(640 - 300, 360 - 300, 600, 600))
	recorte.resize(LADO, LADO, Image.INTERPOLATE_BILINEAR)
	return recorte
