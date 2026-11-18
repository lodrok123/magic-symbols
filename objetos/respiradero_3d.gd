class_name Respiradero3D
extends Area3D

## RESPIRADERO = SETA VENENOSA (18/11/2026, puzle «Respiraderos» del laboratorio de fuego). Una SETA grande (~1,6 u de alto) que EXHALA una nube de veneno (`NubeVeneno3D`) cada `cada` s: la nube dura `vida` s,
## tiene `radio` casillas y NO nace completa: brota del centro de la seta y se EXTIENDE hasta su radio en `crece` s (clave `crece=`, 1,5; el crecimiento es real: `NubeVeneno3D.radio_actual`). Con `dir=n|e|s|o`
## la nube nace media casilla hacia ese lado (el gas sale «hacia fuera»; sin `dir` brota centrada en la seta). Las nubes de un respiradero llevan ONDAS (`NubeVeneno3D.ondas`): anillos que salen de la seta y viajan al
## borde de la nube, para que se vea de dónde viene el gas. Un segundo antes de cada exhalación (AVISO_S) la seta se HINCHA y brilla de verde cada vez más (se ve venir); al exhalar se ENCOGE de golpe (el «puf», T_PUF s).
## No bloquea su casilla (se pisa; lo peligroso es la nube). Hasta el 18/11 era una reja en el suelo: la mecánica y las claves no han cambiado.
##
## EL ASPECTO: la pieza del decorado `setas_pantano` (arte/piezas; un corro de setas que las plantas recolectables NO usan: allí van las rojas, azules y marrones), escalada a ALTO_SETA de alto y teñida de verde
## venenoso con una emisión que se enciende en el aviso, para que no se confunda con una seta que se coge. Sin esa pieza, una seta de primitivas (pie y sombrero). Atascada (agua/hielo): apagada y más oscura, sin brillo.
##
## QUÉ LE HACE CADA ELEMENTO (decisión de esta pieza, lo más barato que es coherente con lo que ya hace la nube):
##   · FUEGO (a la seta o a una nube suya): PRENDE EL GAS (`prender`). Estado «ardiendo» durante `arde_s` s (clave `arde=`, 6): la seta no exhala ni avisa, su nube viva se consume al instante (las nubes que suelta
##     llevan `consume_propio_s = quema_s`, clave `quema=`, 0,5 s, en vez de los 4 s de la tabla `veneno`, que siguen valiendo para el chamán, la colmena y la pieza `nube_veneno`) y se ve: una llama pequeña de
##     primitivas rojo-naranja (nunca amarilla) SOBRE EL SOMBRERO y luz cálida en vez de la verde. Al acabar (`se_apaga_llama`) vuelve a su ciclo DESDE 0 (la primera nube, `cada` s después). La nube de una seta que arde
##     avisa a su seta (`NubeVeneno3D.quemar` → `prender`): fuego a la niebla o a la seta es lo mismo, y el fuego a una nube prende también la seta vecina si su nube cae en el radio (1,5 casillas). Una seta ATASCADA no
##     prende (mojada); `spell_reacts` es true para el fuego siempre (el proyectil se gasta en la seta). El hueco limpio que deja es `arde_s` + `cada` s (el aviso de la siguiente nube va en el último segundo).
##   · AGUA o HIELO (`Materia.via`, como la trampa de pared): atascan la seta `T_AGUA_S` s (8): no exhala ni avisa; SOBRE UNA SETA ARDIENDO apagan además la llama (`se_apaga_llama`) y la dejan atascada.
##     `agua=no` en la pieza lo impide. La TIERRA y el resto no le hacen nada.
##   · `apagar(s)` / `encender()` (acciones del mapa, igual que `trampa_flechas`). `apagar` también quita la llama.
## Señales `exhala`, `apagado`, `encendido_otra_vez`, `prende` (empieza a arder) y `se_apaga_llama`; condiciones de la pieza `activo` | `apagado` | `ardiendo`.
## Pieza `respiradero` (alias `seta_veneno`) del mapa (escenas/puzle.gd); dueño: Juego.

signal exhala                       ## acaba de salir una nube
signal apagado                      ## se atascó (agua, hielo o una regla)
signal encendido_otra_vez           ## volvió a funcionar
signal prende                       ## el fuego prendió el gas: empieza a arder
signal se_apaga_llama               ## la llama se acabó (`arde_s`) o la apagó el agua / una regla

