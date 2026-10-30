class_name Objetos
extends RefCounted

## CATÁLOGO DE OBJETOS Y REACCIONES DEL MUNDO.
##
## Un objeto es solo datos: nombre, descripción, color de su icono y forma de dibujarlo.
## Los ingredientes se consiguen haciendo REACCIONAR un objeto del mundo con un elemento
## (electrificar una seta, quemar una flor...). La tabla REACCIONES dice qué sale de cada
## cruce; no hay sistema de cocina, solo el objeto en la mochila para usarlo en recetas.

## DESDE F0 (29/10, PLAN_BASE_DATOS) NADA DE ESTO SE ESCRIBE AQUÍ: `DATOS`, `PLANTAS`, `MINERALES`, `CLAVE`, `CURAN` y `CONSUMIBLES` se GENERAN al cargar
## el script desde las tablas de `res://nucleo/datos/` (las lee `BD`), para que los 30 y pico sitios que los leen hoy sigan funcionando sin cambiar.
## Si quieres un objeto nuevo, una planta nueva o un consumible nuevo, es una fila en `objetos.tsv` / `fuentes.tsv`, no una línea de GDScript.
##
## Cada entrada de `DATOS` conserva las claves de siempre: `nombre`, `desc`, `color` (Color), `forma` (la de `dibujar`: "frasco", "seta", "flor", "raiz", "cristal",
## "moneda", "tonico", "tarro", "infusion"...), `calidad` (solo si no es común), `usos` (frases del panel «Usos conocidos» del Inventario; sin ellas el panel dice que aún
## no se le conoce ninguno) y `efecto` (los números de un consumible; los lee `Consumibles`, ÚNICO sitio donde viven). Y gana las de la tabla: `categoria` (la de
## §2.1 del plan: hongo, planta, raiz, mineral, animal, botin, consumible, pigmento, clave, ropa, glifo), `etiquetas`, `potencia`, `pila`, `uso`, `modelo` y `zona`.
static var DATOS: Dictionary = {}

## --- Calidades (PLAN_PULSO_RESONANTE §7): común gris/blanco · épico morado · legendario dorado ---
## `color` pinta el borde del aviso al cogerlo y el aro del icono; `aviso_s` es lo que dura el aviso en pantalla.
const CALIDAD_COMUN: String = "comun"
const CALIDAD_EPICO: String = "epico"
const CALIDAD_LEGENDARIO: String = "legendario"
const CALIDADES: Dictionary = {
	"comun": {"nombre": "Común", "color": Color(0.85, 0.87, 0.9), "aviso_s": 1.4},
	"epico": {"nombre": "Épico", "color": Color(0.7, 0.4, 1.0), "aviso_s": 3.0},
	"legendario": {"nombre": "Legendario", "color": Color(1.0, 0.82, 0.3), "aviso_s": 4.5},
}

## Dónde sale cada mineral de un reactivo (gancho de la fase 3 del pulso). Se genera de `fuentes.tsv` (filas golpe/romper/tabla de un objeto de categoría
## mineral cuyo `de` es una veta, un cristal o un jarrón; la primera fila de cada `de` manda).
## reactivo del mundo -> {via: lo que le hace falta (elemento lanzado, "golpe" o "romper"), golpes: cuántos, da: el material}
static var MINERALES: Dictionary = {}

## Plantas del mundo (las que se ven en el suelo antes de reaccionar). Se genera de `fuentes.tsv`: la base es la fila `recoger` de la planta y la tabla son sus
## filas `reaccion` SIN condición (las que dependen de un estado del mundo, como el alga cargada de la charca electrificada, esperan a su fase).
## base: objeto original · tabla: etiqueta del elemento -> objeto resultante
static var PLANTAS: Dictionary = {}

