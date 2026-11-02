extends Node3D

## ESQUIRLAS DE HIELO POR CPU (3/11/2026, hielo «toy»; el equivalente de agua_gotas.gd). Un MultiMesh de tetraedros (hielo_cristal.gdshader, mezcla, sin emisión) que mueve este nodo: NO es un
## GPUParticles3D (no cuenta en el presupuesto de partículas) y su posición y velocidad se pueden medir en las pruebas (`estados()`), porque en headless el MultiMesh no guarda datos.
## Se usa con `const HieloEsquirlas = preload("res://presentacion/vfx/toy/hielo_esquirlas.gd")` (sin class_name). Como RESERVA (`montar(n)` + `emitir(...)`) el nodo es top_level: las esquirlas se quedan
## en el MUNDO, GIRAN, CAEN con gravedad, rebotan una vez al llegar al suelo, se quedan quietas un momento y se desvanecen (de ahí «se rompe y caen las esquirlas»).

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")

var gravedad: float = 9.8                    ## m/s² hacia abajo (mundo)
var suelo_y: float = -1.0e9                  ## altura (mundo) del suelo: ahí rebotan y se quedan; si no hay suelo (muy bajo), caen hasta su vida
var _mi: MultiMeshInstance3D = null
var _s: Array = []
var _cursor: int = 0
static var _malla: ArrayMesh = null


static func malla_esquirla() -> ArrayMesh:
	if _malla == null:
		_malla = HieloMallas.esquirla()
	return _malla


## Un MultiMesh de `cantidad` esquirlas con el material del hielo. Para quien mueve sus propias instancias con una fórmula (ImpactoHieloToy, CargaHieloToy).
static func crear_mm(nombre: String, cantidad: int) -> MultiMeshInstance3D:
	return HieloMallas.crear_mm(nombre, cantidad, malla_esquirla(), 0.8, 2)


## Pone la esquirla `i`: `pos`, orientación `rot` y `tam` (m de largo); `claridad` 0..1; `alfa` 0..1.
static func poner(mm: MultiMesh, i: int, pos: Vector3, rot: Basis, tam: float, alfa: float, claridad: float) -> Transform3D:
	return HieloMallas.poner(mm, i, pos, rot, tam * 0.55, tam, tam * 0.55, claridad, alfa, fposmod(float(i) * 0.37, 1.0))


## Prepara la reserva: `n` huecos. El nodo pasa a top_level (sus esquirlas viven en coordenadas de mundo).
func montar(n: int) -> void:
	top_level = true
	_mi = crear_mm("Esquirlas", n)
	add_child(_mi)
	_s.clear()
	for i in n:
		_s.append({"vivo": false})
	_cursor = 0


func capacidad() -> int:
	return _s.size()


func vivas() -> int:
	var k: int = 0
	for d in _s:
		if bool(d["vivo"]):
			k += 1
	return k


## Una esquirla nueva en `pos` (mundo) con velocidad `vel` y giro `giro` (rad/s, mundo); `vida` s; `tam` = largo en m. Devuelve el hueco o -1 si no hay sitio.
func emitir(pos: Vector3, vel: Vector3, vida: float, tam: float, alfa: float = 0.85, claridad: float = 0.5, giro: Vector3 = Vector3.ZERO) -> int:
	if _s.is_empty():
		return -1
	var hueco: int = -1
	for k in _s.size():
		var j: int = (_cursor + k) % _s.size()
		if not bool((_s[j] as Dictionary)["vivo"]):
			hueco = j
			break
	if hueco < 0:
		return -1                               # reserva llena: se pierde la nueva (mejor que robar una a medio caer)
	_cursor = (hueco + 1) % _s.size()
	var g: Vector3 = giro if giro.length() > 0.01 else Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam": tam, "alfa": alfa, "clar": claridad, "giro": g,
		"rot": Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), "rebotes": 0, "quieta": false}
	return hueco


## Borra todas (p. ej. tras un rebote, que deja la cola vieja apuntando a la pared).
func vaciar() -> void:
	for i in _s.size():
		_s[i] = {"vivo": false}
	if _mi != null:
		var mm: MultiMesh = _mi.multimesh
		for i in _s.size():
			HieloMallas.ocultar(mm, i)


func _process(delta: float) -> void:
	avanzar(delta)


## Mueve todas `delta` s. Las pruebas pueden llamarla a mano.
func avanzar(delta: float) -> void:
	if _mi == null:
		return
	var mm: MultiMesh = _mi.multimesh
	for i in _s.size():
		var d: Dictionary = _s[i]
		if not bool(d["vivo"]):
			continue
		d["edad"] = float(d["edad"]) + delta
		var u: float = float(d["edad"]) / float(d["vida"])
		if u >= 1.0:
			d["vivo"] = false
			HieloMallas.ocultar(mm, i)
			continue
		if not bool(d["quieta"]):
			var v: Vector3 = d["vel"]
			v.y -= gravedad * delta
			var p: Vector3 = (d["pos"] as Vector3) + v * delta
			if p.y < suelo_y:
				p.y = suelo_y
				if int(d["rebotes"]) < 1 and v.y < -1.0:
					v.y = -v.y * 0.28
					v.x *= 0.5
					v.z *= 0.5
					d["rebotes"] = int(d["rebotes"]) + 1
					d["giro"] = (d["giro"] as Vector3) * 0.5
				else:
					v = Vector3.ZERO
					d["quieta"] = true
			d["vel"] = v
			d["pos"] = p
			var g: Vector3 = d["giro"]
			if g.length() > 0.001:
				d["rot"] = (Basis(g.normalized(), g.length() * delta) * (d["rot"] as Basis)).orthonormalized()
		var al: float = float(d["alfa"]) * smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.7, 1.0, u))
		poner(mm, i, d["pos"], d["rot"], float(d["tam"]) * (1.0 - 0.2 * u * u), al, float(d["clar"]))


## Medición para las pruebas: una entrada por esquirla viva: {pos, vel, u, hueco, edad, quieta, rebotes}.
func estados() -> Array:
	var r: Array = []
	for i in _s.size():
		var d: Dictionary = _s[i]
		if bool(d["vivo"]):
			r.append({"pos": d["pos"], "vel": d["vel"], "u": float(d["edad"]) / float(d["vida"]), "hueco": i, "edad": float(d["edad"]), "quieta": bool(d["quieta"]), "rebotes": int(d["rebotes"])})
	return r
