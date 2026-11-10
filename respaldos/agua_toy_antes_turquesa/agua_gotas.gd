extends Node3D

## GOTAS Y BURBUJAS DE AGUA POR CPU (3/11/2026, agua «toy», fase 1). Un MultiMesh de quads (agua_gota.gdshader, mezcla, sin emisión) cuyas instancias mueve este nodo: NO es un GPUParticles3D (no
## cuenta en el presupuesto de partículas) y su posición y velocidad se pueden medir en las pruebas (`estados()`), porque en headless el MultiMesh no guarda datos.
## Se usa con `const AguaGotas = preload("res://presentacion/vfx/toy/agua_gotas.gd")` (sin class_name, igual que sprite_toy.gd). Hay dos usos:
##   · como RESERVA (`montar(n)` + `emitir(...)`): las gotas que se desprenden de la bola en vuelo; el nodo es top_level, así que las gotas se quedan en el MUNDO y caen con GRAVEDAD aunque la bola se mueva.
##   · solo con las funciones estáticas `crear_mm` y `poner` (ImpactoAguaToy y CargaAguaToy mueven sus propias instancias con una fórmula cerrada).
## Gota (tipo 0): cae con `gravedad` y algo de rozamiento. Burbuja (tipo 1): sube despacio y se mueve de lado.

const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const SH_GOTA: String = "res://presentacion/vfx/toy/agua_gota.gdshader"

var gravedad: float = 9.8                    ## m/s² hacia abajo (mundo)
var rozamiento: float = 0.5                  ## 1/s
var suelo_y: float = -1.0e9                  ## por debajo de esta altura (mundo) la gota desaparece
var _mi: MultiMeshInstance3D = null
var _s: Array = []
var _cursor: int = 0


## Un MultiMesh de `cantidad` quads de gota con el material de agua. `custom_aabb` enorme: la CPU las mueve por todo el mundo.
static func crear_mm(nombre: String, cantidad: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = cantidad
	for i in cantidad:
		poner(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_GOTA)
	m.render_priority = 2
	var pal: Dictionary = AguaPaleta.uniforms()
	for k in ["tono_a", "tono_b", "tono_c"]:
		m.set_shader_parameter(k, pal[k])
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return mi


## Pone la gota `i`: `pos` y `dir` (unitaria, hacia donde va) en el espacio del MultiMeshInstance3D; `largo` y `ancho` en m; `claridad` 0..1; `alfa` 0..1; `burbuja` = aro en vez de gota.
static func poner(mm: MultiMesh, i: int, pos: Vector3, dir: Vector3, largo: float, ancho: float, claridad: float, alfa: float, burbuja: bool) -> Transform3D:
	var y: Vector3 = dir.normalized() if dir.length() > 0.0001 else Vector3.DOWN
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	var vivo: bool = alfa > 0.001 and ancho > 0.0
	var w: float = ancho if vivo else 0.0
	var l: float = (maxf(largo, ancho) if not burbuja else ancho) if vivo else 0.0
	var tr: Transform3D = Transform3D(Basis(x * w, y * l, z * w), pos)
	mm.set_instance_transform(i, tr)
	mm.set_instance_custom_data(i, Color(clampf(claridad, 0.0, 1.0), clampf(alfa, 0.0, 1.0), 1.0 if burbuja else 0.0, 0.0))
	return tr


## Prepara la reserva: `n` huecos. El nodo pasa a top_level (sus gotas viven en coordenadas de mundo).
func montar(n: int) -> void:
	top_level = true
	_mi = crear_mm("Gotas", n)
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


## Una gota nueva en `pos` (mundo) con velocidad `vel`; `vida` s; `tam` = ancho en m; `tipo` 0 gota / 1 burbuja; `g` = multiplicador de la gravedad. Devuelve el hueco o -1 si no hay sitio.
func emitir(pos: Vector3, vel: Vector3, vida: float, tam: float, tipo: int = 0, alfa: float = 0.9, claridad: float = 0.5, g: float = 1.0) -> int:
	if _s.is_empty():
		return -1
	var hueco: int = -1
	for k in _s.size():
		var j: int = (_cursor + k) % _s.size()
		if not bool((_s[j] as Dictionary)["vivo"]):
			hueco = j
			break
	if hueco < 0:
		return -1                               # reserva llena: se pierde la gota nueva (mejor que robar una a medio caer)
	_cursor = (hueco + 1) % _s.size()
	_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam": tam, "tipo": tipo, "alfa": alfa, "clar": claridad, "g": g,
		"fase": randf() * TAU}
	return hueco


## Borra todas (p. ej. tras un rebote, que deja la cola vieja apuntando a la pared).
func vaciar() -> void:
	for i in _s.size():
		_s[i] = {"vivo": false}
	if _mi != null:
		var mm: MultiMesh = _mi.multimesh
		for i in _s.size():
			poner(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)


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
		var v: Vector3 = d["vel"]
		if int(d["tipo"]) == 0:
			v.y -= gravedad * float(d["g"]) * delta
			v *= maxf(1.0 - rozamiento * delta, 0.0)
		else:
			v.y = lerpf(v.y, 0.35, minf(delta * 2.0, 1.0))                   # la burbuja sube despacio
			v.x += sin(float(d["edad"]) * 5.0 + float(d["fase"])) * 0.25 * delta
		d["vel"] = v
		d["pos"] = (d["pos"] as Vector3) + v * delta
		if u >= 1.0 or (d["pos"] as Vector3).y < suelo_y:
			d["vivo"] = false
			poner(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
			continue
		var al: float = float(d["alfa"]) * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.72, 1.0, u))
		var tam: float = float(d["tam"]) * (1.0 - 0.25 * u * u)
		var burbuja: bool = int(d["tipo"]) == 1
		var largo: float = tam * clampf(1.0 + 0.3 * v.length(), 1.0, 2.4)
		poner(mm, i, d["pos"], v.normalized() if v.length() > 0.01 else Vector3.DOWN, largo, tam, float(d["clar"]), al, burbuja)


## Medición para las pruebas: una entrada por gota viva: {pos, vel, u, tipo, hueco, edad} (hueco + edad identifican la misma gota entre dos medidas).
func estados() -> Array:
	var r: Array = []
	for i in _s.size():
		var d: Dictionary = _s[i]
		if bool(d["vivo"]):
			r.append({"pos": d["pos"], "vel": d["vel"], "u": float(d["edad"]) / float(d["vida"]), "tipo": int(d["tipo"]), "hueco": i, "edad": float(d["edad"])})
	return r