const CADA_DEFECTO: float = 8.0
const VIDA_DEFECTO: float = 5.0
const RADIO_DEFECTO: float = 1.0    ## casillas
const CRECE_DEFECTO: float = 1.5    ## s que tarda su nube en extenderse del centro de la seta hasta su radio
const AVISO_S: float = 1.0
const T_PUF: float = 0.35           ## s que dura el «puf» al exhalar (la seta se encoge de golpe y vuelve a su tamaño)
const ALTO_CAJA_U: float = 1.5      ## alto de la caja con la que recibe hechizos (la seta mide ALTO_SETA; la caja, lo que un barril)
const ALTO_SETA: float = 1.6        ## u de alto de la seta (la jugadora mide ~1)
const ANCHO_SETA: float = 1.9       ## u de ancho máximo (el pasillo de F12 mide una casilla = 2,3 u)
const RUTA_SETA: String = "res://arte/piezas/setas_pantano.tscn"
const TINTE_SETA: Color = Color(0.50, 1.0, 0.34)             ## se multiplica por los colores de la pieza (amarillos): sale un verde venenoso
const T_AGUA_S: float = 8.0
const COLOR_GAS: Color = Color(0.55, 0.85, 0.25)
const QUEMA_DEFECTO: float = 0.5    ## s que tarda en consumirse una nube suya cuando arde (`consume_propio_s`)
const ARDE_DEFECTO: float = 6.0     ## s que arde la seta tras prenderla el fuego
const COLOR_LLAMA: Color = Color(1.0, 0.36, 0.08)          ## rojo-naranja (nunca amarillo)
const COLOR_LLAMA_FONDO: Color = Color(0.82, 0.14, 0.05)
const COLOR_LLAMA_LUZ: Color = Color(1.0, 0.42, 0.14)
const DIRS: Dictionary = {"n": Vector3(0.0, 0.0, -1.0), "e": Vector3(1.0, 0.0, 0.0), "s": Vector3(0.0, 0.0, 1.0), "o": Vector3(-1.0, 0.0, 0.0)}

var celda: Vector2i = Vector2i.ZERO
var cada: float = CADA_DEFECTO
var vida: float = VIDA_DEFECTO
var radio: float = RADIO_DEFECTO
var crece: float = CRECE_DEFECTO    ## s que tarda su nube en extenderse hasta `radio` (0 = nace completa)
var dir: String = ""                ## "" = centrada; n|e|s|o = media casilla hacia ese lado
var desfase_s: float = 0.0
var apaga_con_agua: bool = true
var activo: bool = true             ## false = atascado (agua, hielo o una regla)
var exhalaciones: int = 0           ## cuántas nubes ha soltado (las pruebas)
var ultima: NubeVeneno3D = null     ## la última nube que soltó (las pruebas)
var en_aviso: bool = false
var quema_s: float = QUEMA_DEFECTO  ## lo que tardan en consumirse sus nubes cuando arden
var arde_s: float = ARDE_DEFECTO    ## lo que arde la seta tras prenderla el fuego
var ardiendo: bool = false          ## el gas está prendido: no exhala ni avisa

var _t: float = 0.0                 ## s desde la última exhalación
var _arde_t: float = 0.0            ## s que le quedan de arder
var _t_llama: float = 0.0
var _t_anim: float = 0.0            ## reloj de los latidos de la seta en el aviso
var _puf_t: float = 0.0             ## s que le quedan al «puf» de la exhalación
var _k_aviso: float = 0.0           ## lo hinchada que está por el aviso (0..1)
var _seta: Node3D = null            ## la seta entera (su origen es la base: escala desde el suelo)
var _mats: Array = []               ## sus materiales (StandardMaterial3D propios): emisión y tinte
var _albedos: Array = []            ## el albedo teñido de cada material (para oscurecerla atascada)
var _llama: Node3D = null
var _conos: Array = []
var _apagado_t: float = 0.0
var _apagado_fijo: bool = false
var _luz: OmniLight3D = null
var _mundo: Node = null
var _alto_visible: float = ALTO_SETA


