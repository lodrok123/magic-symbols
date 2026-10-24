class_name SecuenciaCofreLegendario3D
extends Node

## LA SECUENCIA DEL COFRE LEGENDARIO (23/10, FASE 2 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §8 y §10 punto 6). La dirige el `CofrePuzle` con modelo `legendario` cuando el jugador lo abre
## (E): bloquea el control, acerca la cámara (primer plano), baja la luz de la zona, abre la tapa (el `Cofre3D` de siempre), suelta una onda dorada por las vetas de la sala, saca el
## GLIFO girando con un halo, un DESTELLO (más fuerte que el de §8: blanco casi pleno, un desenfoque radial y un pico de luz), lo hace caer en el libro (una página que se abre sola), donde se
## ESCRIBE de arriba abajo con su nombre en dorado, y lo desbloquea (`Repertoire.unlock_sigil`). Al final devuelve la luz, la cámara y el control, y avisa en dorado.
##
## TIEMPOS (s desde que el jugador pulsa E; constantes `T_*`): 0,0 control, cámara y franjas · 0,4 la luz baja y empieza a abrirse el cofre (anticipa 0,4 s + clip) · 0,8 la tapa se abre y
## la onda recorre las vetas · 1,4 sale el glifo · 2,6 destello y el glifo cae al libro · 3,2 se escribe · 4,5 vuelve todo y sale el aviso.
## SE PUEDE SALTAR a partir de la segunda vez que se ve (la flag global `FLAG_VISTA`): E, Espacio, Intro o Esc. Saltar lleva a mano al final (glifo desbloqueado, aviso, luz y cámara en su sitio).
##
## LA ANIMACIÓN DE LA JUGADORA «abrir cofre» (24/10: clip `abrir_cofre` de Meshy, arte/meshy/clips_jugadora.py; antes se usaba `pick_up`): se inclina y baja las dos manos. Sus manos llegan
## abajo a los `Pj3D.instante_clip("abrir_cofre")` = 1,4 s del clip; el clip se acelera (`VEL_ABRIR`) para que eso pase justo a `T_ONDA`, cuando la tapa empieza a girar. Se queda
## agachada hasta `T_DESTELLO` (cae el glifo al libro) y entonces vuelve a idle. Si la jugadora no tiene el clip, no se mueve de su sitio.
##
## Es un Node suelto: lo crea y libera el CofrePuzle. Sin mundo, sin lanzador o sin cámara (pruebas) cada paso que lo necesita se salta, y la secuencia acaba igual.

signal glifo_escrito                 ## el glifo ya está en el libro (desbloqueado)
signal terminada

const FLAG_VISTA: String = "global.cofre.legendario_visto"
const ROL_ANIMACION: String = "abrir_cofre"      ## el clip de la jugadora (rol de Pj3D.SINONIMOS)

