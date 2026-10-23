class_name Lava3D
extends Area3D

## LAVA (bloque 3 de la revisión EoW, 23/10). Un charco de lava sobre unas casillas: no se pisa, alumbra, prende lo inflamable que tiene al
## lado y, con AGUA o HIELO, se ENFRÍA en roca que sí se pisa (como `ac_FrozenInHotWater` / el suelo de lava de EoW). Da a una sala de fuego
## algo que solo el agua resuelve.
##
## QUÉ HACE
##   · Bloquea sus casillas (`Terreno3D.bloquear_celda`) mientras son lava.
##   · Cada `CADA_FUEGO` s prende lo del grupo `flammable3d` que esté a menos de `ALCANCE_FUEGO` de una casilla de lava (seto, tronco, cuerda…)
##     y enciende un barril que tenga al lado.
##   · Agua o hielo que caigan en una casilla de lava la enfrían, y también a sus cuatro vecinas de lava: pasan a ROCA (se pisa), sueltan vapor
##     y emiten `enfriada(celda)`; cuando ya no queda lava, `apagada`. Se entera de cualquier forma de hechizo: escucha el impacto del mundo
##     (`Mundo3D.impacto`, lo que cae en el suelo) y además es un Area3D de reactivos (`on_spell_hit`, lo que la golpea en vuelo).
##   · `vuelve` > 0: la roca vuelve a ser lava a los `vuelve` s (un puzle contrarreloj). 0 = se queda roca.
##
## EL ASPECTO lo da un plano con un shader propio (sin texturas): lava que fluye con ruido, placas de costra oscura que derivan despacio con
## grietas incandescentes entre ellas, el borde del charco más costroso (más frío) y la roca enfriada como basalto con grietas que se apagan.
## Una máscara RG8 (un píxel por casilla del rectángulo del charco: R lava, G calor de la roca recién enfriada) le dice qué es cada casilla.
##
## Se coloca desde un mapa con `; pieza <id> lava <x> <y> [celdas=<lista>] [vuelve=<s>]` (escenas/puzle.gd) o con `preparar` desde código.

signal enfriada(celda: Vector2i)
signal apagada

const ALCANCE_FUEGO: float = 0.9        ## casillas: lo inflamable a menos de esto de una casilla de lava prende
const CADA_FUEGO: float = 0.5
const T_ENFRIAR: float = 4.0            ## s que tarda la roca recién enfriada en dejar de brillar
const SOBRE_SUELO: float = 0.06         ## u por encima del suelo (un decal: el suelo sigue debajo; algo alto para tapar el rastrojo)
const SUBDIV: int = 4                   ## subdivisiones del plano por casilla (para que la superficie ondule)
const LUZ_CADA: int = 3                 ## una luz por cada 3 × 3 casillas, como mucho 4
const LUZ_COLOR: Color = Color(1.0, 0.45, 0.15)

const CODIGO: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D mascara : filter_linear, repeat_disable;     // R lava · G calor de la roca enfriada
uniform vec2 origen = vec2(0.0);       // esquina del rectángulo del charco, en u del mundo
uniform vec2 tam = vec2(1.0);          // tamaño del rectángulo, en u
uniform vec2 flujo = vec2(0.12, 0.05); // hacia dónde fluye la lava (u/s)
varying vec3 pw;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += ruido(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}
// x = distancia al borde de la celda de Voronoi, y = id de la celda.
vec2 voronoi(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(h21(ip + g), h21(ip + g + 7.7));
			float d = length(g + o - fp);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = h21(ip + g + 3.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d2 - d1, id);
}

void vertex() {
	pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Ondula un poco, solo donde es lava.
	vec2 uvm = (pw.xz - origen) / tam;
	float lava = texture(mascara, uvm).r;
	VERTEX.y += (fbm(pw.xz * 0.8 + TIME * 0.3) - 0.5) * 0.06 * lava;
}

