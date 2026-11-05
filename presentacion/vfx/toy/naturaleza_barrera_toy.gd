class_name NaturalezaBarreraToy
extends Node3D

## BARRERA DE NATURALEZA «TOY» (5/11/2026; referencia: el «buff» de hierba y hojas de un paquete comercial de VFX, solo como idea; todo procedural). Es el aspecto del `EscudoNaturaleza3D`:
##   · un ANILLO DE HIERBA que brota a los pies (briznas curvadas en tres bandas de verde, en tufos de tres, que crecen en ola alrededor),
##   · HOJAS que giran subiendo en espiral alrededor del cuerpo (tantas como escudo queda: al perder escudo se SUELTAN y caen),
##   · una CÚPULA muy tenue (casi transparente en el centro, más visible en el canto) para que se lea que cubre por todos lados,
##   · un aro plano en el suelo.
## Cuatro estados que se leen: ACTIVO (todo verde, se mece) · GOLPE (`golpe`: la hierba se encoge y se abre, la cúpula destella, saltan hojas) · ROTO (`romper("golpes")`: las hojas caen y
## pasan de verde a pardo, la hierba se marchita y se echa) · QUEMADO (`romper("fuego")`: las hojas y la hierba se ponen NARANJAS, luego NEGRAS, caen, y suben brasas).
## No decide nada del juego: lo maneja `EscudoNaturaleza3D` (absorber, vida, señales). Todo se mueve por CPU en `_process`; las pruebas leen `estados_hierba()` y `hojas.estados()`.

const COLOR_CUPULA_CENTRO: Color = Color(0.5, 0.95, 0.5)
const COLOR_CUPULA_BORDE: Color = Color(0.22, 0.74, 0.34)
const N_TUFOS: int = 22
const BRIZNAS_POR_TUFO: int = 4
const VERDES_HIERBA: Array = [Color(0.10, 0.42, 0.17), Color(0.17, 0.55, 0.22), Color(0.28, 0.68, 0.27)]
const N_ORBITA: int = 10
const T_BROTE: float = 0.55                      ## s que tarda en brotar la hierba
const T_FIN_GOLPES: float = 1.5                  ## s que dura el deshojarse
const T_FIN_FUEGO: float = 1.7                   ## s que dura el quemarse
const T_GOLPE: float = 0.38

var alto: float = 0.9
var radio: float = 0.55
var estado: String = "activo"                    ## activo · roto · quemado
var frac_vida: float = 1.0
var hojas: NaturalezaHojas = null
var brasas: NaturalezaManchas = null
var _t: float = 0.0
var _t_fin: float = 0.0
var _t_golpe: float = 1.0                        ## s desde el último golpe (≥ T_GOLPE = sin golpe)
var _golpes: int = 0
var _hierba: MultiMeshInstance3D = null
var _cupula: MeshInstance3D = null
var _mat_cupula: ShaderMaterial = null
var _aro: MeshInstance3D = null
var _mat_aro: ShaderMaterial = null
var _orb: Array = []                             ## índices (en `hojas`) de las hojas que giran, en orden
var _orb_fase: Array = []
var _tufo_ang: PackedFloat32Array = PackedFloat32Array()
var _brz: Array = []                             ## una por brizna: {tufo, yaw, alto, ancho, fase, retraso, col}
var _h_media: float = 0.0
var _col_media: Color = Color.WHITE
var _brasas_t: float = 0.0
var _suelta_cola: Array = []                     ## hojas por soltar tras romper (para que no caigan todas a la vez)