const T_LUZ: float = 0.4                         ## s: la luz empieza a bajar y se abre el cofre (el Cofre3D anticipa T_ANTICIPA antes de girar la tapa)
const T_ONDA: float = 0.8                        ## s: se abre la tapa y la onda corre por las vetas
const T_GLIFO: float = 1.4                       ## s: sale el glifo
const T_DESTELLO: float = 2.6                    ## s: destello y caída al libro
const T_ESCRIBE: float = 3.2                     ## s: se escribe en la página
const T_FIN: float = 4.5                         ## s: vuelve la luz, la cámara y el control
const VEL_ABRIR_MAX: float = 2.0                 ## tope de la velocidad del clip de abrir (más deprisa se ve a trompicones)
const T_SUBE_GLIFO: float = 1.2                  ## s que tarda el glifo en subir
const T_CAE_GLIFO: float = 0.6                   ## s que tarda en caer al libro
const T_ESCRITURA: float = 0.9                   ## s que tarda en escribirse el trazo
const T_NOMBRE: float = 0.3                      ## s que tarda en aparecer su nombre (acaba a los 3,2 + 0,9 + 0,3 = 4,4 s: antes de que vuelva la luz)
const T_ZOOM: float = 0.6                        ## s del acercamiento de cámara
const T_LUZ_BAJA: float = 0.45
const ALTO_ENCUADRE: float = 1.5                 ## u sobre el cofre a las que apunta el encuadre del primer plano (el glifo sube hasta ~3,5 u). 24/10: 1,9 → 1,5 para que entre también la jugadora agachada
const TAM_PRIMER_PLANO: float = 6.4             ## tamaño ortográfico de la cámara en el primer plano (PLAN §8 decía «hacia 4»: con 4 el cofre y el glifo que sube no caben entre las franjas). 24/10: 4,8 → 6,4: con 4,8 la jugadora (delante del cofre) quedaba fuera de plano y no se veía su animación de abrir
const DIST_FRENTE: float = 1.0                   ## u del centro del cofre a las que se coloca la jugadora (si estaba más lejos; el cofre mide 1,6 de ancho y ella 1,0 de alto, y sus manos llegan ~0,15 u por delante)
const T_ACERCARSE: float = 0.4                   ## s que tarda en acercarse al cofre
const LUZ_ZONA_FRACCION: float = 0.4             ## la luz de la zona baja al 40 %
const ALTURA_GLIFO: float = 1.0                  ## casillas que sube el glifo (el plan decía 1,5: con el primer plano a tamaño 4 el glifo se salía por arriba de la pantalla; 1 casilla = 2,3 u, y se ve entero)
const TAM_GLIFO: float = 1.15                    ## u de lado del glifo
const TAM_HALO: float = 4.2                      ## u de lado del halo a pleno
const GIROS_GLIFO: float = 2.0                   ## vueltas que da mientras sube
const ENERGIA_GLIFO: float = 3.2                 ## brillo del glifo (HDR: pasa del 1 y el bloom lo abre)
const ENERGIA_LUZ_HALO: float = 4.0              ## energía de la luz del halo al subir
const ENERGIA_LUZ_DESTELLO: float = 14.0         ## pico de luz del destello
const GLOW_EXTRA: float = 1.2                    ## cuánto sube la intensidad del bloom (`Environment.glow_intensity`) en el destello
const FUERZA_RADIAL: float = 1.0                 ## desenfoque radial del destello (0..1)
const T_BLANCO: float = 0.5                      ## s que dura el destello blanco (sube en 0,05 y baja el resto)
const ALFA_BLANCO: float = 0.95
const FRANJA: float = 0.12                       ## fracción de la pantalla que ocupa cada franja de cine
const COLOR_ORO: Color = Color(1.0, 0.8, 0.28)
const COLOR_ORO_HDR: Color = Color(1.0, 0.78, 0.26, 1.0)
const COLOR_TINTA: Color = Color(0.24, 0.19, 0.16)
const CAPA_CINE: int = 60
const CAPA_PAGINA: int = 64
const CAPA_BLANCO: int = 70
const PAGINA_TAM: Vector2 = Vector2(380.0, 250.0)
const PAGINA_ABAJO: float = 40.0                 ## px de la página al borde de abajo
const GLIFO_PAGINA: float = 110.0                ## px del glifo escrito
const TXT_AVISO_GLIFO: String = "Glifo nuevo: %s"
const TXT_AVISO_PISTA: String = "Pared hueca: prueba el pulso"
## 24/10 (Bosque 01 v01): la pista de dónde se usa cada glifo (el segundo aviso dorado). Un glifo sin fila usa TXT_AVISO_PISTA.
const PISTAS: Dictionary = {"barrera": "Las flechas no atraviesan una barrera"}
const T_AVISO_PISTA: float = 1.6                 ## s entre el primer aviso y el segundo

const CODIGO_ESCRITURA: String = """
shader_type canvas_item;
uniform float progreso = 0.0;
uniform vec4 tinta : source_color = vec4(0.24, 0.19, 0.16, 1.0);
uniform vec4 brillo : source_color = vec4(1.0, 0.8, 0.28, 1.0);
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float d = UV.y - progreso;
	float visto = step(d, 0.0);
	float cerca = smoothstep(0.07, 0.0, abs(d));
	COLOR = vec4(mix(tinta.rgb, brillo.rgb, cerca), t.a * clamp(visto + cerca * 0.7, 0.0, 1.0));
}
"""

