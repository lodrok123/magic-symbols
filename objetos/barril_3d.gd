class_name Barril3D
extends Area3D

## BARRIL DE PÓLVORA (15/10, Juego; referencia de Pablo: «un barril que explota destruyendo una roca» para abrir o cerrar el curso del
## agua). El FUEGO lo enciende; `T_MECHA` s después EXPLOTA: emite `explota(punto, radio)` y avisa a todo lo que esté a `RADIO` u y
## tenga `recibir_explosion(punto)` (una Compuerta3D de tipo roca con `abre_con = "explosion"`, otro barril: reacción en cadena…).
## Después desaparece. El rayo también lo prende (chispa). El agua apaga la mecha si llega a tiempo.
## 4/11/2026: mientras arde la mecha dibuja el ÁREA (AvisoAreaFuego: círculo de fuego en el suelo de radio RADIO que se llena y late cada vez más deprisa), al explotar DAÑA a los enemigos y a la
## jugadora que estén dentro (como las bombas de Echoes of Wisdom) y la explosión se ve con el fuego oficial (ExplosionFuegoToy). Una explosión vecina lo enciende (cadena).
## 5/11/2026 (playtest de Pablo: «falta su asset… hazlo más pequeño y lanzable»):
##   · MODELO: se dibuja con el modelo de Meshy «barril» de la lámina puzle_terrain (el mismo de PiezaPuzle3D: Ø0,98 × 0,95, con la calavera pintada y el agujero de la mecha en la tapa; mira al +Z, o sea a la
##     cámara del juego, que mira al norte). Sin modelo (`PiezaPuzle3D.usar_modelos` = false o el GLB no está) vuelve a las primitivas de antes. La mecha es un cordón crema que se consume sobre la tapa, con
##     chispas naranjas y una luz pequeña en su punta; la madera parpadea de blanco a un rojo suave (se tiñe el albedo; sin emisión, que saturaba).
##   · BARRIL PEQUEÑO (`pequeno` = true; en el mapa `; pieza <id> barril x y tam=pequeno`): el mismo modelo a ×0,58 (0,55 de alto), que la jugadora COGE con E y LANZA con E (CargarObjeto3D, fila
##     `barril_pequeno`; se carga sobre la cabeza, no es «ligero»). Radio 1,6 u, daño 20 a enemigos y 12 a la jugadora, mecha de 2,4 s (más larga: hay que poder cogerlo, llevarlo y lanzarlo). Encendido (fuego,
##     rayo, otra explosión) la mecha corre también en brazos y en el aire y explota donde esté al acabar —¡también en las manos de la jugadora!— o al chocar (suelo, pared, enemigo), lo que pase antes.
##     Sin encender no explota nunca: lanzado se queda donde cae. Cada barril pequeño es un cogible propio (sin casilla mientras viaja: `al_coger` / `al_soltar`, como Rompible3D).
## Qué NO hace: la colmena y otros assets (ver docs/BARRIL_EXPLOSION_2026-11-04.md).

signal explota(punto: Vector3, radio: float)

const T_MECHA: float = 1.2
const RADIO: float = 2.6                ## u (algo más de una casilla): la roca de al lado, no la de dos más allá
const ALTO: float = 0.95