## `p_mundo`: la maqueta (para colgar las nubes de su contenedor de piezas; sin ella, del padre de la seta).
func preparar(p_celda: Vector2i, p_cada: float, p_vida: float, p_radio: float, p_dir: String, p_desfase: float, p_mundo: Node = null) -> void:
	celda = p_celda
	cada = maxf(p_cada, 1.0)
	vida = maxf(p_vida, 0.5)
	radio = maxf(p_radio, 0.2)
	dir = p_dir if DIRS.has(p_dir) else ""
	desfase_s = p_desfase
	_mundo = p_mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	add_to_group("respiradero")
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(Terreno3D.casilla * 0.7, ALTO_CAJA_U, Terreno3D.casilla * 0.7)      # alta como la de un barril: una flecha vuela a la altura de la mano y a ras no la tocaría
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO_CAJA_U * 0.5, 0.0)
	add_child(forma)
	_t = fposmod(desfase_s, cada)
	_construir()
	_pintar(0.0)
	set_physics_process(true)


## La seta (la pieza `setas_pantano` teñida de verde o, sin ella, pie y sombrero de primitivas), la luz verde y la llama (solo mientras arde).
func _construir() -> void:
	_seta = Node3D.new()
	_seta.name = "Seta"
	add_child(_seta)
	var modelo: Node3D = _modelo_seta()
	if modelo == null:
		modelo = _seta_primitivas()
	_seta.add_child(modelo)
	_tenir(modelo)
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	_luz.light_color = COLOR_GAS
	_luz.light_energy = 0.0
	_luz.omni_range = 3.2
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, _alto_visible * 0.7, 0.0)
	add_child(_luz)
	# La llama (solo mientras arde): tres lenguas de primitivas, rojo-naranja, sobre el sombrero.
	_llama = Node3D.new()
	_llama.name = "Llama"
	_llama.position = Vector3(0.0, _alto_visible * 0.72, 0.0)
	_llama.visible = false
	add_child(_llama)
	var lenguas: Array = [[Vector3(0.0, 0.0, 0.0), 0.30, 0.95, COLOR_LLAMA], [Vector3(0.32, 0.0, 0.12), 0.22, 0.65, COLOR_LLAMA_FONDO], [Vector3(-0.30, 0.0, -0.18), 0.24, 0.72, COLOR_LLAMA]]
	for l in lenguas:
		var cono := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = float(l[1])
		cm.height = float(l[2])
		cm.radial_segments = 8
		cono.mesh = cm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = l[3]
		mt.emission_enabled = true
		mt.emission = l[3]
		mt.emission_energy_multiplier = 2.2
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cono.material_override = mt
		cono.position = (l[0] as Vector3) + Vector3(0.0, float(l[2]) * 0.5, 0.0)
		_llama.add_child(cono)
		_conos.append(cono)


## La pieza del decorado, a su medida (alto ALTO_SETA y ancho ≤ ANCHO_SETA), con la base en y = 0 centrada. null si no existe la escena.
func _modelo_seta() -> Node3D:
	if not ResourceLoader.exists(RUTA_SETA):
		return null
	var esc: PackedScene = load(RUTA_SETA) as PackedScene
	if esc == null:
		return null
	var n: Node3D = esc.instantiate() as Node3D
	if n == null:
		return null
	var caja: AABB = Pieza3D._caja(n, Transform3D.IDENTITY)
	if caja.size.y <= 0.0001:
		n.free()
		return null
	var f: float = minf(ALTO_SETA / caja.size.y, ANCHO_SETA / maxf(maxf(caja.size.x, caja.size.z), 0.0001))
	var raiz := Node3D.new()
	raiz.name = "Modelo"
	raiz.add_child(n)
	n.scale *= f
	n.position = -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5) * f
	_alto_visible = caja.size.y * f
	return raiz


## Sin la pieza: un pie y un sombrero (una esfera achatada) de primitivas, del mismo alto.
func _seta_primitivas() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Modelo"
	var pie := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.16
	cil.bottom_radius = 0.24
	cil.height = ALTO_SETA * 0.62
	pie.mesh = cil
	var m_pie := StandardMaterial3D.new()
	m_pie.albedo_color = Color(0.86, 0.88, 0.66)
	pie.material_override = m_pie
	pie.position = Vector3(0.0, ALTO_SETA * 0.31, 0.0)
	raiz.add_child(pie)
	var sombrero := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.8
	es.height = 0.9
	sombrero.mesh = es
	var m_somb := StandardMaterial3D.new()
	m_somb.albedo_color = Color(0.9, 0.9, 0.5)
	sombrero.material_override = m_somb
	sombrero.position = Vector3(0.0, ALTO_SETA * 0.7, 0.0)
	raiz.add_child(sombrero)
	_alto_visible = ALTO_SETA * 0.7 + 0.45
	return raiz


