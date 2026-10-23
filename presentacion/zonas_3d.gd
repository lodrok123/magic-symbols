class_name Zonas3D
extends Node
## ZONAS POR ÁREA (bloque 3 de la revisión EoW, 23/10): cada rectángulo del mapa lleva su luz (una fila de `LuzZona3D.ZONAS`) y, si se
## quiere, su cámara (zoom y tilt-shift). Al cruzar de una a otra, la luz se mezcla en `T_CAMBIO` s; no hay salto.
##
## POR QUÉ. En EoW el ÁREA elige el preset de luz, cámara y ambiente, con independencia de la sala (`PlayRegionCamera`, las regiones `_Top`,
## `_TopWater`, `_SideDark`…: docs/estudios/eow/EOW_2_NIVELES.md §1.4 y §7.10). Hasta ahora la maqueta ponía UNA zona para todo el nivel.
##
## DÓNDE SE DECLARAN. En el mapa del nivel (`mundo/datos_nivel/mapas/<nivel>.txt`), una línea por zona:
##   ; zona <x0>,<y0>..<x1>,<y1> <luz> [zoom=<tamaño de cámara>] [tilt=si|no] [mezcla=<s>] [nombre=<id>] [rotulo=<texto>]
## <luz> es un nombre de `LuzZona3D.ZONAS` (bosque, agua, fuego, ruinas, hielo, atardecer, clasico, cueva, santuario). Si dos zonas se pisan, manda la
## ÚLTIMA declarada. Fuera de todas, la `zona_luz` de la escena. Desde código: `agregar(rect, luz, opciones)`.
##   · zoom: al entrar, la cámara va a ese tamaño; al salir de todas las zonas con zoom, vuelve al que tenía el jugador.
##   · tilt: enciende o apaga la banda de tilt-shift mientras se está dentro.
##   · mezcla: segundos que tarda la luz en cambiar AL ENTRAR en esta zona (0 = de golpe). Sin ella, `T_CAMBIO` (1,5 s, como siempre). Como en EoW: un exterior
##     entra despacio (5 s) y una sala deprisa (≤ 1 s). Al salir a la zona de la escena vale `T_CAMBIO`.
##   · nombre: cómo se llama la zona (letras, cifras, «_»). La usan el botín de los rompibles (`Rompible3D.BOTIN_ZONA`) y el diario (`PlayLog.zona`).
##     Sin ella, el nombre de la luz.
##   · id= y titulo= son otros nombres de nombre= y rotulo= (los usa el diseño del Bosque 01 v01). botin=<fila>: la fila de `Rompible3D.BOTIN_ZONA` que usan los rompibles de la zona.
##   · rotulo: texto que sale la PRIMERA vez que se entra (RotuloZona3D); las palabras van unidas con «_» (`rotulo=Bosque_de_la_Aurora`). «Ya visto» es la flag
##     `<nivel>.rotulo.<nombre o x0_y0>_visto`: persiste con el resto de flags, así que no se repite ni al volver ni al recargar.
## Un mapa sin líneas `; zona` no cambia nada.
## El diario: `PlayLog.zona` es el nombre de la zona donde está el jugador, y todo evento la lleva; al cruzar una zona sale el evento `zona` con `anterior` y `segundos`.

signal zona_cambio(luz: String)

const T_CAMBIO: float = 1.5             ## s que tarda la luz en pasar de una zona a otra (si la zona no dice `mezcla=`)
const T_ZOOM: float = 1.0
const T_MIN_MEZCLA: float = 0.0001      ## s: «de golpe» sin dividir por cero
const RUTA_MAPA: String = "res://mundo/datos_nivel/mapas/%s.txt"
const FLAG_ROTULO: String = "rotulo"    ## el trozo de en medio de `<nivel>.rotulo.<zona>_visto`

var zonas: Array = []                   ## {rect: Rect2i, luz: String, zoom: float (0 = no toca), tilt: int (-1 no toca, 0 no, 1 sí), mezcla: float (s), nombre: String, rotulo: String ("" = ninguno)}
var avisos: Array = []
var nombre_actual: String = ""          ## el nombre de la zona donde está el jugador (la de la escena si no hay ninguna): lo mismo que `PlayLog.zona`
var rotulos_mostrados: Array = []       ## los textos que ha sacado (las pruebas)
var actual: Dictionary = {}             ## la zona en la que está el jugador ({} = ninguna: la de la escena)
var _m: Node3D = null
var _defecto: String = "bosque"
var _desde: Dictionary = {}
var _hacia: Dictionary = {}
var _hacia_luz: String = ""
var _t: float = 1.0
var _dur: float = T_CAMBIO              ## lo que dura el cambio de luz en curso
var _desde_ms: int = 0                  ## cuándo entró en la zona de ahora (para el tiempo que se pasó en cada una)
var _nivel: String = ""
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
	z._nivel = String(maqueta.get("nivel"))
	z.leer(z._nivel)
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
			var kv: PackedStringArray = partes[i].split("=", true, 1)
			if kv.size() == 2:
				op[kv[0]] = kv[1]
		# Alias del diseño del Bosque 01 v01 (docs/PLAN_BOSQUE_01_V01.md): `id=` es `nombre=` y `titulo=` es `rotulo=`.
		if op.has("id") and not op.has("nombre"):
			op["nombre"] = op["id"]
		if op.has("titulo") and not op.has("rotulo"):
			op["rotulo"] = op["titulo"]
		if op.has("mezcla") and (not String(op["mezcla"]).is_valid_float() or float(op["mezcla"]) < 0.0):
			_avisar("línea %d: «%s» (mezcla=<segundos>, 0 o más; se usa %.1f)" % [n, linea, T_CAMBIO])
			op.erase("mezcla")
		if op.has("nombre") and not Puzle3D._id_valido(String(op["nombre"])):
			_avisar("línea %d: «%s» (nombre=<letras, cifras y «_»>; se usa el de la luz)" % [n, linea])
			op.erase("nombre")
		agregar(rect, luz, op)