void fragment() {
	vec2 uvm = (pw.xz - origen) / tam;
	vec3 m = texture(mascara, uvm).rgb;
	// B = parte del charco (lava o roca enfriada). El filtro lineal lo deja en 0,5 justo en el borde de la casilla: fuera, nada.
	if (m.b < 0.5) {
		discard;
	}
	// --- lava ---
	vec2 p = pw.xz;
	float n1 = fbm(p * 0.9 - flujo * TIME * 4.0);
	float n2 = fbm(p * 1.7 + vec2(n1 * 1.5) + flujo.yx * TIME * 3.0);
	float calor = clamp(n2 * 1.35 - 0.1, 0.0, 1.0);
	vec3 rojo = vec3(0.55, 0.06, 0.02);
	vec3 naranja = vec3(1.0, 0.38, 0.05);
	vec3 amarillo = vec3(1.0, 0.82, 0.35);
	vec3 lava_c = mix(mix(rojo, naranja, smoothstep(0.15, 0.6, calor)), amarillo, smoothstep(0.7, 1.0, calor));
	// Placas de costra que derivan despacio; más costra en el borde del charco (la lava se enfría donde toca tierra).
	vec2 v = voronoi(p * 1.1 - flujo * TIME * 0.6);
	float borde_charco = 1.0 - smoothstep(0.55, 0.95, m.r);
	float costra = smoothstep(0.06, 0.16, v.x) * step(v.y, 0.55 + borde_charco * 0.4);
	vec3 costra_c = mix(vec3(0.10, 0.06, 0.05), vec3(0.20, 0.12, 0.09), ruido(p * 6.0));
	vec3 c_lava = mix(lava_c, costra_c, costra);
	vec3 em_lava = lava_c * (1.0 - costra) * 1.3;     // con el bloom, más de ~1,5 quema la imagen (medido en la captura)
	// --- roca enfriada (basalto), con grietas que brillan mientras le queda calor ---
	vec2 vr = voronoi(p * 2.2 + 11.0);
	float grieta = 1.0 - smoothstep(0.0, 0.05, vr.x);
	vec3 basalto = mix(vec3(0.17, 0.16, 0.16), vec3(0.27, 0.25, 0.24), ruido(p * 5.0)) * (1.0 - grieta * 0.6);
	vec3 em_roca = naranja * grieta * m.g * 1.5;
	// m.r = 1 lava, 0 roca enfriada.
	float es_lava = smoothstep(0.35, 0.65, m.r);
	ALBEDO = mix(basalto, c_lava, es_lava);
	EMISSION = mix(em_roca, em_lava, es_lava);
	ROUGHNESS = mix(0.95, mix(0.35, 0.9, costra), es_lava);
	SPECULAR = 0.3;
}
"""

var celdas: Array[Vector2i] = []
var vuelve: float = 0.0
var is_lit: bool = false                ## queda lava (como el `is_lit` de Reactivo3D: lo leen Puzle3D y el contador)
var _lava: Dictionary = {}              ## Vector2i -> true mientras es lava
var _roca: Dictionary = {}              ## Vector2i -> s que le quedan de calor (y, con `vuelve`, para volver a ser lava)
var _rect: Rect2i = Rect2i()
var _img: Image = null
var _tex: ImageTexture = null
var _formas: Dictionary = {}            ## Vector2i -> CollisionShape3D
var _t_fuego: float = 0.0
var _sucia: bool = false


## `p_celdas`: las casillas del charco. `p_vuelve` > 0: la roca vuelve a ser lava a los `p_vuelve` s.
func preparar(p_celdas: Array, p_vuelve: float = 0.0) -> void:
	celdas.clear()
	for c in p_celdas:
		celdas.append(c as Vector2i)
	vuelve = p_vuelve
	if celdas.is_empty():
		return
	var minx: int = celdas[0].x
	var miny: int = celdas[0].y
	var maxx: int = minx
	var maxy: int = miny
	for c in celdas:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
		maxx = maxi(maxx, c.x)
		maxy = maxi(maxy, c.y)
		_lava[c] = true
		Terreno3D.bloquear_celda(c)
		# La lava quema lo que hay debajo: la hierba se queda en rastrojo (lo lee su shader del estado oficial) y no asoma por el charco.
		if Terreno3D.estados != null:
			Terreno3D.estados.poner(c, "quemada", true)
	_rect = Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
	is_lit = true
	position = Vector3.ZERO


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	if celdas.is_empty():
		return
	var s: float = Terreno3D.casilla
	# Máscara: un píxel por casilla del rectángulo, más un borde de un píxel (así el filtro lineal funde el borde del charco y no lo repite).
	_img = Image.create_empty(_rect.size.x + 2, _rect.size.y + 2, false, Image.FORMAT_RGB8)
	for c in celdas:
		_pixel(c)
	_tex = ImageTexture.create_from_image(_img)
	var y: float = Terreno3D.y_pies(celdas[0]) + SOBRE_SUELO
	var plano := PlaneMesh.new()
	plano.size = Vector2(float(_rect.size.x + 2) * s, float(_rect.size.y + 2) * s)
	plano.subdivide_width = (_rect.size.x + 2) * SUBDIV
	plano.subdivide_depth = (_rect.size.y + 2) * SUBDIV
	var sh := Shader.new()
	sh.code = CODIGO
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("mascara", _tex)
	mat.set_shader_parameter("origen", Vector2(float(_rect.position.x - 1) * s, float(_rect.position.y - 1) * s))
	mat.set_shader_parameter("tam", Vector2(float(_rect.size.x + 2) * s, float(_rect.size.y + 2) * s))
	var mi := MeshInstance3D.new()
	mi.name = "lava"
	mi.mesh = plano
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((float(_rect.position.x) + float(_rect.size.x) * 0.5) * s, y, (float(_rect.position.y) + float(_rect.size.y) * 0.5) * s)
	add_child(mi)
	# Una forma por casilla de lava, a ras de suelo: lo que vuela por encima de la roca no la toca.
	for c in celdas:
		var f := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(s, 0.4, s)
		f.shape = caja
		f.position = Vector3((float(c.x) + 0.5) * s, y + 0.2, (float(c.y) + 0.5) * s)
		add_child(f)
		_formas[c] = f
	_poner_luces(y)
	Sfx3D.ambiente(self, "fuego")
	if Mundo3D.actual != null and not Mundo3D.actual.impacto.is_connected(_al_impacto):
		Mundo3D.actual.impacto.connect(_al_impacto)
	set_process(true)


func _exit_tree() -> void:
	if Mundo3D.actual != null and Mundo3D.actual.impacto.is_connected(_al_impacto):
		Mundo3D.actual.impacto.disconnect(_al_impacto)


func _process(delta: float) -> void:
	_t_fuego += delta
	if _t_fuego >= CADA_FUEGO and not _lava.is_empty():
		_t_fuego = 0.0
		_prender_vecinos()
	var vuelven: Array[Vector2i] = []
	for c in _roca.keys():
		_roca[c] = float(_roca[c]) - delta
		_pixel(c)
		if vuelve > 0.0 and float(_roca[c]) <= T_ENFRIAR - vuelve:
			vuelven.append(c)
	for c in vuelven:
		_fundir(c)
	if _sucia and _tex != null:
		_tex.update(_img)
		_sucia = false


## ¿Esta casilla es roca enfriada (todavía no ha vuelto a ser lava)? Lo lee Puzle3D en `casilla(x,y).roca` y el basalto de la Cueva.
func es_roca(c: Vector2i) -> bool:
	return _roca.has(c)


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data == null or not _enfria(rune_data.tags):
		return
	var p: Vector3 = Lanzador3D.ultimo_impacto
	enfriar_en(Terreno3D.celda_de(p) if p != Vector3.INF else celdas[0])


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and not _lava.is_empty() and _enfria(rune_data.tags)


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 0                                # a ras: reacciona pero no detiene lo que vuela por encima


## Enfría la casilla `c` (o la de lava más cercana, si `c` no lo es) y sus cuatro vecinas de lava.
func enfriar_en(c: Vector2i) -> void:
	if _lava.is_empty():
		return
	var centro: Vector2i = c if _lava.has(c) else _mas_cercana(c)
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = centro + d
		if _lava.has(q):
			_enfriar(q)
	if _lava.is_empty():
		is_lit = false
		apagada.emit()


## --- Por dentro ---

func _enfria(tags: Array) -> bool:
	return tags.has("agua") or tags.has("frio")


func _al_impacto(punto: Vector3, elemento: String, radio: float) -> void:
	if elemento != "agua" and elemento != "hielo":
		return
	var c: Vector2i = Terreno3D.celda_de(punto)
	var c2: Vector2i = _mas_cercana(c)
	if c2 == Vector2i(-9999, -9999):
		return
	var d: Vector2 = Vector2(c2 - c)
	if d.length() <= 1.0 + radio / maxf(Terreno3D.casilla, 0.001):
		enfriar_en(c2)


func _enfriar(c: Vector2i) -> void:
	_lava.erase(c)
	_roca[c] = T_ENFRIAR
	_pixel(c)
	Terreno3D.liberar_celda(c)
	if _formas.has(c):
		(_formas[c] as CollisionShape3D).disabled = true
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if get_parent() is Node3D:
		VfxPuzle3D.vapor(get_parent() as Node3D, p + Vector3(0.0, 0.2, 0.0), 1.0)
	Sfx.play(self, "congelar")
	enfriada.emit(c)


func _fundir(c: Vector2i) -> void:
	_roca.erase(c)
	_lava[c] = true
	is_lit = true
	_pixel(c)
	Terreno3D.bloquear_celda(c)
	if _formas.has(c):
		(_formas[c] as CollisionShape3D).disabled = false


func _pixel(c: Vector2i) -> void:
	if _img == null:
		return
	var x: int = c.x - _rect.position.x + 1
	var y: int = c.y - _rect.position.y + 1
	var calor: float = clampf(float(_roca.get(c, 0.0)) / T_ENFRIAR, 0.0, 1.0)
	# B = parte del charco (lava o roca): fuera del charco no se dibuja nada.
	_img.set_pixel(x, y, Color(1.0 if _lava.has(c) else 0.0, calor, 1.0))
	_sucia = true


func _mas_cercana(c: Vector2i) -> Vector2i:
	var mejor: Vector2i = Vector2i(-9999, -9999)
	var dmin: int = 1 << 30
	for q in _lava:
		var d: int = absi(q.x - c.x) + absi(q.y - c.y)
		if d < dmin:
			dmin = d
			mejor = q
	return mejor


func _prender_vecinos() -> void:
	var s: float = Terreno3D.casilla
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_ARDE) + get_tree().get_nodes_in_group("explosionable"):
		if not is_instance_valid(n) or not (n is Node3D) or n == self:
			continue
		var cn: Vector2i = Terreno3D.celda_de((n as Node3D).global_position)
		var q: Vector2i = _mas_cercana(cn)
		if q == Vector2i(-9999, -9999):
			return
		var d: Vector3 = Terreno3D.centro_de(q, 0.0) - (n as Node3D).global_position
		d.y = 0.0
		if d.length() > (0.5 + ALCANCE_FUEGO) * s:
			continue
		if n.has_method("ignite") and not bool(n.get("is_lit")):
			n.call("ignite")
		elif n is Barril3D and not (n as Barril3D).encendido and not (n as Barril3D).explotado:
			(n as Barril3D).encender()


func _poner_luces(y: float) -> void:
	var s: float = Terreno3D.casilla
	var n: int = 0
	for by in range(_rect.position.y, _rect.end.y, LUZ_CADA):
		for bx in range(_rect.position.x, _rect.end.x, LUZ_CADA):
			if n >= 4:
				return
			var hay: bool = false
			for c in celdas:
				if c.x >= bx and c.x < bx + LUZ_CADA and c.y >= by and c.y < by + LUZ_CADA:
					hay = true
			if not hay:
				continue
			var l := OmniLight3D.new()
			l.light_color = LUZ_COLOR
			l.light_energy = 0.9
			l.omni_range = s * 2.2
			l.shadow_enabled = false
			l.position = Vector3((float(bx) + minf(LUZ_CADA, _rect.end.x - bx) * 0.5) * s, y + 0.8, (float(by) + minf(LUZ_CADA, _rect.end.y - by) * 0.5) * s)
			add_child(l)
			LuzTitila3D.aplicar(l, 0.6)
			n += 1
