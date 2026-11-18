class_name PaginaMapa
extends Control
## La pestaña MAPA del menú (13/11/2026): el mapa de la zona que Mid va cartografiando al andar (Cartografia), dibujado a tinta
## sobre el pergamino. Lo no visitado queda en blanco; los caminos se trazan como rutas, la ruta que Mid ha pisado va punteada,
## las salidas llevan su nombre y un punto rojo marca dónde está Mid. Cerrada (con candado) hasta el encargo de Marimanta.

const PIE := 34.0
const TAM_CASILLA := 13.0           ## px por casilla con zoom (antes cabía el mapa entero: ~6 px)
const C_ARBOL := Color(0.29, 0.35, 0.21, 0.62)
const C_HIERBA := Color(0.55, 0.62, 0.36, 0.30)
const C_HIERBA_ALTA := Color(0.45, 0.55, 0.28, 0.42)
const C_AGUA := Color(0.30, 0.48, 0.66, 0.78)
const C_PIEDRA := Color(0.52, 0.50, 0.47, 0.50)
const C_CAMINO := Color(0.66, 0.50, 0.30, 0.55)
const C_RUTA := Color(0.62, 0.16, 0.12, 0.85)
const C_MID := Color(0.80, 0.12, 0.10)

var menu: Node


func _draw() -> void:
	var f: Font = TemaInterfaz.fuente()
	if not Cartografia.desbloqueado():
		_cerrada(f)
		return
	if Cartografia.alto() == 0:
		draw_string(f, Vector2(0, size.y * 0.45), "Esta zona aún no tiene mapa.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, MenuPestanas.TINTA)
		return
	var w := Cartografia.ancho()
	var h := Cartografia.alto()
	# Zoom: casillas de TAM_CASILLA px centradas en Mid (o en lo descubierto si no está en la zona); sin pasarse del borde del mapa.
	var vista := Vector2(size.x, size.y - PIE)
	var s := maxf(TAM_CASILLA, minf(vista.x / w, vista.y / h))
	var foco := Vector2(Cartografia.jugador) + Vector2(0.5, 0.5) if Cartografia.jugador.x >= 0 else _centro_descubierto()
	var o := vista * 0.5 - foco * s
	o.x = clampf(o.x, vista.x - w * s, 0.0) if w * s > vista.x else (vista.x - w * s) * 0.5
	o.y = clampf(o.y, vista.y - h * s, 0.0) if h * s > vista.y else (vista.y - h * s) * 0.5
	# 1) Terreno descubierto.
	for y in range(h):
		for x in range(w):
			var c := Vector2i(x, y)
			if not Cartografia.visto(c):
				continue
			var r := Rect2(o + Vector2(x, y) * s, Vector2(s, s))
			match Cartografia.letra(c):
				"#":
					draw_circle(r.get_center(), s * 0.46, C_ARBOL)
				"~":
					draw_rect(r, C_AGUA)
				"R", "c", "-", "L":
					draw_rect(r, C_PIEDRA)
				"v":
					draw_rect(r, C_HIERBA_ALTA)
				"g":
					draw_rect(r, C_CAMINO)
				" ":
					pass
				_:
					draw_rect(r, C_HIERBA)
	# 2) Rutas: los caminos de tierra se trazan a tinta de casilla a casilla.
	for y in range(h):
		for x in range(w):
			var c := Vector2i(x, y)
			if Cartografia.letra(c) != "g" or not Cartografia.visto(c):
				continue
			var p := o + (Vector2(x, y) + Vector2(0.5, 0.5)) * s
			var solo := true
			for v in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var n: Vector2i = c + v
				if Cartografia.letra(n) == "g" and Cartografia.visto(n):
					solo = false
					if v.x > 0 or v.y > 0:
						draw_line(p, p + Vector2(v) * s, MenuPestanas.TINTA, maxf(1.5, s * 0.22), true)
			if solo:
				draw_circle(p, s * 0.14, MenuPestanas.TINTA)
	# 3) La ruta que ha pisado Mid, punteada.
	for y in range(h):
		for x in range(w):
			if Cartografia.pisado(Vector2i(x, y)):
				draw_circle(o + (Vector2(x, y) + Vector2(0.5, 0.5)) * s, maxf(1.2, s * 0.11), C_RUTA)
	# 4) Salidas con su nombre.
	for sal in Cartografia.salidas:
		var c: Vector2i = sal["celda"]
		if not Cartografia.visto(c):
			continue
		var p := o + (Vector2(c) + Vector2(0.5, 0.5)) * s
		draw_circle(p, s * 0.55, MenuPestanas.DORADO)
		draw_arc(p, s * 0.55, 0.0, TAU, 20, MenuPestanas.TINTA, 1.5, true)
		var nombre := String(sal["nombre"])
		var ancho_txt := f.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var px := clampf(p.x + s, 0.0, size.x - ancho_txt)
		draw_string(f, Vector2(px, p.y + 5.0), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MenuPestanas.TINTA)
	# 5) Mid.
	var j := Cartografia.jugador
	if j.x >= 0:
		var pm := o + (Vector2(j) + Vector2(0.5, 0.5)) * s
		draw_circle(pm, maxf(4.0, s * 0.45), Color.WHITE)
		draw_circle(pm, maxf(3.0, s * 0.32), C_MID)
	# 6) Marco del mapa y pie.
	var marco := Rect2(o, Vector2(w, h) * s).intersection(Rect2(Vector2.ZERO, vista))
	draw_rect(Rect2(0.0, vista.y, size.x, PIE), BolsaUI.PERGAMINO)      # el pie tapa lo que asome del mapa por abajo
	draw_rect(marco, MenuPestanas.TINTA_SUAVE, false, 1.5)
	var pc := Cartografia.porcentaje()
	var pie := "%s · cartografiado %d %%" % [Cartografia.nivel.replace("_", " "), pc]
	if Cartografia.nivel == Cartografia.NIVEL_ENCARGO and not Flags.i().tiene(EncargoMarimanta.ENTREGADO):
		pie += "   ·   encargo de Marimanta: %d %%%s" % [Cartografia.META, "  ✓" if pc >= Cartografia.META else ""]
	draw_string(f, Vector2(0, size.y - 8.0), pie, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, MenuPestanas.TINTA)


func _ready() -> void:
	clip_contents = true            # con zoom el mapa se sale de la página: se recorta


## Centro (en casillas) de lo cartografiado, para cuando Mid está en otra zona.
func _centro_descubierto() -> Vector2:
	var suma := Vector2.ZERO
	var n := 0
	for y in range(Cartografia.alto()):
		for x in range(Cartografia.ancho()):
			if Cartografia.visto(Vector2i(x, y)):
				suma += Vector2(x, y)
				n += 1
	return suma / n + Vector2(0.5, 0.5) if n > 0 else Vector2(Cartografia.ancho(), Cartografia.alto()) * 0.5


func _cerrada(f: Font) -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.36)
	draw_circle(c, 70.0, Color(BolsaUI.PERGAMINO_CLARO, 0.9))
	draw_arc(c, 70.0, 0.0, TAU, 48, Color(MenuPestanas.DORADO, 0.8), 3.0, true)
	MenuPestanas.icono(self, "mapa", c, 36.0, Color(0.31, 0.23, 0.15, 0.6), BolsaUI.PERGAMINO_CLARO)
	# Candado.
	var k := c + Vector2(44.0, 44.0)
	draw_arc(k + Vector2(0, -10), 9.0, PI, TAU, 16, MenuPestanas.TINTA, 3.0, true)
	draw_rect(Rect2(k + Vector2(-13, -10), Vector2(26, 20)), MenuPestanas.DORADO.darkened(0.2))
	draw_string(f, Vector2(0.0, c.y + 112.0), "Sin cartografiar", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, MenuPestanas.DORADO.darkened(0.15))
	draw_string(f, Vector2(80.0, c.y + 142.0), "La Maestre Marimanta te enseñará a cartografiar la Fraga.", HORIZONTAL_ALIGNMENT_CENTER, size.x - 160.0, 15, MenuPestanas.TINTA)