## Las piezas de `fuentes.tsv` que son plantas (las demás `de` son enemigos, cofres, reactivos...). Las cuatro de siempre y las tres de la Cueva que llegan con F0.
const PIEZAS_PLANTA: PackedStringArray = ["seta", "flor", "raiz", "alga", "musgo", "helecho_cueva", "seta_palida"]
## Pila por hueco de un objeto que no está en la tabla (lo de siempre: `Estado.PILA_MAX`).
const PILA_DEFECTO: int = 9

const ETIQUETAS: Array = ["rayo", "fuego", "hielo", "agua", "viento", "tierra"]

## --- Categorías de la bolsa (Fase 14.3) ---
## La bolsa ordena SIEMPRE por categoría: primero los componentes (ingredientes), luego las pociones, al final los objetos clave (llaves
## y cosas de misión). Dentro de cada una, por nombre. Sale de la columna `categoria` de la tabla (ver `categoria`).
const CATEGORIAS: Array = ["componentes", "pociones", "clave"]
## Los objetos de categoría «clave» de la tabla (llaves y cosas de misión; la ropa y los glifos también van a la pestaña clave pero no están aquí).
static var CLAVE: PackedStringArray = PackedStringArray()
## Objetos que curan (la bolsa les pone un corazón rojo, como Echoes of Wisdom): los que llevan `cura` o `tasa` en su `efecto`.
static var CURAN: PackedStringArray = PackedStringArray()
## Los consumibles del HUD, en el orden en que R los recorre (los de `uso = equipar`). Q usa el equipado (ver `Consumibles`). Van en la categoría de pociones.
## Primero los que el juego ya tenía (`estado = hay`, en el orden de la tabla: poción, tónico, bálsamo, infusión) y luego los nuevos, para que R no cambie de orden.
static var CONSUMIBLES: PackedStringArray = PackedStringArray()


## Se ejecuta una vez, al cargar el script: rellena DATOS, PLANTAS, MINERALES, CLAVE, CURAN y CONSUMIBLES desde `BD`.
static func _static_init() -> void:
	_construir()


static func _construir() -> void:
	DATOS = {}
	var clave: PackedStringArray = PackedStringArray()
	var curan: PackedStringArray = PackedStringArray()
	var consumibles_hay: PackedStringArray = PackedStringArray()
	var consumibles_nuevos: PackedStringArray = PackedStringArray()
	var objs: Dictionary = BD.objetos()
	for id in objs:
		var o: Dictionary = objs[id]
		var d: Dictionary = {"nombre": o["nombre"], "desc": o["desc"], "color": o["color"], "forma": o["forma"]}
		if String(o["calidad"]) != "" and String(o["calidad"]) != CALIDAD_COMUN:
			d["calidad"] = o["calidad"]
		if not (o["usos"] as Array).is_empty():
			d["usos"] = o["usos"]
		if not (o["efecto"] as Dictionary).is_empty():
			d["efecto"] = o["efecto"]
		for k in ["categoria", "etiquetas", "potencia", "pila", "uso", "modelo", "zona"]:
			d[k] = o[k]
		DATOS[id] = d
		if String(o["categoria"]) == "clave":
			clave.append(id)
		var ef: Dictionary = o["efecto"]
		if ef.has("cura") or ef.has("tasa"):
			curan.append(id)
		if String(o["uso"]) == "equipar":
			if String(o["estado"]) == "hay":
				consumibles_hay.append(id)
			else:
				consumibles_nuevos.append(id)
	CLAVE = clave
	CURAN = curan
	CONSUMIBLES = consumibles_hay + consumibles_nuevos
	_construir_plantas()
	_construir_minerales()


static func _construir_plantas() -> void:
	PLANTAS = {}
	for pieza in PIEZAS_PLANTA:
		PLANTAS[pieza] = {"base": pieza, "tabla": {}}
	var con_base: Dictionary = {}
	for f in BD.fuentes():
		var de: String = String(f["de"])
		if not PLANTAS.has(de):
			continue
		var planta: Dictionary = PLANTAS[de]
		if String(f["fuente"]) == "recoger":
			if not con_base.has(de):
				con_base[de] = true
				planta["base"] = String(f["objeto"])
		elif String(f["fuente"]) == "reaccion" and String(f["condicion"]) == "" and ETIQUETAS.has(String(f["via"])):
			(planta["tabla"] as Dictionary)[String(f["via"])] = String(f["objeto"])


