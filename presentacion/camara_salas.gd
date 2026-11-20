extends RefCounted
## Sin class_name (para no depender de la caché de clases al lanzar con --script): se usa con
## `const CamaraSalas = preload("res://presentacion/camara_salas.gd")`.
## 20/11/2026 · Cámara confinada a la sala (lo enciende `camara_por_sala` de la maqueta; de serie en los niveles del generador de mapas).
## La cámara se frena cuando el BORDE DEL ENCUADRE sobre el suelo llega al límite de la sala, antes de que el personaje toque
## el muro; en los pasillos solo la frena el borde del mapa. Si la sala no cabe en el encuadre, la cámara se acerca poco a poco
## (nunca de golpe) y recupera el zoom pedido al salir a una sala grande. El ángulo y el giro no cambian (cámara fija).
## Los cálculos de huella y límite vienen del laboratorio de cámara de cuevas (`laboratorios/camara_bordes_bosque.gd`).
##
## DÓNDE SE DECLARAN LAS SALAS. En el mapa del nivel (`mundo/datos_nivel/mapas/<nivel>.txt`), una línea por sala, con las
## casillas de suelo de la esquina noroeste y sureste (las dos incluidas):
##   ; camara <x0>,<y0>..<x1>,<y1>
## Sin líneas `; camara` la cámara se confina solo al mapa.

## Hasta qué zoom (tamaño de la cámara ortográfica) se acerca como mucho; en una sala que ni así cabe, la cámara se centra en
## ella en el eje que no cabe (se ve algo de fuera). De serie el zoom es 6.
const ZOOM_MINIMO_SALA: float = 3.5
## Acercamiento y alejamiento automático: arranca y frena suave (amortiguado), tarda ~1 s y nunca pasa de VELOCIDAD_ZOOM.
const TIEMPO_ZOOM: float = 0.35
const VELOCIDAD_ZOOM: float = 3.0
## Rapidez con la que el límite pasa de una sala a la siguiente (1/s).
const RAPIDEZ_LIMITE: float = 7.0
## Desplazamiento máximo del foco por segundo mientras cambia el límite (que no dé un tirón al cruzar una puerta).
const VELOCIDAD_FOCO: float = 8.0
## Margen al norte (la cabeza del personaje se proyecta hacia arriba en pantalla) y al sur, en casillas.
const MARGEN_NORTE: float = 0.5
const MARGEN_SUR: float = 0.25


## Las salas de cámara de un mapa (líneas `; camara`), en casillas del juego.
static func leer(texto: String) -> Array[Rect2i]:
	var salas: Array[Rect2i] = []
	for bruta in texto.split("\n"):
		var linea: String = bruta.strip_edges()
		if not linea.begins_with("; camara "):
			continue
		var partes: PackedStringArray = linea.substr(9).strip_edges().split("..")
		if partes.size() != 2:
			continue
		var a: PackedStringArray = partes[0].split(",")
		var b: PackedStringArray = partes[1].split(" ")[0].split(",")
		if a.size() != 2 or b.size() != 2:
			continue
		var p0 := Vector2i(int(a[0]), int(a[1]))
		var p1 := Vector2i(int(b[0]), int(b[1]))
		salas.append(Rect2i(p0.min(p1), (p1 - p0).abs() + Vector2i.ONE))
	return salas


## La sala (en unidades del mundo, X/Z) donde la cámara se puede mover, con el margen norte y sur.
static func rect_sala(sala: Rect2i, lado: float, mapa: Rect2) -> Rect2:
	var r := Rect2(Vector2(sala.position) * lado, Vector2(sala.size) * lado)
	return r.grow_individual(0.0, lado * MARGEN_NORTE, 0.0, lado * MARGEN_SUR).intersection(mapa)


