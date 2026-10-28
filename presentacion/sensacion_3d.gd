class_name Sensacion3D
extends RefCounted

## GAMEFEEL, LOTE 1 (28/10, Pablo: «mejorar el gamefeel lanzando los hechizos, también contra los enemigos»). Dueño: Juego.
##
## Lo que hace que lanzar y golpear se SIENTA, en un solo sitio y con cada número a mano (`static var`, como las de `Combate3D`: un laboratorio o el playtest las cambia en vivo):
##   · al DISPARAR (`disparo`, lo llama `Lanzador3D._disparar`): la jugadora retrocede un poco, la cámara da un golpe de zoom corto, la mano destella del color del elemento y suena
##     la salida común (`lanzar_salida`) bajo el sonido del elemento;
##   · al NO PODER lanzar (`no_puedes`, lo llama `Lanzador3D` en cada negativa): un golpe seco, la página tiembla en roja en el HUD y el cursor parpadea en rojo;
##   · el HITSTOP de un golpe a un enemigo, proporcional al daño (`hitstop_de`) y COMPARTIDO: la jugadora se congela también una fracción (`Jugador3D.hitstop`);
##   · al RECIBIR daño la jugadora (`dano_recibido`): viñeta roja, temblor y un hitstop corto.
## Nada de esto cambia reglas (daño, empuje del juego, tiempos de recarga): solo cómo se ve, se oye y se nota. `ACTIVA` = false lo apaga todo.

static var ACTIVA: bool = true
# --- al disparar ---
static var RETROCESO_V0: float = 1.1           ## u/s hacia atrás al soltar (el empuje decae ×7/s: recorre ~0,16 u)
static var ZOOM_GOLPE: float = 0.025           ## la cámara se acerca un 2,5 %…
static var T_ZOOM: float = 0.12                ## …y vuelve en este tiempo
static var DESTELLO_MANO: float = 0.55         ## tamaño de la estrella de la mano (× la de impacto)
static var T_DESTELLO_MANO: float = 0.08
# --- al no poder ---
static var T_TEMBLOR_PAGINA: float = 0.3
static var T_CURSOR_NO: float = 0.25
# --- golpes a enemigos ---
static var DANO_HITSTOP_MAX: float = 40.0      ## con este daño (o más) el hitstop es el máximo (Combate3D.HITSTOP_DEBIL); con 0, el mínimo (Combate3D.HITSTOP)
static var HITSTOP_COMPARTIDO: float = 0.6     ## la jugadora se congela esta fracción del hitstop del enemigo
# --- daño recibido ---
static var T_VINETA: float = 0.22
static var ALFA_VINETA: float = 0.5
static var TEMBLOR_DANO: float = 0.35          ## intensidad de `Vfx3D.temblor` (0..1)
static var HITSTOP_DANO: float = 0.05          ## s que se congela ella al recibir un golpe

## Para las pruebas: cuántas veces se pidió cada cosa.
static var cuenta: Dictionary = {"disparo": 0, "no_puedes": 0, "dano": 0, "zoom": 0}

const CODIGO_VINETA: String = """
shader_type canvas_item;
uniform float fuerza = 0.0;
uniform vec4 color : source_color = vec4(0.85, 0.05, 0.05, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q * vec2(1.0, 0.8));
	float borde = smoothstep(0.55, 1.25, r);
	COLOR = vec4(color.rgb, borde * fuerza);
}
"""
static var _sh_vineta: Shader = null


## Hitstop (s) de un golpe de `dano` a un enemigo: de Combate3D.HITSTOP (flojo) a Combate3D.HITSTOP_DEBIL (con DANO_HITSTOP_MAX o más); si es su debilidad, el máximo.
static func hitstop_de(dano: float, debil: bool) -> float:
	if debil:
		return Combate3D.HITSTOP_DEBIL
	var k: float = clampf(dano / maxf(DANO_HITSTOP_MAX, 0.01), 0.0, 1.0)
	return lerpf(Combate3D.HITSTOP, Combate3D.HITSTOP_DEBIL, k)


## Al salir el hechizo. `dir` = hacia dónde va; `mano` = dónde nace (el destello). `retroceso` false = el hechizo no sale de la mano sino que nace donde se apunta
## (la barrera): entonces no hay empujón hacia atrás, solo el zoom, el destello y el sonido.
static func disparo(lanz: Lanzador3D, elemento: String, dir: Vector3, mano: Vector3, retroceso: bool = true) -> void:
	if not ACTIVA or lanz == null or not lanz.is_inside_tree():
		return
	cuenta["disparo"] = int(cuenta["disparo"]) + 1
	var d := Vector3(dir.x, 0.0, dir.z)
	if retroceso and lanz.jugador != null and d.length() > 0.01 and lanz.jugador.has_method("push"):
		lanz.jugador.call("push", -d.normalized(), RETROCESO_V0)
	golpe_zoom(lanz.get_viewport(), ZOOM_GOLPE, T_ZOOM)
	var fx: Variant = lanz.get("fx")
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).golpe_estrella(mano, elemento, DESTELLO_MANO, T_DESTELLO_MANO)
	Sfx.play(lanz, "lanzar_salida")


