class_name CastPoints
extends RefCounted

## CAST POINTS (T-CP1, 18/10, Juego; docs/LAB_CASTPOINT.md §2). DESDE DÓNDE y CUÁNDO sale un hechizo: el clip de lanzar (recortado), el fotograma exacto en
## que nace (`instante`), de qué punto del cuerpo nace (`origen`) y cómo se reparte la anticipación (runa, voluta, forma) hasta ese instante.
## Antes el disparo salía por reloj (`RETARDO_CONJURO`) sin relación con el clip. Ahora el clip MANDA: el hechizo nace cuando el clip llega a su `instante`.
##
## TRES POSICIONES (la receta V2 las deriva sola: `GeometriaV2.nombre_derivado` = x_mano · alto · abajo) con dos VARIACIONES cada una. La tabla
## `POR_NOMBRE` dice cuál usa cada nombre derivado (Pablo la cambia en el lab: F2, Tab/1–6; G guarda; P imprime la tabla para volcarla aquí).
##
## Campos de cada variación (la clave es su id):
##   posicion      x_mano · alto · abajo (a qué nombre derivado pertenece; solo informativo y para agrupar en el lab)
##   clip          ROL del clip original (resuelto con Pj3D.SINONIMOS: cast_proyectil = MageSoellCast003, cast_columna = ChargedSpellCast002…)
##   inicio, fin   recorte del clip, 0–1 de su duración total (el clip sin recortar dura `len`; CollectObject entero son 6 s)
##   instante      DÓNDE nace el hechizo, como fracción del clip RECORTADO (0 = en `inicio`, 1 = en `fin`). Los valores de partida salen de medir el
##                 pico de la mano (LAB_CASTPOINT §1): p. ej. MageSoellCast003 tiene la mano izquierda en su punto más alto en 0,68 del clip entero
##                 = 0,40 + 0,62 × (0,85 − 0,40).
##   origen        mano_libre (la que NO lleva el libro) · manos_alto (punto medio de las dos manos, sobre la cabeza) · suelo_delante (a los pies,
##                 una casilla hacia donde se lanza) · destino (el punto que se apunta)
##   sostener      s que se queda el clip CONGELADO en el instante, tras el disparo (que el gesto se lea); 0 = sigue
##   anticipacion  [runa, voluta, forma]: reparto del tiempo hasta el instante (suma 1). La forma acaba JUSTO en el instante.
##   desplazamiento [adelante, arriba, lado] (u, respecto al jugador y hacia donde lanza; lado + = su derecha): mueve el punto de origen. Lo afina el lab con las flechas.
##   mano_libro    izquierda | derecha: la mano que sostiene el libro. MageSoellCast003 lanza con la izquierda: ahí el libro va a la derecha.
##   velocidad     del clip (1 = original). 1,6 es la VEL_CAST de siempre; CollectObject va al ×2,5 (dura 6 s).
##   clip_una_mano ROL de un clip a UNA mano con la otra sujetando el libro (CastOneHandFront/Up/Ground, del Pipeline). Con la fuente «una mano»
##                 (`usar_una_mano`) se usa ese clip y el modificador del brazo se apaga. Vacío = no hay.
## Todo es `static var` para que el laboratorio lo toque en vivo; nada se guarda solo: G del lab escribe user://cast_points.json y P imprime esta tabla.

## Qué variación usa cada nombre derivado.
static var POR_NOMBRE: Dictionary = {"x_mano": "x_mano", "alto": "alto_cielo", "abajo": "abajo_golpe"}

## Las seis variaciones de partida (LAB_CASTPOINT §2.2).
static var VARIACIONES: Dictionary = {
	"x_mano": {"posicion": "x_mano", "clip": "cast_proyectil", "inicio": 0.40, "fin": 0.85, "instante": 0.62, "origen": "mano_libre", "sostener": 0.0,
		"anticipacion": [0.30, 0.35, 0.35], "mano_libro": "derecha", "velocidad": 1.6, "clip_una_mano": "cast_mano_frente", "desplazamiento": [0.0, 0.0, 0.0]},
	"x_empuje": {"posicion": "x_mano", "clip": "cast_empuje", "inicio": 0.25, "fin": 0.65, "instante": 0.52, "origen": "mano_libre", "sostener": 0.0,
		"anticipacion": [0.25, 0.35, 0.40], "mano_libro": "izquierda", "velocidad": 1.6, "clip_una_mano": "cast_mano_frente"},
	"alto_cielo": {"posicion": "alto", "clip": "cast_columna", "inicio": 0.30, "fin": 0.85, "instante": 0.69, "origen": "manos_alto", "sostener": 0.0,
		"anticipacion": [0.25, 0.35, 0.40], "mano_libro": "izquierda", "velocidad": 1.6, "clip_una_mano": "cast_mano_alto"},
	"alto_alza": {"posicion": "alto", "clip": "cast_proyectil", "inicio": 0.10, "fin": 0.45, "instante": 0.74, "origen": "manos_alto", "sostener": 0.0,
		"anticipacion": [0.25, 0.35, 0.40], "mano_libro": "derecha", "velocidad": 1.6, "clip_una_mano": "cast_mano_alto"},
	"abajo_golpe": {"posicion": "abajo", "clip": "cast_corro", "inicio": 0.35, "fin": 0.80, "instante": 0.62, "origen": "suelo_delante", "sostener": 0.0,
		"anticipacion": [0.25, 0.35, 0.40], "mano_libro": "izquierda", "velocidad": 1.6, "clip_una_mano": "cast_mano_suelo"},
	"abajo_deja": {"posicion": "abajo", "clip": "pick_up", "inicio": 0.45, "fin": 0.80, "instante": 0.60, "origen": "suelo_delante", "sostener": 0.0,
		"anticipacion": [0.25, 0.35, 0.40], "mano_libro": "izquierda", "velocidad": 2.5, "clip_una_mano": "cast_mano_suelo"},
}

