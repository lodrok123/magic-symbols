extends SceneTree

## PRUEBA DE LOS ICONOS DE LA LÁMINA DE INVENTARIO (5/11/2026), sin ventana. `godot --headless --path . --script res://herramientas/prueba_iconos_inventario.gd`.
## Los 24 PNG de `arte/iconos/<id>.png` (recortados por `herramientas/recortar_lamina_iconos.py`): cada ID existe en el catálogo `Objetos` (con nombre, descripción propia y
## categoría), su PNG carga y es de 256×256 con fondo transparente y margen, `Objetos.icono` lo reduce al tamaño de caché y `Objetos.tiene_icono` lo ve. El único objeto NUEVO es
## `gota_veneno`; los otros 23 ya existían.

const IDS: Array = [
	"resina", "corteza", "panal", "pluma", "seda", "carbon",
	"jiron_escudo", "gota_veneno", "obsidiana", "polvo_cristal", "ceniza_geoda", "cristal_cargado",
	"baba_limo", "pluma_chaman", "cristal_tierra", "pocion", "antidoto", "frescor", "abrigo",
	"pigmento_carmesi", "pigmento_ocre", "pigmento_musgo", "pigmento_ambar", "pigmento_eco",
]
const NUEVOS: Array = ["gota_veneno"]

var fallos: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)


func _init() -> void:
	print("== Catálogo")
	_ok(IDS.size() == 24, "la lámina trae 24 objetos")
	var sin_id: PackedStringArray = []
	var sin_nombre: PackedStringArray = []
	var sin_texto: PackedStringArray = []
	for id in IDS:
		if not Objetos.existe(id):
			sin_id.append(id)
			continue
		if Objetos.nombre(id) == id or Objetos.nombre(id).strip_edges() == "":
			sin_nombre.append(id)
		if TextosObjetos.descripcion(id).strip_edges().length() < 15:
			sin_texto.append(id)
	_ok(sin_id.is_empty(), "los 24 IDs están en el catálogo de Objetos (faltan: %s)" % ", ".join(sin_id))
	_ok(sin_nombre.is_empty(), "los 24 tienen nombre (sin nombre: %s)" % ", ".join(sin_nombre))
	_ok(sin_texto.is_empty(), "los 24 tienen descripción propia en TextosObjetos (sin: %s)" % ", ".join(sin_texto))
	var repetidos: Dictionary = {}
	for id in IDS:
		repetidos[id] = true
	_ok(repetidos.size() == IDS.size(), "ningún ID se repite")
	for id in NUEVOS:
		_ok(Objetos.existe(id) and Objetos.DATOS[id]["categoria"] == "animal" and Objetos.etiquetas(id).has("toxico") and Objetos.es_ingrediente(id),
			"%s es un objeto nuevo: material de receta con la etiqueta toxico" % id)
		_ok(not Objetos.es_consumible(id), "%s no es consumible (sin efecto jugable)" % id)

	print("== Iconos")
	var mal_carga: PackedStringArray = []
	var mal_tam: PackedStringArray = []
	var mal_alfa: PackedStringArray = []
	var mal_margen: PackedStringArray = []
	var mal_cache: PackedStringArray = []
	for id in IDS:
		if not Objetos.tiene_icono(id):
			mal_carga.append(id)
			continue
		var t: Texture2D = Objetos.icono(id)
		if t == null:
			mal_carga.append(id)
			continue
		if t.get_width() != 256 or t.get_height() != 256:
			mal_tam.append("%s %dx%d" % [id, t.get_width(), t.get_height()])
		var img: Image = t.get_image()
		var cubre: int = 0
		var borde_opaco: int = 0
		for y in range(256):
			for x in range(256):
				var a: float = img.get_pixel(x, y).a
				if a > 0.5:
					cubre += 1
				if a > 0.05 and (x < 6 or y < 6 or x > 249 or y > 249):
					borde_opaco += 1
		var frac: float = float(cubre) / 65536.0
		if frac < 0.2 or frac > 0.9 or img.get_pixel(0, 0).a > 0.01 or img.get_pixel(255, 255).a > 0.01:
			mal_alfa.append("%s %.2f" % [id, frac])
		if borde_opaco > 0:
			mal_margen.append(id)
		var pequeno: Texture2D = Objetos.icono(id, 40.0)
		if pequeno == null or pequeno.get_width() != 64:
			mal_cache.append(id)
	_ok(mal_carga.is_empty(), "los 24 PNG de arte/iconos/ cargan (fallan: %s)" % ", ".join(mal_carga))
	_ok(mal_tam.is_empty(), "todos miden 256×256 (%s)" % ", ".join(mal_tam))
	_ok(mal_alfa.is_empty(), "fondo transparente en las esquinas y el objeto cubre entre el 20 y el 90 %% (%s)" % ", ".join(mal_alfa))
	_ok(mal_margen.is_empty(), "ninguno toca el borde del lienzo: hay margen (%s)" % ", ".join(mal_margen))
	_ok(mal_cache.is_empty(), "a 40 px se usa la copia reducida de 64 (%s)" % ", ".join(mal_cache))
	_ok(not Objetos.tiene_icono("seta_roja_inexistente") and Objetos.icono("seta_roja_inexistente") == null, "un id sin PNG no tiene icono (cae al dibujo en código)")
	_ok(Objetos.icono("pocion", 40.0) == Objetos.icono("pocion", 50.0), "la copia reducida se reutiliza (una sola reducción por tamaño)")

	print("== Recetas")
	var f: FileAccess = FileAccess.open("res://nucleo/datos/recetas.tsv", FileAccess.READ)
	var recetas_con_icono: int = 0
	if f != null:
		f.get_line()
		while not f.eof_reached():
			var c: PackedStringArray = f.get_line().split("\t")
			if c.size() < 7:
				continue
			var da: String = c[6].split(":")[0]
			var ancla: String = c[4]
			if IDS.has(da) or IDS.has(ancla):
				recetas_con_icono += 1
	_ok(recetas_con_icono >= 9, "las recetas (da o ancla) usan al menos 9 de estos IDs: %d" % recetas_con_icono)
	for id in ["pocion", "antidoto", "frescor", "abrigo", "pigmento_carmesi", "pigmento_ocre", "pigmento_musgo", "pigmento_ambar", "pigmento_eco"]:
		_ok(Objetos.es_consumible(id) or Objetos.categoria_bd(id) == "pigmento", "%s sigue siendo el consumible/pigmento de la receta" % id)

	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)