## Golpe de zoom de la cámara activa: se acerca `k` (fracción) y vuelve en `t` s. Ortográfica: `size`; en perspectiva: `fov`. Como el temblor de Vfx3D, un golpe nuevo
## parte del valor ORIGINAL (no del que dejó uno a medias), así varios seguidos no la van acercando.
static func golpe_zoom(vp: Viewport, k: float, t: float) -> void:
	if vp == null or k <= 0.0:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return
	var prop: String = "size" if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
	if cam.has_meta("zoom_base"):
		var viejo: Variant = cam.get_meta("zoom_tween")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
			cam.set(prop, float(cam.get_meta("zoom_base")))
	var base: float = float(cam.get(prop))
	cam.set_meta("zoom_base", base)
	cam.set(prop, base * (1.0 - k))
	var tw: Tween = cam.create_tween()
	cam.set_meta("zoom_tween", tw)
	tw.tween_property(cam, prop, base, maxf(t, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: cam.remove_meta("zoom_base"))
	cuenta["zoom"] = int(cuenta["zoom"]) + 1


## No se puede lanzar (recarga, tinta, ahora no…): golpe seco, la página `indice` tiembla en rojo en el HUD (si se sabe cuál) y el cursor parpadea en rojo.
static func no_puedes(lanz: Lanzador3D, indice: int = -1) -> void:
	if lanz == null:
		return
	cuenta["no_puedes"] = int(cuenta["no_puedes"]) + 1
	if not ACTIVA:
		return
	Sfx.play(lanz, "no_puedes")
	var hud: Variant = lanz.get("_page_hud")
	if indice >= 0 and hud is Control and is_instance_valid(hud) and (hud as Control).has_method("temblar"):
		(hud as Control).call("temblar", indice, T_TEMBLOR_PAGINA)
	if lanz.is_inside_tree():
		var img: Image = Apuntado3D.imagen_cursor(Apuntado3D.COLOR_NO, true)
		var tex := ImageTexture.create_from_image(img)
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(Apuntado3D.TAM_CURSOR, Apuntado3D.TAM_CURSOR) * 0.5)
		lanz.get_tree().create_timer(T_CURSOR_NO, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(lanz) and not lanz.modo_lanzar:
				Input.set_custom_mouse_cursor(null))


## La jugadora recibe `cantidad` de daño: viñeta roja, temblor y un hitstop corto. `j` es el Jugador3D.
static func dano_recibido(j: Node3D, cantidad: float) -> void:
	if not ACTIVA or j == null or not j.is_inside_tree():
		return
	cuenta["dano"] = int(cuenta["dano"]) + 1
	var fuerza: float = clampf(0.6 + cantidad / 40.0, 0.6, 1.0)
	_vineta(j, fuerza)
	var mundo: Variant = j.get("mundo")
	var fx: Variant = (mundo as Object).get("_fx") if mundo is Object else null
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).temblor(TEMBLOR_DANO * fuerza)
	if j.has_method("hitstop"):
		j.call("hitstop", HITSTOP_DANO)


## La viñeta roja: un CanvasLayer que se crea una vez por jugadora y se reutiliza.
static func _vineta(j: Node3D, fuerza: float) -> void:
	var capa: CanvasLayer = j.get_meta("vineta_dano") if j.has_meta("vineta_dano") else null
	if capa == null or not is_instance_valid(capa):
		if _sh_vineta == null:
			_sh_vineta = Shader.new()
			_sh_vineta.code = CODIGO_VINETA
		capa = CanvasLayer.new()
		capa.layer = 50
		capa.name = "VinetaDano"
		var r := ColorRect.new()
		r.name = "R"
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		m.shader = _sh_vineta
		r.material = m
		capa.add_child(r)
		j.add_child(capa)
		j.set_meta("vineta_dano", capa)
	var rect: ColorRect = capa.get_node("R") as ColorRect
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if capa.has_meta("tw"):
		var viejo: Variant = capa.get_meta("tw")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
	mat.set_shader_parameter("fuerza", ALFA_VINETA * fuerza)
	var tw: Tween = capa.create_tween()
	capa.set_meta("tw", tw)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fuerza", v), ALFA_VINETA * fuerza, 0.0, T_VINETA).set_ease(Tween.EASE_IN)
