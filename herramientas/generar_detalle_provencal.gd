extends SceneTree

## Genera los mapas de DETALLE EN GRIS (albedo _B) y las NORMALES aplanadas (_N) de arte/provencal/detalle/ a partir de los TGA del pack Fantasy Provencal (Leartes Studios).
## Los TGA no estan en el repo: se pasan por argumento. Lo lanza `tools/generar_detalle_provencal.py` (que busca Godot y pone las rutas); a mano:
##   godot --headless --path . --script res://herramientas/generar_detalle_provencal.gd -- <carpeta con los TGA> <carpeta de salida>
## Formula general (la de todas las texturas salvo las de VENTANAS): d = 1 + K·(L − media)/media, recortado a [0,4 ; 1,25]; se guarda d/1,25 (el material multiplica el color por 1,25).
## VENTANAS: el vidrio y los parteluces son claros y esa formula los recortaba a blanco: se ESTIRA a su propio rango (percentiles 2 y 98 de L) alrededor de la media, sin recortar:
##   d = 1 + s·(L − media), con s = min(K_VENTANA / media, (1,25 − 1) / (p98 − media), (1 − 0,4) / (media − p2)).
## Los albedos con alfa (hojas, aspas, calcomanias) guardan el alfa binario (>= 128). Las normales se aplanan al 50 %.

const K: float = 0.6
const TOPE: float = 1.25
const SUELO: float = 0.4
const FUERZA_NORMAL: float = 0.5
const K_VENTANA: float = 1.2                  ## contraste (K) de las ventanas; el estirado lo limita si hiciera falta recortar
const VENTANAS: Array = ["T_Windows_B"]
const ALBEDOS: Array = ["T_Atlas_House_B","T_Barrel_Jar_B","T_Cart_B","T_Crates_B","T_Flora_Atlas_01_B","T_Flora_Atlas_02_B","T_Flower_Pot_B","T_Decals_B","T_Plaster_B","T_Rocks_Cliff_B","T_Rocks_B","T_Rocks_Bricks_B","T_Rock_Walls_B","T_RoofTileMeshes_01_B","T_RoofTiles_01_B","T_Shrine_Candle_B","T_TunnelProps_B","T_WaterMill_Wheel_B","T_WindMill_B","T_Windows_B","T_WoodTrunk_B","T_WoodenMeshes_B"]
const NORMALES: Array = ["T_Atlas_House_N","T_Barrel_Jar_N","T_Cart_N","T_Crates_N","T_Plaster_N","T_Rocks_Cliff_N","T_Rocks_N","T_Rocks_Bricks_N","T_Rock_Walls_N","T_RoofTileMeshes_N","T_RoofTiles_Normal","T_Shrine_Candle_N","T_TunnelProps_N","T_WaterMill_Wheel_N","T_WindMill_N","T_Windows_N","T_WoodTrunk_N","T_WoodenMeshes_N","T_Decals_N","T_Flower_Pot_N"]

var _tga: String = ""
var _salida: String = ""


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 2:
		print("FALLO  uso: -- <carpeta con los TGA> <carpeta de salida>")
		quit(2)
		return
	_tga = a[0].rstrip("/\\") + "/"
	_salida = a[1].rstrip("/\\") + "/"
	DirAccess.make_dir_recursive_absolute(_salida)
	for s in ALBEDOS:
		_albedo(s)
	for s in NORMALES:
		_normal(s)
	quit()


func _cargar(s: String) -> Image:
	var im := Image.load_from_file(_tga + s + ".tga")
	if im == null:
		print("FALLO sin ", s)
		return null
	im.convert(Image.FORMAT_RGBA8)
	var lado: int = 512 if im.get_width() <= 1024 else 1024
	if im.get_width() != lado or im.get_height() != lado:
		im.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
	return im


func _albedo(s: String) -> void:
	var im: Image = _cargar(s)
	if im == null:
		return
	var d: PackedByteArray = im.get_data()
	var n: int = d.size() / 4
	var suma: float = 0.0
	var vivos: int = 0
	var lum := PackedFloat32Array()
	lum.resize(n)
	var vivas := PackedFloat32Array()
	var ventana_pre: bool = VENTANAS.has(s)
	for i in n:
		var l: float = (0.2126 * d[i * 4] + 0.7152 * d[i * 4 + 1] + 0.0722 * d[i * 4 + 2]) / 255.0
		lum[i] = l
		if d[i * 4 + 3] >= 128:
			suma += l
			vivos += 1
			if ventana_pre:
				vivas.append(l)
	var media: float = maxf(suma / maxf(vivos, 1), 0.01)
	var ventana: bool = VENTANAS.has(s)
	var escala: float = 0.0
	if ventana:
		vivas.sort()
		var p2: float = vivas[int(0.02 * (vivas.size() - 1))]
		var p98: float = vivas[int(0.98 * (vivas.size() - 1))]
		escala = K_VENTANA / media
		if p98 - media > 0.0001:
			escala = minf(escala, (TOPE - 1.0) / (p98 - media))
		if media - p2 > 0.0001:
			escala = minf(escala, (1.0 - SUELO) / (media - p2))
		print("VENTANA ", s, " media=", snappedf(media, 0.001), " p2=", snappedf(p2, 0.001), " p98=", snappedf(p98, 0.001), " K efectivo=", snappedf(escala * media, 0.01))
	var recorte: bool = float(vivos) / float(n) < 0.97
	var salida := PackedByteArray()
	salida.resize(n * (2 if recorte else 1))
	for i in n:
		var v: float = (clampf(1.0 + escala * (lum[i] - media), SUELO, TOPE) if ventana else clampf(1.0 + K * (lum[i] - media) / media, SUELO, TOPE)) / TOPE
		if recorte:
			salida[i * 2] = int(round(v * 255.0))
			salida[i * 2 + 1] = 255 if d[i * 4 + 3] >= 128 else 0
		else:
			salida[i] = int(round(v * 255.0))
	var out := Image.create_from_data(im.get_width(), im.get_height(), false, Image.FORMAT_LA8 if recorte else Image.FORMAT_L8, salida)
	out.save_png(_salida + s + ".png")
	print("ALBEDO ", s, " ", im.get_width(), " media_lum=", snappedf(media, 0.001), " opaco=", snappedf(100.0 * vivos / n, 0.1), "% ", "RECORTE" if recorte else "")


func _normal(s: String) -> void:
	var im: Image = _cargar(s)
	if im == null:
		return
	var d: PackedByteArray = im.get_data()
	var n: int = d.size() / 4
	var salida := PackedByteArray()
	salida.resize(n * 3)
	for i in n:
		for c in 3:
			var v: float = d[i * 4 + c] / 255.0
			var plano: float = 1.0 if c == 2 else 0.5
			salida[i * 3 + c] = int(round(lerpf(plano, v, FUERZA_NORMAL) * 255.0))
	Image.create_from_data(im.get_width(), im.get_height(), false, Image.FORMAT_RGB8, salida).save_png(_salida + s + ".png")
	print("NORMAL ", s, " ", im.get_width())
