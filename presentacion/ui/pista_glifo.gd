class_name PistaGlifo
extends Node3D

## LA PISTA DE USO INMEDIATO (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4.5 H6, «show, don't tell» como en Zelda): al conseguir un glifo el juego te lo deja escrito en una página (`Grimorio.equipar_glifo_nuevo`)
## y te pone delante el sitio donde usarlo. No explica nada: señala.
##   · el HUD (`page_hud.gd`) pinta encima de las pestañas «[runa] Pulsa 2» con la tecla REAL de la página (su nombre ya sale justo debajo, H16);
##   · con `reto_en` (una casilla) el suelo lleva un marcador suave —un aro con la runa, del color de la runa, que late despacio—: dice DÓNDE, no cómo.
## Se cumple (la pista y el marcador se van) cuando:
##   · no hay `reto`: la jugadora lanza por primera vez un hechizo que lleva el glifo (señal `Lanzador3D.glifos_lanzados`);
##   · hay `reto` (una flag de `Flags`): se pone esa flag, que es lo que de verdad resuelve la sala (la barrera de fuego que abre la reja…).
## Al cumplirse: destello del marcador (o de la pestaña si no hay marcador), sonido de acierto y `PlayLog.event("glifo_primer_uso", {glifo, segundos, reto})`.
## NO se guarda en la partida: es un hijo del lanzador, así que recargar el nivel (o la partida) la quita. El cofre la pide con `reto=<flag>` y `reto_en=x,z`; la ceremonia la crea al cerrarse.

signal cumplida

const GRUPO: String = "pista_glifo"
const T_DESTELLO: float = 0.7
const RADIO_ARO: float = 0.80                  ## m: la casilla mide `Terreno3D.casilla` (2,3), el aro casi la llena
const SONIDO_ACIERTO: String = "logro_acierto"
const ALTO_MARCADOR: float = 0.30                  ## m sobre el suelo: a 0,05 la hierba y el relieve de las cuevas lo tapaban

var id: String = ""
var pagina: int = -1
var reto: String = ""
var reto_en: Variant = null                   ## Vector2i (la casilla del marcador) o null
var cumplido: bool = false
var segundos_al_cumplir: float = -1.0         ## lo que tardó desde que se obtuvo (para las pruebas)
var marcador: Node3D = null                   ## el aro con la runa, mientras exista

var _lanz: Node = null
var _desde_ms: int = 0
var _t: float = 0.0
var _t_destello: float = -1.0
var _aro: MeshInstance3D = null
var _runa: MeshInstance3D = null
var _color: Color = Color.WHITE


## Crea la pista como hija del lanzador. Devuelve null si no hay lanzador o si la flag del reto ya estaba puesta (no hay nada que enseñar). `p_reto_en` = Vector2i o null.
static func crear(lanz: Node, p_id: String, p_pagina: int, p_reto: String = "", p_reto_en: Variant = null) -> PistaGlifo:
	if lanz == null or not lanz.is_inside_tree():
		return null
	if p_reto != "" and Flags.i().tiene(p_reto):
		return null
	for v in lanz.get_tree().get_nodes_in_group(GRUPO):
		v.queue_free()                         # una pista nueva sustituye a la anterior
	var p := PistaGlifo.new()
	p.id = p_id
	p.pagina = p_pagina
	p.reto = p_reto
	p.reto_en = p_reto_en if p_reto_en is Vector2i else null
	p.name = "PistaGlifo"
	p._lanz = lanz
	lanz.add_child(p)
	return p


## El color de la runa en el HUD y en el suelo: el de su familia (`LaminaGlifo.color_de`).
func color() -> Color:
	return _color


## La textura de la runa (`altura` se dibuja como su alias ᛏ).
func textura() -> Texture2D:
	var clave: String = "levitacion" if id == "altura" else id
	var t: Texture2D = Sigils.GLYPHS.get(clave) as Texture2D
	if t == null:
		var ruta: String = "res://art/ui/glyphs/%s.png" % id
		if ResourceLoader.exists(ruta):
			t = load(ruta) as Texture2D
	return t