## El orden en que el lab recorre las variaciones (Tab y 1–6).
const ORDEN: Array = ["x_mano", "x_empuje", "alto_cielo", "alto_alza", "abajo_golpe", "abajo_deja"]

## El elemento escala el tiempo TOTAL (LAB_CASTPOINT §2.1: rayo ×0,6, tierra ×1,3): la duración se multiplica por esto (la velocidad del clip, por su inverso).
const ESCALA_TIEMPO: Dictionary = {"lightning": 0.6, "rayo": 0.6, "earth": 1.3, "tierra": 1.3}
const ORIGENES: Array = ["mano_libre", "manos_alto", "suelo_delante", "destino"]
const MANOS: Array = ["izquierda", "derecha"]
## Qué clip a una mano va con cada origen (los tres del Pipeline, diario 150): frente = mano libre, alto = manos arriba, suelo = al suelo.
const UNA_MANO_DE_ORIGEN: Dictionary = {"mano_libre": "cast_mano_frente", "manos_alto": "cast_mano_alto", "suelo_delante": "cast_mano_suelo", "destino": "cast_mano_frente"}

## Fuente del clip: false = el original (a dos manos, con el modificador del brazo del libro); true = el clip a una mano si la variación lo tiene.
static var usar_una_mano: bool = false
## ¿Se aplica el modificador del brazo del libro con los clips originales? (el lab lo apaga con B para ver la diferencia)
static var brazo_activo: bool = true
## Peso del modificador (0 = nada, 1 = el brazo del libro clavado en la pose). LAB_CASTPOINT pide 0,8–1.
static var peso_brazo: float = 0.9


## Id de la variación que corresponde a un nombre derivado ("" si no hay: sin cast point, se lanza como antes).
static func variacion_de(nombre_derivado: String) -> String:
	var id: String = String(POR_NOMBRE.get(nombre_derivado, ""))
	return id if VARIACIONES.has(id) else ""


## Los datos del cast point de un nombre derivado (x_mano · alto · abajo) para un elemento: la variación que le toca más `origen` y el factor de tiempo del
## elemento. Es la forma que esperaba el Pipeline (`CastPoints.de(forma, elemento)["origen"]`, prueba_conjuro_vfx); vacío si el nombre no tiene variación.
static func de(nombre_derivado: String, elemento: String = "") -> Dictionary:
	var id: String = variacion_de(nombre_derivado)
	if id == "":
		return {}
	var d: Dictionary = datos(id)
	d["escala_tiempo"] = escala_tiempo(elemento)
	return d


static func existe(id: String) -> bool:
	return VARIACIONES.has(id)


## Copia de los datos de una variación (vacío si no existe). Los campos que falten se rellenan con los valores neutros.
static func datos(id: String) -> Dictionary:
	if not VARIACIONES.has(id):
		return {}
	var d: Dictionary = (VARIACIONES[id] as Dictionary).duplicate(true)
	d["id"] = id
	d["sostener"] = float(d.get("sostener", 0.0))
	d["velocidad"] = float(d.get("velocidad", 1.6))
	d["anticipacion"] = normalizar_anticipacion(d.get("anticipacion", [0.25, 0.35, 0.40]))
	d["desplazamiento"] = desplazamiento(id)
	return d


## El desplazamiento del punto de origen de la variación como Vector3 (adelante, arriba, lado). Cero si no lo tiene.
static func desplazamiento(id: String) -> Vector3:
	var v: Variant = (VARIACIONES.get(id, {}) as Dictionary).get("desplazamiento", [0.0, 0.0, 0.0])
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


## Ese desplazamiento puesto en el mundo para un lanzamiento hacia `dir` (en el plano): adelante = dir, lado = su derecha (con la cara hacia `dir`: la mano derecha del jugador).
static func desplazamiento_mundo(id: String, dir: Vector3) -> Vector3:
	var o: Vector3 = desplazamiento(id)
	var f: Vector3 = Vector3(dir.x, 0.0, dir.z)
	f = f.normalized() if f.length() > 0.001 else Vector3.FORWARD
	var derecha: Vector3 = f.cross(Vector3.UP)          # la derecha de quien mira hacia f
	return f * o.x + Vector3.UP * o.y + derecha * o.z


