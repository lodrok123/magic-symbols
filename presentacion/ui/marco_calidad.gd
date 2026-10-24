class_name MarcoCalidad
extends RefCounted

## MARCOS POR CALIDAD PARA LOS ICONOS DE OBJETO (24/10; PLAN_PULSO_RESONANTE §7, referencia Zelda: Echoes of Wisdom).
##   común       marco sobrio: un filo fino gris cálido, sin brillo.
##   épico       marco morado con brillo interior y exterior suave, y un latido lento del borde.
##   legendario  marco dorado con bisel (filo oscuro por fuera, claro por dentro), remaches en las cuatro esquinas, brillo cálido
##               y un destello que recorre el borde de vez en cuando.
## Cómo está hecho: la textura del marco (anillo + brillos, transparente por dentro) se GENERA en código la primera vez que se pide, con una
## distancia a un rectángulo redondeado, y se usa como NinePatch (StyleBoxTexture): sirve para cualquier tamaño de hueco sin deformar las esquinas.
## Sin PNG ni importación: no hay nada que esperar ni que perder. Las medidas y los colores son las constantes de abajo.
## Uso:
##   MarcoCalidad.dibujar(self, Rect2(Vector2.ZERO, size), "epico", tiempo)      # desde un _draw (el brillo animado pide redibujar cada fotograma: ver `anima`)
##   MarcoCalidad.Icono.new()  .configurar("nucleo_eco")                            # un control suelto: placa oscura + icono + marco (avisos y recompensas)
## Es solo aspecto: no lee ni cambia nada del juego.

const LADO_TEX: int = 64                  ## lado de la textura generada (px)
const MARGEN_NUEVE: float = 20.0          ## margen del nine-patch: las esquinas (radio + brillo) no se estiran
const INSET: float = 3.0                  ## aire entre el borde de la textura y el filo, para que quepa el brillo exterior
const RADIO_PX: float = 14.0              ## radio de las esquinas del marco (px de textura)
const PERIODO_LATIDO_S: float = 2.4       ## épico: lo que tarda el borde en latir una vez
const LATIDO_ALFA_MIN: float = 0.08
const LATIDO_ALFA_MAX: float = 0.30
const PERIODO_DESTELLO_S: float = 3.2     ## legendario: un destello cada tanto
const FRACCION_RECORRIDO: float = 0.55    ## del periodo, lo que dura el recorrido del destello (el resto descansa)
const COLA_PUNTOS: int = 7                ## puntos de la cola del destello
const COLA_SEPARACION: float = 0.012      ## fracción del perímetro entre punto y punto de la cola
const DESTELLO_RADIO_PX: float = 2.6
const REMACHE_RADIO_PX: float = 2.3

## Aspecto de cada calidad. `grosor`: ancho del filo. `filo_ext`/`filo_int`: color por fuera y por dentro del filo (el bisel).
## `brillo_in`/`brillo_out`: color con alfa del resplandor hacia dentro y hacia fuera. `ancho_in`: cuánto entra el resplandor interior.
const MARCOS: Dictionary = {
	"comun": {"grosor": 2.0, "filo_ext": Color(0.50, 0.46, 0.40, 1.0), "filo_int": Color(0.74, 0.70, 0.63, 1.0),
		"brillo_in": Color(1, 1, 1, 0.0), "brillo_out": Color(0, 0, 0, 0.0), "ancho_in": 0.0, "remaches": false},
	"epico": {"grosor": 3.0, "filo_ext": Color(0.42, 0.18, 0.72, 1.0), "filo_int": Color(0.78, 0.52, 1.0, 1.0),
		"brillo_in": Color(0.70, 0.40, 1.0, 0.55), "brillo_out": Color(0.70, 0.40, 1.0, 0.45), "ancho_in": 7.0, "remaches": false},
	"legendario": {"grosor": 3.0, "filo_ext": Color(0.62, 0.40, 0.08, 1.0), "filo_int": Color(1.0, 0.92, 0.55, 1.0),
		"brillo_in": Color(1.0, 0.80, 0.30, 0.60), "brillo_out": Color(1.0, 0.78, 0.25, 0.50), "ancho_in": 8.0, "remaches": true},
}
const COLOR_REMACHE: Color = Color(1.0, 0.95, 0.70, 1.0)
const COLOR_DESTELLO: Color = Color(1.0, 0.97, 0.80, 1.0)

