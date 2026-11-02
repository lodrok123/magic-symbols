class_name FuegoToyMallas
extends RefCounted

## MALLAS DEL FUEGO PARAMÉTRICO (FuegoToy). Mismo método que montar_efectos_lelu.gd (revolución abierta, U alrededor, V = 0 abajo y 1 arriba), pero con tamaño variable:
## el contorno es una superelipse de semiejes a × b (exponente 2 = elipse, 6 = rectángulo redondeado) y U mide la LONGITUD DEL CONTORNO, de modo que
## la textura de lenguas nunca se estira al alargar un muro; cuántas veces se repite lo decide quien llama con `repeticiones_u` (un entero, para que cierre la costura).

## Metros de contorno (o de meridiano, en vertical) que ocupa UNA repetición de la textura de lenguas, MEDIDOS en las escenas validadas de la prueba 3:
## [horizontal lenguas, vertical lenguas, horizontal ruido, vertical ruido]
const M_MURO: Array = [2.90, 1.667, 2.417, 0.9375]          # banda exterior: contorno 14,5 m / 5 rep.; 1,5 m / 0,9; 14,5 / 6; 1,5 / 1,6
const M_MURO_IN: Array = [2.24, 1.167, 1.92, 0.656]         # interior: 13,44 m / 6; 1,05 / 0,9; 13,44 / 7; 1,05 / 1,6
const M_PILAR: Array = [3.1416, 2.5, 1.5708, 2.0]           # cilindro r 0,5 × 4: 3,14 m / 1; 4 / 1,6; 3,14 / 2; 4 / 2
const M_PILAR_IN: Array = [1.885, 2.214, 0.9425, 1.55]      # núcleo r 0,3 × 3,1: 1,88 / 1; 3,1 / 1,4; 1,88 / 2; 3,1 / 2
const M_BARRERA: Array = [3.1416, 3.366, 1.885, 2.356]      # esfera r 1,5: ecuador 9,42 / 3; meridiano 4,71 / 1,4; 9,42 / 5; 4,71 / 2


## Perímetro de una elipse de semiejes a y b (aproximación de Ramanujan).
static func perimetro_elipse(a: float, b: float) -> float:
	var h: float = pow(a - b, 2.0) / pow(a + b, 2.0)
	return PI * (a + b) * (1.0 + 3.0 * h / (10.0 + sqrt(4.0 - 3.0 * h)))


