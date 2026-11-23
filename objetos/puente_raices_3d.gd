class_name PuenteRaices3D
extends Node3D

## PUENTE DE RAÍCES (23/11, fase 1 con modelos PROVISIONALES): el hermano vegetal de `PuenteReactivo3D`. Una pieza `puente estilo=raices` de Puzle3D lo monta sobre el agua de `celdas`; lo despierta la acción
## `tender` (en la demo, la regla `cuando=tocon.germino` del bancal con tocón) y crece casilla a casilla DESDE LA PRIMERA de `celdas` (la pegada al tocón) hacia fuera.
##
## Misma interfaz que `PuenteReactivo3D` (así Puzle3D no distingue): señales `losa_lista(celda)` y `completo`; `tendido`; `preparar(...)`, `poner_hilo(...)`, `tender(desde)` y `tender_ya()`.
##
## Cada casilla es un TRAMO: 3 ramas de `raices_musgo` alargadas hasta cubrir la casilla (2,3 u), dispuestas en paralelo y giradas en alabeo para que parezcan trenzadas (si falta la escena, 3 cilindros).
## Secuencia de cada tramo (i = orden; el mismo escalonado que las losas):
##   t = RETRASO_INICIAL + i·RETRASO_TRAMO  salpicadura en el agua
##   +0,08 s                                el tramo emerge con rebote (TRANS_BACK) y SE REVELA a lo largo del eje del puente: un frente (shader, `frente` 0 → 1) con un borde verde brillante,
##                                          como el borde de `disolver` del material común de Ocluso3D, pero recortando por una COORDENADA A LO LARGO DE LA DIRECCIÓN en vez de por celdas
##   a la vez                               un giro de alabeo (TORSION) que se asienta con TRANS_ELASTIC: el «retorcido»
##   al asentarse                           `losa_lista(celda)`: la casilla pasa a ser andable (lo hace quien carga el nivel, igual que con las losas)
##   tras el último                         brotan unas hojas sobre el puente (esferas aplastadas, provisional) y salta `completo`
##
## 23/11 · ESTILO `zarcillos` (PUENTE DE ZARCILLOS, el concepto elegido; `zarcillos = true` ANTES de `preparar`). Misma clase y misma maquinaria (frente por shader, escalonado, `losa_lista`, `completo`), con otras piezas:
##   · el PRIMER tramo es el ARRANQUE: un abanico de zarcillos que salen estrechos del lado del nudo (el borde de entrada) y se abren hasta el ancho del puente (ANCHO_TEJIDO), con rizos laterales; la segunda mitad
##     ya se cruza en enrejado
##   · los tramos siguientes son TEJIDO: un enrejado plano de zarcillos cruzados (sobre-bajo) con dos bordes gruesos, cara superior plana a `y_tope`, cortes limpios del mismo ancho y alto
##   · el ÚLTIMO extremo es el ANCLAJE (`montar_anclaje`, lo llama Puzle3D si la casilla siguiente en +dir es de suelo): dos rocas con anillos verdes que se CIERRAN (escala 0 → 1 con rebote) al acabar el último tramo;
##     es solo decorado (no bloquea la casilla). `completo` sale cuando acaban de cerrarse. Sin anclaje montado, `completo` sale al acabar el último tramo como siempre
##   · todo el verde es COLOR_ZARCILLO (#9CC94A). Sin hojas de esfera (las tendrán los modelos de Meshy).
## MODELOS: los tres provisionales (arranque, tejido, anclaje) se generan por código (`ZarcilloMalla`). Si existen `arte/meshy/piezas/zarcillos_arranque.glb`, `zarcillos_tramo.glb` o `zarcillos_anclaje.glb` se usan solos
## (ver las constantes `MODELO_*`; el arranque y el tramo pasan por el mismo shader de crecimiento, con su textura; el anclaje aparece con un pop).
## No pasa por el material común de Ocluso3D (tiene su propio shader, `CODIGO_TRAMO`): no se vuelve translúcido cuando tapa a la jugadora. Pendiente cuando haya modelo definitivo.

signal losa_lista(celda: Vector2i)       ## mismo nombre que en las losas: Puzle3D conecta igual los dos estilos
signal completo