## Reparto [runa, voluta, forma] que suma 1 (si llega algo raro: el reparto de siempre).
static func normalizar_anticipacion(a: Variant) -> Array:
	var v: Array = a if a is Array and (a as Array).size() == 3 else [0.25, 0.35, 0.40]
	var s: float = maxf(float(v[0]), 0.0) + maxf(float(v[1]), 0.0) + maxf(float(v[2]), 0.0)
	if s <= 0.0001:
		return [0.25, 0.35, 0.40]
	return [maxf(float(v[0]), 0.0) / s, maxf(float(v[1]), 0.0) / s, maxf(float(v[2]), 0.0) / s]


## El rol del clip que se usa de verdad: el de una mano si la fuente lo pide y la variación lo tiene; si no, el original.
static func rol_clip(id: String) -> String:
	var d: Dictionary = datos(id)
	if d.is_empty():
		return ""
	if usar_una_mano and String(d.get("clip_una_mano", "")) != "":
		return String(d["clip_una_mano"])
	return String(d["clip"])


## ¿Con esta variación y fuente se usa un clip a una mano?
static func es_una_mano(id: String) -> bool:
	var d: Dictionary = datos(id)
	return not d.is_empty() and usar_una_mano and String(d.get("clip_una_mano", "")) != ""


## La mano del libro: con un clip a una mano, la izquierda (la otra lanza); con el original, la que dice la variación.
static func mano_libro(id: String) -> String:
	var d: Dictionary = datos(id)
	if d.is_empty() or es_una_mano(id):
		return "izquierda"
	return String(d.get("mano_libro", "izquierda"))


static func mano_libre(id: String) -> String:
	return "derecha" if mano_libro(id) == "izquierda" else "izquierda"


## Factor de duración por elemento (1 si no hay entrada).
static func escala_tiempo(elemento: String) -> float:
	return float(ESCALA_TIEMPO.get(elemento, 1.0))


## Los recortes ya normalizados: [inicio, fin] con 0 ≤ inicio < fin ≤ 1.
static func recorte(id: String) -> Vector2:
	var d: Dictionary = datos(id)
	if d.is_empty():
		return Vector2(0.0, 1.0)
	var a: float = clampf(float(d["inicio"]), 0.0, 0.98)
	var b: float = clampf(float(d["fin"]), a + 0.02, 1.0)
	return Vector2(a, b)


## Lo que se imprime con P del laboratorio: la tabla lista para pegar en este archivo.
static func tabla_texto() -> String:
	var t: PackedStringArray = []
	t.append("# Cast points · magia/cast_points.gd")
	t.append("POR_NOMBRE = %s" % str(POR_NOMBRE))
	for id in ORDEN:
		var d: Dictionary = VARIACIONES[id]
		var a: Array = d["anticipacion"]
		t.append("%-12s %-9s clip %-15s recorte %.2f–%.2f  instante %.2f  origen %-13s sostener %.2f  anticipación %.2f/%.2f/%.2f  libro %-9s vel %.2f  una_mano %s" % [
			id, String(d["posicion"]), String(d["clip"]), float(d["inicio"]), float(d["fin"]), float(d["instante"]), String(d["origen"]), float(d["sostener"]),
			float(a[0]), float(a[1]), float(a[2]), String(d["mano_libro"]), float(d["velocidad"]), String(d.get("clip_una_mano", ""))])
	t.append("usar_una_mano = %s · brazo_activo = %s · peso_brazo = %.2f" % [str(usar_una_mano), str(brazo_activo), peso_brazo])
	return "\n".join(t)


## Para el lab (G): todo lo editable como diccionario serializable.
static func a_diccionario() -> Dictionary:
	return {"por_nombre": POR_NOMBRE.duplicate(), "variaciones": VARIACIONES.duplicate(true), "usar_una_mano": usar_una_mano, "brazo_activo": brazo_activo, "peso_brazo": peso_brazo}


## Carga lo que escribió G (o lo que sea con la misma forma). Los ids desconocidos se ignoran; los campos que faltan se quedan como estaban.
static func desde_diccionario(d: Dictionary) -> int:
	var n: int = 0
	var pn: Variant = d.get("por_nombre", {})
	if pn is Dictionary:
		for k in (pn as Dictionary):
			if VARIACIONES.has(String((pn as Dictionary)[k])):
				POR_NOMBRE[String(k)] = String((pn as Dictionary)[k])
	var vs: Variant = d.get("variaciones", {})
	if vs is Dictionary:
		for id in (vs as Dictionary):
			if VARIACIONES.has(String(id)) and (vs as Dictionary)[id] is Dictionary:
				for campo in ((vs as Dictionary)[id] as Dictionary):
					(VARIACIONES[String(id)] as Dictionary)[String(campo)] = ((vs as Dictionary)[id] as Dictionary)[campo]
				n += 1
	usar_una_mano = bool(d.get("usar_una_mano", usar_una_mano))
	brazo_activo = bool(d.get("brazo_activo", brazo_activo))
	peso_brazo = float(d.get("peso_brazo", peso_brazo))
	return n
