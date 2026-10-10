class_name Surtidor3D
extends Area3D

## SURTIDOR (9.11, Juego): la fuente de piedra (letra `u`) que, al recibir AGUA, llena el CAUCE SECO (casillas `c`) y lo une
## al río. Es la regla «agua que rellena» de 5.5, en pequeño: un solo surtidor, un solo cauce, una sola vez.
##
## POR QUÉ SE CAMBIA LA LETRA DE LA CASILLA. Todo el juego decide si una casilla es agua mirando su letra (`~`): el jugador al
## nadar, los goblins al esquivarla, el hielo, el emisor de rayo. Si el cauce «parece» agua pero su letra sigue siendo `c`,
## nada de eso lo sabe y la corriente no pasaría. Cambiar la letra en `_mapa` (y bloquearla a pie, como las demás `~`) hace
## que TODAS esas reglas lo vean a la vez, sin tocar ninguna. Lo mismo hizo el puente reactivo con la letra `b`.
##
## Cómo se ve: si la maqueta tiene `poner_agua(celdas)` (lo pone el Pipeline, 9.7) se usa para dibujar el agua de verdad; si
## no, una losa azul translúcida por casilla. La lógica no depende de ello: se prueba sin dibujo.
##
## Contrato de hechizos (docs/DIARIO.md, 2026-10-06): on_spell_hit, spell_reacts, nivel_altura, carried_element. Solo reacciona
## al agua. El hielo no: congelar el surtidor no lo llena.

signal lleno(celdas: Array)

const LETRA_CAUCE: String = "c"
const T_ENTRE_CASILLAS: float = 0.22     ## s entre una casilla del cauce y la siguiente: el agua BAJA, no aparece de golpe

var m: Variant = null
var celda: Vector2i = Vector2i.ZERO
var cauce: Array = []                    ## Vector2i del cauce seco, de la más cercana al surtidor a la más lejana
var esta_lleno: bool = false


func preparar(p_mundo: Variant, p_celda: Vector2i) -> void:
	m = p_mundo
	celda = p_celda
	position = Lanzador3D.centro_de(celda, Lanzador3D.alto_suelo)
	cauce = Surtidor3D.buscar_cauce(celda, func(c: Vector2i) -> bool: return String(m.call("_letra", c)) == LETRA_CAUCE)


func _ready() -> void:
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(Lanzador3D.casilla * 0.9, 1.4, Lanzador3D.casilla * 0.9)
	forma.shape = caja
	forma.position = Vector3(0.0, 0.7, 0.0)
	add_child(forma)


## Casillas de cauce unidas (por las 4 vecinas) a las vecinas del surtidor, ordenadas por distancia de relleno: así el agua
## corre desde el surtidor hacia fuera. Estática: se mide sin escena.
static func buscar_cauce(origen: Vector2i, es_cauce: Callable) -> Array:
	var visto: Dictionary = {}
	var cola: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = origen + d
		if bool(es_cauce.call(c)) and not visto.has(c):
			visto[c] = true
			cola.append(c)
	var i: int = 0
	while i < cola.size():
		var c2: Vector2i = cola[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c2 + d
			if not visto.has(v) and bool(es_cauce.call(v)):
				visto[v] = true
				cola.append(v)
	return cola


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data != null and rune_data.tags.has("agua") and not esta_lleno:
		llenar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and rune_data.tags.has("agua") and not esta_lleno


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## Llena el cauce, una casilla tras otra. Se puede llamar a mano (las pruebas).
func llenar() -> void:
	if esta_lleno:
		return
	esta_lleno = true
	var celdas: Array = cauce.duplicate()
	if m != null and m.get("_fx") != null:
		(m.get("_fx") as Vfx3D).chispazo(global_position + Vector3(0.0, 1.2, 0.0), "agua")
	for i in range(celdas.size()):
		var c: Vector2i = celdas[i]
		if i == 0 or not is_inside_tree():
			Surtidor3D.convertir_a_agua(m, c)
		else:
			get_tree().create_timer(T_ENTRE_CASILLAS * float(i)).timeout.connect(Surtidor3D.convertir_a_agua.bind(m, c))
	var total: float = T_ENTRE_CASILLAS * float(maxi(celdas.size() - 1, 0))
	if is_inside_tree():
		get_tree().create_timer(total).timeout.connect(func() -> void: lleno.emit(celdas))
	else:
		lleno.emit(celdas)


## Pasa UNA casilla de la maqueta a agua: la letra (`~`), el bloqueo a pie, y su dibujo.
static func convertir_a_agua(p_mundo: Variant, c: Vector2i) -> void:
	if p_mundo == null or not is_instance_valid(p_mundo):
		return
	var mapa: PackedStringArray = p_mundo.get("_mapa")
	if c.y < 0 or c.y >= mapa.size() or c.x < 0 or c.x >= mapa[c.y].length():
		return
	var fila: String = mapa[c.y]
	mapa[c.y] = fila.substr(0, c.x) + "~" + fila.substr(c.x + 1)
	p_mundo.set("_mapa", mapa)
	var bloq: Variant = p_mundo.get("_bloqueadas")
	if bloq is Dictionary:
		(bloq as Dictionary)[c] = true           # como el resto del agua: a pie no se pisa (se nada desde la orilla)
	if p_mundo.has_method("poner_agua"):
		p_mundo.call("poner_agua", [c])
	elif p_mundo is Node3D and (p_mundo as Node3D).is_inside_tree():
		var q := MeshInstance3D.new()
		var plano := QuadMesh.new()
		plano.orientation = PlaneMesh.FACE_Y
		plano.size = Vector2(Lanzador3D.casilla, Lanzador3D.casilla)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.5, 0.9, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plano.material = mat
		q.mesh = plano
		q.name = "agua_nueva"
		q.position = Lanzador3D.centro_de(c, Lanzador3D.alto_agua + 0.02)
		(p_mundo as Node3D).add_child(q)
	var fx: Variant = p_mundo.get("_fx")
	if fx != null:
		(fx as Vfx3D).vapor(Lanzador3D.centro_de(c, Lanzador3D.alto_agua))
