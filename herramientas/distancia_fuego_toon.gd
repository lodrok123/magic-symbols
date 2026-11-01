extends SceneTree

## DISTANCIA DE ASPECTO DEL FUEGO (1/11, prueba 2, ronda 2): compara la franja de fuego de una captura con la de `ref_muro.jpg` por histograma de tono × valor (8 × 8 celdas)
## sobre los píxeles «de fuego» (saturación > 0,4). Distancia = suma de |diferencias| de los histogramas normalizados: 0 = igual, 2 = nada en común. Sin ventana:
##   godot --headless --path . --script res://herramientas/distancia_fuego_toon.gd -- <captura.png> <x> <y> <ancho> <alto>
## Sin argumentos mide las capturas por defecto de docs/capturas/comparativa_vfx/godot_toon/ (muro_cerca_r1, muro_cerca, juego_muro) con sus rectángulos.
## Límite honesto: la referencia tiene hierba naranja detrás que también cuenta como «fuego» (saturación alta), y la captura propia lleva chispas y humo en su rectángulo.

const REFERENCIA: String = "res://docs/capturas/comparativa_vfx/referencia/ref_muro.jpg"
const RECT_REF: Rect2i = Rect2i(0, 270, 883, 110)
const SAT_MIN: float = 0.4
const CELDAS_TONO: int = 8
const CELDAS_VALOR: int = 8
const DIR: String = "res://docs/capturas/comparativa_vfx/godot_toon/"
## nombre -> rectángulo del muro en la captura de 1600 × 1000
const CAPTURAS: Dictionary = {
	"muro_cerca_r1.png": Rect2i(220, 200, 1380, 800),
	"muro_cerca.png": Rect2i(220, 200, 1380, 800),
	"juego_muro.png": Rect2i(220, 140, 1160, 250),
}


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var ref: Image = Image.load_from_file(ProjectSettings.globalize_path(REFERENCIA))
	if ref == null:
		print("no se lee la referencia")
		quit(1)
		return
	var h_ref: PackedFloat32Array = _histograma(ref, RECT_REF)
	print("referencia: %d píxeles de fuego en %s" % [_cuenta(ref, RECT_REF), str(RECT_REF)])
	print("  reparto de la referencia por valor (claro a oscuro): " + _por_valor(h_ref))
	if a.size() >= 5:
		var img: Image = Image.load_from_file(a[0])
		var r: Rect2i = Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
		print("%s: distancia %.3f   reparto por valor: %s" % [a[0].get_file(), _distancia(h_ref, _histograma(img, r)), _por_valor(_histograma(img, r))])
	else:
		for n in CAPTURAS:
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(DIR + String(n)))
			if img == null:
				print("%s: no existe" % n)
				continue
			var h: PackedFloat32Array = _histograma(img, CAPTURAS[n])
			print("%s: distancia %.3f   reparto por valor: %s" % [n, _distancia(h_ref, h), _por_valor(h)])
	quit()


func _cuenta(img: Image, r: Rect2i) -> int:
	var n: int = 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			if img.get_pixel(x, y).s > SAT_MIN:
				n += 1
	return n


func _histograma(img: Image, r: Rect2i) -> PackedFloat32Array:
	var h: PackedFloat32Array = PackedFloat32Array()
	h.resize(CELDAS_TONO * CELDAS_VALOR)
	var total: float = 0.0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			var c: Color = img.get_pixel(x, y)
			if c.s <= SAT_MIN:
				continue
			var it: int = clampi(int(c.h * CELDAS_TONO), 0, CELDAS_TONO - 1)
			var iv: int = clampi(int(c.v * CELDAS_VALOR), 0, CELDAS_VALOR - 1)
			h[it * CELDAS_VALOR + iv] += 1.0
			total += 1.0
	if total > 0.0:
		for i in h.size():
			h[i] /= total
	return h


func _distancia(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var d: float = 0.0
	for i in a.size():
		d += absf(a[i] - b[i])
	return d


## Reparto de los píxeles de fuego por valor (8 celdas), en %.
func _por_valor(h: PackedFloat32Array) -> String:
	var s: String = ""
	for iv in range(CELDAS_VALOR - 1, -1, -1):
		var t: float = 0.0
		for it in CELDAS_TONO:
			t += h[it * CELDAS_VALOR + iv]
		s += "%d " % int(round(t * 100.0))
	return s
