class_name Objetos
extends RefCounted

## CATÁLOGO DE OBJETOS Y REACCIONES DEL MUNDO.
##
## Un objeto es solo datos: nombre, descripción, color de su icono y forma de dibujarlo.
## Los ingredientes se consiguen haciendo REACCIONAR un objeto del mundo con un elemento
## (electrificar una seta, quemar una flor...). La tabla REACCIONES dice qué sale de cada
## cruce; no hay sistema de cocina, solo el objeto en la mochila para usarlo en recetas.

## forma: "frasco", "seta", "flor", "raiz", "cristal", "moneda", "tonico", "tarro", "infusion"
## Campos opcionales (24/10, menú de pestañas estilo Echoes of Wisdom): `usos` = lista de frases del panel «Usos conocidos» del Inventario (sin ella, el panel
## dice que aún no se le conoce ningún uso); `efecto` = los números de un consumible (los lee `Consumibles`, ÚNICO sitio donde viven).
const DATOS: Dictionary = {
	"oro": {"nombre": "Oro", "desc": "Moneda de oro", "color": Color(1.0, 0.85, 0.3), "forma": "moneda"},
	"pocion": {"nombre": "Poción de vida", "desc": "Cura vida. Equípala y usa Q", "color": Color(1.0, 0.35, 0.3), "forma": "frasco",
		"usos": ["Cura 40 de vida al beberla (1,5 s quieto)", "Se interrumpe si te golpean"], "efecto": {"cura": 40.0}},
	# Los otros tres consumibles del HUD (Q usa el equipado, R cambia). Números en `efecto`; el texto de `desc` los repite: si cambias uno, cambia el otro.
	"tonico_tinta": {"nombre": "Tónico de tinta", "desc": "Recarga un frasco de tinta vacío", "color": Color(0.30, 0.55, 1.0), "forma": "tonico",
		"usos": ["Recarga 1 frasco de reserva de tinta", "Solo sirve si falta algún frasco"], "efecto": {"frascos": 1}},
	"balsamo_protector": {"nombre": "Bálsamo protector", "desc": "Absorbe el próximo golpe durante 20 s", "color": Color(0.95, 0.74, 0.28), "forma": "tarro",
		"usos": ["Absorbe por completo el próximo golpe", "Dura 20 s; si nadie te pega, se pierde"], "efecto": {"dura": 20.0}},
	"infusion_brezo": {"nombre": "Infusión de brezo", "desc": "Regenera 3 de vida por segundo durante 12 s", "color": Color(0.66, 0.42, 0.86), "forma": "infusion",
		"usos": ["Regenera 3 de vida por segundo durante 12 s", "Un golpe no corta el efecto"], "efecto": {"dura": 12.0, "tasa": 3.0}},

	# Cosas del decorado con lógica: se recogen del escenario con E (ver recolectable.gd)
	"lavanda": {"nombre": "Lavanda", "desc": "Huele a calma. Ingrediente", "color": Color(0.7, 0.55, 0.95), "forma": "flor",
		"usos": ["Ingrediente de síntesis (próximamente)", "Calma a las criaturas del bosque"]},
	"baya": {"nombre": "Bayas", "desc": "Dulces y rojas. Ingrediente", "color": Color(0.85, 0.2, 0.35), "forma": "baya",
		"usos": ["Ingrediente de síntesis (próximamente)"]},
	"helecho": {"nombre": "Helecho", "desc": "Hojas frescas. Ingrediente", "color": Color(0.35, 0.75, 0.4), "forma": "hoja",
		"usos": ["Ingrediente de síntesis (próximamente)", "Base de la Infusión de brezo"]},
	"piedra": {"nombre": "Piedra", "desc": "Una piedra del camino. Ingrediente", "color": Color(0.62, 0.62, 0.66), "forma": "piedra"},
	"flor_silvestre": {"nombre": "Flor silvestre", "desc": "Crece por todo el prado. Ingrediente", "color": Color(1.0, 0.9, 0.4), "forma": "flor"},

	"seta": {"nombre": "Seta", "desc": "Una seta del bosque", "color": Color(0.85, 0.75, 0.6), "forma": "seta"},
	"seta_electrificada": {"nombre": "Seta electrificada", "desc": "Chisporrotea. Ingrediente", "color": Color(1.0, 0.95, 0.35), "forma": "seta"},
	"seta_asada": {"nombre": "Seta asada", "desc": "Huele a brasa. Ingrediente", "color": Color(0.85, 0.45, 0.2), "forma": "seta"},
	"seta_helada": {"nombre": "Seta helada", "desc": "Cubierta de escarcha. Ingrediente", "color": Color(0.6, 0.9, 1.0), "forma": "seta"},
	"seta_humeda": {"nombre": "Seta empapada", "desc": "Chorrea agua. Ingrediente", "color": Color(0.45, 0.65, 0.95), "forma": "seta"},
	"esporas": {"nombre": "Esporas", "desc": "Dispersadas por el viento. Ingrediente", "color": Color(0.75, 0.9, 0.6), "forma": "cristal"},

	"flor_luna": {"nombre": "Flor de luna", "desc": "Pétalos pálidos", "color": Color(0.85, 0.85, 1.0), "forma": "flor"},
	"flor_ardiente": {"nombre": "Flor ardiente", "desc": "Sus pétalos arden sin quemarse. Ingrediente", "color": Color(1.0, 0.5, 0.2), "forma": "flor"},
	"flor_rocio": {"nombre": "Flor de rocío", "desc": "Gotas que no se secan. Ingrediente", "color": Color(0.4, 0.8, 1.0), "forma": "flor"},
	"flor_chispa": {"nombre": "Flor cargada", "desc": "Pica al tocarla. Ingrediente", "color": Color(1.0, 0.95, 0.4), "forma": "flor"},
	"petalos": {"nombre": "Pétalos al viento", "desc": "Ligeros como el aire. Ingrediente", "color": Color(1.0, 0.75, 0.9), "forma": "cristal"},
	"flor_escarcha": {"nombre": "Flor de escarcha", "desc": "Fría y quebradiza. Ingrediente", "color": Color(0.7, 0.95, 1.0), "forma": "flor"},

	"raiz": {"nombre": "Raíz", "desc": "Raíz retorcida", "color": Color(0.6, 0.45, 0.3), "forma": "raiz"},
	"raiz_cenizas": {"nombre": "Raíz carbonizada", "desc": "Negra y dura. Ingrediente", "color": Color(0.3, 0.27, 0.27), "forma": "raiz"},
	"raiz_hinchada": {"nombre": "Raíz hinchada", "desc": "Llena de agua. Ingrediente", "color": Color(0.5, 0.7, 0.9), "forma": "raiz"},
	"raiz_magnetica": {"nombre": "Raíz magnética", "desc": "Atrae el metal. Ingrediente", "color": Color(0.8, 0.85, 1.0), "forma": "raiz"},
	"cristal_tierra": {"nombre": "Cristal de tierra", "desc": "Se forma al golpear la raíz con tierra. Ingrediente", "color": Color(0.7, 0.55, 0.3), "forma": "cristal"},

	# Materiales de la Cueva (docs/MATERIALES_CUEVA.md). `calidad` ausente = común. Formas y colores: las que ya había, sin arte nuevo.
	"seta_resonante": {"nombre": "Seta resonante", "desc": "Madura al compás del pulso. Ingrediente", "color": Color(0.6, 0.85, 1.0), "forma": "seta"},
	"alga_cueva": {"nombre": "Alga de cueva", "desc": "Atrapada en el hielo de la charca. Ingrediente", "color": Color(0.35, 0.7, 0.62), "forma": "hoja"},
	"alga_seca": {"nombre": "Alga seca", "desc": "Quebradiza y salada. Ingrediente", "color": Color(0.68, 0.6, 0.38), "forma": "hoja"},
	"mineral_veta": {"nombre": "Mineral de veta", "desc": "Un trozo de la veta del pulso. Ingrediente", "color": Color(0.5, 0.58, 0.78), "forma": "piedra"},
	"esquirla_cristal": {"nombre": "Esquirla de cristal", "desc": "Zumba muy bajito. Ingrediente", "color": Color(0.78, 0.92, 1.0), "forma": "cristal"},
	"basalto": {"nombre": "Basalto", "desc": "Roca de lava enfriada. Ingrediente", "color": Color(0.36, 0.35, 0.38), "forma": "piedra"},
	"colmillo_goblin": {"nombre": "Colmillo de goblin", "desc": "Amarillento y astillado. Ingrediente", "color": Color(0.92, 0.88, 0.74), "forma": "raiz"},
	# Épicos: ingredientes para mejorar al PERSONAJE (vida, tinta, pigmentos, ropa), no variables de un glifo (PLAN_PULSO_RESONANTE §10.4).
	"nucleo_eco": {"nombre": "Núcleo de eco", "desc": "Late dentro como un segundo corazón. Mejora al personaje", "color": Color(0.72, 0.42, 1.0), "forma": "cristal", "calidad": "epico",
		"usos": ["Mejora al personaje (vida o tinta)", "Material épico: no se vende"]},
	"geoda_resonante": {"nombre": "Geoda resonante", "desc": "Hueca y cantarina. Mejora al personaje", "color": Color(0.62, 0.36, 0.95), "forma": "cristal", "calidad": "epico"},
}

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