## 4/11/2026 (decisión de Pablo, como las bombas de Zelda: Echoes of Wisdom): la explosión DAÑA a los enemigos Y a la jugadora que estén dentro de RADIO (en el plano; ver ALTO_AFECTA), además de romper lo de
## siempre (grupo `explosionable`) y encender a los otros barriles (cadena). Se hace por las vías que ya existen: a un `Combate3D` con `recibir_golpe_cuerpo` (daño plano sin debilidades, interrumpe
## su ataque y empuja por la reacción `empujado`), y a la jugadora con `Jugador3D.recibir_dano(cantidad, desde)` (defensa, barrera, bálsamo, invulnerabilidad de 0,7 s y retroceso de 4,5 u/s incluidos).
## Comparación: golpe F 5 · jarrón lanzado 8 · caja 6 · piedra 12 · geoda explosiva 30 (aturde 2 s) · goblin que pega 20 (50 de vida) · barril 35 a los enemigos: un goblin (50) sobrevive con 15 y el
## segundo barril o un golpe lo remata; el elemental (500) casi ni lo nota. A la jugadora 20 (lo que un golpe de goblin, de 100 de vida): se aprende a salir del círculo, no castiga a muerte.
const DANO_ENEMIGO: float = 35.0
const EMPUJE_ENEMIGO: float = 6000.0    ## fuerza de `recibir_golpe_cuerpo` (la escala del jarrón 4500, el golpe F 5000, la piedra 6000): sale despedido más de 2 casillas
const DANO_JUGADORA: float = 20.0
const ALTO_AFECTA: float = 1.6          ## u: tope de altura (|Δy| entre quien sea y el suelo del barril) para que la explosión lo alcance: un nivel de tierra más arriba (1 casilla ≈ 1 u) sí, dos no
const COLOR_MADERA: Color = Color(0.45, 0.3, 0.15)     ## el color de las primitivas (sin modelo)
const COLOR_MECHA: Color = Color(0.85, 0.16, 0.07)     ## el rojo al que parpadea la madera de las primitivas mientras arde la mecha
const TINTE_MODELO: Color = Color(1.0, 0.4, 0.3)       ## el modelo lleva su textura: el albedo base es blanco y parpadea hacia este tinte rojo (mezcla 0,10–0,50; sin emisión)
const GRUPO_BARRILES: String = "barriles_polvora"   ## para la cadena: los barriles se avisan entre ellos (no están en `explosionable` para no cambiar lo que hace la lava con ese grupo)

## El barril pequeño (lanzable). Mismo modelo a ×`ALTO_PEQUENO / ALTO`.
const ALTO_PEQUENO: float = 0.55
const RADIO_PEQUENO: float = 1.6
const DANO_ENEMIGO_PEQUENO: float = 20.0
const EMPUJE_ENEMIGO_PEQUENO: float = 4500.0
const DANO_JUGADORA_PEQUENO: float = 12.0
const T_MECHA_PEQUENO: float = 2.4
const COGIBLE: String = "barril_pequeno"             ## la fila de CargarObjeto3D.COGIBLES

const CORDON_LARGO: float = 0.22        ## u: lo que sobresale la mecha de la tapa (×escala en el pequeño)
const COLOR_CORDON: Color = Color(0.62, 0.5, 0.34)

var celda: Vector2i = Vector2i.ZERO
var pequeno: bool = false                ## true = barril pequeño lanzable (ver arriba)
var radio: float = RADIO                 ## alcance de ESTE barril (RADIO, o RADIO_PEQUENO)
var alto: float = ALTO
var dano_enemigo: float = DANO_ENEMIGO
var empuje_enemigo: float = EMPUJE_ENEMIGO
var dano_jugadora: float = DANO_JUGADORA
var t_mecha: float = T_MECHA
var encendido: bool = false
var explotado: bool = false
var roto_ya: bool = false                ## = explotado (CargarObjeto3D lo pregunta: un cogible roto ya no se coge)
var en_brazos: bool = false              ## la jugadora lo lleva o va en el aire (CargarObjeto3D): sin casilla y sin colisión
var _sin_celda: bool = false             ## su casilla ya no la bloquea él
var _t: float = 0.0
var _cuerpo: Node3D = null               ## el modelo (o el cilindro de las primitivas)
var _modelo_ok: bool = false             ## true = dibujado con el modelo de Meshy
var _mat: StandardMaterial3D = null
var aviso: AvisoAreaFuego = null         ## el círculo de aviso mientras arde la mecha (null si no arde)
var golpeados: Array = []                ## los Combate3D que alcanzó al explotar (las pruebas)
var jugadora_alcanzada: bool = false     ## ¿estaba la jugadora dentro del área al explotar? (las pruebas; el daño real depende además de su invulnerabilidad)
var explosion_vfx: ExplosionFuegoToy = null
var _aro: MeshInstance3D = null
var _mecha: MeshInstance3D = null        ## el cordón (se acorta según arde)
var _chispas: GPUParticles3D = null      ## las chispas de la punta (solo encendido)
var _luz: OmniLight3D = null
var _punta: MeshInstance3D = null


func preparar(p_celda: Vector2i, p_pequeno: bool = false) -> void:
	celda = p_celda
	pequeno = p_pequeno
	_configurar()
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)