## Monta la barrera para un cuerpo de `p_alto` m. `colores` opcional: el verde del escudo.
func montar(p_alto: float) -> void:
	alto = maxf(p_alto, 0.6)
	radio = clampf(alto * 0.62, 0.45, 0.85)
	# hierba
	_hierba = NaturalezaHojas.crear_mm("Hierba", N_TUFOS * BRIZNAS_POR_TUFO, 1, 0.55)
	add_child(_hierba)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5112026
	for i in N_TUFOS:
		var a: float = float(i) / float(N_TUFOS) * TAU + rng.randf_range(-0.08, 0.08)
		_tufo_ang.append(a)
		for k in BRIZNAS_POR_TUFO:
			var tono: float = rng.randf()
			_brz.append({"tufo": i, "yaw": a + (float(k) - 1.5) * 0.7 + rng.randf_range(-0.3, 0.3), "alto": alto * rng.randf_range(0.28, 0.46) * (1.0 if k == 1 else 0.8),
				"ancho": rng.randf_range(0.11, 0.16), "fase": rng.randf() * TAU, "retraso": float(i) / float(N_TUFOS) * 0.38 + rng.randf_range(0.0, 0.05),
				"radio": radio * rng.randf_range(0.93, 1.07), "col": VERDES_HIERBA[mini(int(tono * 3.0), 2)]})
	# hojas que giran + las que caen
	hojas = NaturalezaHojas.new()
	hojas.name = "Hojas"
	add_child(hojas)
	hojas.montar(N_ORBITA + 44)
	hojas.suelo_y = global_position.y if is_inside_tree() else 0.0
	for i in N_ORBITA:
		var fase: float = float(i) / float(N_ORBITA)
		_orb_fase.append(fase)
		var col: Color = NaturalezaHojas.PALETA_VERDES[(i % 3) + 1]
		var idx: int = hojas.emitir_atada(func() -> Vector3: return _pos_orbita(fase), randf_range(0.13, 0.19), col)
		_orb.append(idx)
	# brasas del quemado
	brasas = NaturalezaManchas.new()
	brasas.name = "Brasas"
	add_child(brasas)
	brasas.montar(40, 0.2, 0.5)
	# cúpula tenue
	var esf := SphereMesh.new()
	esf.radius = alto * 0.62
	esf.height = alto * 1.24
	esf.radial_segments = 24
	esf.rings = 12
	_cupula = MeshInstance3D.new()
	_cupula.name = "Cupula"
	_cupula.mesh = esf
	_cupula.position = Vector3(0, alto * 0.5, 0)
	_mat_cupula = ShaderMaterial.new()
	_mat_cupula.shader = load("res://presentacion/vfx/toy/naturaleza_esfera.gdshader") as Shader
	_mat_cupula.set_shader_parameter("color_centro", Vector3(COLOR_CUPULA_CENTRO.r, COLOR_CUPULA_CENTRO.g, COLOR_CUPULA_CENTRO.b))
	_mat_cupula.set_shader_parameter("color_medio", Vector3(0.32, 0.82, 0.38))
	_mat_cupula.set_shader_parameter("color_borde", Vector3(COLOR_CUPULA_BORDE.r, COLOR_CUPULA_BORDE.g, COLOR_CUPULA_BORDE.b))
	_mat_cupula.set_shader_parameter("alfa_centro", 0.0)
	_mat_cupula.set_shader_parameter("alfa_borde", 0.34)
	_mat_cupula.set_shader_parameter("bandas", 0.0)
	_cupula.material_override = _mat_cupula
	_cupula.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cupula)
	# aro del suelo
	_aro = MeshInstance3D.new()
	_aro.name = "Aro"
	var q := QuadMesh.new()
	q.size = Vector2(radio * 2.7, radio * 2.7)
	q.orientation = PlaneMesh.FACE_Y
	_aro.mesh = q
	_mat_aro = ShaderMaterial.new()
	_mat_aro.shader = load("res://presentacion/vfx/toy/naturaleza_blob.gdshader") as Shader
	_mat_aro.set_shader_parameter("cartel", false)
	_mat_aro.set_shader_parameter("anillo", 1.0)
	_mat_aro.set_shader_parameter("blandura", 0.6)
	_mat_aro.set_shader_parameter("modulo", Color(0.3, 0.8, 0.35, 0.0))
	_aro.material_override = _mat_aro
	_aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aro.position = Vector3(0, 0.04, 0)
	add_child(_aro)
	_pintar(0.0)


func _pos_orbita(fase: float) -> Vector3:
	var u: float = fposmod(_t * 0.2 + fase, 1.0)                              # sube de los pies a la cabeza y vuelve a empezar
	var a: float = _t * 1.9 + fase * TAU * 2.0
	var r: float = radio * (0.82 + 0.16 * sin(_t * 1.3 + fase * 9.0)) * (0.92 + 0.15 * sin(u * PI))
	var y: float = alto * (0.08 + 0.85 * u)
	return global_position + Vector3(cos(a) * r, y, sin(a) * r)


func _escala_orbita(fase: float) -> float:
	var u: float = fposmod(_t * 0.2 + fase, 1.0)
	return smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.82, u)


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

## Hojas vivas que giran (las que no se han soltado).
func n_orbitando() -> int:
	return _orb.size()


## El escudo queda al `frac` (0..1): las hojas que sobran se sueltan y caen.
func poner_vida(frac: float) -> void:
	frac_vida = clampf(frac, 0.0, 1.0)
	if estado != "activo":
		return
	var quedan: int = int(ceil(float(N_ORBITA) * frac_vida - 0.001))
	while _orb.size() > quedan and not _orb.is_empty():
		var idx: int = int(_orb.pop_back())
		_orb_fase.pop_back()
		var fuera := Vector3(randf_range(-1, 1), randf_range(0.2, 0.9), randf_range(-1, 1)).normalized() * randf_range(0.7, 1.3)
		hojas.soltar(idx, fuera)
		hojas.cambiar_color(idx, NaturalezaHojas.color_aleatorio(), NaturalezaHojas.FINAL_VERDE)


