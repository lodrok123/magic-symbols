extends SceneTree

## SOLO CAPTURA (5/11/2026): cómo se ven los iconos de la lámina de inventario en la bolsa (con ventana, sin --headless):
##   godot --path . --script res://herramientas/captura_iconos_inventario.gd -- <prefijo_salida>
## Escribe <prefijo>_bolsa.png (la bolsa con 20 de los objetos, y el detalle de uno), <prefijo>_avisos.png (los 24 en el icono del aviso, 40 px, y ampliados ×3).

const IDS: Array = [
	"resina", "corteza", "panal", "pluma", "seda", "carbon",
	"jiron_escudo", "gota_veneno", "obsidiana", "polvo_cristal", "ceniza_geoda", "cristal_cargado",
	"baba_limo", "pluma_chaman", "cristal_tierra", "pocion", "antidoto", "frescor", "abrigo",
	"pigmento_carmesi", "pigmento_ocre", "pigmento_musgo", "pigmento_ambar", "pigmento_eco",
]


func _initialize() -> void:
	_correr()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var pref: String = a[0] if a.size() > 0 else "res://docs/capturas/iconos_inventario"
	root.size = Vector2i(1280, 720)
	await _frames(3)
	# --- la bolsa ---
	Estado.nuevo()
	var e: Estado = Estado.i()
	e.capacidad = 20
	for k in range(20):
		e.agregar(IDS[k], 3 + k % 5)
	var fondo := ColorRect.new()
	fondo.color = Color(0.16, 0.2, 0.17)
	fondo.size = Vector2(1280, 720)
	root.add_child(fondo)
	var b := BolsaUI.new()
	root.add_child(b)
	b.alternar()
	await _frames(20)
	root.get_viewport().get_texture().get_image().save_png(pref + "_bolsa.png")
	print("foto bolsa")
	b.queue_free()
	await _frames(2)
	# --- los avisos ---
	var tira := Control.new()
	tira.size = Vector2(1280, 720)
	root.add_child(tira)
	for i in range(IDS.size()):
		var ic := MarcoCalidad.Icono.new()
		ic.configurar(IDS[i])
		ic.position = Vector2(20 + (i % 12) * 52, 20 + (i / 12) * 52)
		tira.add_child(ic)
		var grande := MarcoCalidad.Icono.new()
		grande.configurar(IDS[i])
		grande.scale = Vector2(3, 3)
		grande.position = Vector2(20 + (i % 8) * 150, 150 + (i / 8) * 150)
		tira.add_child(grande)
	await _frames(20)
	root.get_viewport().get_texture().get_image().save_png(pref + "_avisos.png")
	print("foto avisos")
	quit(0)
