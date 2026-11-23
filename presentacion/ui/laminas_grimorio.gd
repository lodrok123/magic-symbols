extends RefCounted

## LÁMINAS TOON DEL LIBRO AVANZADO (dos círculos de dibujo abajo). Las medidas se tomaron en `LabLibroAvanzado` (F1–F5) sobre los PNG de 1536 × 1024.
## Desde el 12/11 (Pablo: «sería esta [la azul] pero también usa la versión verde y roja») el JUEGO las usa como lámina oficial: `Spellbook._libro()` pide
## `oficial(Equipo3D.nivel_grimorio)` y el libro de la página va a juego con el libro 3D del cinto (`arte/equipo/grimorio_1..3.glb`):
##   1 = botánico (verde, un medallón de sello) · 2 = azul (rúnico, dos medallones) · 3 = rojo (legendario, dos medallones).
## Esas tres viven en `art/ui/grimorio_toon_*.png`; las dos de un sello rojo/azul siguen en `docs/diseno_grimorios/toon/` solo para el laboratorio.

const CARPETA: String = "res://docs/diseno_grimorios/toon/"
const NOMBRES: Array[String] = ["Botánico · 1 sello", "Rojo · 1 sello", "Rojo · 2 sellos", "Azul · 1 sello", "Azul · 2 sellos"]

## Índice de `LAMINAS` que lleva cada nivel de grimorio (`Equipo3D.nivel_grimorio`). Un nivel que no esté aquí usa el 2 (azul).
const POR_NIVEL: Dictionary = {1: 0, 2: 4, 3: 2}
const NIVEL_POR_DEFECTO: int = 2

# Coordenadas medidas en los PNG originales (1536 × 1024).
# Corona en orden horario a partir del hueco de arriba.
# `ruta` = dónde está el PNG cuando no es la carpeta de revisión (las tres oficiales, en art/ui).
const LAMINAS: Array[Dictionary] = [
	{"archivo": "botanico-1-sello", "ruta": "res://art/ui/grimorio_toon_botanico.png", "sello": Vector3(321, 637, 89), "glifo": Vector3(572, 633, 117),
		"medallones": [Vector2(441, 318)], "radio_med": 60, "centro": Vector2(441, 318),
		"corona": [Vector2(441, 181), Vector2(560, 247), Vector2(560, 383), Vector2(441, 454), Vector2(324, 383), Vector2(324, 247)],
		"sellos_x": [896, 1009, 1123, 1237], "sellos_y": [226, 343], "glifos_x": [928, 1069, 1211], "glifos_y": [487, 610, 734],
		"hoja": Rect2(190, 123, 1156, 690)},
	{"archivo": "rojo-1-sello", "sello": Vector3(311, 627, 97), "glifo": Vector3(574, 622, 126),
		"medallones": [Vector2(438, 300)], "radio_med": 46, "centro": Vector2(438, 300),
		"corona": [Vector2(439, 157), Vector2(563, 230), Vector2(563, 370), Vector2(439, 439), Vector2(314, 370), Vector2(314, 230)],
		"sellos_x": [896, 1014, 1131, 1249], "sellos_y": [213, 334], "glifos_x": [933, 1070, 1208], "glifos_y": [477, 600, 726],
		"hoja": Rect2(178, 116, 1170, 693)},
	{"archivo": "rojo-2-sellos", "ruta": "res://art/ui/grimorio_toon_rojo.png", "sello": Vector3(316, 621, 87), "glifo": Vector3(569, 620, 109),
		"medallones": [Vector2(373, 299), Vector2(489, 299)], "radio_med": 32, "centro": Vector2(431, 299),
		"corona": [Vector2(430, 151), Vector2(565, 220), Vector2(563, 374), Vector2(431, 446), Vector2(298, 374), Vector2(298, 220)],
		"sellos_x": [918, 1031, 1144, 1257], "sellos_y": [211, 331], "glifos_x": [952, 1087, 1223], "glifos_y": [486, 610, 735],
		"hoja": Rect2(171, 110, 1196, 694)},
	{"archivo": "azul-1-sello", "sello": Vector3(336, 650, 92), "glifo": Vector3(594, 649, 112),
		"medallones": [Vector2(470, 328)], "radio_med": 80, "centro": Vector2(470, 328),
		"corona": [Vector2(471, 164), Vector2(602, 238), Vector2(602, 413), Vector2(471, 485), Vector2(340, 414), Vector2(339, 238)],
		"sellos_x": [899, 1003, 1108, 1212], "sellos_y": [214, 326], "glifos_x": [920, 1058, 1196], "glifos_y": [471, 601, 733],
		"hoja": Rect2(190, 118, 1152, 704)},
	{"archivo": "azul-2-sellos", "ruta": "res://art/ui/grimorio_toon_azul.png", "sello": Vector3(329, 646, 91), "glifo": Vector3(605, 646, 118),
		"medallones": [Vector2(404, 318), Vector2(534, 318)], "radio_med": 48, "centro": Vector2(469, 318),
		"corona": [Vector2(470, 156), Vector2(612, 225), Vector2(611, 403), Vector2(469, 476), Vector2(327, 401), Vector2(328, 225)],
		"sellos_x": [905, 1016, 1126, 1235], "sellos_y": [216, 332], "glifos_x": [938, 1074, 1210], "glifos_y": [478, 608, 739],
		"hoja": Rect2(189, 118, 1158, 708)},
]