## Material propio por malla (no se comparte con las setas del decorado), teñido de verde y con la emisión verde que enciende el aviso.
func _tenir(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi: MeshInstance3D = nodo as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(s) if mi.get_surface_override_material(s) != null else mi.get_active_material(s)
				var d: StandardMaterial3D = null
				if m is BaseMaterial3D:
					d = (m as BaseMaterial3D).duplicate() as StandardMaterial3D
				if d == null:
					d = StandardMaterial3D.new()
				d.albedo_color = d.albedo_color * TINTE_SETA
				d.emission_enabled = true
				d.emission = COLOR_GAS
				d.emission_energy_multiplier = 0.15
				mi.set_surface_override_material(s, d)
				_mats.append(d)
				_albedos.append(d.albedo_color)
	for h in nodo.get_children():
		_tenir(h)


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t_anim += delta
	_puf_t = maxf(_puf_t - delta, 0.0)
	if not activo:
		if not _apagado_fijo:
			_apagado_t -= delta
			if _apagado_t <= 0.0:
				encender()
		en_aviso = false
		_pintar(0.0)
		return
	if ardiendo:
		_arde_t -= delta
		en_aviso = false
		_quemar_nubes()                  # por si le quedara alguna nube viva
		if _arde_t <= 0.0:
			_quitar_llama(true)
		else:
			_pintar(0.0, delta)
		return
	_t += delta
	if _t >= cada:
		_t = fposmod(_t, cada)
		exhalar()
	var aviso: float = minf(AVISO_S, cada)
	en_aviso = _t >= cada - aviso
	_pintar(clampf((_t - (cada - aviso)) / aviso, 0.0, 1.0) if en_aviso else 0.0)


## Suelta una nube ahora (el reloj lo hace solo; público para las pruebas). Ardiendo no exhala (null). La nube nace del centro de la seta, con `crece` s para extenderse y con sus ondas.
func exhalar() -> NubeVeneno3D:
	if ardiendo:
		return null
	exhalaciones += 1
	var donde: Vector3 = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	if dir != "":
		donde += (DIRS[dir] as Vector3) * Terreno3D.casilla * 0.5
	var padre: Node = _contenedor()
	var nube: NubeVeneno3D = NubeVeneno3D.crear(padre, donde, vida, radio, null, crece, true)
	nube.consume_propio_s = quema_s
	nube.respiradero = self
	ultima = nube
	_puf_t = T_PUF                       # el «puf»: la seta se encoge de golpe
	_k_aviso = 0.0
	exhala.emit()
	return nube


func _contenedor() -> Node:
	if _mundo is Object:
		var pr: Variant = (_mundo as Object).get("_props")
		if pr is Node:
			return pr
	return get_parent() if get_parent() != null else self


## Lo hinchada que está la seta por el aviso (0 = normal, 1 = al máximo) y, mientras dura el «puf», negativa no: eso es `puf()`.
func hinchazon() -> float:
	return _k_aviso


## Lo que le queda al «puf» de la exhalación (1 = recién exhalada, 0 = ya pasó).
func puf() -> float:
	return _puf_t / T_PUF


## Escala actual de la seta (x = z = ancho, y = alto): las pruebas y las capturas.
func escala_seta() -> Vector3:
	return _seta.scale if _seta != null else Vector3.ONE


func _poner_emision(color: Color, energia: float, oscuridad: float) -> void:
	for i in range(_mats.size()):
		var m: StandardMaterial3D = _mats[i]
		m.emission = color
		m.emission_energy_multiplier = energia
		m.albedo_color = (_albedos[i] as Color) * oscuridad


func _pintar(k: float, delta: float = 0.0) -> void:
	_k_aviso = k
	if ardiendo:
		# La llama (luz cálida y el sombrero rojizo en vez de verde) parpadea con el reloj de la seta.
		_t_llama += delta
		_poner_emision(COLOR_LLAMA_FONDO, 1.1, 0.8)
		if _seta != null:
			_seta.scale = Vector3.ONE
		if _luz != null:
			_luz.light_color = COLOR_LLAMA_LUZ
			_luz.light_energy = 1.7 + 0.4 * sin(_t_llama * 17.0) + 0.2 * sin(_t_llama * 29.0)
		for i in range(_conos.size()):
			var cn: MeshInstance3D = _conos[i]
			var f: float = _t_llama * (11.0 + 3.0 * float(i)) + float(i) * 2.1
			cn.scale = Vector3(1.0 + 0.10 * sin(f * 1.3), 1.0 + 0.22 * sin(f), 1.0 + 0.10 * sin(f * 1.3 + 1.0))
		return
	var p: float = _puf_t / T_PUF
	var e: float = p * p
	if not activo:
		# atascada (mojada): apagada, más oscura y un poco caída, sin brillo
		_poner_emision(COLOR_GAS, 0.0, 0.55)
		if _seta != null:
			_seta.scale = Vector3(1.0, 0.93, 1.0)
		if _luz != null:
			_luz.light_energy = 0.0
		return
	# hinchada por el aviso (con un latido que se acelera) y encogida de golpe al exhalar
	var latido: float = 0.045 * k * sin(_t_anim * (10.0 + 10.0 * k))
	if _seta != null:
		_seta.scale = Vector3(1.0 + 0.40 * k - 0.30 * e + latido, 1.0 + 0.22 * k - 0.24 * e + latido, 1.0 + 0.40 * k - 0.30 * e + latido)
	_poner_emision(COLOR_GAS, 0.10 + 0.4 * k + 0.5 * e, 1.0)
	if _luz != null:
		_luz.light_color = COLOR_GAS
		_luz.light_energy = 0.5 * k + 0.5 * e


# ---------------------------------------------------------------------------------------------------------------------
#  Prender el gas
# ---------------------------------------------------------------------------------------------------------------------

## El fuego prende el gas: arde `arde_s` s (no exhala ni avisa) y su nube viva se consume al instante. false si ya ardía o está atascada (mojada).
func prender() -> bool:
	if ardiendo or not activo:
		return false
	ardiendo = true
	_arde_t = arde_s
	_t_llama = 0.0
	en_aviso = false
	if _llama != null:
		_llama.visible = true
	_quemar_nubes()
	_pintar(0.0)
	prende.emit()
	return true


## Quema al instante las nubes vivas que soltó esta seta (cada una tarda `quema_s`, por su `consume_propio_s`).
func _quemar_nubes() -> void:
	for v in NubeVeneno3D.vivas.duplicate():
		if is_instance_valid(v) and (v as NubeVeneno3D).respiradero == self and not (v as NubeVeneno3D).ardiendo:
			(v as NubeVeneno3D).quemar(quema_s)


## Quita la llama. `ciclo_nuevo`: acabó de arder (vuelve a su ciclo desde 0); si no, la apagó el agua o una regla (el ciclo lo gobierna el atasco).
func _quitar_llama(ciclo_nuevo: bool) -> void:
	if not ardiendo:
		return
	ardiendo = false
	_arde_t = 0.0
	if _llama != null:
		_llama.visible = false
	if ciclo_nuevo:
		_t = 0.0
	_pintar(0.0)
	se_apaga_llama.emit()


# ---------------------------------------------------------------------------------------------------------------------
#  Apagar / encender (reglas del mapa, agua, hielo)
# ---------------------------------------------------------------------------------------------------------------------

## La atasca `segundos` s (0 o menos = hasta `encender`).
func apagar(segundos: float = 0.0) -> void:
	var estaba: bool = activo
	activo = false
	_quitar_llama(false)
	if segundos > 0.0:
		_apagado_fijo = false
		_apagado_t = maxf(_apagado_t, segundos)
	else:
		_apagado_fijo = true
		_apagado_t = 0.0
	if estaba:
		apagado.emit()


func encender() -> void:
	if activo:
		return
	activo = true
	_apagado_fijo = false
	_apagado_t = 0.0
	_t = 0.0
	encendido_otra_vez.emit()


# --- Contrato con los hechizos (el agua y el hielo la atascan) ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	if e == "fuego":
		prender()
	elif apaga_con_agua and (e == "agua" or e == "hielo"):
		apagar(T_AGUA_S)


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	var e: String = Materia.via(Materia.de(hechizo if hechizo != null else rune_data))
	if e == "fuego":
		return true
	if not apaga_con_agua or not activo:
		return false
	return e == "agua" or e == "hielo"


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, 0.2, 0.0))
