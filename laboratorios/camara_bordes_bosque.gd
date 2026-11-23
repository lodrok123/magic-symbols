extends RefCounted
## Prototipo: el límite pertenece al suelo visible, no al centro de la cámara.
## Cámara ortográfica; rectángulo en X/Z y suelo horizontal en y_suelo.

static func huella(camara: Camera3D, y_suelo: float = 0.0) -> Rect2:
	var tam := camara.get_viewport().get_visible_rect().size
	var plano := Plane(Vector3.UP, y_suelo)
	var centro: Vector3 = plano.intersects_ray(camara.project_ray_origin(tam * 0.5), camara.project_ray_normal(tam * 0.5))
	var rect := Rect2(Vector2.ZERO, Vector2.ZERO)
	for pixel: Vector2 in [Vector2.ZERO, Vector2(tam.x, 0), tam, Vector2(0, tam.y)]:
		var punto: Vector3 = plano.intersects_ray(camara.project_ray_origin(pixel), camara.project_ray_normal(pixel))
		rect = rect.expand(Vector2(punto.x - centro.x, punto.z - centro.z))
	return rect

static func limitar(deseado: Vector3, limites: Rect2, vista: Rect2) -> Vector3:
	var minimo := limites.position - vista.position
	var maximo := limites.end - vista.end
	return Vector3(
		clampf(deseado.x, minimo.x, maximo.x) if minimo.x <= maximo.x else limites.get_center().x,
		deseado.y,
		clampf(deseado.z, minimo.y, maximo.y) if minimo.y <= maximo.y else limites.get_center().y)

static func huella_desde_foco(camara: Camera3D, foco: Vector3, y_suelo: float) -> Rect2:
	# La cámara real mira al torso, por encima del suelo: el centro de pantalla
	# intersecta el suelo más al fondo. Ese desplazamiento también consume margen.
	var pixel := camara.get_viewport().get_visible_rect().size * 0.5
	var centro: Vector3 = Plane(Vector3.UP, y_suelo).intersects_ray(camara.project_ray_origin(pixel), camara.project_ray_normal(pixel))
	var vista := huella(camara, y_suelo)
	vista.position += Vector2(centro.x - foco.x, centro.z - foco.z)
	return vista

static func tamanio_maximo(camara: Camera3D, limites: Rect2) -> float:
	var vista := huella(camara)
	return camara.size * minf(limites.size.x / vista.size.x, limites.size.y / vista.size.y) * 0.98

static func seguir(actual: Vector3, deseado: Vector3, limites: Rect2, vista: Rect2, delta: float) -> Vector3:
	var destino := limitar(deseado, limites, vista)
	# Limitar también DESPUÉS de interpolar evita enseñar fuera al cambiar de zoom o tamaño de ventana.
	return limitar(actual.lerp(destino, 1.0 - exp(-9.0 * delta)), limites, vista)
