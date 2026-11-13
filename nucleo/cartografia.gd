class_name Cartografia
extends RefCounted
## EL MAPA QUE SE DIBUJA ANDANDO (13/11/2026, Pablo). Mid cartografía las casillas que ve a su alrededor y marca por dónde pasa.
## Se desbloquea con el encargo de Marimanta (EncargoMarimanta.RECIBIDO): antes, la pestaña Mapa sale cerrada y no se registra nada.
## El 60 % de Bosque 02 cartografiado cumple el primer objetivo del encargo.
##
## Datos del nivel actual (los pone el nivel al montarse con `preparar`): sus letras, sus salidas y la casilla de Mid.
## Lo descubierto se guarda en flags (cadena hexadecimal, un bit por casilla), así sobrevive al viaje y al guardado:
##   mapa.<nivel>.visto     casillas cartografiadas          mapa.<nivel>.ruta   casillas pisadas (la ruta que se marca)
##   mapa.<nivel>.porcentaje  entero 0..100 (lo leen Monte Sumicio y el diario sin tener las letras del nivel)

const RADIO_VISTA := 2.6            ## casillas que se cartografían alrededor de Mid
const META := 60                    ## % de Bosque 02 que pide el encargo
const NIVEL_ENCARGO := "Bosque_02"
const NO_CUENTA := "# "             ## letras que no son terreno de la zona (árbol/roca del anillo y fuera del mapa)

static var nivel := ""
static var letras: PackedStringArray = []
static var salidas: Array = []      ## [{"celda": Vector2i, "nombre": String}]
static var jugador := Vector2i(-1, -1)
static var _visto := PackedByteArray()
static var _ruta := PackedByteArray()
static var _total := 0
static var _vistas := 0


static func desbloqueado() -> bool:
	return EncargoMarimanta.recibido()


static func ancho() -> int:
	return letras[0].length() if letras.size() > 0 else 0


static func alto() -> int:
	return letras.size()


static func _clave(n: String, que: String) -> String:
	return "mapa.%s.%s" % [n.to_lower(), que]


## El nivel se presenta: sus filas de letras y sus salidas. Recupera lo que ya estaba cartografiado.
static func preparar(p_nivel: String, p_letras: PackedStringArray, p_salidas: Array = []) -> void:
	nivel = p_nivel
	letras = p_letras
	salidas = p_salidas
	jugador = Vector2i(-1, -1)
	var n := ancho() * alto()
	_visto = _leer(_clave(nivel, "visto"), n)
	_ruta = _leer(_clave(nivel, "ruta"), n)
	_total = 0
	_vistas = 0
	for y in range(alto()):
		for x in range(ancho()):
			if cuenta(Vector2i(x, y)):
				_total += 1
				if _bit(_visto, x, y):
					_vistas += 1


## Prepara un nivel hecho con mapa de letras (`mundo/datos_nivel/mapas/<nivel>.txt`): sus filas y sus salidas (`; pieza … salida X Y a=Nivel:entrada`).
static func preparar_desde_mapa(p_nivel: String) -> bool:
	var ruta := HorneadorNivel.ruta_mapa(p_nivel)
	if ruta == "" or not FileAccess.file_exists(ruta):
		return false
	var filas := PackedStringArray()
	var sal: Array = []
	for l in FileAccess.get_file_as_string(ruta).replace("\r", "").split("\n"):
		if l.begins_with(";"):
			var t := l.split(" ", false)
			if t.size() >= 7 and t[1] == "pieza" and t[3] == "salida":
				for p in t:
					if p.begins_with("a="):
						var destino := p.trim_prefix("a=").get_slice(":", 0)
						sal.append({"celda": Vector2i(int(t[4]), int(t[5])), "nombre": NOMBRES.get(destino, destino)})
		elif l != "" and filas.size() < 400:
			filas.append(l)
	preparar(p_nivel, filas, sal)
	return true


const NOMBRES: Dictionary = {"MonteSumicio": "Monte Sumicio", "Cueva": "La Cueva"}


static func letra(c: Vector2i) -> String:
	if c.y < 0 or c.y >= alto() or c.x < 0 or c.x >= letras[c.y].length():
		return " "
	return letras[c.y][c.x]


static func cuenta(c: Vector2i) -> bool:
	return not NO_CUENTA.contains(letra(c))


static func visto(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ancho() and c.y < alto() and _bit(_visto, c.x, c.y)


static func pisado(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ancho() and c.y < alto() and _bit(_ruta, c.x, c.y)


## Mid está en `c`: cartografía su alrededor y marca la ruta. Devuelve true si descubrió algo nuevo.
static func registrar(c: Vector2i) -> bool:
	jugador = c
	if not desbloqueado() or alto() == 0:
		return false
	var nuevo := false
	var r := int(ceil(RADIO_VISTA))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var v := c + Vector2i(dx, dy)
			if Vector2(dx, dy).length() > RADIO_VISTA or v.x < 0 or v.y < 0 or v.x >= ancho() or v.y >= alto():
				continue
			if not _bit(_visto, v.x, v.y):
				_poner_bit(false, v.x, v.y)
				nuevo = true
				if cuenta(v):
					_vistas += 1
	var ruta_nueva := false
	if cuenta(c) and not _bit(_ruta, c.x, c.y):
		_poner_bit(true, c.x, c.y)
		ruta_nueva = true
	if nuevo:
		Flags.i().poner(_clave(nivel, "visto"), _visto.hex_encode())
		Flags.i().poner(_clave(nivel, "porcentaje"), maxi(1, porcentaje()) if _vistas > 0 else 0)
	if ruta_nueva:
		Flags.i().poner(_clave(nivel, "ruta"), _ruta.hex_encode())
	return nuevo


## % cartografiado del nivel actual (0..100).
static func porcentaje() -> int:
	return int(floor(100.0 * _vistas / _total)) if _total > 0 else 0


## % guardado de cualquier nivel (aunque no sea el actual).
static func porcentaje_de(n: String) -> int:
	if n == nivel and _total > 0:
		return porcentaje()
	return int(Flags.i().valor(_clave(n, "porcentaje"), 0))


static func _leer(clave: String, n: int) -> PackedByteArray:
	var b := PackedByteArray()
	var hex := String(Flags.i().valor(clave, ""))
	if hex != "" and hex.length() % 2 == 0:
		b = hex.hex_decode()
	b.resize((n + 7) / 8)
	return b


static func _bit(b: PackedByteArray, x: int, y: int) -> bool:
	var i := y * ancho() + x
	return i >= 0 and i / 8 < b.size() and (b[i / 8] >> (i % 8)) & 1 == 1


## Los PackedByteArray van por copia: se escribe en el estático que toque (`ruta` = el de las casillas pisadas).
static func _poner_bit(ruta: bool, x: int, y: int) -> void:
	var i := y * ancho() + x
	if ruta:
		_ruta[i / 8] = _ruta[i / 8] | (1 << (i % 8))
	else:
		_visto[i / 8] = _visto[i / 8] | (1 << (i % 8))
