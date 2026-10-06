class_name Objetos
extends RefCounted

## CATÁLOGO DE OBJETOS Y REACCIONES DEL MUNDO.
##
## Un objeto es solo datos: nombre, descripción, color de su icono y forma de dibujarlo.
## Los ingredientes se consiguen haciendo REACCIONAR un objeto del mundo con un elemento
## (electrificar una seta, quemar una flor...). La tabla REACCIONES dice qué sale de cada
## cruce; no hay sistema de cocina, solo el objeto en la mochila para usarlo en recetas.

## forma: "frasco", "seta", "flor", "raiz", "cristal", "moneda"
const DATOS: Dictionary = {
	"oro": {"nombre": "Oro", "desc": "Moneda de oro", "color": Color(1.0, 0.85, 0.3), "forma": "moneda"},
	"pocion": {"nombre": "Poción de vida", "desc": "Cura vida (Q para usar)", "color": Color(1.0, 0.35, 0.3), "forma": "frasco"},

	# Cosas del decorado con lógica: se recogen del escenario con E (ver recolectable.gd)
	"lavanda": {"nombre": "Lavanda", "desc": "Huele a calma. Ingrediente", "color": Color(0.7, 0.55, 0.95), "forma": "flor"},
	"baya": {"nombre": "Bayas", "desc": "Dulces y rojas. Ingrediente", "color": Color(0.85, 0.2, 0.35), "forma": "baya"},
	"helecho": {"nombre": "Helecho", "desc": "Hojas frescas. Ingrediente", "color": Color(0.35, 0.75, 0.4), "forma": "hoja"},
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
}

const ETIQUETAS: Array = ["rayo", "fuego", "hielo", "agua", "viento", "tierra"]


static func existe(id: String) -> bool:
	return DATOS.has(id)


static func nombre(id: String) -> String:
	return String(DATOS.get(id, {}).get("nombre", id))


static func color(id: String) -> Color:
	return DATOS.get(id, {}).get("color", Color.WHITE)


static func es_ingrediente(id: String) -> bool:
	return id != "oro" and id != "pocion"


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
