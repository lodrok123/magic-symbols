extends SceneTree
## Captura de la mano con pluma y la tinta sobre un pergamino (Fase 14.4). Uso: -- <prefijo>. Simula un trazo (una S) a 60 fps con el reloj de la mano.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefijo: String = args[0] if args.size() > 0 else "/tmp/cap_escritura"
	var fondo := ColorRect.new()
	fondo.color = Color("efe7d3")
	fondo.size = Vector2(1152, 648)
	root.add_child(fondo)
	var tinta := TintaPluma2D.new()
	root.add_child(tinta)
	var mano := ManoPluma2D.new()
	root.add_child(mano)
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	# Dos trazos: una S despacio y un rasgo rápido; se capturan tres momentos (escribiendo, soltando, levantada).
	var capturas: Array = []
	var pos := Vector2(300, 300)
	for i in 100:
		t += dt
		var k: float = float(i) / 99.0
		pos = Vector2(300 + 400.0 * k, 320.0 + 90.0 * sin(k * TAU * 1.0))
		mano.apuntar(pos, true, t)
		if i == 0:
			tinta.empezar(pos, t)
		else:
			tinta.anadir(mano.punta() if i > 5 else pos, t)
		await process_frame
		if i == 70:
			root.get_viewport().get_texture().get_image().save_png(prefijo + "_escribiendo.png")
	tinta.soltar()
	for i in 20:
		t += dt
		mano.apuntar(pos + Vector2(10.0 * i, -6.0 * i), false, t)
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefijo + "_levantada.png")
	quit()