## La lámina OFICIAL del juego para un nivel de grimorio (ver POR_NIVEL), o {} si su PNG no está.
static func oficial(nivel: int) -> Dictionary:
	return cargar(int(POR_NIVEL.get(nivel, POR_NIVEL[NIVEL_POR_DEFECTO])))


## Cuántos medallones de sello (sellos por página) trae la lámina oficial de un nivel: 1 en la botánica, 2 en la azul y la roja.
static func sellos_oficiales(nivel: int) -> int:
	var datos: Dictionary = LAMINAS[int(POR_NIVEL.get(nivel, POR_NIVEL[NIVEL_POR_DEFECTO]))]
	return (datos["medallones"] as Array).size()


static func cargar(indice: int) -> Dictionary:
	var datos: Dictionary = LAMINAS[indice]
	var ruta: String = String(datos.get("ruta", CARPETA + String(datos["archivo"]) + ".png"))
	var arte: Texture2D
	if ResourceLoader.exists(ruta):
		arte = load(ruta) as Texture2D
	else:
		# Permite abrir el laboratorio directamente antes de importar desde el editor.
		var imagen := Image.load_from_file(ruta)
		if imagen != null:
			arte = ImageTexture.create_from_image(imagen)
	if arte == null:
		push_error("No se pudo cargar la lámina del laboratorio: " + ruta)
		return {}
	var centro: Vector2 = datos["centro"]
	return {
		"arte": arte, "medidas": arte.get_size(), "contorno_hoja": datos["hoja"],
		"aros_impresos": true,                 # el arte trae pintados el círculo mágico, los medallones, la corona y las dos zonas: el código no los repinta
		"nombre": NOMBRES[indice],
		"bloque": Rect2(42, 0, 1452, 1000), "centro": centro, "radio": 150.0,
		"nucleo": 120.0, "guias": false, "pestanas": Vector2(593, 142),
		"leyenda_sellos": _rejilla(datos["sellos_x"], datos["sellos_y"]),
		"leyenda": _rejilla(datos["glifos_x"], datos["glifos_y"]),
		"sello_tam": 54.0, "glifo_tam": 49.0,
		"avanzado": {
			"circulo": {"centro": centro, "radio": 150.0},
			"medallones": datos["medallones"], "medallon_radio": datos["radio_med"],
			"huecos": datos["corona"], "hueco_radio": 28.0,
			"zona_sellos": _zona(datos["sello"]), "zona_glifos": _zona(datos["glifo"]),
			"pista_y": 798.0,
		},
	}


static func _zona(circulo: Vector3) -> Dictionary:
	return {"centro": Vector2(circulo.x, circulo.y), "radio": circulo.z}


static func _rejilla(columnas: Array, filas: Array) -> Array:
	var centros: Array[Vector2] = []
	for y in filas:
		for x in columnas:
			centros.append(Vector2(x, y))
	return centros