## Los números de este barril según su tamaño.
func _configurar() -> void:
	radio = RADIO_PEQUENO if pequeno else RADIO
	alto = ALTO_PEQUENO if pequeno else ALTO
	dano_enemigo = DANO_ENEMIGO_PEQUENO if pequeno else DANO_ENEMIGO
	empuje_enemigo = EMPUJE_ENEMIGO_PEQUENO if pequeno else EMPUJE_ENEMIGO
	dano_jugadora = DANO_JUGADORA_PEQUENO if pequeno else DANO_JUGADORA
	t_mecha = T_MECHA_PEQUENO if pequeno else T_MECHA


func escala_modelo() -> float:
	return alto / ALTO


func _ready() -> void:
	_configurar()
	add_to_group(GRUPO_BARRILES)
	if pequeno:
		add_to_group("cogible")
		set_meta("cogible", COGIBLE)
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	var lado: float = 1.0 * escala_modelo()
	caja.size = Vector3(lado, alto, lado)
	forma.shape = caja
	forma.position = Vector3(0.0, alto * 0.5, 0.0)
	add_child(forma)
	_poner_visual()
	_poner_mecha()
	set_process(true)


## El modelo de Meshy (puzle_terrain «barril») o, si no hay, el cilindro y el aro de siempre. El modelo mira a +Z (la cámara del juego mira al norte) y no hay que girarlo.
func _poner_visual() -> void:
	var malla: Mesh = PiezaPuzle3D.malla_modelo("barril")
	if malla != null:
		var mi := MeshInstance3D.new()
		mi.name = "modelo"
		mi.mesh = malla
		_mat = PiezaPuzle3D._material_modelo("barril")      # copia propia: el parpadeo no toca a los demás barriles
		_mat.albedo_color = Color.WHITE
		mi.material_override = _mat
		mi.scale = Vector3.ONE * escala_modelo()
		add_child(mi)
		_cuerpo = mi
		_modelo_ok = true
		return
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_MADERA
	var cuerpo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.42 * escala_modelo()
	cil.bottom_radius = 0.42 * escala_modelo()
	cil.height = alto
	cuerpo.mesh = cil
	cuerpo.position = Vector3(0.0, alto * 0.5, 0.0)
	cuerpo.material_override = _mat
	add_child(cuerpo)
	_cuerpo = cuerpo
	var aro := MeshInstance3D.new()
	_aro = aro
	var t := TorusMesh.new()
	t.inner_radius = 0.4 * escala_modelo()
	t.outer_radius = 0.47 * escala_modelo()
	aro.mesh = t
	aro.position = Vector3(0.0, alto * 0.5, 0.0)
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color(0.3, 0.3, 0.32)
	aro.material_override = ma
	add_child(aro)


## El cordón de la mecha sobre la tapa (siempre visible; se consume al arder) y la luz de su punta (solo encendido).
func _poner_mecha() -> void:
	var largo: float = CORDON_LARGO * escala_modelo()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.013
	cil.bottom_radius = 0.017
	cil.height = largo
	cil.radial_segments = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR_CORDON
	m.roughness = 0.9
	cil.material = m
	_mecha = MeshInstance3D.new()
	_mecha.name = "mecha"
	_mecha.mesh = cil
	_mecha.position = Vector3(0.0, alto + largo * 0.5 - 0.02, 0.0)
	add_child(_mecha)
	_punta = MeshInstance3D.new()                       # la brasa de la punta (solo encendido)
	_punta.name = "brasa_punta"
	var es := SphereMesh.new()
	es.radius = 0.034 * maxf(escala_modelo(), 0.7)
	es.height = es.radius * 2.0
	es.radial_segments = 8
	es.rings = 4
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.albedo_color = Color(1.0, 0.32, 0.06)
	es.material = mp
	_punta.mesh = es
	_punta.visible = false
	_punta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_punta)
	_luz = OmniLight3D.new()
	_luz.name = "luz_mecha"
	_luz.light_color = Color(1.0, 0.5, 0.2)
	_luz.omni_range = 2.2 * maxf(escala_modelo(), 0.7)
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, alto + largo, 0.0)
	add_child(_luz)


## Fracción 0..1 de mecha que queda (1 = entera).
func mecha_restante() -> float:
	if not encendido:
		return 0.0 if explotado else 1.0
	return clampf(_t / t_mecha, 0.0, 1.0)


