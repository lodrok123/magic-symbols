class_name Zonas3D
extends Node
## ZONAS POR ÁREA (bloque 3 de la revisión EoW, 23/10): cada rectángulo del mapa lleva su luz (una fila de `LuzZona3D.ZONAS`) y, si se
## quiere, su cámara (zoom y tilt-shift). Al cruzar de una a otra, la luz se mezcla en `T_CAMBIO` s; no hay salto.
##
## POR QUÉ. En EoW el ÁREA elige el preset de luz, cámara y ambiente, con independencia de la sala (`PlayRegionCamera`, las regiones `_Top`,
## `_TopWater`, `_SideDark`…: docs/estudios/eow/EOW_2_NIVELES.md §1.4 y §7.10). Hasta ahora la maqueta ponía UNA zona para todo el nivel.
##
## DÓNDE SE DECLARAN. En el mapa del nivel (`mundo/datos_nivel/mapas/<nivel>.txt`), una línea por zona:
##   ; zona <x0>,<y0>..<x1>,<y1> <luz> [zoom=<tamaño de cámara>] [tilt=si|no]
## <luz> es un nombre de `LuzZona3D.ZONAS` (bosque, agua, fuego, ruinas, hielo, atardecer, clasico). Si dos zonas se pisan, manda la
## ÚLTIMA declarada. Fuera de todas, la `zona_luz` de la escena. Desde código: `agregar(rect, luz, opciones)`.
##   · zoom: al entrar, la cámara va a ese tamaño; al salir de todas las zonas con zoom, vuelve al que tenía el jugador.
##   · tilt: enciende o apaga la banda de tilt-shift mientras se está dentro.
## Un mapa sin líneas `; zona` no cambia nada.

signal zona_cambio(luz: String)

const T_CAMBIO: float = 1.5             ## s que tarda la luz en pasar de una zona a otra
const T_ZOOM: float = 1.0
const RUTA_MAPA: String = "res://mundo/datos_nivel/mapas/%s.txt"

var zonas: Array = []                   ## {rect: Rect2i, luz: String, zoom: float (0 = no toca), tilt: int (-1 no toca, 0 no, 1 sí)}
var avisos: Array = []
var actual: Dictionary = {}             ## la zona en la que está el jugador ({} = ninguna: la de la escena)
var _m: Node3D = null
var _defecto: String = "bosque"
var _desde: Dictionary = {}
var _hacia: Dictionary = {}
var _hacia_luz: String = ""
var _t: float = 1.0
var _zoom_jugador: float = -1.0
var _tilt_escena: bool = false
var _tw_zoom: Tween = null


## Lo cuelga de la maqueta, lee las zonas de su mapa y arranca en la zona de la escena. Devuelve el nodo.
static func montar(maqueta: Node3D) -> Zonas3D:
	var z := Zonas3D.new()
	z.name = "Zonas3D"
	z._m = maqueta
	z._defecto = String(maqueta.get("zona_luz"))
	z._tilt_escena = bool(maqueta.get("tilt_shift"))
	z.leer(String(maqueta.get("nivel")))
	maqueta.add_child(z)
	return z


## Lee las líneas `; zona` del mapa `nivel`. Las malas avisan (en `avisos` y por consola) y las demás siguen.
func leer(nivel: String) -> void:
	var ruta: String = RUTA_MAPA % nivel
	if not FileAccess.file_exists(ruta):
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return
	leer_texto(f.get_as_text())


## Lo mismo que `leer`, sobre el texto de un mapa (las pruebas lo usan sin archivo).
func leer_texto(texto: String) -> void:
	var n: int = 0
	for bruta in texto.split("\n"):
		var linea: String = bruta.strip_edges()
		n += 1
		if not linea.begins_with(";"):
			continue
		var partes: PackedStringArray = linea.substr(1).strip_edges().split(" ", false)
		if partes.size() < 3 or partes[0] != "zona":
			continue
		var rect: Rect2i = _rect(partes[1])
		var luz: String = partes[2]
		if rect.size.x <= 0 or not LuzZona3D.ZONAS.has(luz):
			_avisar("línea %d: «%s» (zona <x0>,<y0>..<x1>,<y1> <luz>; luces: %s)" % [n, linea, ", ".join(LuzZona3D.ZONAS.keys())])
			continue
		var op: Dictionary = {}
		for i in range(3, partes.size()):
			var kv: PackedStringArray = partes[i].split("=")
			if kv.size() == 2:
				op[kv[0]] = kv[1]
		agregar(rect, luz, op)


