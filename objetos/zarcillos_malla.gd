class_name ZarcilloMalla
extends RefCounted

## ZARCILLOS PROVISIONALES POR CÓDIGO (23/11): tubos curvos que barren un círculo por una polilínea (transporte paralelo), con radio que varía de un extremo al otro y tapas planas opcionales.
## Los usan el nudo del bancal `modelo=surco` (una espiral) y las piezas del `puente estilo=zarcillos` (arranque en abanico, tejido de enrejado, rizos). Cuando lleguen los modelos de Meshy
## (`nudo_zarcillos_*`, `zarcillos_arranque`, `zarcillos_tramo`) estas mallas son solo el RESPALDO: ver las constantes `MODELO_*` de `BancalPuzle` y de `PuenteRaices3D`.
##
## Cada tubo lleva COLOR por vértice (lo multiplica el material: `vertex_color_use_as_albedo` / `COLOR` del shader): una variación de tono por tubo de ±7 % (fibra distinta de tira a tira) y un falso
## oscurecimiento de la cara de abajo y de lo que va bajo el cruce, para que lea como cuerda aunque el motor no calcule oclusión entre tubos. Determinista (semilla fija).
## Uso: `var m := ZarcilloMalla.new(); m.tubo(puntos, r0, r1); var malla: ArrayMesh = m.malla()`. Varios tubos se acumulan en la misma malla (una sola superficie).

var _v: PackedVector3Array = PackedVector3Array()
var _n: PackedVector3Array = PackedVector3Array()
var _uv: PackedVector2Array = PackedVector2Array()
var _i: PackedInt32Array = PackedInt32Array()
var _c: PackedColorArray = PackedColorArray()
var _rng: RandomNumberGenerator = null


## Un tubo por `pts` (≥ 2 puntos), de radio `r0` en el primero a `r1` en el último. `lados` = caras del círculo; `tapas` cierra los dos extremos con un abanico plano.
func tubo(pts: PackedVector3Array, r0: float, r1: float, lados: int = 6, tapas: bool = true) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = 2311
	var tono: float = 1.0 + _rng.randf_range(-0.07, 0.07)
	var base: int = _v.size()
	var tang: Vector3 = (pts[1] - pts[0]).normalized()
	var ref: Vector3 = Vector3.UP if absf(tang.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u: Vector3 = tang.cross(ref).normalized()
	var w: Vector3 = tang.cross(u).normalized()
	for k in range(n):
		var t: Vector3
		if k == 0:
			t = (pts[1] - pts[0]).normalized()
		elif k == n - 1:
			t = (pts[n - 1] - pts[n - 2]).normalized()
		else:
			t = (pts[k + 1] - pts[k - 1]).normalized()
		# Transporte paralelo del marco: se quita de `u` lo que se haya torcido hacia la nueva tangente.
		u = (u - t * u.dot(t)).normalized()
		w = t.cross(u).normalized()
		var f: float = float(k) / float(n - 1)
		var r: float = lerpf(r0, r1, f)
		for j in range(lados + 1):
			var a: float = TAU * float(j) / float(lados)
			var dir: Vector3 = u * cos(a) + w * sin(a)
			_v.append(pts[k] + dir * r)
			_n.append(dir)
			_uv.append(Vector2(f, float(j) / float(lados)))
			var bajo: float = 0.78 + 0.22 * (dir.y * 0.5 + 0.5)                       # la cara de abajo, más oscura
			var hondo: float = lerpf(0.82, 1.0, clampf((pts[k].y + 0.02) / 0.2, 0.0, 1.0))   # lo que va por debajo del cruce, más oscuro
			var g: float = tono * bajo * hondo
			_c.append(Color(g, g, g, 1.0))
	var fila: int = lados + 1
	for k in range(n - 1):
		for j in range(lados):
			var a0: int = base + k * fila + j
			var b0: int = a0 + fila
			_i.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))
	if tapas:
		_tapa(pts[0], -(pts[1] - pts[0]).normalized(), base, lados, true)
		_tapa(pts[n - 1], (pts[n - 1] - pts[n - 2]).normalized(), base + (n - 1) * fila, lados, false)


## Abanico plano que cierra un extremo: reutiliza los vértices del anillo pero con la normal de la tapa (vértices nuevos).
func _tapa(centro: Vector3, normal: Vector3, anillo: int, lados: int, invertir: bool) -> void:
	var c: int = _v.size()
	_v.append(centro)
	_n.append(normal)
	_uv.append(Vector2(0.5, 0.5))
	_c.append(_c[anillo])
	for j in range(lados + 1):
		_v.append(_v[anillo + j])
		_n.append(normal)
		_uv.append(Vector2(0.5, 0.5))
		_c.append(_c[anillo + j])
	for j in range(lados):
		if invertir:
			_i.append_array(PackedInt32Array([c, c + 1 + j + 1, c + 1 + j]))
		else:
			_i.append_array(PackedInt32Array([c, c + 1 + j, c + 1 + j + 1]))


## Un rizo (espiral plana que se cierra) que arranca en `origen`: sale hacia `dir_sale`, se enrolla alrededor del eje `eje` (normal del plano del rizo) y acaba más fino. `radio` = el del primer giro.
func rizo(origen: Vector3, dir_sale: Vector3, eje: Vector3, radio: float, vueltas: float, grosor: float, lados: int = 5) -> void:
	var lado: Vector3 = eje.cross(dir_sale).normalized()
	var pts: PackedVector3Array = PackedVector3Array()
	var pasos: int = maxi(8, int(vueltas * 10.0))
	# centro del enroscado: a `radio` del origen, hacia el lado
	var centro: Vector3 = origen + lado * radio
	var a0: float = atan2((origen - centro).dot(dir_sale.normalized()), (origen - centro).dot(lado))
	for k in range(pasos + 1):
		var f: float = float(k) / float(pasos)
		var a: float = a0 + f * vueltas * TAU
		var r: float = radio * (1.0 - 0.8 * f)
		pts.append(centro + (lado * cos(a) + dir_sale.normalized() * sin(a)) * r)
	tubo(pts, grosor, grosor * 0.35, lados, false)


func malla() -> ArrayMesh:
	var m := ArrayMesh.new()
	if _v.is_empty():
		return m
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_TEX_UV] = _uv
	arr[Mesh.ARRAY_COLOR] = _c
	arr[Mesh.ARRAY_INDEX] = _i
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func vacia() -> bool:
	return _v.is_empty()