## Añade una zona. `opciones`: zoom (número), tilt (si/no), mezcla (s), nombre y rotulo, como en el mapa.
func agregar(rect: Rect2i, luz: String, opciones: Dictionary = {}) -> void:
	var tilt: int = -1
	if opciones.has("tilt"):
		tilt = 1 if String(opciones["tilt"]) in ["si", "sí", "true", "1"] else 0
	zonas.append({"rect": rect, "luz": luz, "zoom": float(opciones.get("zoom", 0.0)), "tilt": tilt,
		"mezcla": maxf(float(opciones.get("mezcla", T_CAMBIO)), 0.0), "nombre": String(opciones.get("nombre", luz)),
		"rotulo": String(opciones.get("rotulo", "")).replace("_", " "), "botin": String(opciones.get("botin", ""))})


## El nombre de la zona que manda en una casilla: su `nombre=` (o el de su luz) y, fuera de todas, la luz de la escena.
func nombre_en(c: Vector2i) -> String:
	var z: Dictionary = zona_en(c)
	return String(z.get("nombre", z.get("luz", _defecto)))


## La fila del botín que pide la zona de una casilla con su `botin=` ("" si no pide ninguna): ver Rompible3D.BOTIN_ZONA.
func botin_en(c: Vector2i) -> String:
	return String(zona_en(c).get("botin", ""))


## La luz de la zona que manda en una casilla (la de la escena fuera de todas).
func luz_en(c: Vector2i) -> String:
	return String(zona_en(c).get("luz", _defecto))


## La flag de «ya visto» del rótulo de una zona: `<nivel>.rotulo.<nombre o x0_y0>_visto`.
func flag_rotulo(z: Dictionary) -> String:
	var r: Rect2i = z["rect"]
	var base: String = String(z["nombre"]) if String(z["nombre"]) != String(z["luz"]) else "%d_%d" % [r.position.x, r.position.y]
	return "%s.%s.%s_visto" % [Rompible3D._limpio(_nivel), FLAG_ROTULO, Rompible3D._limpio(base)]


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
	_desde_ms = Time.get_ticks_msec()
	nombre_actual = _defecto
	PlayLog.zona = nombre_actual            # todo evento del diario lleva la zona (PlayLog.event); antes de entrar en ninguna, la de la escena


## Salta ya a la luz de la zona donde está el jugador, sin mezcla (al llegar de otro nivel: la zona nueva no se funde desde la del nivel anterior). No saca el rótulo.
func forzar() -> void:
	if _m == null or not is_instance_valid(_m):
		return
	var pj: Node3D = _m.get("_jugador") as Node3D
	if pj == null:
		return
	var z: Dictionary = zona_en(Terreno3D.celda_de(pj.position))
	_entrar(z, true)
	_t = 1.0
	_desde = _hacia
	LuzZona3D.aplicar_valores(_m.get("_env") as Environment, _m.get("_sol") as DirectionalLight3D, _hacia)
	LuzZona3D.aplicar_sombra(_m.get("_sol") as DirectionalLight3D, _hacia_luz)


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
		_t = minf(_t + delta / maxf(_dur, T_MIN_MEZCLA), 1.0)
		var s: float = smoothstep(0.0, 1.0, _t)
		LuzZona3D.aplicar_valores(_m.get("_env") as Environment, _m.get("_sol") as DirectionalLight3D, LuzZona3D.mezclar(_desde, _hacia, s))
		if _t >= 1.0:
			LuzZona3D.aplicar_sombra(_m.get("_sol") as DirectionalLight3D, _hacia_luz)


func _entrar(z: Dictionary, en_silencio: bool = false) -> void:
	var antes: Dictionary = actual
	actual = z
	var luz: String = String(z.get("luz", _defecto))
	if luz != _hacia_luz:
		# Desde donde esté AHORA (a mitad de otro cambio, si lo hay), hacia la luz nueva. Dura lo que diga la zona a la que se entra (`mezcla=`).
		_desde = LuzZona3D.mezclar(_desde, _hacia, smoothstep(0.0, 1.0, _t))
		_hacia = LuzZona3D.valores(luz)
		_hacia_luz = luz
		_dur = float(z.get("mezcla", T_CAMBIO))
		_t = 0.0
		zona_cambio.emit(luz)
	_anotar_zona(z, en_silencio)
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


## El diario (`PlayLog.zona` y el evento `zona`) y el rótulo de la primera entrada. `en_silencio`: sin el evento `zona` (al llegar de otro nivel; el rótulo sí sale).
func _anotar_zona(z: Dictionary, en_silencio: bool) -> void:
	var nuevo: String = String(z.get("nombre", z.get("luz", _defecto)))
	if nuevo != nombre_actual:
		var ahora: int = Time.get_ticks_msec()
		if not en_silencio:
			PlayLog.event("zona", {"anterior": nombre_actual, "segundos": snappedf(float(ahora - _desde_ms) / 1000.0, 0.1), "luz": String(z.get("luz", _defecto))})
		_desde_ms = ahora
		nombre_actual = nuevo
		PlayLog.zona = nuevo
	var rotulo: String = String(z.get("rotulo", ""))
	if rotulo != "":
		var flag: String = flag_rotulo(z)
		if Flags.nombre_valido(flag) and not Flags.i().tiene(flag):
			Flags.i().poner(flag)
			rotulos_mostrados.append(rotulo)
			RotuloZona3D.mostrar(self, rotulo)
			PlayLog.event("rotulo_zona", {"texto": rotulo, "flag": flag})


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