static func _construir_minerales() -> void:
	MINERALES = {}
	for f in BD.fuentes():
		var de: String = String(f["de"])
		if not ["veta", "cristal_resonante", "jarron"].has(de) or MINERALES.has(de):
			continue
		if not ["golpe", "romper", "tabla"].has(String(f["fuente"])) or String(BD.objeto(String(f["objeto"])).get("categoria", "")) != "mineral":
			continue
		var via: String = String(f["via"])
		var m: Dictionary = {"da": String(f["objeto"])}
		if via.begins_with("golpes:"):
			m["via"] = "golpe"
			m["golpes"] = via.substr(7).to_int()
		elif via == "romper":
			m["via"] = "romper"
			m["golpes"] = 1
		elif ETIQUETAS.has(via):
			m["via"] = via
			m["golpes"] = 1
		else:
			continue
		MINERALES[de] = {"via": m["via"], "golpes": m["golpes"], "da": m["da"]}


static func existe(id: String) -> bool:
	return DATOS.has(id)


static func nombre(id: String) -> String:
	return String(DATOS.get(id, {}).get("nombre", id))


static func color(id: String) -> Color:
	return DATOS.get(id, {}).get("color", Color.WHITE)


## Calidad de un objeto: común si no dice otra cosa (o si dice una que no existe).
static func calidad(id: String) -> String:
	var c: String = String(DATOS.get(id, {}).get("calidad", CALIDAD_COMUN))
	return c if CALIDADES.has(c) else CALIDAD_COMUN


static func color_calidad(id: String) -> Color:
	return (CALIDADES[calidad(id)] as Dictionary)["color"]


## Cuánto dura el aviso de coger este objeto (más largo cuanto más raro).
static func duracion_aviso(id: String) -> float:
	return float((CALIDADES[calidad(id)] as Dictionary)["aviso_s"])


## El material que da un reactivo con esa vía (ver MINERALES), o "" si no da nada.
static func mineral_de(reactivo: String, via: String) -> String:
	var m: Dictionary = MINERALES.get(reactivo, {})
	return String(m.get("da", "")) if String(m.get("via", "")) == via else ""


## La categoría de la BOLSA (componentes / pociones / clave), agrupando la de la tabla como dice PLAN_BASE_DATOS §2.1:
## consumible + pigmento → pociones; clave + ropa + glifo → clave; todo lo demás (hongos, plantas, raíces, minerales, animales, botín) → componentes.
static func categoria(id: String) -> String:
	match categoria_bd(id):
		"consumible", "pigmento":
			return "pociones"
		"clave", "ropa", "glifo":
			return "clave"
	return "componentes"


## La categoría fina de la tabla (hongo, planta, raiz, mineral, animal, botin, consumible, pigmento, clave, ropa, glifo); "" si el objeto no existe.
static func categoria_bd(id: String) -> String:
	return String((DATOS.get(id, {}) as Dictionary).get("categoria", ""))


## Cuántas unidades caben en un hueco de la mochila (columna `pila`); 9 si el objeto no está en la tabla.
static func pila(id: String) -> int:
	return maxi(1, int((DATOS.get(id, {}) as Dictionary).get("pila", PILA_DEFECTO)))


## Las etiquetas que aporta a una receta (`vital`, `calor`...); [] si no tiene.
static func etiquetas(id: String) -> Array:
	return (DATOS.get(id, {}) as Dictionary).get("etiquetas", [])


## Cuánto aporta cada etiqueta (1–5); 0 si no aporta nada.
static func potencia(id: String) -> int:
	return int((DATOS.get(id, {}) as Dictionary).get("potencia", 0))