## Recibe un golpe sin romperse: la hierba se encoge y se abre, la cúpula destella.
func golpe() -> void:
	if estado != "activo":
		return
	_golpes += 1
	_t_golpe = 0.0


func golpes_recibidos() -> int:
	return _golpes


## El escudo se acaba: "golpes" (se deshoja y marchita) o "fuego" (se quema).
func romper(causa: String) -> void:
	if estado != "activo":
		return
	estado = "quemado" if causa == "fuego" else "roto"
	_t_fin = 0.0
	_t_golpe = 1.0
	var quemado: bool = estado == "quemado"
	var n: int = _orb.size()
	for k in n:
		var idx: int = int(_orb[k])
		var fuera := Vector3(randf_range(-1, 1), randf_range(0.1, 0.8), randf_range(-1, 1)).normalized() * randf_range(0.5, 1.4)
		hojas.soltar(idx, fuera)
		if quemado:
			hojas.cambiar_color(idx, NaturalezaHojas.NARANJA_FUEGO, NaturalezaHojas.NEGRO_CENIZA)
			hojas.fijar_vida(idx, randf_range(1.1, 1.5))
		else:
			hojas.cambiar_color(idx, NaturalezaHojas.color_aleatorio(), NaturalezaHojas.FINAL_VERDE)
	_orb.clear()
	_orb_fase.clear()
	# hojas extra que se sueltan de la hierba / el aire, para que se lea el «deshojado»
	for i in 16:
		var a: float = randf() * TAU
		var r: float = radio * randf_range(0.3, 1.0)
		var p: Vector3 = global_position + Vector3(cos(a) * r, alto * randf_range(0.1, 0.85), sin(a) * r)
		var v := Vector3(cos(a), randf_range(0.0, 0.6), sin(a)) * randf_range(0.2, 0.9)
		var col: Color = NaturalezaHojas.NARANJA_FUEGO if quemado else NaturalezaHojas.color_aleatorio()
		var fin: Color = NaturalezaHojas.NEGRO_CENIZA if quemado else NaturalezaHojas.FINAL_VERDE
		hojas.emitir(p, v, randf_range(0.9, 1.4), randf_range(0.11, 0.17), col, fin)
	if quemado:
		brasas.emitir(global_position + Vector3(0, alto * 0.5, 0), Vector3.ZERO, 0.3, 0.4, 1.4, Color(1.0, 0.5, 0.15), Color(0.7, 0.15, 0.05), 0.7)


## ¿Ha acabado de animarse la rotura (y ya no cae ninguna hoja)?
func terminada() -> bool:
	if estado == "activo":
		return false
	var dur: float = T_FIN_FUEGO if estado == "quemado" else T_FIN_GOLPES
	return _t_fin >= dur and hojas.vivas() == 0 and brasas.vivas() == 0


func estados_hierba() -> Dictionary:
	return {"alto_medio": _h_media, "color_medio": _col_media, "brizna_n": _brz.size(), "t": _t}


func color_cupula_alfa() -> float:
	return float(_mat_cupula.get_shader_parameter("alfa_borde"))


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if estado == "activo":
		_t_golpe = minf(_t_golpe + delta, 1.0)
	else:
		_t_fin += delta
	hojas.suelo_y = global_position.y
	for k in _orb.size():
		hojas.poner_escala(int(_orb[k]), _escala_orbita(float(_orb_fase[k])))
	if estado == "quemado":
		_brasas_t += delta
		if _t_fin < 1.0 and _brasas_t >= 0.04:
			_brasas_t = 0.0
			for _k in 2:
				_brasa()
	_pintar(delta)


func _brasa() -> void:
	var a: float = randf() * TAU
	var r: float = radio * randf_range(0.5, 1.1)
	brasas.emitir(global_position + Vector3(cos(a) * r, randf_range(0.0, alto * 0.7), sin(a) * r), Vector3(randf_range(-0.2, 0.2), randf_range(0.5, 1.1), randf_range(-0.2, 0.2)),
		randf_range(0.5, 0.9), randf_range(0.07, 0.12), 0.02, Color(1.0, 0.5, 0.14), Color(0.55, 0.12, 0.05), 0.9)