static var _estilos: Dictionary = {}
static var _texturas: Dictionary = {}


## Una calidad válida (si no existe, común).
static func normalizar(cal: String) -> String:
	return cal if MARCOS.has(cal) else Objetos.CALIDAD_COMUN


## ¿La calidad lleva animación? (común no: así los huecos sin brillo no gastan redibujados).
static func anima(cal: String) -> bool:
	return normalizar(cal) != Objetos.CALIDAD_COMUN


## Color de acento de la calidad (el del filo de dentro): para teñir un detalle del mismo tono.
static func color_acento(cal: String) -> Color:
	return (MARCOS[normalizar(cal)] as Dictionary)["filo_int"]


## Distancia con signo (px) de `p` al rectángulo redondeado de medio tamaño `mitad`, radio `radio`, centrado en `c`. Negativa dentro.
static func _dist(p: Vector2, c: Vector2, mitad: Vector2, radio: float) -> float:
	var q: Vector2 = (p - c).abs() - (mitad - Vector2(radio, radio))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radio


## `base` con `arriba` encima (mezcla alfa normal, colores no premultiplicados).
static func _sobre(base: Color, arriba: Color) -> Color:
	var a: float = arriba.a + base.a * (1.0 - arriba.a)
	if a <= 0.0001:
		return Color(0, 0, 0, 0)
	var rgb: Color = (arriba * arriba.a + base * base.a * (1.0 - arriba.a)) / a
	return Color(rgb.r, rgb.g, rgb.b, a)


## Genera la imagen del marco de una calidad: anillo con bisel, resplandor hacia dentro y hacia fuera, y remaches si los lleva.
static func generar_imagen(cal: String) -> Image:
	var m: Dictionary = MARCOS[normalizar(cal)]
	var grosor: float = float(m["grosor"])
	var img := Image.create(LADO_TEX, LADO_TEX, false, Image.FORMAT_RGBA8)
	var c := Vector2(LADO_TEX, LADO_TEX) * 0.5
	var mitad := Vector2(LADO_TEX, LADO_TEX) * 0.5 - Vector2(INSET, INSET)
	var brillo_in: Color = m["brillo_in"]
	var brillo_out: Color = m["brillo_out"]
	var ancho_in: float = float(m["ancho_in"])
	for y in range(LADO_TEX):
		for x in range(LADO_TEX):
			var d: float = _dist(Vector2(x + 0.5, y + 0.5), c, mitad, RADIO_PX)
			var px: Color = Color(0, 0, 0, 0)
			# Resplandor exterior (entre el filo y el borde de la textura).
			if d > 0.0 and brillo_out.a > 0.0:
				var k: float = clampf(1.0 - d / INSET, 0.0, 1.0)
				px = _sobre(px, Color(brillo_out.r, brillo_out.g, brillo_out.b, brillo_out.a * k * k))
			# Resplandor interior (más intenso pegado al filo).
			if d < -grosor and ancho_in > 0.0:
				var k2: float = clampf(1.0 - (-d - grosor) / ancho_in, 0.0, 1.0)
				px = _sobre(px, Color(brillo_in.r, brillo_in.g, brillo_in.b, brillo_in.a * k2 * k2))
			# El filo: cobertura suave en sus dos bordes y color de fuera a dentro (bisel).
			var cobertura: float = clampf(0.5 - d, 0.0, 1.0) * clampf(0.5 + d + grosor, 0.0, 1.0)
			if cobertura > 0.0:
				var t: float = clampf(-d / grosor, 0.0, 1.0)
				var col: Color = (m["filo_ext"] as Color).lerp(m["filo_int"] as Color, t)
				px = _sobre(px, Color(col.r, col.g, col.b, cobertura))
			img.set_pixel(x, y, px)
	if bool(m["remaches"]):
		_remaches(img, c, mitad, grosor)
	return img