## El texto que pinta el HUD: «Pulsa 2» (la tecla real de la página). "" si ya se cumplió.
func texto_hud() -> String:
	if cumplido or pagina < 0:
		return ""
	var tecla: String = Controles.texto_teclas("pagina_%d" % (pagina + 1))
	return "Pulsa %s" % tecla                  # el nombre de la página ya sale justo debajo (H16)


func _ready() -> void:
	top_level = true
	add_to_group(GRUPO)
	_desde_ms = Time.get_ticks_msec()
	_color = LaminaGlifo.color_de(id)
	if _lanz != null and _lanz.has_signal("glifos_lanzados"):
		_lanz.connect("glifos_lanzados", _al_lanzar)
	if reto_en is Vector2i:
		_montar_marcador(reto_en as Vector2i)


func _montar_marcador(c: Vector2i) -> void:
	marcador = Node3D.new()
	marcador.name = "MarcadorReto"
	add_child(marcador)
	marcador.global_position = Terreno3D.centro_de(c, Terreno3D.y_pies(c)) + Vector3.UP * ALTO_MARCADOR
	_aro = MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = RADIO_ARO - 0.09
	toro.outer_radius = RADIO_ARO
	toro.rings = 32
	toro.ring_segments = 6
	_aro.mesh = toro
	_aro.material_override = _material(_color, null)
	_aro.scale = Vector3(1.0, 0.25, 1.0)             # el toro plano: un aro en el suelo, sin grosor que tape
	marcador.add_child(_aro)
	var tex: Texture2D = textura()
	if tex != null:
		_runa = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 1.1)
		_runa.mesh = q
		_runa.material_override = _material(_color, tex)
		_runa.rotation_degrees = Vector3(-90.0, 0.0, 0.0)          # tumbada en el suelo, de cara al cielo
		_runa.position = Vector3(0.0, 0.12, 0.0)
		marcador.add_child(_runa)


func _material(col: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	if tex != null:
		m.albedo_texture = tex
	return m


func _process(delta: float) -> void:
	_t += delta
	if cumplido:
		_t_destello += delta
		var k: float = clampf(_t_destello / T_DESTELLO, 0.0, 1.0)
		if marcador != null:
			marcador.scale = Vector3.ONE * lerpf(1.0, 2.3, ease(k, 0.4))
			_poner_alfa(1.0 - k, Color(1.0, 0.97, 0.85).lerp(_color, k))
		if k >= 1.0:
			queue_free()
		return
	if marcador != null:
		var latido: float = 0.5 + 0.5 * sin(_t * 2.2)                # ~un latido cada 2,9 s: despacio
		marcador.scale = Vector3.ONE * (1.0 + 0.06 * latido)
		_poner_alfa(0.35 + 0.35 * latido, _color)
	if reto != "" and Flags.i().tiene(reto):
		_cumplir()


func _poner_alfa(a: float, col: Color) -> void:
	for m in [_aro, _runa]:
		if m != null:
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color = Color(col, clampf(a, 0.0, 1.0))


## ¿Este nombre de glifo de una página es la runa de la pista? (`linea_x`/`linea_z` son `linea`; `levitacion` vale como `altura`.)
func _es_la_runa(g: String) -> bool:
	return g == id or Sigils.repertorio_de(g) == id or Sigils.glifo_v2(g) == Sigils.glifo_v2(id)


func _al_lanzar(glifos: Array) -> void:
	if cumplido or reto != "":
		return                                    # con reto la pista no se va al lanzar, sino cuando se cumple el reto
	for g in glifos:
		if _es_la_runa(String(g)):
			_cumplir()
			return


func _cumplir() -> void:
	if cumplido:
		return
	cumplido = true
	_t_destello = 0.0
	segundos_al_cumplir = float(Time.get_ticks_msec() - _desde_ms) / 1000.0
	Sfx.play(self, SONIDO_ACIERTO)
	PlayLog.event("glifo_primer_uso", {"glifo": id, "segundos": snappedf(segundos_al_cumplir, 0.1), "reto": reto})
	if marcador == null:
		# Sin marcador en el suelo, el destello lo lleva la pestaña de la página.
		var hud: Variant = _lanz.get("_page_hud") if _lanz != null else null
		if hud is Object and (hud as Object).has_method("destello") and pagina >= 0:
			(hud as Object).call("destello", pagina, 0.6)
	cumplida.emit()