## Puntos de la superelipse (n = 2 elipse; n = 6 rectángulo redondeado) y su longitud acumulada. Devuelve {pts: Array[Vector2], acum: Array[float], total: float}.
static func contorno(a: float, b: float, n: float, seg: int) -> Dictionary:
	var pts: Array = []
	var acum: Array = [0.0]
	for i in seg + 1:
		var t: float = TAU * float(i) / float(seg)
		var c: float = cos(t)
		var s: float = sin(t)
		pts.append(Vector2(a * signf(c) * pow(absf(c), 2.0 / n), b * signf(s) * pow(absf(s), 2.0 / n)))
		if i > 0:
			acum.append(float(acum[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
	return {"pts": pts, "acum": acum, "total": float(acum[seg])}


## Longitud del contorno de la superelipse (para saber cuántas repeticiones de la textura caben).
static func largo_contorno(a: float, b: float, n: float) -> float:
	return float(contorno(a, b, n, 240)["total"])


## Repeticiones ENTERAS (≥ 1) de una textura que mide `metros_por_rep` m cuando el contorno mide `largo` m.
static func repeticiones_u(largo: float, metros_por_rep: float) -> float:
	return float(maxi(1, int(round(largo / maxf(metros_por_rep, 0.01)))))


## Segmentos alrededor: uno cada ~12 cm de contorno, entre 32 y 360.
static func segmentos(largo: float) -> int:
	return clampi(int(round(largo / 0.12)), 32, 360)


## Cilindro / banda abierta: cada anillo j tiene `perfil[j] = Vector2(escala del contorno, y)`. V = j / (n - 1).
static func banda(a: float, b: float, n_exp: float, perfil: Array, seg: int) -> ArrayMesh:
	var c: Dictionary = contorno(a, b, n_exp, seg)
	var pts: Array = c["pts"]
	var acum: Array = c["acum"]
	var total: float = c["total"]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: int = perfil.size()
	for j in anillos:
		var v: float = float(j) / float(anillos - 1)
		var esc: float = (perfil[j] as Vector2).x
		var y: float = (perfil[j] as Vector2).y
		for i in seg + 1:
			var p: Vector2 = pts[i]
			st.set_uv(Vector2(float(acum[i]) / total, v))
			st.set_normal(Vector3(p.x / (a * a), 0.0, p.y / (b * b)).normalized())
			st.add_vertex(Vector3(p.x * esc, y, p.y * esc))
	_indices(st, anillos, seg)
	return st.commit()


## Perfil de la banda del muro: la escala baja linealmente de 1 a `s_alto` y la altura sube de 0 a `alto` (14 anillos, como el muro validado).
static func perfil_muro(alto: float, s_alto: float, n: int = 14) -> Array:
	var r: Array = []
	for j in n:
		var v: float = float(j) / float(n - 1)
		r.append(Vector2(lerpf(1.0, s_alto, v), v * alto))
	return r


## Perfil del cilindro del pilar (ahusado: del radio de la base al de arriba, con el mismo suavizado que `_anillos` de montar_efectos_lelu.gd): `ratio_alto` = r_alto / r_base.
static func perfil_cilindro(ratio_alto: float, alto: float, n: int = 14) -> Array:
	var claves: Array = [Vector2(0.0, 1.0), Vector2(0.6, lerpf(1.0, ratio_alto, 0.6)), Vector2(1.0, ratio_alto)]
	var alt: Array = [0.0, 0.6 * alto, alto]
	var r: Array = []
	for i in n:
		var v: float = float(i) / float(n - 1)
		var k: int = 0
		while k < claves.size() - 2 and v > (claves[k + 1] as Vector2).x:
			k += 1
		var a: Vector2 = claves[k]
		var b: Vector2 = claves[k + 1]
		var u: float = clampf((v - a.x) / maxf(b.x - a.x, 0.0001), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		r.append(Vector2(lerpf(a.y, b.y, u), lerpf(float(alt[k]), float(alt[k + 1]), u)))
	return r


## Elipsoide abierto (los dos polos son un anillo de radio 0): semiejes rx, ry, rz, centrado en el origen; V = 0 en el polo de abajo, 1 en el de arriba. Normales del elipsoide.
static func elipsoide(rx: float, ry: float, rz: float, anillos: int = 25, seg: int = 48) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in anillos:
		var v: float = float(j) / float(anillos - 1)
		var s: float = sin(PI * v)
		var y: float = -ry * cos(PI * v)
		for i in seg + 1:
			var u: float = float(i) / float(seg)
			var ang: float = u * TAU
			var p: Vector3 = Vector3(cos(ang) * rx * s, y, sin(ang) * rz * s)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(p.x / (rx * rx), p.y / (ry * ry), p.z / (rz * rz)).normalized())
			st.add_vertex(p)
	_indices(st, anillos, seg)
	return st.commit()


static func _indices(st: SurfaceTool, anillos: int, seg: int) -> void:
	for j in anillos - 1:
		for i in seg:
			var a0: int = j * (seg + 1) + i
			var b0: int = a0 + seg + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)


# ------------------------------------------------------------------ láminas billboard de eje vertical (revisión «muy 2D») ------------------------------------------------------------------

## Cuadrícula de 1 × 1 m para las láminas Y-billboard (fuego_lelu_vbb.gdshader): x de -0,5 a 0,5, y de 0 a 1, UV con V = 0 abajo y 1 arriba. Varias filas y columnas para que el balanceo
## de los vértices la doble como una lengua y no como una carta.
static func quad_vbb(cols: int = 4, filas: int = 10) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in filas + 1:
		var v: float = float(j) / float(filas)
		for i in cols + 1:
			var u: float = float(i) / float(cols)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(u - 0.5, v, 0.0))
	for j in filas:
		for i in cols:
			var a0: int = j * (cols + 1) + i
			var b0: int = a0 + cols + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## Una lámina: {pos (suelo), w, h (m), sem, hot (0-1), fase (s), alfa (0-1)}.
static func _lamina(p: Vector3, w: float, h: float, rng: RandomNumberGenerator, hot: float, alfa: float) -> Dictionary:
	return {"pos": p, "w": w, "h": h, "sem": rng.randf() * 7.0, "hot": hot, "fase": rng.randf() * 20.0, "alfa": alfa}


## MURO: una columna cada ~0,55 m a lo largo de x y, en cada una, tres láminas repartidas en el fondo (una al centro, más caliente y baja, y dos a los lados, cada una con su desplazamiento
## en z y en x), de modo que de canto (mirando a lo largo del muro) se ve una masa de ~2·b de profundidad y no una raya. Determinista (semilla fija).
static func laminas_muro(a: float, b: float, alto: float, tope: int = 90) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261102
	var paso: float = 0.55
	var n: int = clampi(int(round(2.0 * a * 0.93 / paso)) + 1, 3, tope / 3)
	var r: Array = []
	var ancho: float = maxf(paso * 2.0, 0.9)
	for i in n:
		var x: float = lerpf(-a * 0.93, a * 0.93, float(i) / float(n - 1))
		var jx: float = paso * 0.35
		r.append(_lamina(Vector3(x + rng.randf_range(-jx, jx), 0.0, rng.randf_range(-0.2, 0.2) * b), ancho * rng.randf_range(0.8, 1.0), alto * rng.randf_range(0.65, 0.8), rng, 1.0, 0.9))
		for lado in [-1.0, 1.0]:
			r.append(_lamina(Vector3(x + rng.randf_range(-jx, jx), 0.0, float(lado) * b * rng.randf_range(0.55, 1.0)), ancho * rng.randf_range(0.85, 1.15), alto * rng.randf_range(0.85, 1.0), rng, 0.2, 0.8))
	return r


## PILAR: un anillo de láminas alrededor del eje (elipse de semiejes rx·0,5 × rz·0,5, con radio y ángulo desplazados) y tres láminas de núcleo, más calientes y bajas.
static func laminas_pilar(rx: float, rz: float, alto: float, tope: int = 60) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261103
	var rm: float = (rx + rz) * 0.5
	var n: int = clampi(int(round(perimetro_elipse(rx, rz) / 0.5)), 5, tope - 4)
	var r: Array = []
	var ancho: float = 1.3 * rm + 0.2
	var fase: float = rng.randf() * TAU
	for i in n:
		var ang: float = fase + TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
		var rr: float = rng.randf_range(0.35, 0.65)
		r.append(_lamina(Vector3(cos(ang) * rx * rr, 0.0, sin(ang) * rz * rr), ancho * rng.randf_range(0.85, 1.1), alto * rng.randf_range(0.88, 1.0), rng, 0.2, 0.8))
	for i in 3:
		var ang2: float = fase + TAU * float(i) / 3.0
		r.append(_lamina(Vector3(cos(ang2) * rx * 0.15, 0.0, sin(ang2) * rz * 0.15), ancho * 0.75, alto * rng.randf_range(0.7, 0.8), rng, 1.0, 0.9))
	return r

# ------------------------------------------------------------------ HAZ cónico (ronda de Pablo, 2/11) ------------------------------------------------------------------

## Cuántos largos del haz mide la malla del chorro (el trozo de más es el sitio al que se desplaza el chorro al cortarse: haz_toy.gdshader, corte).
const HAZ_LARGO_MALLA: float = 1.8
const HAZ_ABRE_POT: float = 0.8            ## el radio crece como s^0,8: casi lineal y más rápido al principio (un cono que se abre en bocanadas)


## Semianchura base (m) del chorro a la fracción s (0 = origen, 1 = punta) de su largo: nace de un punto fino 0 y se abre hasta 1. La misma fórmula que haz_toy.gdshader (sin la bocanada).
static func ancho_haz(s: float, r0: float, r1: float) -> float:
	return r0 + (r1 - r0) * pow(clampf(s, 0.0, 1.0), HAZ_ABRE_POT)


## Tira de eje -Z de largo · HAZ_LARGO_MALLA m con ilas filas y cols columnas laterales: la fila s tiene semianchura ncho_haz(s), así que el origen es un PUNTO (ancho r0) y la punta
## el radio r1. UV.x = lateral (0 a 1), UV.y = fracción a lo largo de la malla (0 a 1). El shader la gira alrededor de su eje para que mire a la cámara.
static func haz_cono(largo: float, r0: float, r1: float, cols: int = 6, filas: int = 56) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in filas + 1:
		var v: float = float(j) / float(filas)
		var s: float = v * HAZ_LARGO_MALLA
		var w: float = ancho_haz(s, r0, r1)
		for i in cols + 1:
			var u: float = float(i) / float(cols)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0, 1, 0))
			st.add_vertex(Vector3((u * 2.0 - 1.0) * w, 0.0, -s * largo))
	_indices(st, filas + 1, cols)
	return st.commit()