## Acorta el cordón y baja la punta (chispas y luz) según lo que queda.
func _actualizar_mecha() -> void:
	if _mecha == null:
		return
	var largo: float = CORDON_LARGO * escala_modelo()
	var f: float = lerpf(0.08, 1.0, mecha_restante()) if encendido else 1.0
	(_mecha.mesh as CylinderMesh).height = largo * f
	_mecha.position.y = alto - 0.02 + largo * f * 0.5
	var y_punta: float = alto - 0.02 + largo * f
	if _luz != null:
		_luz.position.y = y_punta
	if _punta != null:
		_punta.position.y = y_punta
		_punta.visible = encendido
	if _chispas != null and is_instance_valid(_chispas):
		_chispas.position.y = y_punta


## 16/10 (Fase 14.6, laboratorio de fuego · F4 contrafuego): el fuego DE MAPA también lo enciende. Cada CADA_FUEGO s mira si algo que
## arde (grupo `flammable3d`: seto, tronco, cuerda…) está a ≤ RADIO_FUEGO u, el mismo alcance con el que un seto contagia a otro
## (Reactivo3D.CONTAGIO). Antes solo lo encendían un hechizo o `encender()`, y una línea de setos ardiendo pasaba de largo.
const RADIO_FUEGO: float = Reactivo3D.CONTAGIO
const CADA_FUEGO: float = 0.25
var _t_fuego: float = 0.0


func _vigilar_fuego(delta: float) -> void:
	if encendido or explotado or not is_inside_tree():
		return
	_t_fuego += delta
	if _t_fuego < CADA_FUEGO:
		return
	_t_fuego = 0.0
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_ARDE):
		if not is_instance_valid(n) or not (n is Node3D) or not bool(n.get("is_lit")):
			continue
		var d: Vector3 = (n as Node3D).global_position - global_position
		d.y = 0.0
		if d.length() <= RADIO_FUEGO:
			encender()
			return


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if rune_data == null or explotado:
		return
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	if Materia.calienta(m) or Materia.conduce(m):
		encender()
	elif encendido and Materia.riega(m):
		apagar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	if rune_data == null or explotado:
		return false
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	if Materia.calienta(m) or Materia.conduce(m):
		return not encendido
	return encendido and Materia.riega(m)


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, alto, 0.0))


func encender() -> void:
	if encendido or explotado:
		return
	encendido = true
	_t = t_mecha
	Sfx.play(self, "mecha")     # 13/11 (inventario SFX): antes no sonaba
	# Sin emisión: con el entorno del juego (brillo) hasta 0,05 de emisión saturaba el barril entero de naranja. La mecha se lee como un rojo que sube y baja en la propia madera.
	_poner_color_mecha(0.15)
	_poner_aviso()
	_poner_chispas()
	if _luz != null:
		_luz.light_energy = 0.7
	_actualizar_mecha()


func apagar() -> void:
	encendido = false
	if _mat != null:
		_mat.emission_enabled = false
	_poner_color_mecha(-1.0)
	_quitar_aviso()
	_quitar_chispas()
	if _luz != null:
		_luz.light_energy = 0.0
	_actualizar_mecha()


## k < 0: el color de la madera sin más. k entre 0 y 1: cuánto se tiñe de rojo (el modelo lleva su textura: se multiplica el albedo, blanco → rojo suave).
func _poner_color_mecha(k: float) -> void:
	if _mat == null:
		return
	if _modelo_ok:
		_mat.albedo_color = Color.WHITE if k < 0.0 else Color.WHITE.lerp(TINTE_MODELO, k * 0.85)
	else:
		_mat.albedo_color = COLOR_MADERA if k < 0.0 else COLOR_MADERA.lerp(COLOR_MECHA, k)


## Las chispas naranjas de la punta de la mecha (continuas, en coordenadas del mundo: la punta se mueve con el barril y las chispas se quedan).
func _poner_chispas() -> void:
	if _chispas != null and is_instance_valid(_chispas):
		return
	if not is_inside_tree():
		return
	var esc: float = maxf(escala_modelo(), 0.6)
	_chispas = VfxPuzle3D._emisor(self, Vector3(0.0, alto + CORDON_LARGO * escala_modelo(), 0.0), "brasa", 9, 0.45, 0.11 * esc, 1.6 * esc,
		{"color": Color(1.0, 0.38, 0.07, 1.0), "aditivo": true, "hdr": 1.5, "gravedad": -3.0, "abanico": 150.0, "continuo": true, "radio_emision": 0.03})
	_chispas.name = "chispas_mecha"