## Cuatro remaches en las esquinas, sobre el filo (en el punto medio de cada arco).
static func _remaches(img: Image, c: Vector2, mitad: Vector2, grosor: float) -> void:
	var radio_filo: float = RADIO_PX - grosor * 0.5
	var desde: Vector2 = mitad - Vector2(RADIO_PX, RADIO_PX)
	var diag: float = radio_filo * 0.70710678
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p: Vector2 = c + Vector2(float(sx) * (desde.x + diag), float(sy) * (desde.y + diag))
			for y in range(int(p.y) - 4, int(p.y) + 5):
				for x in range(int(p.x) - 4, int(p.x) + 5):
					if x < 0 or y < 0 or x >= LADO_TEX or y >= LADO_TEX:
						continue
					var dd: float = Vector2(x + 0.5, y + 0.5).distance_to(p)
					var cob: float = clampf(REMACHE_RADIO_PX + 0.5 - dd, 0.0, 1.0)
					if cob > 0.0:
						var borde: float = clampf(dd - (REMACHE_RADIO_PX - 0.9), 0.0, 1.0)
						var col: Color = COLOR_REMACHE.lerp((MARCOS["legendario"] as Dictionary)["filo_ext"] as Color, borde)
						img.set_pixel(x, y, _sobre(img.get_pixel(x, y), Color(col.r, col.g, col.b, cob)))


## La textura del marco de una calidad (una sola vez).
static func textura(cal: String) -> Texture2D:
	var k: String = normalizar(cal)
	if not _texturas.has(k):
		_texturas[k] = ImageTexture.create_from_image(generar_imagen(k))
	return _texturas[k]


## El NinePatch de una calidad (una sola vez): úsalo con `draw_style_box` o como `StyleBox` de un panel.
static func estilo(cal: String) -> StyleBoxTexture:
	var k: String = normalizar(cal)
	if not _estilos.has(k):
		var s := StyleBoxTexture.new()
		s.texture = textura(k)
		s.texture_margin_left = MARGEN_NUEVE
		s.texture_margin_right = MARGEN_NUEVE
		s.texture_margin_top = MARGEN_NUEVE
		s.texture_margin_bottom = MARGEN_NUEVE
		_estilos[k] = s
	return _estilos[k]


## Posiciones del contorno del filo de `r`, con la distancia acumulada (para recorrerlo con el destello). Devuelve [puntos, acumulado].
static func _perimetro(r: Rect2, grosor: float) -> Array:
	var pts: PackedVector2Array = BolsaUI.camino(r.grow(-(INSET + grosor * 0.5)), RADIO_PX - grosor * 0.5)
	var acum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		acum.append(acum[i - 1] + pts[i].distance_to(pts[i - 1]))
	return [pts, acum]


## El punto que está a la fracción `f` (0..1) del perímetro.
static func punto_en(per: Array, f: float) -> Vector2:
	var pts: PackedVector2Array = per[0]
	var acum: PackedFloat32Array = per[1]
	var total: float = acum[acum.size() - 1]
	var d: float = fposmod(f, 1.0) * total
	for i in range(1, pts.size()):
		if acum[i] >= d:
			var seg: float = acum[i] - acum[i - 1]
			return pts[i - 1].lerp(pts[i], (d - acum[i - 1]) / maxf(seg, 0.0001))
	return pts[pts.size() - 1]


## Dónde va el destello legendario en el instante `t` (s): fracción del perímetro, o -1 mientras descansa.
static func posicion_destello(t: float) -> float:
	var fase: float = fposmod(t, PERIODO_DESTELLO_S) / PERIODO_DESTELLO_S
	if fase >= FRACCION_RECORRIDO:
		return -1.0
	return fase / FRACCION_RECORRIDO


