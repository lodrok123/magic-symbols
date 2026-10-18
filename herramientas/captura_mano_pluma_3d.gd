extends SceneTree
## SOLO CAPTURA (Pipeline, 16/10): el libro nuevo con la ManoPluma3D encima, para MIRAR cómo queda (no prueba nada).
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_mano_pluma_3d.gd -- <carpeta_salida> [ancho alto]
## Reproduce `spellbook._book_rect` y `_on_page` con `bloque` de LIBROS["bosque"]; escribe 4 capturas: escribiendo en un hueco, en el sello, levantada y un trazo largo.
const LIBRO: Dictionary = {"tam": Vector2(1470.0, 1070.0), "bloque": Rect2(107, 86, 1240, 760)}
var _fit: float
var _origen: Vector2

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = a[0]
	var tam := Vector2i(int(a[1]) if a.size() > 2 else 1920, int(a[2]) if a.size() > 2 else 1080)
	var vp := SubViewport.new(); vp.size = tam; vp.transparent_bg = false; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var pb: Rect2 = LIBRO["bloque"]
	_fit = minf(float(tam.x) / pb.size.x, float(tam.y) / pb.size.y)
	_origen = Vector2(tam) * 0.5 - (pb.position + pb.size * 0.5) * _fit
	var fondo := ColorRect.new(); fondo.color = Color(0.12, 0.10, 0.09); fondo.size = Vector2(tam); vp.add_child(fondo)
	var lam := TextureRect.new(); lam.texture = load("res://art/ui/grimorio_bosque.png"); lam.stretch_mode = TextureRect.STRETCH_SCALE
	lam.position = _origen; lam.size = LIBRO["tam"] * _fit; vp.add_child(lam)
	var tinta := TintaPluma2D.new(); vp.add_child(tinta)
	var mano := ManoPluma3D.new(); mano.escala = _fit; vp.add_child(mano)
	await _pasos(vp, mano, 3)
	var casos: Array = [
		["hueco", Vector2(305.4, 578.7), true], ["sello", Vector2(433.7, 383.1), true],
		["sello_der", Vector2(838.3, 276.8), true], ["levantada", Vector2(431.4, 628.1), false]]
	for c in casos:
		var p: Vector2 = _pag(c[1])
		tinta.limpiar()
		# un trazo corto que termina en el punto, para ver tinta + mano
		var t0: float = 0.0
		for i in 12:
			var q: Vector2 = p + Vector2(-60 + 5 * i, 14.0 * sin(float(i) * 0.7)) * _fit
			mano.apuntar(q, c[2]); await _pasos(vp, mano, 2)
			if c[2]: tinta.anadir(mano.punta(), t0); t0 += 0.03
		for i in 12:
			mano.apuntar(p, c[2]); await process_frame
		if c[2]: tinta.anadir(mano.punta(), t0)
		await _pasos(vp, mano, 6)
		vp.get_texture().get_image().save_png("%s_%s.png" % [salida, c[0]])
		print("%s  punto pantalla=%s  punta=%s" % [c[0], p, mano.punta()])
	quit()

func _pag(p: Vector2) -> Vector2:
	return _origen + p * _fit

func _pasos(_vp: SubViewport, mano: Node, n: int) -> void:
	for _i in n:
		await process_frame