var cofre: Node3D = null                         ## el CofrePuzle
var ctrl: Object = null                          ## su Cofre3D (null = sin tapa que abrir)
var mundo: Object = null
var glifo: String = ""                           ## id del glifo que da (raido)
var saltable: bool = false                       ## ¿ya se ha visto antes? (lo decide `iniciar` con la flag global)
var saltada: bool = false
var activa: bool = false
var hecha: bool = false                          ## ya acabó
var escrito: bool = false                        ## el glifo ya se desbloqueó
var t: float = 0.0                               ## s transcurridos de la secuencia (las pruebas y las capturas)
var fase: String = ""                            ## qué paso va (las pruebas): control · luz · onda · glifo · destello · escritura · fin
var luz_baja: float = 1.0                        ## fracción de la luz de la zona ahora (1 = normal)
var _lanz: Node = null
var _jugador: Node = null                        ## Jugador3D
var _pj: Node3D = null
var _cam: Camera3D = null
var _env: Environment = null
var _sol: DirectionalLight3D = null
var _sol0: float = 1.0
var _amb0: float = 1.0
var _glow0: float = 1.0
var _tam0: float = 0.0
var _capa_cine: CanvasLayer = null
var _franja_arriba: ColorRect = null
var _franja_abajo: ColorRect = null
var _capa_pagina: CanvasLayer = null
var _pagina: Panel = null
var _rastro: Node3D = null
var _glifo3d: Node3D = null
var _halo: MeshInstance3D = null
var _luz_halo: OmniLight3D = null
var _tw_zoom: Tween = null
var _tw_encuadre: Tween = null
var _tex: Texture2D = null
var _mat_escritura: ShaderMaterial = null
var _etiqueta: Label = null


## Arranca la secuencia. `p_ctrl` = el Cofre3D del modelo (puede ser null). Devuelve false si ya estaba en marcha.
func iniciar(p_cofre: Node3D, p_ctrl: Object, p_mundo: Object, p_glifo: String) -> bool:
	if activa or hecha:
		return false
	cofre = p_cofre
	ctrl = p_ctrl
	mundo = p_mundo
	glifo = p_glifo
	activa = true
	saltable = Flags.i().tiene(FLAG_VISTA)
	_tex = Sigils.GLYPHS.get(glifo) as Texture2D
	_correr()
	return true


## Salta a mano al final (solo si ya se había visto). Las pruebas y las teclas la llaman. Devuelve false si no es saltable.
func saltar() -> bool:
	if not activa or not saltable or saltada:
		return false
	saltada = true
	return true


func _unhandled_input(ev: InputEvent) -> void:
	if not activa or not saltable or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if k.pressed and not k.echo and (k.keycode == KEY_E or k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_ESCAPE):
		if saltar():
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if activa:
		t += delta


# ---------------------------------------------------------------------------------------------------------------------
#  El guion
# ---------------------------------------------------------------------------------------------------------------------

func _correr() -> void:
	_buscar_cosas()
	# 0,0 · control, cámara y franjas
	fase = "control"
	_bloquear(true)
	_colocar_frente()
	_pose_abrir()
	_franjas(true)
	_zoom_a(TAM_PRIMER_PLANO)
	_encuadrar(false)
	await _hasta(T_LUZ)
	# 0,4 · la luz baja y se abre el cofre
	fase = "luz"
	_bajar_luz(LUZ_ZONA_FRACCION)
	if ctrl != null and is_instance_valid(ctrl):
		ctrl.call("abrir")                        # el Cofre3D anticipa 0,4 s y gira la tapa a los 0,8
	await _hasta(T_ONDA)
	# 0,8 · la tapa se abre y la onda recorre las vetas
	fase = "onda"
	_onda_vetas()
	await _hasta(T_GLIFO)
	# 1,4 · sale el glifo girando, con halo
	fase = "glifo"
	_sacar_glifo()
	await _hasta(T_DESTELLO)
	# 2,6 · destello y el glifo cae al libro
	fase = "destello"
	_levantar()
	_destello()
	await _hasta(T_ESCRIBE)
	# 3,2 · se escribe en la página
	fase = "escritura"
	_escribir()
	await _hasta(T_FIN)
	# 4,5 · vuelve todo
	fase = "fin"
	_cerrar()