func _quitar_chispas() -> void:
	if _chispas != null and is_instance_valid(_chispas):
		_chispas.emitting = false
		if _chispas.get_parent() != null:
			_chispas.get_parent().remove_child(_chispas)
		_chispas.queue_free()
	_chispas = null


## Una explosión vecina lo enciende (cadena): arde su mecha entera y explota T_MECHA s después, con su propio aviso.
func recibir_explosion(_punto: Vector3) -> void:
	encender()


## El círculo de aviso del área, de radio `radio` exacto, a ras del suelo bajo el barril (va suelto del barril: si viaja en brazos o por el aire no gira ni se levanta con él). Solo con el barril ya en el árbol.
func _poner_aviso() -> void:
	if aviso != null and is_instance_valid(aviso):
		return
	if not is_inside_tree():
		return
	aviso = AvisoAreaFuego.crear(radio)
	aviso.name = "AvisoArea"
	add_child(aviso)
	aviso.top_level = true
	_colocar_aviso()


## Pone el aviso en el suelo de la casilla en la que está el barril ahora.
func _colocar_aviso() -> void:
	if aviso == null or not is_instance_valid(aviso):
		return
	var p: Vector3 = global_position
	aviso.global_transform = Transform3D(Basis.IDENTITY, Vector3(p.x, _y_suelo(p), p.z))


## Altura del suelo bajo `p` (la de la casilla; si está fuera del mapa, la propia).
func _y_suelo(p: Vector3) -> float:
	var c: Vector2i = Terreno3D.celda_de(p)
	return Terreno3D.y_pies(c) if Terreno3D.en_mapa(c) else p.y


func _quitar_aviso() -> void:
	if aviso != null and is_instance_valid(aviso):
		if aviso.get_parent() != null:
			aviso.get_parent().remove_child(aviso)     # sale del árbol ya (las pruebas cuentan el grupo en el mismo fotograma) y se libera
		aviso.queue_free()
	aviso = null


func _process(delta: float) -> void:
	_vigilar_fuego(delta)
	if not encendido or explotado:
		return
	_poner_aviso()
	_t -= delta
	_poner_color_mecha(0.15 + 0.3 * absf(sin(_t * 20.0)))     # parpadea cada vez más deprisa
	_actualizar_mecha()
	if aviso != null:
		_colocar_aviso()
		aviso.actualizar(1.0 - clampf(_t / t_mecha, 0.0, 1.0), delta)
	if _t <= 0.0:
		_explotar()


## --- Cogerlo y lanzarlo (solo el pequeño: CargarObjeto3D; docs/RECOGER_LANZAR_2026-11-04.md) ---
## El nodo entero viaja con la jugadora (su `global_position` la pone ella mientras lo lleva o lo lanza). La mecha, si ardía, sigue corriendo.

## La jugadora lo levanta: libera su casilla y deja de ser golpeable. false si ya no está o ya va en brazos.
func al_coger() -> bool:
	if explotado or en_brazos:
		return false
	en_brazos = true
	if not _sin_celda:
		Terreno3D.liberar_celda(celda)
		_sin_celda = true
	collision_layer = 0
	return true


## Lo deja ENTERO en `punto` (suelo): ocupa la casilla de ese punto. Si ardía, la mecha sigue.
func al_soltar(punto: Vector3) -> void:
	if explotado or not en_brazos:
		return
	en_brazos = false
	_sin_celda = false
	celda = Terreno3D.celda_de(punto)
	rotation = Vector3.ZERO
	global_position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	collision_layer = Lanzador3D.CAPA_REACTIVO
	Terreno3D.bloquear_celda(celda)


## CargarObjeto3D._aterrizar, justo después de dejarlo: lanzado y ENCENDIDO explota donde ha caído o chocado (suelo, pared, enemigo); sin encender se queda ahí.
func al_impactar_lanzado(punto: Vector3) -> void:
	if explotado or not encendido:
		return
	global_position = Vector3(punto.x, maxf(punto.y, _y_suelo(punto)), punto.z)
	_t = 0.0
	_explotar()


## Dónde se centra la explosión: el barril, y si el pequeño va por el aire o en las manos, el suelo bajo él (el decal y el daño se miden desde el suelo).
func _punto_explosion() -> Vector3:
	var p: Vector3 = global_position
	if pequeno:
		var y: float = _y_suelo(p)
		if p.y - y > -0.5 and p.y - y < 2.5:
			p.y = y
	return p