const ESCENA_RAICES: String = "res://arte/piezas/raices_musgo.tscn"
const CASILLA: float = 2.3
const ALTO: float = 0.40                 ## grosor del tramo (su cara superior es `y_tope`)
const ANCHO_RAMA: float = 0.72           ## ancho de cada rama
const ESTIRA: float = 1.8                ## cuánto más largo que la casilla se escala el modelo: su caja incluye zarcillos finos y el grueso de la malla mide ~la mitad (se vio a ojo)
const SEPARACION: float = 0.32           ## lo que se separan las ramas a lo ancho
const HUNDIDA: float = 0.7               ## cuánto más abajo que su sitio final empieza el tramo (bajo el agua)
const RETRASO_INICIAL: float = 0.45
const RETRASO_TRAMO: float = 0.12        ## igual que RETRASO_LOSA
const DURA_SUBIDA: float = 0.5
const DURA_CRECER: float = 0.8           ## lo que tarda el frente en recorrer el tramo (y los zarcillos que sobresalen: FRENTE_FIN)
const FRENTE_FIN: float = 1.7            ## el frente acaba más allá del borde de salida (1) + borde brillante + zarcillos; en `tender_ya`, 2
const BORDE: float = 0.16                ## anchura del borde brillante (fracción del largo del tramo)
const TORSION: float = 0.22              ## rad de alabeo inicial; se asienta con rebote elástico
const N_HOJAS: int = 4                   ## hojas por casilla al acabar
const COLOR_RAIZ: Color = Color(0.62, 0.72, 0.42)
## --- estilo zarcillos ---
## TODO modelo Meshy: arte/meshy/piezas/zarcillos_arranque.glb   (2,3 u de largo en X, estrecho en −X y ~1,6 u en +X, ~0,35 de grueso, origen en el centro de la base)
const MODELO_ARRANQUE: String = "res://arte/meshy/piezas/zarcillos_arranque.glb"
## TODO modelo Meshy: arte/meshy/piezas/zarcillos_tramo.glb      (2,3 × 1,6 u, ~0,3 de grueso, corte limpio en los dos extremos)
const MODELO_TRAMO: String = "res://arte/meshy/piezas/zarcillos_tramo.glb"
## TODO modelo Meshy: arte/meshy/piezas/zarcillos_anclaje.glb    (~1,8 u de ancho, postes de ~1,2 u; el tejido llega desde −X; origen en el centro de la base)
const MODELO_ANCLAJE: String = "res://arte/meshy/piezas/zarcillos_anclaje.glb"
const ROCA_ANCLAJE: String = "res://arte/piezas/piedra_est_musgo_%d.tscn"      ## provisional: dos rocas pequeñas (índices ROCAS_ANCLAJE)
const ROCAS_ANCLAJE: Array = [0, 1]
const ROCA_ALTO: float = 0.9
const ANCHO_TEJIDO: float = 1.6          ## ancho del arranque (en su extremo) y del tejido
const BASE_TEJIDO: float = 0.085         ## altura (sobre el centro del cuerpo) del eje de los zarcillos del enrejado
const ONDA_TEJIDO: float = 0.04          ## lo que sube/baja cada zarcillo al pasar por encima/por debajo
const RADIO_TEJIDO: float = 0.05
const RADIO_BORDE: float = 0.11
const COLOR_ZARCILLO: Color = Color("7E9E45")     ## verde de todo lo vivo del puente (nudo vivo, arranque, tejido, anillos, zarcillos de unión): apagado y mate; el borde brillante del frente es lo único que emite
const NUDO_LATERAL: float = 0.8                   ## u a un lado del eje del puente a la que está el nudo del bancal (y de donde nace el abanico del arranque)
const N_SLOTS: int = 8                            ## cruces transversales por casilla del enrejado
const TORSION_ZARCILLOS: float = 0.08
const RETRASO_INICIAL_ZARCILLOS: float = 0.2      ## el puente espera menos: el nudo ya está abriéndose cuando sale `germino`
const RETRASO_TRAMO_ZARCILLOS: float = 0.3        ## más espaciado que las losas: parece un único frente que avanza
const DURA_CRECER_ZARCILLOS: float = 0.6
const DURA_ANCLAJE: float = 0.35                  ## cada anillo se cierra en esto; el segundo y siguientes con 0,1 s de retraso
const COLOR_BORDE: Color = Color(0.45, 0.95, 0.25)