## Lo que se ve del suelo, relativo al punto del suelo en el centro de la pantalla. Cámara ortográfica.
static func huella(camara: Camera3D, y_suelo: float = 0.0) -> Rect2:
	var tam := camara.get_viewport().get_visible_rect().size
	var plano := Plane(Vector3.UP, y_suelo)
	var centro: Variant = plano.intersects_ray(camara.project_ray_origin(tam * 0.5), camara.project_ray_normal(tam * 0.5))
	if centro == null:
		return Rect2()
	var rect := Rect2()
	var primero := true
	for pixel: Vector2 in [Vector2.ZERO, Vector2(tam.x, 0), tam, Vector2(0, tam.y)]:
		var punto: Variant = plano.intersects_ray(camara.project_ray_origin(pixel), camara.project_ray_normal(pixel))
		if punto == null:
			continue
		var d := Vector2((punto as Vector3).x - (centro as Vector3).x, (punto as Vector3).z - (centro as Vector3).z)
		rect = Rect2(d, Vector2.ZERO) if primero else rect.expand(d)
		primero = false
	return rect


## La huella relativa al FOCO (la cámara mira al torso, por encima del suelo: el centro de pantalla cae más al fondo).
static func huella_desde_foco(camara: Camera3D, foco: Vector3, y_suelo: float) -> Rect2:
	var pixel := camara.get_viewport().get_visible_rect().size * 0.5
	var centro: Variant = Plane(Vector3.UP, y_suelo).intersects_ray(camara.project_ray_origin(pixel), camara.project_ray_normal(pixel))
	var vista := huella(camara, y_suelo)
	if centro != null:
		vista.position += Vector2((centro as Vector3).x - foco.x, (centro as Vector3).z - foco.z)
	return vista


## El foco más cercano a `deseado` con el que la vista cabe en los límites (centrado en el eje donde no cabe).
static func limitar(deseado: Vector3, limites: Rect2, vista: Rect2) -> Vector3:
	var minimo := limites.position - vista.position
	var maximo := limites.end - vista.end
	return Vector3(
		clampf(deseado.x, minimo.x, maximo.x) if minimo.x <= maximo.x else limites.get_center().x,
		deseado.y,
		clampf(deseado.z, minimo.y, maximo.y) if minimo.y <= maximo.y else limites.get_center().y)


## El zoom más grande con el que la vista cabe entera en `limites`.
static func zoom_que_cabe(camara: Camera3D, limites: Rect2) -> float:
	var vista := huella(camara)
	if vista.size.x <= 0.0 or vista.size.y <= 0.0:
		return camara.size
	return camara.size * minf(limites.size.x / vista.size.x, limites.size.y / vista.size.y) * 0.98


## Un paso del zoom automático, amortiguado (empieza y acaba suave, sin el tirón inicial de un lerp exponencial).
## `vel` es un Array de un número (la velocidad del zoom, que se conserva entre fotogramas). Devuelve el zoom nuevo.
static func paso_zoom(actual: float, objetivo: float, vel: Array, dt: float) -> float:
	var omega: float = 2.0 / TIEMPO_ZOOM
	var x: float = omega * dt
	var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var cambio: float = clampf(actual - objetivo, -VELOCIDAD_ZOOM * TIEMPO_ZOOM, VELOCIDAD_ZOOM * TIEMPO_ZOOM)
	var meta: float = actual - cambio
	var tmp: float = (float(vel[0]) + omega * cambio) * dt
	vel[0] = (float(vel[0]) - omega * tmp) * e
	var nuevo: float = meta + (cambio + tmp) * e
	if (objetivo - actual > 0.0) == (nuevo > objetivo):
		nuevo = objetivo
		vel[0] = 0.0
	return nuevo


## Lo mismo sin cámara (para el generador de mapas): zoom que cabe en una sala de `celdas` casillas con la ventana en
## `aspecto` (ancho/alto) y la cámara a `elevacion` grados sobre el suelo. Godot mantiene la altura: `size` es lo alto de la vista.
static func zoom_que_cabe_en(celdas: Vector2i, lado: float, aspecto: float = 16.0 / 9.0, elevacion: float = 30.0) -> float:
	var ancho: float = float(celdas.x) * lado
	var fondo: float = float(celdas.y) * lado + lado * (MARGEN_NORTE + MARGEN_SUR)
	return minf(ancho / aspecto, fondo * sin(deg_to_rad(elevacion))) * 0.98