func _pintar(_delta: float) -> void:
	var mm: MultiMesh = _hierba.multimesh
	var fin: float = 0.0
	if estado != "activo":
		fin = clampf(_t_fin / (T_FIN_FUEGO if estado == "quemado" else T_FIN_GOLPES), 0.0, 1.0)
	var gk: float = 1.0 - clampf(_t_golpe / T_GOLPE, 0.0, 1.0)             # 1 en el golpe, 0 al pasar
	var gk2: float = gk * gk
	var suma_h: float = 0.0
	var suma_c := Color(0, 0, 0, 0)
	for i in _brz.size():
		var b: Dictionary = _brz[i]
		var brote: float = clampf((_t - float(b["retraso"])) / T_BROTE, 0.0, 1.0)
		var crece: float = 1.0 - pow(1.0 - brote, 3.0)
		crece *= 1.0 + 0.12 * sin(brote * PI)                                  # un pasito de más al brotar
		var h: float = float(b["alto"]) * crece
		var col: Color = b["col"]
		var inclina: float = 0.14 + 0.10 * sin(_t * 1.8 + float(b["fase"])) + (0.22 if i % 2 == 0 else 0.0) * 0.0
		h *= 1.0 - 0.38 * gk2                                                  # el golpe aplasta la hierba
		inclina += 0.55 * gk2                                                  # ...y la abre hacia fuera
		col = col.lerp(Color(0.85, 1.0, 0.65), 0.55 * gk2)
		if estado == "roto":
			var m: float = smoothstep(0.0, 0.55, fin)
			col = col.lerp(NaturalezaHojas.FINAL_VERDE, m)
			h *= 1.0 - 0.75 * smoothstep(0.25, 1.0, fin)
			inclina += 1.0 * m                                                 # se echa
		elif estado == "quemado":
			var a: float = smoothstep(0.0, 0.18, fin)
			col = col.lerp(NaturalezaHojas.NARANJA_FUEGO, a)
			col = col.lerp(NaturalezaHojas.NEGRO_CENIZA, smoothstep(0.28, 0.75, fin))
			h *= 1.0 - 0.9 * smoothstep(0.35, 1.0, fin)
			inclina += 0.5 * smoothstep(0.3, 1.0, fin)
		var ang: float = _tufo_ang[int(b["tufo"])]
		var r: float = float(b["radio"]) * (1.0 + 0.1 * gk2)
		var base := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var yaw: float = float(b["yaw"])
		# el quad mira hacia fuera del anillo (±) y se inclina hacia fuera
		var rot: Basis = Basis(Vector3.UP, -yaw + PI * 0.5) * Basis(Vector3.RIGHT, -inclina)
		var an: float = float(b["ancho"]) * (0.8 + 0.2 * crece)
		if h < 0.004:
			NaturalezaHojas.ocultar(mm, i)
		else:
			mm.set_instance_transform(i, Transform3D(rot * Basis.from_scale(Vector3(an, h, h)), base))
			mm.set_instance_color(i, col.srgb_to_linear())
		suma_h += h
		suma_c += col
	var n: float = maxf(float(_brz.size()), 1.0)
	_h_media = suma_h / n
	_col_media = Color(suma_c.r / n, suma_c.g / n, suma_c.b / n, 1.0)
	# cúpula
	var ap: float = clampf((_t - 0.1) / 0.5, 0.0, 1.0)
	var alfa: float = 0.34 * ap + 0.0
	var destello: float = gk2
	var esc: float = lerpf(0.9, 1.0, ap) * (1.0 + 0.045 * gk2)
	if estado == "roto":
		alfa *= 1.0 - smoothstep(0.0, 0.35, fin)
		esc *= 1.0 + 0.12 * smoothstep(0.0, 0.35, fin)
	elif estado == "quemado":
		alfa *= 1.0 - smoothstep(0.0, 0.18, fin)
		destello = 0.0
		_mat_cupula.set_shader_parameter("color_borde", Vector3(1.0, 0.45, 0.12))
		_mat_cupula.set_shader_parameter("color_medio", Vector3(0.95, 0.35, 0.1))
	_mat_cupula.set_shader_parameter("alfa_borde", alfa + 0.14 * destello)
	_mat_cupula.set_shader_parameter("destello", destello)
	_mat_cupula.set_shader_parameter("tiempo", _t)
	_cupula.scale = Vector3.ONE * esc
	_cupula.visible = alfa > 0.002 or destello > 0.0
	# aro del suelo
	var aa: float = 0.30 * smoothstep(0.0, 0.4, _t)
	var c_aro := Color(0.28, 0.78, 0.34, aa)
	if estado == "roto":
		aa *= 1.0 - fin
		c_aro = Color(0.5, 0.45, 0.2, aa)
	elif estado == "quemado":
		aa *= 1.0 - smoothstep(0.1, 0.8, fin)
		c_aro = Color(0.12, 0.08, 0.06, aa)
	c_aro.a = aa
	_mat_aro.set_shader_parameter("modulo", c_aro)
	_aro.scale = Vector3.ONE * (0.75 + 0.25 * clampf(_t / 0.5, 0.0, 1.0)) * (1.0 + 0.06 * gk2)