## Espera hasta que la secuencia lleve `hasta` s (o se salte). Cuenta fotogramas, no un temporizador: va con el reloj del juego y con `--fixed-fps`.
func _hasta(hasta: float) -> void:
	while t < hasta and not saltada and is_inside_tree():
		await get_tree().process_frame


func _buscar_cosas() -> void:
	var arbol: SceneTree = get_tree()
	_lanz = arbol.get_first_node_in_group("spellcaster")
	if _lanz == null:
		_lanz = arbol.get_first_node_in_group("player")
	_jugador = _lanz.get("jugador") as Node if _lanz != null else null
	_pj = (_jugador.get("pj") as Node3D) if _jugador != null and _jugador.get("pj") != null else null
	if mundo != null:
		_cam = mundo.get("_camara") as Camera3D
		_env = mundo.get("_env") as Environment
		_sol = mundo.get("_sol") as DirectionalLight3D
		var tam: Variant = mundo.get("_tam_camara")
		_tam0 = float(tam) if tam != null else 0.0
	if _sol != null:
		_sol0 = _sol.light_energy
	if _env != null:
		_amb0 = _env.ambient_light_energy
		_glow0 = _env.glow_intensity


# --- control y pose ---

func _bloquear(si: bool) -> void:
	if _jugador != null and _jugador.has_method("bloquear"):
		_jugador.call("bloquear", si)


func _pose_abrir() -> void:
	if _jugador != null:
		_jugador.set("animacion_externa", true)       # el Jugador3D deja de elegir clip cada fotograma
	if _pj != null and _pj.has_method("jugar") and _pj.has_method("clip_de") and String(_pj.call("clip_de", ROL_ANIMACION)) != "":
		_pj.set("animacion_actual", "")
		_pj.call("jugar", ROL_ANIMACION, true, velocidad_abrir())


## Velocidad del clip de abrir para que las manos lleguen abajo (`Pj3D.instante_clip`) justo a `T_ONDA`, cuando la tapa empieza a girar. 1 si el rol no tiene instante medido.
static func velocidad_abrir() -> float:
	var instante: float = Pj3D.instante_clip(ROL_ANIMACION)
	return clampf(instante / T_ONDA, 1.0, VEL_ABRIR_MAX) if instante > 0.0 else 1.0


## La jugadora se incorpora: vuelve a idle (con la mezcla de siempre) sin esperar al final de la secuencia, que sigue sin ella.
func _levantar() -> void:
	if _pj != null and _pj.has_method("jugar") and not saltada:
		_pj.set("animacion_actual", "")
		_pj.call("jugar", "idle")