## Dónde sale cada mineral de un reactivo (gancho de la fase 3 del pulso: la veta y el cristal aún no llaman a esto).
## reactivo del mundo -> {via: lo que le hace falta (elemento lanzado o golpes), da: el material}
const MINERALES: Dictionary = {
	"veta": {"via": "tierra", "golpes": 1, "da": "mineral_veta"},
	"cristal_resonante": {"via": "golpe", "golpes": 2, "da": "esquirla_cristal"},
	"jarron": {"via": "romper", "golpes": 1, "da": "esquirla_cristal"},
}

## Plantas del mundo (las que se ven en el suelo antes de reaccionar).
## base: objeto original · tabla: etiqueta del elemento -> objeto resultante
const PLANTAS: Dictionary = {
	"seta": {"base": "seta", "tabla": {
		"rayo": "seta_electrificada", "fuego": "seta_asada", "hielo": "seta_helada",
		"agua": "seta_humeda", "viento": "esporas"}},
	"flor": {"base": "flor_luna", "tabla": {
		"fuego": "flor_ardiente", "agua": "flor_rocio", "rayo": "flor_chispa",
		"viento": "petalos", "hielo": "flor_escarcha"}},
	"raiz": {"base": "raiz", "tabla": {
		"fuego": "raiz_cenizas", "agua": "raiz_hinchada", "rayo": "raiz_magnetica",
		"tierra": "cristal_tierra"}},
	# La Cueva: el alga solo se coge con la charca helada (ver `coge_si` en Recolectable3D); el fuego la seca.
	"alga": {"base": "alga_cueva", "tabla": {"fuego": "alga_seca"}},
}

const ETIQUETAS: Array = ["rayo", "fuego", "hielo", "agua", "viento", "tierra"]

## --- Categorías de la bolsa (Fase 14.3) ---
## La bolsa ordena SIEMPRE por categoría: primero los componentes (ingredientes), luego las pociones, al final los objetos clave (llaves
## y cosas de misión). Dentro de cada una, por nombre. Lo que no está en CLAVE ni en CURAN es un componente.
const CATEGORIAS: Array = ["componentes", "pociones", "clave"]
const CLAVE: PackedStringArray = ["llave", "llave_goblin", "perla", "aletas"]
## Objetos que curan: la bolsa les pone un corazón rojo (como Echoes of Wisdom).
const CURAN: PackedStringArray = ["pocion", "infusion_brezo"]
## Los consumibles del HUD, en el orden en que R los recorre. Q usa el equipado (ver `Consumibles`). Van en la categoría de pociones.
const CONSUMIBLES: PackedStringArray = ["pocion", "tonico_tinta", "balsamo_protector", "infusion_brezo"]


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


static func categoria(id: String) -> String:
	if CURAN.has(id) or CONSUMIBLES.has(id):
		return "pociones"
	if CLAVE.has(id):
		return "clave"
	return "componentes"


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