## Añade una zona. `opciones`: zoom (número) y tilt (si/no), como en el mapa.
func agregar(rect: Rect2i, luz: String, opciones: Dictionary = {}) -> void:
	var tilt: int = -1
	if opciones.has("tilt"):
		tilt = 1 if String(opciones["tilt"]) in ["si", "sí", "true", "1"] else 0
	zonas.append({"rect": rect, "luz": luz, "zoom": float(opciones.get("zoom", 0.0)), "tilt": tilt})


## La zona que manda en la casilla `c` ({} = ninguna). Si se pisan, la última declarada.
func zona_en(c: Vector2i) -> Dictionary:
	for i in range(zonas.size() - 1, -1, -1):
		if (zonas[i]["rect"] as Rect2i).has_point(c):
			return zonas[i]
	return {}


func _ready() -> void:
	_hacia_luz = _defecto
	_hacia = LuzZona3D.valores(_defecto)
	_desde = _hacia
	_t = 1.0


func _process(delta: float) -> void:
	if zonas.is_empty() or _m == null or not is_instance_valid(_m):
		return
	var pj: Node3D = _m.get("_jugador") as Node3D
	if pj == null:
		return
	var z: Dictionary = zona_en(Terreno3D.celda_de(pj.position))
	if z != actual:
		_entrar(z)
	if _t < 1.0:
		_t = minf(_t + delta / T_CAMBIO, 1.0)
		var s: float = smoothstep(0.0, 1.0, _t)
		LuzZona3D.aplicar_valores(_m.get("_env") as Environment, _m.get("_sol") as DirectionalLight3D, LuzZona3D.mezclar(_desde, _hacia, s))
		if _t >= 1.0:
			LuzZona3D.aplicar_sombra(_m.get("_sol") as DirectionalLight3D, _hacia_luz)


func _entrar(z: Dictionary) -> void:
	var antes: Dictionary = actual
	actual = z
	var luz: String = String(z.get("luz", _defecto))
	if luz != _hacia_luz:
		# Desde donde esté AHORA (a mitad de otro cambio, si lo hay), hacia la luz nueva.
		_desde = LuzZona3D.mezclar(_desde, _hacia, smoothstep(0.0, 1.0, _t))
		_hacia = LuzZona3D.valores(luz)
		_hacia_luz = luz
		_t = 0.0
		zona_cambio.emit(luz)
	# Cámara: el zoom de la zona, o de vuelta al del jugador al salir de las zonas con zoom.
	var zoom: float = float(z.get("zoom", 0.0))
	var zoom_antes: float = float(antes.get("zoom", 0.0))
	if zoom > 0.0:
		if zoom_antes <= 0.0:
			_zoom_jugador = float(_m.get("_tam_camara"))
		_zoom_a(zoom)
	elif zoom_antes > 0.0 and _zoom_jugador > 0.0:
		_zoom_a(_zoom_jugador)
	var tilt: int = int(z.get("tilt", -1))
	_poner_tilt(_tilt_escena if tilt < 0 else tilt == 1)


func _zoom_a(tam: float) -> void:
	if _tw_zoom != null and _tw_zoom.is_valid():
		_tw_zoom.kill()
	_tw_zoom = create_tween()
	_tw_zoom.tween_method(_poner_zoom, float(_m.get("_tam_camara")), tam, T_ZOOM).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _poner_zoom(v: float) -> void:
	_m.set("_tam_camara", v)
	var cam: Camera3D = _m.get("_camara") as Camera3D
	if cam != null:
		cam.size = v


func _poner_tilt(si: bool) -> void:
	if bool(_m.get("tilt_shift")) == si:
		return
	_m.set("tilt_shift", si)
	var t: Object = _m.get("_tilt")
	if t != null:
		t.set("encendido", si)


func _rect(s: String) -> Rect2i:
	var ab: PackedStringArray = s.split("..")
	if ab.size() != 2:
		return Rect2i()
	var a: PackedStringArray = ab[0].split(",")
	var b: PackedStringArray = ab[1].split(",")
	if a.size() != 2 or b.size() != 2 or not (a[0].is_valid_int() and a[1].is_valid_int() and b[0].is_valid_int() and b[1].is_valid_int()):
		return Rect2i()
	var x0: int = mini(a[0].to_int(), b[0].to_int())
	var y0: int = mini(a[1].to_int(), b[1].to_int())
	return Rect2i(x0, y0, absi(b[0].to_int() - a[0].to_int()) + 1, absi(b[1].to_int() - a[1].to_int()) + 1)


func _avisar(t: String) -> void:
	avisos.append(t)
	push_warning("Zonas3D: " + t)
