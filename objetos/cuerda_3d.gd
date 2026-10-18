class_name Cuerda3D
extends Area3D

## CUERDA (Fase 14.6 · laboratorio de fuego, F3 «quema la cuerda», 16/10, Juego; es la pieza 12.5 de FASE14_PRESENTACION.md). Una cuerda
## SOSTIENE algo: una compuerta levantada o un puente plegado. El fuego la quema: arde `T_ARDE` s (1 s) y se rompe. Al romperse emite
## `rota` y lo que sostenía CAE:
##   · una Compuerta3D (`cerrar`): la compuerta que estaba levantada (abierta, dejando pasar el agua) cae y cierra el paso;
##   · un PuenteReactivo3D (`tender`): el puente plegado se tiende y se puede cruzar.
## Cualquier otro nodo con `tender()` o `cerrar()` vale igual (se prefiere `tender`). Sin `sostiene`, solo emite la señal.
##
## Se comporta como lo que arde del juego: está en el grupo `flammable3d` (`can_burn`, `ignite`, `is_lit`), así que un seto o un barril
## que arde a su lado la quema por contagio, y el agua la apaga si todavía no se ha roto (el agua no arregla una cuerda rota). Habla el
## contrato de los hechizos (`on_spell_hit`, `spell_reacts`, `carried_element`, `nivel_altura`, `punto_activacion`) y vive en la capa de
## reactivos como Barril3D. No bloquea la casilla (es un poste con una cuerda; se anda por al lado y a través).
## Lo dibuja ella misma (un poste, la cuerda y la anilla de la que cuelga): entera marrón, ardiendo naranja, rota caída en el suelo.
## Los tres estados que el Pipeline sustituirá por su modelo: `estado` (ENTERA | ARDIENDO | ROTA) y los hijos «poste», «cuerda», «cabo».

signal rota
signal ardiendo_cambio(si: bool)

enum EstadoCuerda { ENTERA, ARDIENDO, ROTA }

const T_ARDE: float = 1.0
const ALTO: float = 1.9
const RADIO: float = 0.07
const COLOR_ENTERA: Color = Color(0.62, 0.45, 0.25)
const COLOR_ARDE: Color = Color(1.0, 0.5, 0.15)
const COLOR_CENIZA: Color = Color(0.2, 0.17, 0.15)
## Dónde está la anilla en el modelo `cuerda_poste` (medido en su malla: el brazo sube hasta y≈1,87 y la anilla queda en x≈0,45). De ahí
## cuelga `cuerda_tensa` (1,3) y, de su nudo, `cuerda_cabo` (0,35): el conjunto llega justo al suelo. Es una estimación: hay que verlo en pantalla.
const ANILLA_MODELO: Vector3 = Vector3(0.45, 1.65, -0.28)

var celda: Vector2i = Vector2i.ZERO
var estado: EstadoCuerda = EstadoCuerda.ENTERA
var is_lit: bool = false                 ## arde (lo leen el barril, el contador y el viento)
var rota_ya: bool = false                ## ya se rompió (la condición `cuerda.rota` de Puzle3D)
var sostiene: Node = null                ## lo que cae al romperse
var _t: float = 0.0
var _cuerda: Node3D = null
var _cabo: Node3D = null
var _caida: Node3D = null                ## el cabo caído en el suelo (modelo `cuerda_caida`); solo con modelos
var _modelo: bool = false                ## true si poste/cuerda/cabo son los modelos del Pipeline (PiezaFuego3D), no primitivas
var _capa: StandardMaterial3D = null     ## capa translúcida (material_overlay) con la que se tiñe el modelo al arder; no toca su textura
var _mat: StandardMaterial3D = null
var _luz: OmniLight3D = null


func preparar(p_celda: Vector2i, p_sostiene: Node = null) -> void:
	celda = p_celda
	sostiene = p_sostiene
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	add_to_group(Reactivo3D.GRUPO_ARDE)
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.7, ALTO, 0.7)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_ENTERA
	# Con los modelos del Pipeline (ARTE §14) se usan los tres; si falta alguno, las primitivas de siempre (el comportamiento no cambia).
	if _montar_modelos():
		set_process(false)
		return
	var poste := MeshInstance3D.new()
	poste.name = "poste"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.1
	pm.bottom_radius = 0.14
	pm.height = ALTO
	poste.mesh = pm
	poste.position = Vector3(0.0, ALTO * 0.5, 0.0)
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.4, 0.3, 0.2)
	poste.material_override = mp
	add_child(poste)
	_cuerda = MeshInstance3D.new()
	_cuerda.name = "cuerda"
	var cm := CylinderMesh.new()
	cm.top_radius = RADIO
	cm.bottom_radius = RADIO
	cm.height = ALTO * 0.7
	_cuerda.mesh = cm
	_cuerda.position = Vector3(0.28, ALTO * 0.62, 0.0)
	_cuerda.material_override = _mat
	add_child(_cuerda)
	_cabo = MeshInstance3D.new()
	_cabo.name = "cabo"
	var bm := SphereMesh.new()
	bm.radius = 0.16
	bm.height = 0.32
	_cabo.mesh = bm
	_cabo.position = Vector3(0.28, ALTO * 0.22, 0.0)
	_cabo.material_override = _mat
	add_child(_cabo)
	set_process(false)