## BASE IRREGULAR DEL PILAR (ronda de Pablo, 2/11: «mete un patrón más irregular en la base»): lenguas bajas de distinta altura y grosor alrededor de la base, a radios distintos (algunas pegadas al pilar, otras
## separadas) y unas pocas llamitas sueltas en el suelo, más lejos. Determinista. Se dibujan con las láminas Y-billboard (siempre visibles: el filtro por elevación de la cámara se desactiva en el material).
static func laminas_base_pilar(rx: float, rz: float, alto: float) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261104
	var rm: float = (rx + rz) * 0.5
	var r: Array = []
	var n: int = clampi(int(round(perimetro_elipse(rx, rz) / 0.42)), 6, 16)
	var fase: float = rng.randf() * TAU
	for i in n:
		var ang: float = fase + TAU * (float(i) + rng.randf_range(-0.38, 0.38)) / float(n)
		var rr: float = rng.randf_range(0.7, 1.35)
		var h: float = clampf(alto * rng.randf_range(0.04, 0.2), 0.2, 0.95)
		var w: float = rng.randf_range(0.22, 0.6) * (0.6 + 0.8 * rm)
		r.append(_lamina(Vector3(cos(ang) * rx * rr, 0.0, sin(ang) * rz * rr), w, h, rng, 0.15, 0.9))
	for i in 5:
		var ang2: float = fase + rng.randf() * TAU
		var rr2: float = rng.randf_range(1.5, 2.4)
		r.append(_lamina(Vector3(cos(ang2) * rx * rr2 + (0.0 if rx > 0.3 else 0.3), 0.0, sin(ang2) * rz * rr2), rng.randf_range(0.16, 0.3), rng.randf_range(0.14, 0.32), rng, 0.05, 0.85))
	return r

