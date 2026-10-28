class_name TrazosRitual
extends RefCounted

## LOS TRAZOS DE LA RUNA DEL CHAMÁN (28/10): lo que dibuja la punta del bastón en el suelo, con el mismo orden y reparto de tiempo para las dos partes que lo usan:
##   · AnimacionesChaman (el clip `trazar` lleva la punta del bastón por estos puntos) y
##   · RunaSuelo3D (dibuja las líneas luminosas siguiendo ese mismo camino).
## Pablo (28/10): la runa es un ROMBO (el gesto de la barrera) dentro de su SELLO circular. El rombo es la forma real del gesto `barrera` de GestureLibrary (su primera muestra: 4 esquinas unidas
## por rectas, normalizada a [-0,5, 0,5] con la y hacia abajo en pantalla; aquí se gira para que «arriba» sea delante); sin biblioteca, un rombo regular.
## Coordenadas del PLANO DE LA RUNA, en unidades del sello (radio 1): `a` = hacia la DERECHA del chamán, `b` = hacia DELANTE (como lo ve él).
## Reparto del tiempo (fracciones del progreso 0..1; el clip `trazar` dura AnimacionesChaman.DUR_TRAZAR): el aro del sello, la punta se alza y viaja, el rombo, y el regreso al inicio (cierra el bucle).

const SELLO_FIN: float = 0.36
const ROMBO_INI: float = 0.44
const ROMBO_FIN: float = 0.88
const RADIO_ROMBO: float = 0.86                 ## semidiagonal del rombo dentro del sello
const PUNTOS_ARO: int = 56
const GESTO: String = "barrera"

static var _cache: Array = []


## Los trazos en orden: [{"nombre", "puntos": PackedVector2Array (a, b), "t0", "t1", "largos": acumulados, "largo"}].
static func trazos() -> Array:
	if not _cache.is_empty():
		return _cache
	var def: Array = [["sello", _aro(), 0.0, SELLO_FIN], ["rombo", _rombo(), ROMBO_INI, ROMBO_FIN]]
	for d in def:
		var pts: PackedVector2Array = d[1]
		var largos := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			largos.append(largos[i - 1] + pts[i].distance_to(pts[i - 1]))
		_cache.append({"nombre": d[0], "puntos": pts, "t0": d[2], "t1": d[3], "largos": largos, "largo": largos[largos.size() - 1]})
	return _cache


static func recargar() -> void:
	_cache.clear()


static func _aro() -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(PUNTOS_ARO + 1):
		var ang: float = PI + TAU * float(i) / float(PUNTOS_ARO)             # empieza a la izquierda, junto al principio del rombo
		p.append(Vector2(cos(ang), sin(ang)))
	return p


## La primera muestra de `barrera` (cerrada, centrada y escalada a RADIO_ROMBO) o un rombo regular.
static func _rombo() -> PackedVector2Array:
	var g: GestureLibrary = GestureLibrary.get_shared()
	var m := PackedVector2Array()
	if g != null and g.templates.has(GESTO) and not (g.templates[GESTO] as Array).is_empty():
		m = (g.templates[GESTO] as Array)[0] as PackedVector2Array
	var p := PackedVector2Array()
	if m.size() >= 6:
		var c := Vector2.ZERO
		for q in m:
			c += q
		c /= float(m.size())
		var rmax: float = 0.0
		for q in m:
			rmax = maxf(rmax, (q - c).length())
		for q in m:
			var v: Vector2 = (q - c) / maxf(rmax, 0.0001) * RADIO_ROMBO
			p.append(Vector2(v.x, -v.y))
		if p[0].distance_to(p[p.size() - 1]) > 0.01:
			p.append(p[0])
		return p
	var r: float = RADIO_ROMBO
	return PackedVector2Array([Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])


static func punto_en_trazo(t: Dictionary, f: float) -> Vector2:
	var pts: PackedVector2Array = t["puntos"]
	var largos: PackedFloat32Array = t["largos"]
	var d: float = clampf(f, 0.0, 1.0) * float(t["largo"])
	var i: int = 1
	while i < pts.size() - 1 and largos[i] < d:
		i += 1
	var seg: float = maxf(largos[i] - largos[i - 1], 0.00001)
	return pts[i - 1].lerp(pts[i], clampf((d - largos[i - 1]) / seg, 0.0, 1.0))


## Dónde está la punta a los `u` (0..1): {"pos": Vector2 (a, b), "baja": 0..1 (1 = toca el suelo y dibuja), "trazo": índice del trazo que dibuja (-1 si viaja)}.
static func punta(u: float) -> Dictionary:
	var ts: Array = trazos()
	u = clampf(u, 0.0, 1.0)
	for k in range(ts.size()):
		var t: Dictionary = ts[k]
		if u >= float(t["t0"]) and u <= float(t["t1"]):
			var f: float = (u - float(t["t0"])) / (float(t["t1"]) - float(t["t0"]))
			return {"pos": punto_en_trazo(t, f), "baja": 1.0, "trazo": k}
	var k0: int = 0
	for k in range(ts.size()):
		if u > float((ts[k] as Dictionary)["t1"]):
			k0 = k
	var a_t: Dictionary = ts[k0]
	var b_t: Dictionary = ts[(k0 + 1) % ts.size()]
	var ini: float = float(a_t["t1"])
	var fin: float = float(b_t["t0"]) if k0 + 1 < ts.size() else 1.0
	var s: float = clampf((u - ini) / maxf(fin - ini, 0.00001), 0.0, 1.0)
	var e: float = s * s * (3.0 - 2.0 * s)
	var alz: float = clampf(minf(s, 1.0 - s) / 0.3, 0.0, 1.0)
	return {"pos": punto_en_trazo(a_t, 1.0).lerp(punto_en_trazo(b_t, 0.0), e), "baja": 1.0 - alz, "trazo": -1}


## Fracción dibujada (0..1) del trazo `k` a los `u` del tiempo.
static func fraccion_de_trazo(k: int, u: float) -> float:
	var t: Dictionary = trazos()[k]
	return clampf((u - float(t["t0"])) / (float(t["t1"]) - float(t["t0"])), 0.0, 1.0)