## Monta poste, cuerda tensa y cabo con `PiezaFuego3D`. Devuelve false (sin añadir nada) si falta cualquiera de los cuatro modelos.
func _montar_modelos() -> bool:
	for id in ["cuerda_poste", "cuerda_tensa", "cuerda_cabo", "cuerda_caida"]:
		if not PiezaFuego3D.usar_modelos or not PiezaFuego3D.hay_modelo(id):
			return false
	var poste: PiezaFuego3D = PiezaFuego3D.crear("cuerda_poste")
	poste.name = "poste"
	add_child(poste)
	_cuerda = PiezaFuego3D.crear("cuerda_tensa")
	_cuerda.name = "cuerda"
	_cuerda.position = ANILLA_MODELO
	add_child(_cuerda)
	_cabo = PiezaFuego3D.crear("cuerda_cabo")
	_cabo.name = "cabo"
	_cabo.position = ANILLA_MODELO + Vector3(0.0, -1.3, 0.0)
	add_child(_cabo)
	_caida = PiezaFuego3D.crear("cuerda_caida")
	_caida.name = "cuerda_caida"
	_caida.position = Vector3(ANILLA_MODELO.x, 0.0, ANILLA_MODELO.z)
	_caida.visible = false
	add_child(_caida)
	_modelo = true
	return true


## Tiñe la cuerda: `c` = null la deja como es; con color, una capa translúcida con brillo (modelo) o el material propio (primitivas).
func _tenir(c: Variant, emision: float = 0.0) -> void:
	if not _modelo:
		if c == null:
			_mat.albedo_color = COLOR_ENTERA
			_mat.emission_enabled = false
		else:
			_mat.albedo_color = c
			_mat.emission_enabled = emision > 0.0
			_mat.emission = c
			_mat.emission_energy_multiplier = emision
		return
	if c == null:
		_capa = null
	else:
		_capa = StandardMaterial3D.new()
		_capa.albedo_color = Color((c as Color).r, (c as Color).g, (c as Color).b, 0.55)
		_capa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_capa.emission_enabled = emision > 0.0
		_capa.emission = c
		_capa.emission_energy_multiplier = emision
	for n in [_cuerda, _cabo]:
		for m in (n as Node).find_children("*", "MeshInstance3D", true, false):
			(m as GeometryInstance3D).material_overlay = _capa


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data == null:
		return
	if rune_data.tags.has("calor") or rune_data.tags.has("rayo") or rune_data.tags.has("electrico"):
		arder()
	elif (rune_data.tags.has("agua") or rune_data.tags.has("frio")) and estado == EstadoCuerda.ARDIENDO:
		_apagar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null:
		return false
	if rune_data.tags.has("calor") or rune_data.tags.has("rayo") or rune_data.tags.has("electrico"):
		return estado == EstadoCuerda.ENTERA
	return (rune_data.tags.has("agua") or rune_data.tags.has("frio")) and estado == EstadoCuerda.ARDIENDO


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO * 0.5, 0.0))


## --- Lo que arde (el mismo trato que un seto) ---

func can_burn() -> bool:
	return estado == EstadoCuerda.ENTERA


func ignite(_desde: Vector3 = Vector3.INF) -> void:
	arder()


## --- La cuerda ---

func arder() -> void:
	if estado != EstadoCuerda.ENTERA:
		return
	estado = EstadoCuerda.ARDIENDO
	is_lit = true
	_t = 0.0
	_tenir(COLOR_ARDE, 1.6)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.6, 0.3)
	_luz.light_energy = 0.9
	_luz.omni_range = 3.0
	_luz.position = (ANILLA_MODELO + Vector3(0.0, -0.7, 0.0)) if _modelo else Vector3(0.28, ALTO * 0.5, 0.0)
	add_child(_luz)
	set_process(true)
	ardiendo_cambio.emit(true)


## Los puntos que se pueden pedir por código (el botón del laboratorio: `quemar`).
func quemar() -> void:
	arder()


func _apagar() -> void:
	if estado != EstadoCuerda.ARDIENDO:
		return
	estado = EstadoCuerda.ENTERA
	is_lit = false
	_t = 0.0
	_tenir(null)
	_quitar_luz()
	set_process(false)
	ardiendo_cambio.emit(false)


func _process(delta: float) -> void:
	if estado != EstadoCuerda.ARDIENDO:
		return
	_t += delta
	if _luz != null:
		_luz.light_energy = 0.7 + 0.4 * absf(sin(_t * 18.0))
	if _t >= T_ARDE:
		_romper()


func _romper() -> void:
	estado = EstadoCuerda.ROTA
	rota_ya = true
	is_lit = false
	_quitar_luz()
	remove_from_group(Reactivo3D.GRUPO_ARDE)
	collision_layer = 0
	_tenir(COLOR_CENIZA if not _modelo else null, 0.0)
	set_process(false)
	if _modelo:
		# Con modelos: la cuerda tensa y el cabo desaparecen y aparece el cabo caído en el suelo (la anilla se queda en el poste).
		_cuerda.visible = false
		_cabo.visible = false
		_caida.visible = true
	# La cuerda cae al suelo hecha un cabo; la anilla se queda donde estaba.
	elif is_inside_tree():
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(_cuerda, "position", Vector3(0.28, 0.1, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_cuerda, "scale", Vector3(1.0, 0.15, 1.0), 0.35)
	ardiendo_cambio.emit(false)
	rota.emit()
	_soltar()


## Lo sostenido cae: un puente se tiende, una compuerta levantada baja y cierra.
func _soltar() -> void:
	if sostiene == null or not is_instance_valid(sostiene):
		return
	if sostiene.has_method("tender"):
		sostiene.call("tender")
	elif sostiene.has_method("cerrar"):
		sostiene.call("cerrar")


func _quitar_luz() -> void:
	if _luz != null and is_instance_valid(_luz):
		_luz.queue_free()
	_luz = null