func _explotar() -> void:
	explotado = true
	Sfx.play(self, "explosion")     # 13/11 (inventario SFX): antes no sonaba
	roto_ya = true
	encendido = false
	var punto: Vector3 = _punto_explosion()
	if not _sin_celda:
		Terreno3D.liberar_celda(celda)
	_sin_celda = true
	# Lo que está al alcance y sabe recibir una explosión.
	for n in get_tree().get_nodes_in_group("explosionable"):
		if is_instance_valid(n) and n != self and n is Node3D and (n as Node3D).global_position.distance_to(punto) <= radio and n.has_method("recibir_explosion"):
			n.call("recibir_explosion", punto)
	# Cadena: los otros barriles al alcance se encienden (cada uno con su mecha y su aviso).
	for n in get_tree().get_nodes_in_group(GRUPO_BARRILES):
		if is_instance_valid(n) and n != self and n is Barril3D and not (n as Barril3D).explotado and (n as Barril3D).global_position.distance_to(punto) <= radio:
			(n as Barril3D).recibir_explosion(punto)
	_danar(punto)
	_quitar_aviso()
	_quitar_chispas()
	explota.emit(punto, radio)
	PulsoPantalla3D.lanzar_en(get_tree(), punto, 0.6 if not pequeno else 0.4, 0.3 if not pequeno else 0.22)     # bloque 2 EoW: golpe de pantalla desde la explosión
	# La explosión con el fuego oficial (ExplosionFuegoToy: bola de fuego, lenguas, brasas, chispas, onda a ras de suelo y luz). Cuelga del padre del barril, no de él, y se libera sola.
	explosion_vfx = ExplosionFuegoToy.crear(radio)
	var padre: Node = get_parent()
	if padre != null:
		padre.add_child(explosion_vfx)
		explosion_vfx.global_position = punto
	else:
		add_child(explosion_vfx)
	_cuerpo.visible = false
	if _aro != null:
		_aro.visible = false
	if _mecha != null:
		_mecha.visible = false
	if _punta != null:
		_punta.visible = false
	if _luz != null:
		_luz.light_energy = 0.0
	collision_layer = 0                                    # el nodo se queda (los puzles y las pruebas lo siguen consultando), pero ya no se golpea
	if pequeno:
		queue_free()      # el pequeño viaja: si la jugadora lo llevaba en brazos, CargarObjeto3D ve que ya no existe y le suelta las manos


## Daño a lo que esté dentro del área: los enemigos (`Combate3D`, grupo `combate3d`) y la jugadora. Se mide en el plano (XZ) hasta `radio` y con un tope de altura ALTO_AFECTA.
func _danar(punto: Vector3) -> void:
	golpeados.clear()
	jugadora_alcanzada = false
	for n in get_tree().get_nodes_in_group("combate3d"):
		if not is_instance_valid(n) or not (n is Node3D) or bool(n.get("muerto")) or not _en_area(n as Node3D, punto):
			continue
		var d: Vector3 = (n as Node3D).global_position - punto
		d.y = 0.0
		if d.length() < 0.01:
			d = Vector3(0.0, 0.0, 1.0)              # justo encima del barril: sale hacia el sur
		if (n as Object).has_method("recibir_golpe_cuerpo"):
			(n as Object).call("recibir_golpe_cuerpo", d.normalized(), dano_enemigo, empuje_enemigo)
		elif (n as Object).has_method("receive_damage"):
			(n as Object).call("receive_damage", dano_enemigo)
		golpeados.append(n)
	var j: Node3D = _jugadora()
	if j != null and _en_area(j, punto):
		jugadora_alcanzada = true
		if (j as Object).has_method("recibir_dano"):
			(j as Object).call("recibir_dano", dano_jugadora, punto)     # respeta su invulnerabilidad y empuja desde `punto`


func _en_area(n: Node3D, punto: Vector3) -> bool:
	var d: Vector3 = n.global_position - punto
	var dy: float = absf(d.y)
	d.y = 0.0
	return d.length() <= radio and dy <= ALTO_AFECTA


func _jugadora() -> Node3D:
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	var j: Variant = lanz.get("jugador") if lanz != null else null
	return j as Node3D if j != null and is_instance_valid(j) else null