## Alfa del latido del borde épico en el instante `t` (s).
static func alfa_latido(t: float) -> float:
	var s: float = 0.5 - 0.5 * cos(TAU * t / PERIODO_LATIDO_S)
	return lerpf(LATIDO_ALFA_MIN, LATIDO_ALFA_MAX, s)


## Dibuja el marco de `cal` sobre `r` en el CanvasItem `c`, con las animaciones de su calidad en el instante `t` (s; por defecto el del reloj).
static func dibujar(c: CanvasItem, r: Rect2, cal: String, t: float = -1.0) -> void:
	var k: String = normalizar(cal)
	if t < 0.0:
		t = float(Time.get_ticks_msec()) / 1000.0
	c.draw_style_box(estilo(k), r)
	if k == Objetos.CALIDAD_COMUN:
		return
	var m: Dictionary = MARCOS[k]
	var grosor: float = float(m["grosor"])
	var per: Array = _perimetro(r, grosor)
	if k == Objetos.CALIDAD_EPICO:
		var col: Color = m["filo_int"]
		c.draw_polyline(per[0] as PackedVector2Array, Color(col.r, col.g, col.b, alfa_latido(t)), grosor * 2.2, true)
		return
	var f: float = posicion_destello(t)
	if f < 0.0:
		return
	for i in range(COLA_PUNTOS):
		var p: Vector2 = punto_en(per, f - float(i) * COLA_SEPARACION)
		var a: float = 1.0 - float(i) / float(COLA_PUNTOS)
		# El destello entra y sale suave (no aparece de golpe en una esquina).
		var borde_t: float = minf(minf(f, 1.0 - f) * 12.0, 1.0)
		c.draw_circle(p, DESTELLO_RADIO_PX * (0.45 + 0.55 * a), Color(COLOR_DESTELLO.r, COLOR_DESTELLO.g, COLOR_DESTELLO.b, 0.85 * a * a * borde_t))


## UN ICONO CON SU MARCO como control suelto: placa oscura redondeada, el icono del objeto dibujado dentro y el marco de su calidad encima.
## Es lo que sale en los avisos de «has cogido…» y lo que puede enseñar un cofre. `configurar(id)` lee la calidad de `Objetos`;
## `configurar_calidad(id, cal)` fuerza la calidad (el glifo legendario del cofre no es un objeto de DATOS).
class Icono extends Control:
	const LADO_PX: float = 40.0
	const PLACA: Color = Color(0.07, 0.06, 0.11, 0.95)
	const MARGEN_ICONO: float = 0.3         ## del lado: el icono ocupa el resto
	var id: String = ""
	var calidad: String = Objetos.CALIDAD_COMUN

	func _init() -> void:
		custom_minimum_size = Vector2(LADO_PX, LADO_PX)
		size = Vector2(LADO_PX, LADO_PX)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func configurar(p_id: String) -> void:
		configurar_calidad(p_id, Objetos.calidad(p_id))

	func configurar_calidad(p_id: String, cal: String) -> void:
		id = p_id
		calidad = MarcoCalidad.normalizar(cal)
		set_process(MarcoCalidad.anima(calidad))
		queue_redraw()

	func _ready() -> void:
		set_process(MarcoCalidad.anima(calidad))       # al entrar en el árbol Godot enciende _process solo: el común vuelve a apagarlo

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var placa := StyleBoxFlat.new()
		placa.bg_color = PLACA
		placa.set_corner_radius_all(int(MarcoCalidad.RADIO_PX) - 2)
		placa.anti_aliasing = true
		placa.draw(get_canvas_item(), r.grow(-MarcoCalidad.INSET))
		if id != "":
			Objetos.dibujar(self, id, size * 0.5, size.x * (0.5 - MARGEN_ICONO) + 2.0)
		MarcoCalidad.dibujar(self, r, calidad)