static func cura(id: String) -> bool:
	return CURAN.has(id)


static func es_ingrediente(id: String) -> bool:
	return id != "oro" and not CONSUMIBLES.has(id)


static func es_consumible(id: String) -> bool:
	return CONSUMIBLES.has(id)


## «Usos conocidos» de un objeto (frases para el panel de detalle del Inventario); vacío si aún no se le conoce ninguno.
static func usos(id: String) -> Array:
	return (DATOS.get(id, {}) as Dictionary).get("usos", [])


## Los números del efecto de un consumible ({} si no tiene): `Consumibles` los lee de aquí.
static func efecto(id: String) -> Dictionary:
	return (DATOS.get(id, {}) as Dictionary).get("efecto", {})


static func descripcion(id: String) -> String:
	return String((DATOS.get(id, {}) as Dictionary).get("desc", ""))


## Qué elemento (nombre de sello) lleva una runa, mirando sus etiquetas.
static func elemento_de(rune_data: RuneData) -> String:
	if rune_data == null:
		return ""
	for e in ETIQUETAS:
		if rune_data.tags.has(e):
			return e
	if rune_data.tags.has("electrico"):
		return "rayo"
	if rune_data.tags.has("calor"):
		return "fuego"
	if rune_data.tags.has("frio"):
		return "hielo"
	return ""


