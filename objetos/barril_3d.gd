class_name Barril3D
extends Area3D

## BARRIL DE PÓLVORA (15/10, Juego; referencia de Pablo: «un barril que explota destruyendo una roca» para abrir o cerrar el curso del
## agua). El FUEGO lo enciende; `T_MECHA` s después EXPLOTA: emite `explota(punto, radio)` y avisa a todo lo que esté a `RADIO` u y
## tenga `recibir_explosion(punto)` (una Compuerta3D de tipo roca con `abre_con = "explosion"`, otro barril: reacción en cadena…).
## Después desaparece. El rayo también lo prende (chispa). El agua apaga la mecha si llega a tiempo.
## 4/11/2026: mientras arde la mecha dibuja el ÁREA (AvisoAreaFuego: círculo de fuego en el suelo de radio RADIO que se llena y late cada vez más deprisa), al explotar DAÑA a los enemigos y a la
## jugadora que estén dentro (como las bombas de Echoes of Wisdom) y la explosión se ve con el fuego oficial (ExplosionFuegoToy). Una explosión vecina lo enciende (cadena).
## Qué NO hace: dibujo bueno del barril (el Pipeline tiene «barril»).

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
const GRUPO_BARRILES: String = "barriles_polvora"   ## para la cadena: los barriles se avisan entre ellos (no están en `explosionable` para no cambiar lo que hace la lava con ese grupo)

var celda: Vector2i = Vector2i.ZERO
var encendido: bool = false
var explotado: bool = false
var _t: float = 0.0
var _cuerpo: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var aviso: AvisoAreaFuego = null         ## el círculo de aviso mientras arde la mecha (null si no arde)
var golpeados: Array = []                ## los Combate3D que alcanzó al explotar (las pruebas)
var jugadora_alcanzada: bool = false     ## ¿estaba la jugadora dentro del área al explotar? (las pruebas; el daño real depende además de su invulnerabilidad)
var explosion_vfx: ExplosionFuegoToy = null
var _aro: MeshInstance3D = null


func preparar(p_celda: Vector2i) -> void:
	celda = p_celda
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	add_to_group(GRUPO_BARRILES)
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.0, ALTO, 1.0)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.45, 0.3, 0.15)
	_cuerpo = MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.42
	cil.bottom_radius = 0.42
	cil.height = ALTO
	_cuerpo.mesh = cil
	_cuerpo.position = Vector3(0.0, ALTO * 0.5, 0.0)
	_cuerpo.material_override = _mat
	add_child(_cuerpo)
	var aro := MeshInstance3D.new()
	_aro = aro
	var t := TorusMesh.new()
	t.inner_radius = 0.4
	t.outer_radius = 0.47
	aro.mesh = t
	aro.position = Vector3(0.0, ALTO * 0.5, 0.0)
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color(0.3, 0.3, 0.32)
	aro.material_override = ma
	add_child(aro)
	set_process(true)


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
	return to_global(Vector3(0.0, ALTO, 0.0))


func encender() -> void:
	if encendido or explotado:
		return
	encendido = true
	_t = T_MECHA
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.4, 0.1)
	_mat.emission_energy_multiplier = 0.6
	_poner_aviso()


func apagar() -> void:
	encendido = false
	_mat.emission_enabled = false
	_quitar_aviso()


## Una explosión vecina lo enciende (cadena): arde su mecha entera y explota T_MECHA s después, con su propio aviso.
func recibir_explosion(_punto: Vector3) -> void:
	encender()


## El círculo de aviso del área, de radio RADIO exacto, colgado del barril (su origen es el suelo de la casilla). Solo con el barril ya en el árbol.
func _poner_aviso() -> void:
	if aviso != null and is_instance_valid(aviso):
		return
	if not is_inside_tree():
		return
	aviso = AvisoAreaFuego.crear(RADIO)
	aviso.name = "AvisoArea"
	add_child(aviso)


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
	_mat.emission_energy_multiplier = 0.6 + 0.6 * absf(sin(_t * 20.0))     # parpadea cada vez más deprisa
	if aviso != null:
		aviso.actualizar(1.0 - clampf(_t / T_MECHA, 0.0, 1.0), delta)
	if _t <= 0.0:
		_explotar()


func _explotar() -> void:
	explotado = true
	encendido = false
	var punto: Vector3 = global_position
	Terreno3D.liberar_celda(celda)
	# Lo que está al alcance y sabe recibir una explosión.
	for n in get_tree().get_nodes_in_group("explosionable"):
		if is_instance_valid(n) and n != self and n is Node3D and (n as Node3D).global_position.distance_to(punto) <= RADIO and n.has_method("recibir_explosion"):
			n.call("recibir_explosion", punto)
	# Cadena: los otros barriles al alcance se encienden (cada uno con su mecha y su aviso).
	for n in get_tree().get_nodes_in_group(GRUPO_BARRILES):
		if is_instance_valid(n) and n != self and n is Barril3D and not (n as Barril3D).explotado and (n as Barril3D).global_position.distance_to(punto) <= RADIO:
			(n as Barril3D).recibir_explosion(punto)
	_danar(punto)
	_quitar_aviso()
	explota.emit(punto, RADIO)
	PulsoPantalla3D.lanzar_en(get_tree(), punto, 0.6, 0.3)     # bloque 2 EoW: golpe de pantalla desde la explosión
	# La explosión con el fuego oficial (ExplosionFuegoToy: bola de fuego, chispas, onda a ras de suelo y luz). Cuelga del padre del barril, no de él, y se libera sola.
	explosion_vfx = ExplosionFuegoToy.crear(RADIO)
	var padre: Node = get_parent()
	if padre != null:
		padre.add_child(explosion_vfx)
		explosion_vfx.global_position = punto
	else:
		add_child(explosion_vfx)
	_cuerpo.visible = false
	if _aro != null:
		_aro.visible = false
	collision_layer = 0                                     # el nodo se queda (los puzles y las pruebas lo siguen consultando), pero ya no se golpea


## Daño a lo que esté dentro del área: los enemigos (`Combate3D`, grupo `combate3d`) y la jugadora. Se mide en el plano (XZ) hasta RADIO y con un tope de altura ALTO_AFECTA.
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
			(n as Object).call("recibir_golpe_cuerpo", d.normalized(), DANO_ENEMIGO, EMPUJE_ENEMIGO)
		elif (n as Object).has_method("receive_damage"):
			(n as Object).call("receive_damage", DANO_ENEMIGO)
		golpeados.append(n)
	var j: Node3D = _jugadora()
	if j != null and _en_area(j, punto):
		jugadora_alcanzada = true
		if (j as Object).has_method("recibir_dano"):
			(j as Object).call("recibir_dano", DANO_JUGADORA, punto)     # respeta su invulnerabilidad y empuja desde `punto`


func _en_area(n: Node3D, punto: Vector3) -> bool:
	var d: Vector3 = n.global_position - punto
	var dy: float = absf(d.y)
	d.y = 0.0
	return d.length() <= RADIO and dy <= ALTO_AFECTA


func _jugadora() -> Node3D:
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	var j: Variant = lanz.get("jugador") if lanz != null else null
	return j as Node3D if j != null and is_instance_valid(j) else null