## COLOCACIÓN: la jugadora puede haber pulsado E a 2,7 u del cofre; se desliza hasta `DIST_FRENTE` u de su centro (en línea recta desde donde estaba) y lo mira, para que sus manos
## lleguen a él al agacharse. Si ya está más cerca no se mueve (solo se gira).
func _colocar_frente() -> void:
	if _jugador == null or cofre == null or not (_jugador is Node3D) or not cofre.is_inside_tree():
		return
	var j: Node3D = _jugador as Node3D
	var d: Vector3 = j.global_position - cofre.global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	if d.length() > DIST_FRENTE:
		var destino: Vector3 = cofre.global_position + d.normalized() * DIST_FRENTE
		destino.y = j.global_position.y
		var tw: Tween = create_tween()
		tw.tween_property(j, "global_position", destino, 0.0 if saltada else T_ACERCARSE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _jugador.has_method("mirar_hacia"):
		_jugador.call("mirar_hacia", -d)


func _fin_pose() -> void:
	if _jugador != null:
		_jugador.set("animacion_externa", false)
	if _pj != null and _pj.has_method("jugar"):
		_pj.set("animacion_actual", "")
		_pj.call("jugar", "idle")


# --- cámara, franjas, luz ---

func _zoom_a(tam: float) -> void:
	if mundo == null or _cam == null:
		return
	if _tw_zoom != null and _tw_zoom.is_valid():
		_tw_zoom.kill()
	_tw_zoom = create_tween()
	_tw_zoom.tween_method(_poner_zoom, float(mundo.get("_tam_camara")), tam, 0.0 if saltada else T_ZOOM).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _poner_zoom(v: float) -> void:
	if mundo != null:
		mundo.set("_tam_camara", v)
	if _cam != null:
		_cam.size = v


## ENCUADRE: la cámara sigue a la jugadora, que está delante del cofre; en primer plano el cofre quedaba arriba del todo y el glifo, al subir, se salía de la pantalla. Se desplaza el
## encuadre (`Camera3D.h_offset`/`v_offset`, que `_colocar_camara` de la maqueta no toca) hacia un punto sobre el cofre (`ALTO_ENCUADRE` u). `volver` lo deja a 0.
func _encuadrar(volver: bool) -> void:
	if _cam == null or cofre == null or not cofre.is_inside_tree():
		return
	var h: float = 0.0
	var v: float = 0.0
	if not volver:
		var foco: Vector3 = (_pj.global_position + Vector3(0.0, 0.85, 0.0)) if _pj != null else cofre.global_position
		var d: Vector3 = (cofre.global_position + Vector3(0.0, ALTO_ENCUADRE, 0.0)) - foco
		h = d.dot(_cam.global_transform.basis.x)
		v = d.dot(_cam.global_transform.basis.y)
	if _tw_encuadre != null and _tw_encuadre.is_valid():
		_tw_encuadre.kill()
	_tw_encuadre = create_tween().set_parallel(true)
	var dur: float = 0.0 if saltada else T_ZOOM
	_tw_encuadre.tween_property(_cam, "h_offset", h, dur)
	_tw_encuadre.tween_property(_cam, "v_offset", v, dur)


func _franjas(entrar: bool) -> void:
	if _capa_cine == null:
		_capa_cine = CanvasLayer.new()
		_capa_cine.layer = CAPA_CINE
		add_child(_capa_cine)
		_franja_arriba = _rect_negro(true)
		_franja_abajo = _rect_negro(false)
	var alto: float = _tam_pantalla().y * FRANJA
	for par in [[_franja_arriba, true], [_franja_abajo, false]]:
		var r: ColorRect = par[0]
		var arriba: bool = par[1]
		var a: float = alto if entrar else 0.0
		var tw: Tween = r.create_tween().set_parallel(true)
		tw.tween_property(r, "size:y", a, T_ZOOM)
		if not arriba:
			tw.tween_property(r, "position:y", _tam_pantalla().y - a, T_ZOOM)


func _rect_negro(arriba: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(_tam_pantalla().x, 0.0)
	r.position = Vector2(0.0, 0.0 if arriba else _tam_pantalla().y)
	_capa_cine.add_child(r)
	return r


func _tam_pantalla() -> Vector2:
	var vp: Viewport = get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)


func _bajar_luz(fraccion: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(_poner_luz, luz_baja, fraccion, T_LUZ_BAJA if not saltada else 0.0)


func _poner_luz(f: float) -> void:
	luz_baja = f
	if _sol != null:
		_sol.light_energy = _sol0 * f
	if _env != null:
		_env.ambient_light_energy = _amb0 * f


# --- la onda por las vetas ---

func _onda_vetas() -> void:
	if cofre == null or not Terreno3D.hay_mundo():
		return
	var origen: Vector2i = cofre.get("celda")
	Pulso3D.anillo(cofre, cofre.global_position, COLOR_ORO, 1.1)
	var vistas: Dictionary = {}
	for c in Pulso3D.vetas.keys():
		var v: Variant = Pulso3D.vetas[c]
		if v == null or not is_instance_valid(v):
			continue
		var d: int = absi((c as Vector2i).x - origen.x) + absi((c as Vector2i).y - origen.y)
		if d > Pulso3D.ALCANCE_DEFECTO * 2:
			continue
		vistas[c] = true
		get_tree().create_timer(float(d) * Pulso3D.SEG_POR_CASILLA * 0.5, false).timeout.connect(_encender_veta.bind(weakref(v), c))


func _encender_veta(ref: WeakRef, c: Vector2i) -> void:
	var v: Variant = ref.get_ref()
	if v != null and is_instance_valid(v):
		(v as Object).call("encender", c, COLOR_ORO)


# --- el glifo ---

func _material_quad(textura: Texture2D, color: Color, aditivo: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = textura
	m.albedo_color = color
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = true
	return m


func _halo_textura() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	g.set_color(1, Color(1.0, 0.7, 0.2, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	return gt


func _sacar_glifo() -> void:
	if cofre == null or not cofre.is_inside_tree():
		return
	_rastro = Node3D.new()
	_rastro.name = "GlifoSecuencia"
	cofre.add_child(_rastro)
	var base: float = Terreno3D.casilla * 0.55
	_rastro.position = Vector3(0.0, base, 0.0)
	# Mira a la cámara (un quad vertical que gira sobre su propio eje se ve girar desde la cámara cenital).
	if _cam != null:
		_rastro.global_transform.basis = _cam.global_transform.basis
	var q := QuadMesh.new()
	q.size = Vector2(TAM_GLIFO, TAM_GLIFO)
	_glifo3d = Node3D.new()
	_rastro.add_child(_glifo3d)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _material_quad(_tex, Color(COLOR_ORO_HDR.r * ENERGIA_GLIFO, COLOR_ORO_HDR.g * ENERGIA_GLIFO, COLOR_ORO_HDR.b * ENERGIA_GLIFO, 1.0), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glifo3d.add_child(mi)
	var qh := QuadMesh.new()
	qh.size = Vector2(TAM_HALO, TAM_HALO)
	_halo = MeshInstance3D.new()
	_halo.mesh = qh
	_halo.material_override = _material_quad(_halo_textura(), Color(1.0, 1.0, 1.0, 0.0), true)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.position = Vector3(0.0, 0.0, -0.05)
	_rastro.add_child(_halo)
	_luz_halo = OmniLight3D.new()
	_luz_halo.light_color = COLOR_ORO
	_luz_halo.omni_range = Terreno3D.casilla * 4.0
	_luz_halo.light_energy = 0.0
	_luz_halo.shadow_enabled = false
	_rastro.add_child(_luz_halo)
	var dur: float = 0.0 if saltada else T_SUBE_GLIFO
	var tw: Tween = _rastro.create_tween().set_parallel(true)
	tw.tween_property(_rastro, "position:y", base + Terreno3D.casilla * ALTURA_GLIFO, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_glifo3d, "rotation:z", TAU * GIROS_GLIFO, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_halo.material_override, "albedo_color:a", 0.9, dur)
	tw.tween_property(_luz_halo, "light_energy", ENERGIA_LUZ_HALO, dur)
	_subir_bloom(GLOW_EXTRA * 0.5, dur)


func _subir_bloom(extra: float, dur: float) -> void:
	if _env == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_env, "glow_intensity", _glow0 + extra, maxf(dur, 0.001))


func _destello() -> void:
	var arbol: SceneTree = get_tree()
	# El destello: blanco casi pleno, un desenfoque radial desde el cofre y un pico de luz; el bloom sube y baja.
	var capa := CanvasLayer.new()
	capa.layer = CAPA_BLANCO
	add_child(capa)
	var blanco := ColorRect.new()
	blanco.color = Color(1.0, 1.0, 1.0, 0.0)
	blanco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blanco.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(blanco)
	var tw: Tween = blanco.create_tween()
	tw.tween_property(blanco, "color:a", ALFA_BLANCO, 0.05)
	tw.tween_property(blanco, "color:a", 0.0, T_BLANCO - 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(capa.queue_free)
	if cofre != null and cofre.is_inside_tree():
		PulsoPantalla3D.lanzar_en(arbol, cofre.global_position + Vector3(0.0, Terreno3D.casilla, 0.0), FUERZA_RADIAL, 0.6)
	if _luz_halo != null:
		var tl: Tween = _luz_halo.create_tween()
		tl.tween_property(_luz_halo, "light_energy", ENERGIA_LUZ_DESTELLO, 0.05)
		tl.tween_property(_luz_halo, "light_energy", 0.0, T_BLANCO)
	if _env != null:
		var tb: Tween = create_tween()
		tb.tween_property(_env, "glow_intensity", _glow0 + GLOW_EXTRA, 0.05)
		tb.tween_property(_env, "glow_intensity", _glow0, 0.9)
	if _halo != null:
		var th: Tween = _halo.create_tween()
		th.tween_property(_halo, "scale", Vector3(0.2, 0.2, 0.2), T_CAE_GLIFO)          # el halo se condensa
	_caer_al_libro()


## El glifo (ya en 2D, donde se vio en pantalla) cae a la página que se abre sola abajo.
func _caer_al_libro() -> void:
	_capa_pagina = CanvasLayer.new()
	_capa_pagina.layer = CAPA_PAGINA
	add_child(_capa_pagina)
	var pantalla: Vector2 = _tam_pantalla()
	_pagina = Panel.new()
	_pagina.size = PAGINA_TAM
	_pagina.position = Vector2((pantalla.x - PAGINA_TAM.x) * 0.5, pantalla.y - PAGINA_TAM.y - PAGINA_ABAJO)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.93, 0.86, 0.70)
	estilo.border_color = Color(0.36, 0.24, 0.14)
	estilo.set_border_width_all(5)
	estilo.set_corner_radius_all(10)
	estilo.shadow_color = Color(0, 0, 0, 0.45)
	estilo.shadow_size = 14
	_pagina.add_theme_stylebox_override("panel", estilo)
	_pagina.modulate.a = 0.0
	_pagina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_pagina.add_child(_pagina)
	var tp: Tween = _pagina.create_tween()
	tp.tween_property(_pagina, "modulate:a", 1.0, 0.35)
	# El glifo dorado viaja de donde estaba en pantalla al centro de la página.
	var desde := Vector2(pantalla.x * 0.5, pantalla.y * 0.4)
	if _cam != null and _glifo3d != null and _glifo3d.is_inside_tree() and not _cam.is_position_behind(_glifo3d.global_position):
		desde = _cam.unproject_position(_glifo3d.global_position)
	var vuelo := TextureRect.new()
	vuelo.texture = _tex
	vuelo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vuelo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vuelo.size = Vector2(GLIFO_PAGINA * 1.6, GLIFO_PAGINA * 1.6)
	vuelo.pivot_offset = vuelo.size * 0.5
	vuelo.position = desde - vuelo.size * 0.5
	vuelo.modulate = COLOR_ORO
	vuelo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_pagina.add_child(vuelo)
	var destino: Vector2 = _pagina.position + Vector2(PAGINA_TAM.x * 0.5, PAGINA_TAM.y * 0.42)
	var tv: Tween = vuelo.create_tween().set_parallel(true)
	tv.tween_property(vuelo, "position", destino - vuelo.size * 0.5, 0.0 if saltada else T_CAE_GLIFO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tv.tween_property(vuelo, "scale", Vector2.ONE * (GLIFO_PAGINA / (GLIFO_PAGINA * 1.6)), 0.0 if saltada else T_CAE_GLIFO)
	tv.chain().tween_callback(vuelo.queue_free)
	if _rastro != null:
		var tr: Tween = _rastro.create_tween()
		tr.tween_property(_rastro, "scale", Vector3.ZERO, 0.15)
		tr.tween_callback(_rastro.queue_free)


## El glifo se escribe de arriba abajo con un frente dorado, y debajo aparece su nombre; al acabar queda desbloqueado.
func _escribir() -> void:
	if _capa_pagina == null:
		_caer_al_libro()
	var escrito_tex := TextureRect.new()
	escrito_tex.texture = _tex
	escrito_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	escrito_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	escrito_tex.size = Vector2(GLIFO_PAGINA, GLIFO_PAGINA)
	escrito_tex.position = _pagina.position + Vector2((PAGINA_TAM.x - GLIFO_PAGINA) * 0.5, PAGINA_TAM.y * 0.42 - GLIFO_PAGINA * 0.5)
	escrito_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CODIGO_ESCRITURA
	_mat_escritura = ShaderMaterial.new()
	_mat_escritura.shader = sh
	_mat_escritura.set_shader_parameter("tinta", COLOR_TINTA)
	_mat_escritura.set_shader_parameter("brillo", COLOR_ORO)
	_mat_escritura.set_shader_parameter("progreso", 0.0)
	escrito_tex.material = _mat_escritura
	_capa_pagina.add_child(escrito_tex)
	_etiqueta = Label.new()
	_etiqueta.text = Sigils.nombre_visible(glifo).capitalize()
	_etiqueta.visible_ratio = 0.0
	_etiqueta.add_theme_color_override("font_color", Color(0.78, 0.55, 0.08))
	_etiqueta.add_theme_color_override("font_outline_color", Color(0.25, 0.16, 0.05))
	_etiqueta.add_theme_constant_override("outline_size", 4)
	_etiqueta.add_theme_font_size_override("font_size", 34)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.size = Vector2(PAGINA_TAM.x, 44.0)
	_etiqueta.position = _pagina.position + Vector2(0.0, PAGINA_TAM.y * 0.42 + GLIFO_PAGINA * 0.5 + 10.0)
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_pagina.add_child(_etiqueta)
	var dur: float = 0.0 if saltada else T_ESCRITURA
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void: _mat_escritura.set_shader_parameter("progreso", v), 0.0, 1.15, maxf(dur, 0.001))
	tw.tween_property(_etiqueta, "visible_ratio", 1.0, 0.0 if saltada else T_NOMBRE)
	tw.tween_callback(_desbloquear)


func _desbloquear() -> void:
	if escrito:
		return
	escrito = true
	if glifo != "":
		Repertoire.unlock_sigil(glifo)               # el libro de verdad ya lo enseña en la chuleta
	if cofre != null and cofre.is_inside_tree() and Terreno3D.hay_mundo():
		Sfx.play(cofre, Pulso3D.SFX_PULSO, 1.8)       # la nota limpia al escribirse (provisional: sello_ok agudo)
	glifo_escrito.emit()


# --- el final ---

func _cerrar() -> void:
	if not escrito:
		_desbloquear()
	_poner_luz(luz_baja)
	var tw: Tween = create_tween()
	tw.tween_method(_poner_luz, luz_baja, 1.0, 0.0 if saltada else T_LUZ_BAJA)
	_zoom_a(_tam0 if _tam0 > 0.0 else float(mundo.get("_tam_camara")) if mundo != null else 0.0)
	_franjas(false)
	_encuadrar(true)
	if _capa_pagina != null:
		var tp: Tween = _capa_pagina.create_tween()
		tp.tween_property(_pagina, "modulate:a", 0.0, 0.4)
		tp.tween_callback(_capa_pagina.queue_free)
	if _rastro != null and is_instance_valid(_rastro):
		_rastro.queue_free()
	if _env != null:
		_env.glow_intensity = _glow0
	_fin_pose()
	# La luz, la cámara y las franjas vuelven en T_ZOOM s: la escena no se da por terminada hasta que todo está en su sitio (y el control no vuelve antes).
	await _hasta(t + T_ZOOM + 0.05)               # (con la secuencia saltada, `_hasta` no espera)
	await get_tree().process_frame
	_poner_luz(1.0)
	if _tam0 > 0.0:
		_poner_zoom(_tam0)
	if _cam != null:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	_bloquear(false)
	Flags.i().poner(FLAG_VISTA)
	# El aviso dorado: primero el glifo, después la pista de dónde usarlo.
	_aviso(TXT_AVISO_GLIFO % Sigils.nombre_visible(glifo))
	get_tree().create_timer(T_AVISO_PISTA, false).timeout.connect(_aviso.bind(String(PISTAS.get(glifo, TXT_AVISO_PISTA))))
	activa = false
	hecha = true
	terminada.emit()
	get_tree().create_timer(T_AVISO_PISTA + 1.0, false).timeout.connect(_liberar_tras_cerrar)      # 24/10: tras el segundo aviso (con 1,0 s el nodo moría antes de que saliera la pista)


func _aviso(texto: String) -> void:
	if _lanz != null and is_instance_valid(_lanz) and _lanz.has_method("avisar"):
		_lanz.call("avisar", texto, COLOR_ORO)


func _liberar_tras_cerrar() -> void:
	if is_inside_tree():
		queue_free()