## Reveal por coordenada a lo largo de `dir`: t = 0 en el borde de entrada del tramo, 1 en el de salida (coordenadas del MUNDO: el rebote vertical y el alabeo sobre el eje no la cambian).
## Se descarta lo que está por delante del frente (también en la sombra) y se ilumina el borde de detrás del frente con `color_borde`.
const CODIGO_TRAMO: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D t_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 tinte : source_color = vec4(0.62, 0.72, 0.42, 1.0);
uniform vec3 origen = vec3(0.0);
uniform vec3 dir = vec3(1.0, 0.0, 0.0);
uniform float largo = 2.3;
uniform float frente : hint_range(0.0, 2.0) = 0.0;
uniform float borde = 0.16;
uniform vec3 color_borde : source_color = vec3(0.45, 0.95, 0.25);
uniform float energia_borde = 2.5;
uniform float rugosidad = 0.9;
uniform float especular = 0.5;
varying vec3 pm;
void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = dot(pm - origen, dir) / largo;
	if (t > frente) {
		discard;
	}
	float b = 1.0 - smoothstep(0.0, borde, frente - t);
	ALBEDO = texture(t_albedo, UV).rgb * tinte.rgb * COLOR.rgb;
	SPECULAR = especular;
	ROUGHNESS = rugosidad;
	EMISSION = color_borde * b * energia_borde;
}
"""

var tendido: bool = false
var _tramos: Array = []                  ## {celda, centro, dir, raiz, cuerpo, mat}
var _fx: Vfx3D = null
var _color: Color = COLOR_BORDE
var _y_tope: float = 0.0
var _y_agua: float = 0.0
var _hilo: HiloLuz3D = null
var _dura_hilo: float = 0.0
var _sombreado: Shader = null
var _hojas: Array = []                   ## MeshInstance3D de las hojas (creadas al brotar)
var _hojas_hechas: bool = false
var zarcillos: bool = false              ## estilo `zarcillos`: lo pone quien monta la pieza ANTES de `preparar`
var _ancla: Node3D = null                ## el anclaje (estilo zarcillos), si se montó
var _uniones: Array = []                 ## los zarcillos que unen cada anillo con el borde del tejido (también están en `_anillos`)
var _anillos: Array = []                 ## los anillos del anclaje provisional (Node3D con escala 0 hasta cerrarse)
var anclaje_cerrado: bool = false
var _t_anclaje: float = 0.0


## Mismos datos que `PuenteReactivo3D.preparar`. `dir_txt` (n|e|s|o) solo manda con UNA casilla; con varias, el sentido sale de `celdas` (de cada casilla a la siguiente).
func preparar(celdas: Array, centros: Array, y_tope: float, y_agua: float, fx: Vfx3D, color: Color, dir_txt: String = "") -> void:
	_fx = fx
	_color = color
	_y_tope = y_tope
	_y_agua = y_agua
	_sombreado = Shader.new()
	_sombreado.code = CODIGO_TRAMO
	for i in range(celdas.size()):
		var c: Vector2i = celdas[i]
		var p: Vector3 = centros[i]
		var d: Vector3 = _direccion(i, centros, dir_txt)
		var raiz: Node3D = Node3D.new()
		raiz.name = "tramo_%d_%d" % [c.x, c.y]
		raiz.position = Vector3(p.x, 0.0, p.z)
		raiz.rotation.y = atan2(-d.z, d.x)       # el eje x local del tramo mira hacia `d`
		raiz.visible = false
		add_child(raiz)
		var cuerpo: Node3D = Node3D.new()
		cuerpo.name = "cuerpo"
		cuerpo.position.y = _y_final() - HUNDIDA
		raiz.add_child(cuerpo)
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = _sombreado
		mat.set_shader_parameter("largo", CASILLA)
		mat.set_shader_parameter("borde", BORDE)
		mat.set_shader_parameter("color_borde", color)
		mat.set_shader_parameter("frente", 0.0)
		if zarcillos:
			mat.set_shader_parameter("rugosidad", 0.88)
			mat.set_shader_parameter("especular", 0.2)
			mat.set_shader_parameter("energia_borde", 3.4)
			_montar_zarcillos(cuerpo, mat, i, d)
		else:
			_montar_ramas(cuerpo, mat, i * 7 + c.x * 3 + c.y)
		_tramos.append({"celda": c, "centro": p, "dir": d, "raiz": raiz, "cuerpo": cuerpo, "mat": mat})


## Sentido del tramo `i`: hacia la casilla siguiente (el último, el mismo que el anterior); con una sola, `dir_txt` (por defecto hacia +z, el sur del mapa). Siempre un eje (±x o ±z).
func _direccion(i: int, centros: Array, dir_txt: String) -> Vector3:
	var d: Vector3 = Vector3(0.0, 0.0, 1.0)
	if centros.size() > 1:
		var a: Vector3 = centros[i] if i < centros.size() - 1 else centros[i - 1]
		var b: Vector3 = centros[i + 1] if i < centros.size() - 1 else centros[i]
		d = Vector3(b.x - a.x, 0.0, b.z - a.z)
	else:
		match dir_txt:
			"n": d = Vector3(0.0, 0.0, -1.0)
			"e": d = Vector3(1.0, 0.0, 0.0)
			"o": d = Vector3(-1.0, 0.0, 0.0)
	if absf(d.x) >= absf(d.z):
		return Vector3(signf(d.x) if d.x != 0.0 else 1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(d.z))


## Sentido en que termina el puente (el del último tramo): hacia dónde queda la casilla de llegada.
func direccion_final() -> Vector3:
	return (_tramos.back()["dir"] as Vector3) if not _tramos.is_empty() else Vector3(0.0, 0.0, 1.0)


func _y_final() -> float:
	return _y_tope - ALTO * 0.5


## Un hilo de luz que va del activador al puente (como en las losas): el crecimiento empieza cuando la luz llega.
func poner_hilo(hilo: HiloLuz3D, dura: float) -> void:
	_hilo = hilo
	_dura_hilo = dura


## Tiende el puente. `desde` se ignora (crece siempre desde la primera casilla de `celdas`, la del tocón); está por compatibilidad con las losas. Una sola vez.
func tender(_desde: Vector3 = Vector3.INF) -> void:
	if tendido or _tramos.is_empty():
		return
	tendido = true
	if _hilo != null:
		_hilo.viajar(_dura_hilo)
	for i in range(_tramos.size()):
		_secuencia(_tramos[i] as Dictionary, i, i == _tramos.size() - 1)


## Tendido YA, sin animación (partida cargada: `tendido_si=`). Cada tramo sale completo, asentado y avisa con `losa_lista`; sin hojas animadas (salen puestas) y sin `completo`.
func tender_ya() -> void:
	if tendido or _tramos.is_empty():
		return
	tendido = true
	for l in _tramos:
		var d: Dictionary = l
		(d["raiz"] as Node3D).visible = true
		(d["cuerpo"] as Node3D).position.y = _y_final()
		(d["cuerpo"] as Node3D).rotation.x = 0.0
		(d["mat"] as ShaderMaterial).set_shader_parameter("frente", 2.0)
		_orientar(d)
		losa_lista.emit(d["celda"] as Vector2i)
	_cerrar_anclaje(false)
	_poner_hojas(false)


func _secuencia(l: Dictionary, i: int, ultima: bool) -> void:
	var cuerpo: Node3D = l["cuerpo"]
	var mat: ShaderMaterial = l["mat"]
	var tw: Tween = create_tween()
	var r_ini: float = RETRASO_INICIAL_ZARCILLOS if zarcillos else RETRASO_INICIAL
	var r_tramo: float = RETRASO_TRAMO_ZARCILLOS if zarcillos else RETRASO_TRAMO
	var dura: float = DURA_CRECER_ZARCILLOS if zarcillos else DURA_CRECER
	var tors: float = TORSION_ZARCILLOS if zarcillos else TORSION
	tw.tween_interval(r_ini + _dura_hilo + float(i) * r_tramo)
	tw.tween_callback(_salpicar.bind(l["centro"] as Vector3))
	tw.tween_interval(0.08)
	tw.tween_callback(_empezar.bind(l, tors if i % 2 == 0 else -tors))
	tw.tween_property(cuerpo, "position:y", _y_final(), DURA_SUBIDA).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("frente", v), 0.0, FRENTE_FIN, dura).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cuerpo, "rotation:x", 0.0, DURA_SUBIDA + 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(losa_lista.emit.bind(l["celda"] as Vector2i))
	if ultima:
		if _ancla != null:
			tw.tween_callback(_cerrar_anclaje.bind(true))
			tw.tween_interval(_t_anclaje)
		tw.tween_callback(_poner_hojas.bind(true))
		tw.tween_callback(completo.emit)


## Arranca un tramo: lo hace visible con el frente a cero y el alabeo inicial, y le dice al shader dónde empieza (el borde de entrada) y hacia dónde crece.
func _empezar(l: Dictionary, torsion: float) -> void:
	(l["raiz"] as Node3D).visible = true
	(l["cuerpo"] as Node3D).rotation.x = torsion
	(l["mat"] as ShaderMaterial).set_shader_parameter("frente", 0.0)
	_orientar(l)


func _orientar(l: Dictionary) -> void:
	var d: Vector3 = l["dir"]
	var c: Vector3 = l["centro"]
	var origen: Vector3 = Vector3(c.x, 0.0, c.z) - d * (CASILLA * 0.5)
	if is_inside_tree():
		origen = to_global(origen)
		d = (global_transform.basis * d).normalized()
	var mat: ShaderMaterial = l["mat"]
	mat.set_shader_parameter("origen", origen)
	mat.set_shader_parameter("dir", d)


func _salpicar(p: Vector3) -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.salpicadura(Vector3(p.x, _y_agua, p.z), 1.0)


## Las ramas del tramo: 3 `raices_musgo` alargadas hasta cubrir la casilla (largo CASILLA·ESTIRA a lo largo de x, ALTO de grueso, ANCHO_RAMA de ancho), separadas a lo ancho y giradas en alabeo para que parezcan
## trenzadas. Todas comparten el material del tramo. Sin la escena, tres cilindros.
func _montar_ramas(cuerpo: Node3D, mat: ShaderMaterial, semilla: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla + 4711
	var ps: PackedScene = load(ESCENA_RAICES) as PackedScene if ResourceLoader.exists(ESCENA_RAICES) else null
	var base: Texture2D = null
	for k in range(3):
		var rama: Node3D = Node3D.new()
		rama.name = "rama_%d" % k
		rama.position = Vector3(0.0, 0.0, (float(k) - 1.0) * SEPARACION)
		rama.rotation.x = (float(k) - 1.0) * 0.5 + rng.randf_range(-0.12, 0.12)     # alabeo: la del medio recta, las de los lados ladeadas
		rama.rotation.y = rng.randf_range(-0.07, 0.07)
		cuerpo.add_child(rama)
		var modelo: Node3D = null
		if ps != null:
			modelo = _modelo_ajustado(ps, k % 2 == 1)
		if modelo == null:
			modelo = _cilindro()
		rama.add_child(modelo)
		for mi in modelo.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if base == null and m.mesh != null:
				var bm: BaseMaterial3D = m.get_active_material(0) as BaseMaterial3D
				if bm != null and bm.albedo_texture != null:
					base = bm.albedo_texture
			m.material_override = mat
	if base != null:
		mat.set_shader_parameter("t_albedo", base)
	mat.set_shader_parameter("tinte", COLOR_RAIZ)


## Una instancia de la escena de raíces, escalada (x, y, z por separado) a la caja ALARGADA de una rama y centrada en el origen. Si su lado largo es z, se gira 90° antes. `espejo` la vuelve del revés
## para que las ramas no sean idénticas.
func _modelo_ajustado(ps: PackedScene, espejo: bool) -> Node3D:
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return null
	for cuerpo in inst.find_children("*", "CollisionObject3D", true, false):    # decorado: sin colisiones
		(cuerpo as Node).get_parent().remove_child(cuerpo as Node)
		(cuerpo as Node).free()
	var soporte: Node3D = Node3D.new()
	soporte.add_child(inst)
	var caja: AABB = _caja(soporte)
	if caja.size.x <= 0.0001 or caja.size.y <= 0.0001 or caja.size.z <= 0.0001:
		soporte.free()
		return null
	if caja.size.z > caja.size.x:
		inst.rotation.y = PI * 0.5
		caja = _caja(soporte)
	if espejo:
		inst.rotation.y += PI
		caja = _caja(soporte)
	var s: Vector3 = Vector3(CASILLA * ESTIRA / caja.size.x, ALTO / caja.size.y, ANCHO_RAMA / caja.size.z)
	var envoltura: Node3D = Node3D.new()
	envoltura.add_child(soporte)
	envoltura.scale = s
	envoltura.position = -caja.get_center() * s
	var raiz: Node3D = Node3D.new()
	raiz.add_child(envoltura)
	return raiz


func _cilindro() -> Node3D:
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = ANCHO_RAMA * 0.4
	cil.bottom_radius = ANCHO_RAMA * 0.4
	cil.height = CASILLA * 1.03
	cil.radial_segments = 8
	mi.mesh = cil
	mi.rotation.z = PI * 0.5               # el eje del cilindro (y) pasa a x
	var raiz: Node3D = Node3D.new()
	raiz.add_child(mi)
	return raiz


## Caja de las mallas de `n` en el espacio de `n` (sin la transformación del propio `n`).
func _caja(n: Node) -> AABB:
	var r := AABB()
	var primero: bool = true
	for h in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = mi.mesh.get_aabb()
		var t: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		a = t * a
		r = a if primero else r.merge(a)
		primero = false
	return r


## Unas hojas sueltas sobre el puente (provisional: esferas aplastadas verdes). `animar`: brotan una a una con rebote; si no (partida cargada), salen ya puestas. Una sola vez.
func _poner_hojas(animar: bool) -> void:
	if _hojas_hechas:
		return
	_hojas_hechas = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.68, 0.26)
	mat.roughness = 0.8
	var n: int = 0
	var efectos: Array = []
	for l in _tramos:
		var d: Dictionary = l
		var c: Vector3 = d["centro"]
		var dir: Vector3 = d["dir"]
		var lado: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		for k in range(0 if zarcillos else N_HOJAS):
			var hoja := MeshInstance3D.new()
			var esfera := SphereMesh.new()
			esfera.radius = rng.randf_range(0.08, 0.14)
			esfera.height = esfera.radius * 2.0
			esfera.radial_segments = 8
			esfera.rings = 4
			esfera.material = mat
			hoja.mesh = esfera
			hoja.position = c + dir * rng.randf_range(-1.0, 1.0) + lado * rng.randf_range(-0.45, 0.45)
			hoja.position.y = _y_tope + 0.03
			hoja.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU), rng.randf_range(-0.5, 0.5))
			var forma: Vector3 = Vector3(1.0, 0.28, 0.62)
			hoja.scale = forma
			add_child(hoja)
			_hojas.append(hoja)
			if animar and is_inside_tree():
				hoja.scale = Vector3.ZERO
				var tw: Tween = create_tween()
				tw.tween_interval(0.05 * float(n))
				tw.tween_property(hoja, "scale", forma, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			n += 1
		if animar and _fx != null and is_instance_valid(_fx):
			efectos.append(_fx.esporas(Vector3(c.x, _y_tope + 0.2, c.z)))
	if not efectos.is_empty() and is_inside_tree():
		var vfx: Vfx3D = _fx
		get_tree().create_timer(1.2).timeout.connect(func() -> void:        # las esporas se quedan emitiendo: las suelta quien las pide
			for ef in efectos:
				if is_instance_valid(vfx) and is_instance_valid(ef):
					vfx.apagar(ef as Node3D))


# ------------------------------------------------------------------ estilo zarcillos ------------------------------------------------------------------

## Material de los zarcillos provisionales y de los modelos de Meshy: el shader de crecimiento con el verde común.
func _montar_zarcillos(cuerpo: Node3D, mat: ShaderMaterial, i: int, d: Vector3) -> void:
	mat.set_shader_parameter("tinte", COLOR_ZARCILLO)
	var ruta: String = MODELO_ARRANQUE if i == 0 else MODELO_TRAMO
	var modelo: Node3D = _glb_tramo(ruta, mat)
	if modelo != null:
		cuerpo.add_child(modelo)
		return
	var mi := MeshInstance3D.new()
	mi.name = "arranque" if i == 0 else "tejido"
	mi.mesh = _malla_arranque(lado_nudo(d) * NUDO_LATERAL) if i == 0 else _malla_tejido(i)
	mi.material_override = mat
	cuerpo.add_child(mi)


## Un `.glb` de Meshy para el arranque o el tramo (null si no existe): sin colisiones, escalado a CASILLA de largo, centrado en x/z y con su cara de arriba a +ALTO/2 del cuerpo. Usa el shader de crecimiento con la textura del modelo.
func _glb_tramo(ruta: String, mat: ShaderMaterial) -> Node3D:
	if not ResourceLoader.exists(ruta):
		return null
	var ps: PackedScene = load(ruta) as PackedScene
	var inst: Node3D = ps.instantiate() as Node3D if ps != null else null
	if inst == null:
		return null
	for cuerpo in inst.find_children("*", "CollisionObject3D", true, false):
		(cuerpo as Node).get_parent().remove_child(cuerpo as Node)
		(cuerpo as Node).free()
	var soporte: Node3D = Node3D.new()
	soporte.add_child(inst)
	var caja: AABB = _caja(soporte)
	if caja.size.x <= 0.0001:
		soporte.free()
		return null
	var esc: float = CASILLA / caja.size.x
	soporte.scale = Vector3.ONE * esc
	soporte.position = Vector3(-caja.get_center().x * esc, ALTO * 0.5 - caja.end.y * esc, -caja.get_center().z * esc)
	var base: Texture2D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if base == null and m.mesh != null:
			var bm: BaseMaterial3D = m.get_active_material(0) as BaseMaterial3D
			if bm != null and bm.albedo_texture != null:
				base = bm.albedo_texture
		m.material_override = mat
	if base != null:
		mat.set_shader_parameter("t_albedo", base)
		mat.set_shader_parameter("tinte", Color.WHITE)
	var raiz: Node3D = Node3D.new()
	raiz.add_child(soporte)
	return raiz


## Lado (±1, en el eje z LOCAL del tramo, que en el mundo es (−d.z, 0, d.x)) en el que queda el nudo del bancal respecto al eje del puente: siempre el más cercano a la cámara (la cámara mira al norte desde el sur:
## z mundo positivo; con el puente hacia n o s, el lado +x). Lo usan el bancal (para colocar el nudo) y el arranque (para que el abanico nazca en él).
static func lado_nudo(d: Vector3) -> float:
	var lat: Vector3 = Vector3(-d.z, 0.0, d.x)
	if absf(lat.z) > 0.01:
		return signf(lat.z)
	return signf(lat.x)


## Altura del eje de un zarcillo del enrejado en `x` (local del tramo): sube/baja alternando con el cruce. `j` = índice de la fila (0 = borde), `amp` = cuánto de enrejado hay (0 = plano).
func _y_trama(x: float, j: int, amp: float) -> float:
	var paso: float = CASILLA / float(N_SLOTS)
	return BASE_TEJIDO - ONDA_TEJIDO * amp * cos(PI * ((x + CASILLA * 0.5) / paso - 0.5) + PI * float(j))


## Posiciones z de las filas del enrejado: [borde −, 5 interiores, borde +].
func _filas_z() -> Array:
	var b: float = ANCHO_TEJIDO * 0.5 - RADIO_BORDE
	return [-b, -0.5, -0.25, 0.0, 0.25, 0.5, b]


## El TEJIDO: 5 zarcillos longitudinales que suben y bajan (+ 10 transversales que hacen lo contrario) entre dos bordes gruesos rectos. Cara superior plana (el techo de todos es ALTO/2). Con unos rizos solo en los lados.
func _malla_tejido(_i: int) -> ArrayMesh:
	var zm := ZarcilloMalla.new()
	var filas: Array = _filas_z()
	var mitad: float = CASILLA * 0.5
	var b: float = float(filas[6])
	# Bordes gruesos.
	for lado in [-1.0, 1.0]:
		zm.tubo(PackedVector3Array([Vector3(-mitad, 0.09, b * lado), Vector3(0.0, 0.09, b * lado), Vector3(mitad, 0.09, b * lado)]), RADIO_BORDE, RADIO_BORDE, 6, true)
	# Longitudinales (filas 1..5).
	for j in range(1, 6):
		var pts := PackedVector3Array()
		for k in range(41):
			var x: float = -mitad + CASILLA * float(k) / 40.0
			pts.append(Vector3(x, _y_trama(x, j, 1.0), float(filas[j])))
		zm.tubo(pts, RADIO_TEJIDO, RADIO_TEJIDO, 5, true)
	# Transversales: sobre-bajo contrario al de las longitudinales.
	var paso: float = CASILLA / float(N_SLOTS)
	for sl in range(N_SLOTS):
		var x: float = -mitad + (float(sl) + 0.5) * paso
		var pts := PackedVector3Array()
		for j in range(7):
			var yj: float = 0.09
			if j > 0 and j < 6:
				yj = BASE_TEJIDO + (BASE_TEJIDO - _y_trama(x, j, 1.0))
			if j > 0:
				pts.append(Vector3(x, (pts[pts.size() - 1].y + yj) * 0.5, (float(filas[j - 1]) + float(filas[j])) * 0.5))
			pts.append(Vector3(x, yj, float(filas[j])))
		zm.tubo(pts, RADIO_TEJIDO, RADIO_TEJIDO, 5, true)
	# Rizos laterales (solo en los lados).
	zm.rizo(Vector3(-0.55, 0.12, b + 0.05), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), 0.13, 1.4, 0.035)
	zm.rizo(Vector3(0.45, 0.12, -b - 0.05), Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), 0.13, 1.4, 0.035)
	return zm.malla()


## El ARRANQUE: 7 zarcillos que parten juntos del borde de entrada (−x, ~0,45 de ancho) y se abren hasta las filas del tejido (los dos de fuera acaban como bordes gruesos); en la segunda mitad empiezan a cruzarse
## (transversales y subida/bajada) hasta casar con el tejido en el borde de salida. Rizos sueltos en los lados.
func _malla_arranque(z0: float = 0.0) -> ArrayMesh:
	var zm := ZarcilloMalla.new()
	var filas: Array = _filas_z()
	var mitad: float = CASILLA * 0.5
	var pasos: int = 28
	var z_ini: Array = []
	for k in range(7):
		z_ini.append(z0 + lerpf(-0.18, 0.18, float(k) / 6.0))
	var trazados: Array = []        # por fila: los puntos del zarcillo
	for j in range(7):
		var pts := PackedVector3Array()
		for k in range(pasos + 1):
			var u: float = float(k) / float(pasos)
			var x: float = -mitad + CASILLA * u
			var e: float = 1.0 - pow(1.0 - u, 1.8)            # se abre deprisa y luego sigue paralelo
			var z: float = lerpf(float(z_ini[j]), float(filas[j]), e)
			var amp: float = clampf((u - 0.4) / 0.35, 0.0, 1.0)
			var y: float = 0.09
			if j > 0 and j < 6:
				y = lerpf(BASE_TEJIDO, _y_trama(x, j, 1.0), amp)
			pts.append(Vector3(x, y, z))
		trazados.append(pts)
		var borde: bool = j == 0 or j == 6
		zm.tubo(pts, 0.045, RADIO_BORDE if borde else RADIO_TEJIDO, 6 if borde else 5, true)
	# Transversales de la segunda mitad.
	var paso: float = CASILLA / float(N_SLOTS)
	for sl in range(N_SLOTS / 2, N_SLOTS):
		var x: float = -mitad + (float(sl) + 0.5) * paso
		var u: float = (x + mitad) / CASILLA
		var amp: float = clampf((u - 0.4) / 0.35, 0.0, 1.0)
		var k: int = clampi(int(round(u * float(pasos))), 0, pasos)
		var pts := PackedVector3Array()
		for j in range(7):
			var pj: Vector3 = (trazados[j] as PackedVector3Array)[k]
			var yj: float = 0.09
			if j > 0 and j < 6:
				yj = BASE_TEJIDO + (BASE_TEJIDO - _y_trama(x, j, 1.0)) * amp
			if j > 0:
				var pa: Vector3 = (trazados[j - 1] as PackedVector3Array)[k]
				pts.append(Vector3(x, (pts[pts.size() - 1].y + yj) * 0.5, (pa.z + pj.z) * 0.5))
			pts.append(Vector3(x, yj, pj.z))
		zm.tubo(pts, RADIO_TEJIDO * 0.9, RADIO_TEJIDO, 5, true)
	# Rizos sueltos en los costados, saliendo de los zarcillos de fuera.
	for dato in [[0.28, 1.0], [0.5, -1.0], [0.68, 1.0]]:
		var u2: float = float(dato[0])
		var lado: float = float(dato[1])
		var jf: int = 6 if lado > 0.0 else 0
		var pj2: Vector3 = (trazados[jf] as PackedVector3Array)[int(round(u2 * float(pasos)))]
		zm.rizo(pj2 + Vector3(0.0, 0.03, lado * 0.06), Vector3(0.3, 0.0, lado).normalized(), Vector3(-lado, 0.0, 0.0), 0.14, 1.5, 0.035)
	return zm.malla()


## Monta el ANCLAJE en la casilla de llegada (`centro` = centro de esa casilla a la altura del suelo, en el espacio del puente): dos rocas a los lados del final del tejido y anillos verdes que, al acabar el último tramo,
## se cierran sobre ellas. Solo decorado: no toca el bloqueo de la casilla. Con `zarcillos_anclaje.glb` se usa ese modelo (aparece con un pop). Una sola vez, después de `preparar`.
func montar_anclaje(centro: Vector3) -> void:
	if _ancla != null or _tramos.is_empty():
		return
	var d: Vector3 = direccion_final()
	var lado: Vector3 = Vector3(-d.z, 0.0, d.x)
	_ancla = Node3D.new()
	_ancla.name = "anclaje"
	_ancla.position = centro
	add_child(_ancla)
	var glb: Node3D = _glb_anclaje()
	if glb != null:
		glb.rotation.y = atan2(-d.z, d.x)
		glb.scale = Vector3.ZERO
		_ancla.add_child(glb)
		_anillos.append(glb)
		_t_anclaje = DURA_ANCLAJE + 0.1
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ZARCILLO
	mat.roughness = 0.85
	var k: int = 0
	for signo in [-1.0, 1.0]:
		var roca: Node3D = _roca(int(ROCAS_ANCLAJE[k % ROCAS_ANCLAJE.size()]))
		var pos: Vector3 = d * (-CASILLA * 0.5 + 0.45) + lado * (ANCHO_TEJIDO * 0.5 + 0.12) * float(signo)
		var radio_roca: float = 0.3
		if roca != null:
			roca.position = Vector3(pos.x, roca.position.y, pos.z)
			roca.rotation.y = float(k) * 1.7
			_ancla.add_child(roca)
			var caja: AABB = _caja(roca)
			radio_roca = 0.5 * maxf(caja.size.x, caja.size.z) * 0.9 * roca.scale.x
		for h in [0.36, 0.64]:
			var anillo: MeshInstance3D = MeshInstance3D.new()
			var toro := TorusMesh.new()
			toro.inner_radius = radio_roca
			toro.outer_radius = radio_roca + 0.15
			toro.rings = 16
			toro.ring_segments = 8
			var mat_a: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
			var f: float = 1.0 + 0.06 * float(_anillos.size() % 3 - 1)         # un tono distinto por anillo
			mat_a.albedo_color = Color(COLOR_ZARCILLO.r * f, COLOR_ZARCILLO.g * f, COLOR_ZARCILLO.b * f)
			toro.material = mat_a
			anillo.mesh = toro
			anillo.position = Vector3(pos.x, ROCA_ALTO * float(h), pos.z)
			anillo.rotation = Vector3(0.12 * float(signo), 0.0, 0.1 * float(h))
			anillo.scale = Vector3.ZERO
			_ancla.add_child(anillo)
			_anillos.append(anillo)
			# De cada anillo baja un zarcillo grueso que recorre el suelo de la casilla y se mete en el borde final del tejido (el borde grueso de su lado).
			var salida: Vector3 = anillo.position - d * (radio_roca + 0.075)
			var y_borde: float = (_y_tope - centro.y) - ALTO * 0.5 + 0.09
			var llegada: Vector3 = d * (-CASILLA * 0.5) + lado * (ANCHO_TEJIDO * 0.5 - RADIO_BORDE) * float(signo)
			llegada.y = y_borde
			_union(salida, llegada, mat_a)
		k += 1
	_t_anclaje = DURA_ANCLAJE + 0.1 * float(_anillos.size() - 1) + 0.1


## Zarcillo de unión de un anillo al borde del tejido: curva suave (Catmull-Rom) que baja del anillo al suelo de la casilla de llegada y converge hacia `llegada`. Cuelga de un pivote en `salida` para que crezca
## desde el anillo con la misma escala que los anillos (entra en `_anillos`). Sin colisión. Mismo verde y sombreado que el resto (color por vértice).
func _union(salida: Vector3, llegada: Vector3, mat: StandardMaterial3D) -> void:
	var suelo: float = 0.1
	var g1: Vector3 = salida.lerp(llegada, 0.25)
	g1.y = suelo + 0.05
	var g2: Vector3 = salida.lerp(llegada, 0.6)
	g2.y = lerpf(suelo, llegada.y, 0.6)
	var guia: Array = [salida + Vector3(0.0, 0.05, 0.0), g1, g2, llegada]
	var cola: Vector3 = llegada + (llegada - g2).normalized() * 0.1
	var puntos: Array = [salida + (salida - g1).normalized() * 0.1] + guia + [cola]
	var pts := PackedVector3Array()
	for i in range(1, puntos.size() - 2):
		for k in range(6):
			var t: float = float(k) / 6.0
			pts.append(_catmull(puntos[i - 1], puntos[i], puntos[i + 1], puntos[i + 2], t) - salida)
	pts.append(llegada - salida)
	var zm := ZarcilloMalla.new()
	zm.tubo(pts, RADIO_BORDE * 0.8, RADIO_BORDE, 6, true)
	var mat_u: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
	mat_u.vertex_color_use_as_albedo = true
	mat_u.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = zm.malla()
	mi.material_override = mat_u
	var pivote: Node3D = Node3D.new()
	pivote.name = "union"
	pivote.position = salida
	pivote.scale = Vector3.ZERO
	pivote.add_child(mi)
	_ancla.add_child(pivote)
	_anillos.append(pivote)
	_uniones.append(pivote)


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _glb_anclaje() -> Node3D:
	if not ResourceLoader.exists(MODELO_ANCLAJE):
		return null
	var ps: PackedScene = load(MODELO_ANCLAJE) as PackedScene
	var n: Node3D = ps.instantiate() as Node3D if ps != null else null
	if n == null:
		return null
	for cuerpo in n.find_children("*", "CollisionObject3D", true, false):
		(cuerpo as Node).get_parent().remove_child(cuerpo as Node)
		(cuerpo as Node).free()
	return n


## Una roca provisional (escena de `piedra_est_musgo_N`), sin colisión, a ROCA_ALTO de alto y con la base en y = 0 (el suelo de la casilla). Sin la escena, un cilindro.
func _roca(n: int) -> Node3D:
	var ruta: String = ROCA_ANCLAJE % n
	var inst: Node3D = null
	if ResourceLoader.exists(ruta):
		var ps: PackedScene = load(ruta) as PackedScene
		inst = ps.instantiate() as Node3D if ps != null else null
	if inst != null:
		for cuerpo in inst.find_children("*", "CollisionObject3D", true, false):
			(cuerpo as Node).get_parent().remove_child(cuerpo as Node)
			(cuerpo as Node).free()
		var soporte: Node3D = Node3D.new()
		soporte.add_child(inst)
		var caja: AABB = _caja(soporte)
		if caja.size.y > 0.0001:
			var esc: float = ROCA_ALTO / caja.size.y
			var envoltura: Node3D = Node3D.new()
			soporte.position = -Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
			envoltura.add_child(soporte)
			envoltura.scale = Vector3.ONE * esc
			return envoltura
		soporte.free()
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.22
	cil.bottom_radius = 0.3
	cil.height = ROCA_ALTO
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.48)
	m.roughness = 0.95
	cil.material = m
	mi.mesh = cil
	mi.position.y = ROCA_ALTO * 0.5
	return mi


## Los anillos se cierran sobre las rocas (escala 0 → 1 con rebote, uno tras otro) y salta un destello. `animar` = false: ya cerrados.
func _cerrar_anclaje(animar: bool) -> void:
	if _ancla == null or anclaje_cerrado:
		return
	anclaje_cerrado = true
	var n: int = 0
	for a in _anillos:
		var anillo: Node3D = a as Node3D
		if animar and is_inside_tree():
			var tw: Tween = create_tween()
			tw.tween_interval(0.1 * float(n))
			tw.tween_property(anillo, "scale", Vector3.ONE, DURA_ANCLAJE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			anillo.scale = Vector3.ONE
		n += 1
	if animar and _fx != null and is_instance_valid(_fx) and is_inside_tree():
		var ef: Node3D = _fx.destellos(to_global(_ancla.position) + Vector3(0.0, 0.7, 0.0), _color)
		var vfx: Vfx3D = _fx
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(vfx) and is_instance_valid(ef):
				vfx.apagar(ef))