## Dibuja el icono de un objeto en `c` con su centro en `p` y radio aproximado `r`.
static func dibujar(c: CanvasItem, id: String, p: Vector2, r: float) -> void:
	var d: Dictionary = DATOS.get(id, {})
	var col: Color = d.get("color", Color.WHITE)
	var oscuro: Color = col.darkened(0.45)
	match String(d.get("forma", "cristal")):
		"moneda":
			c.draw_circle(p, r, oscuro)
			c.draw_circle(p, r * 0.8, col)
			c.draw_arc(p, r * 0.5, 0.0, TAU, 14, oscuro, maxf(1.0, r * 0.12))
		"frasco":
			c.draw_circle(p + Vector2(0, r * 0.25), r * 0.8, oscuro)
			c.draw_circle(p + Vector2(0, r * 0.25), r * 0.64, col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.22, -r * 0.95), Vector2(r * 0.44, r * 0.6)), Color(0.8, 0.75, 0.65))
		"tonico":
			# Frasco de cuello alto con tapón y una gota clara dentro (la tinta).
			c.draw_circle(p + Vector2(0, r * 0.25), r * 0.8, oscuro)
			c.draw_circle(p + Vector2(0, r * 0.25), r * 0.64, col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.2, -r * 0.95), Vector2(r * 0.4, r * 0.7)), Color(0.8, 0.75, 0.65))
			c.draw_rect(Rect2(p + Vector2(-r * 0.28, -r * 1.08), Vector2(r * 0.56, r * 0.2)), Color(0.55, 0.38, 0.22))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 0.05), p + Vector2(r * 0.2, r * 0.3), p + Vector2(0, r * 0.5), p + Vector2(-r * 0.2, r * 0.3)]), Color(1, 1, 1, 0.85))
		"tarro":
			# Tarro ancho de bálsamo con tapa de cuero y una cinta.
			c.draw_rect(Rect2(p + Vector2(-r * 0.8, -r * 0.35), Vector2(r * 1.6, r * 1.2)), oscuro)
			c.draw_rect(Rect2(p + Vector2(-r * 0.68, -r * 0.25), Vector2(r * 1.36, r * 1.0)), col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.9, -r * 0.7), Vector2(r * 1.8, r * 0.4)), Color(0.5, 0.32, 0.18))
			c.draw_rect(Rect2(p + Vector2(-r * 0.68, r * 0.1), Vector2(r * 1.36, r * 0.22)), Color(0.55, 0.32, 0.22))
			c.draw_circle(p + Vector2(-r * 0.35, -r * 0.05), r * 0.1, Color(1, 1, 1, 0.7))
		"infusion":
			# Frasco redondo con una ramita de brezo dentro.
			c.draw_circle(p + Vector2(0, r * 0.25), r * 0.8, oscuro)
			c.draw_circle(p + Vector2(0, r * 0.25), r * 0.64, col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.22, -r * 0.95), Vector2(r * 0.44, r * 0.6)), Color(0.8, 0.75, 0.65))
			c.draw_line(p + Vector2(0, r * 0.75), p + Vector2(0, -r * 0.1), Color(0.35, 0.75, 0.4), maxf(1.5, r * 0.14), true)
			for k in range(3):
				var yy: float = r * (0.5 - 0.22 * float(k))
				c.draw_circle(p + Vector2(-r * 0.2, yy), r * 0.1, Color(0.95, 0.8, 1.0))
				c.draw_circle(p + Vector2(r * 0.2, yy - r * 0.1), r * 0.1, Color(0.95, 0.8, 1.0))
		"seta":
			c.draw_rect(Rect2(p + Vector2(-r * 0.2, -r * 0.1), Vector2(r * 0.4, r * 0.8)), Color(0.93, 0.9, 0.82))
			c.draw_circle(p + Vector2(0, -r * 0.1), r * 0.8, oscuro)
			c.draw_circle(p + Vector2(0, -r * 0.15), r * 0.7, col)
			c.draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.12, Color(1, 1, 1, 0.8))
		"flor":
			for k in range(5):
				var a: float = TAU * float(k) / 5.0
				c.draw_circle(p + Vector2(cos(a), sin(a)) * r * 0.5, r * 0.38, col)
			c.draw_circle(p, r * 0.28, oscuro.lightened(0.3))
		"baya":
			for o in [Vector2(-0.45, 0.2), Vector2(0.4, 0.3), Vector2(0.0, -0.35)]:
				c.draw_circle(p + o * r, r * 0.42, oscuro)
				c.draw_circle(p + o * r, r * 0.34, col)
			c.draw_circle(p + Vector2(-0.1, -0.5) * r, r * 0.1, Color(1, 1, 1, 0.7))
		"hoja":
			for k in range(5):
				var a2: float = -PI * 0.5 + (float(k) - 2.0) * 0.5
				c.draw_line(p + Vector2(0, r * 0.7), p + Vector2(cos(a2), sin(a2)) * r * 0.95, col, maxf(1.5, r * 0.22))
		"piedra":
			var q := PackedVector2Array([p + Vector2(-r * 0.9, r * 0.5), p + Vector2(-r * 0.5, -r * 0.5), p + Vector2(r * 0.3, -r * 0.7), p + Vector2(r * 0.9, r * 0.1), p + Vector2(r * 0.5, r * 0.6)])
			c.draw_colored_polygon(q, col)
			c.draw_polyline(PackedVector2Array([q[0], q[1], q[2], q[3], q[4], q[0]]), oscuro, 1.5)
		"raiz":
			c.draw_line(p + Vector2(-r * 0.7, r * 0.5), p + Vector2(0, -r * 0.3), col, r * 0.4)
			c.draw_line(p + Vector2(0, -r * 0.3), p + Vector2(r * 0.7, -r * 0.7), col, r * 0.3)
			c.draw_line(p + Vector2(-r * 0.1, 0.0), p + Vector2(r * 0.6, r * 0.5), col, r * 0.25)
		_:
			var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)])
			c.draw_colored_polygon(pts, col)
			c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), oscuro, 1.5)
	# Aro del color de la calidad (los comunes no llevan): el épico se distingue de un vistazo en la bolsa.
	if calidad(id) != CALIDAD_COMUN:
		c.draw_arc(p, r * 1.15, 0.0, TAU, 24, color_calidad(id), maxf(1.5, r * 0.14), true)
