class_name Lanzables
extends RefCounted

## LANZABLES (10/11, Juego; docs/PROPUESTA_CONSUMIBLES.md §2 y §8, primera tanda): los objetos de `uso = lanzar` de `objetos.tsv`. Se eligen en la rueda
## (`Estado.rueda`, la rellena la mochila) y la G lanza el elegido en arco hacia el ratón (`Jugador3D._lanzar_objeto` crea un `Lanzable3D`). Al caer, `aplicar`
## hace lo que diga su `efecto`:
##   lanza=luz     ilumina la casilla (`Mundo3D.iluminar`, estado de zona `oscuridad`) `dura` s y deja una luz visible ese rato
##   lanza=fuego   el mismo impacto de fuego que un hechizo en esa casilla (`Lanzador3D.impacto_filtrado`: suelo, hierba, agua) + los objetos de la casilla
##                 reaccionan como a un hechizo de fuego (`on_spell_hit`, la Materia del fuego) + `dano` a los enemigos de la casilla
##   lanza=hielo   lo mismo con hielo: hiela el agua de la casilla y lo que se hiela con hielo
##   lanza=rayo    lo mismo con rayo (electrifica lo mojado, activa lo que se activa con rayo) + `dano` a los enemigos Y a la jugadora si está a menos de
##                 RADIO_PROPIO u (es el riesgo del fruto chispa)
## No gasta tinta ni pide glifos: es un hechizo de una casilla, sin más. Gasta UNA unidad de la mochila al lanzarlo (`lanzar`).
## El límite es la pila del objeto (5): «pila o tarros» sigue por decidir (§8).

const ALCANCE_CASILLAS: float = 6.0   ## casillas máximas de un lanzamiento (Terreno3D.casilla = 2,3 u: unas 14 u)
const ALCANCE_MIN_CASILLAS: float = 1.0   ## casillas mínimas: más cerca, cae a esta distancia en la dirección del ratón
const VEL: float = 16.0               ## u/s en el plano: un lanzamiento a 6 casillas tarda ~0,9 s
const ALTO_ARCO: float = 2.0          ## u que sube el arco en su punto más alto
const RADIO_ENEMIGO_CASILLAS: float = 0.6   ## casillas (en el plano) a las que el impacto alcanza a un enemigo: su casilla y poco más
const RADIO_PROPIO_CASILLAS: float = 1.45   ## casillas a las que el rayo del fruto chispa alcanza a la jugadora: tu casilla y las ocho de alrededor (la diagonal mide 1,41)
const LUZ_ENERGIA: float = 1.6
const LUZ_ALCANCE_CASILLAS: float = 3.0     ## lo mismo que cuenta `Mundo3D.iluminada` (`ilumina_casillas` de la oscuridad)
const RUNAS: Dictionary = {
	"fuego": "res://nucleo/fire_rune.tres",
	"hielo": "res://nucleo/ice_rune.tres",
	"rayo": "res://nucleo/lightning_rune.tres",
}


## Lo que hace `id` al caer ("" si no es un lanzable o no tiene `lanza`).
static func efecto(id: String) -> String:
	return String(Objetos.efecto(id).get("lanza", "")) if Objetos.es_lanzable(id) else ""


## Por qué no se puede lanzar `id` ahora ("" = se puede).
static func motivo_no(id: String, e: Estado = null) -> String:
	var est: Estado = e if e != null else Estado.i()
	if id == "":
		return "La rueda no tiene nada elegido"
	if not Objetos.es_lanzable(id):
		return "Eso no se lanza"
	if est.cuenta(id) <= 0:
		return "No te quedan"
	return ""


## Dónde cae un lanzamiento desde `desde` hacia `hacia`: a lo sumo ALCANCE u y al menos ALCANCE_MIN, al centro de su casilla y a la altura de su suelo.
static func destino(desde: Vector3, hacia: Vector3) -> Vector3:
	var d: Vector3 = hacia - desde
	d.y = 0.0
	var largo: float = clampf(d.length(), ALCANCE_MIN_CASILLAS * Terreno3D.casilla, ALCANCE_CASILLAS * Terreno3D.casilla)
	var dir: Vector3 = d.normalized() if d.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
	var p: Vector3 = desde + dir * largo
	var c: Vector2i = Terreno3D.celda_de(p)
	var y: float = Terreno3D.y_pies(c) if Terreno3D.en_mapa(c) else desde.y
	return Terreno3D.centro_de(c, y)


## Gasta una unidad de `id` y lo lanza desde `desde` hacia `hacia` (crea el `Lanzable3D` en `mundo`). Devuelve el proyectil, o null si no se pudo.
static func lanzar(mundo: Node3D, lanz: Node, jugador: Node3D, id: String, desde: Vector3, hacia: Vector3, e: Estado = null) -> Lanzable3D:
	var est: Estado = e if e != null else Estado.i()
	if mundo == null or motivo_no(id, est) != "" or not est.quitar(id):
		return null
	var p := Lanzable3D.new()
	p.objeto = id
	p.lanz = lanz
	p.jugador = jugador
	p.desde = desde
	p.hasta = destino(desde, hacia)
	mundo.add_child(p)
	PlayLog.event("lanzable", {"objeto": id, "celda": [Terreno3D.celda_de(p.hasta).x, Terreno3D.celda_de(p.hasta).y]})
	return p


## Lo que pasa al caer `id` en `punto`. Devuelve {efecto, objetos (cuántos reaccionaron), enemigos (cuántos recibieron daño), jugadora (si la alcanzó)}.
static func aplicar(arbol: SceneTree, lanz: Node, jugador: Node3D, id: String, punto: Vector3) -> Dictionary:
	var ef: Dictionary = Objetos.efecto(id)
	var tipo: String = efecto(id)
	var res: Dictionary = {"efecto": tipo, "objetos": 0, "enemigos": 0, "jugadora": false}
	var c: Vector2i = Terreno3D.celda_de(punto)
	match tipo:
		"luz":
			Mundo3D.iluminar(c, float(ef.get("dura", 60.0)))
		"fuego", "hielo", "rayo":
			if lanz != null and lanz.has_method("impacto_filtrado"):
				lanz.call("impacto_filtrado", tipo, punto)
			else:
				Mundo3D.aplicar_accion(AccionElemental.nueva(tipo, punto))
			res["objetos"] = _objetos(arbol, tipo, c)
			var dano: float = float(ef.get("dano", 0.0))
			if dano > 0.0:
				res["enemigos"] = _danar_enemigos(arbol, punto, dano)
			if tipo == "rayo" and jugador != null and is_instance_valid(jugador):
				var d: Vector3 = jugador.global_position - punto
				d.y = 0.0
				if d.length() <= RADIO_PROPIO_CASILLAS * Terreno3D.casilla:
					res["jugadora"] = true
					if jugador.has_method("aplicar_estado"):
						jugador.call("aplicar_estado", "rayo", 0.6)
					if dano > 0.0 and jugador.has_method("dano_ambiental"):
						jugador.call("dano_ambiental", dano, "rayo")
		_:
			return res
	return res


## Los objetos de la casilla reaccionan como a un hechizo de `elemento` (`on_spell_hit` con la runa de ese elemento: la Materia hace el resto). Se mira TODO lo que
## cuelga de la escena y sabe recibir un hechizo (reactivos, barriles, colmenas, nidos, lava, cristales...): un lanzamiento es raro, recorrer el árbol una vez no pesa.
## Los enemigos no: a ellos les llega `dano` aparte.
static func _objetos(arbol: SceneTree, elemento: String, c: Vector2i) -> int:
	if arbol == null or arbol.root == null or not RUNAS.has(elemento):
		return 0
	var runa: RuneData = load(String(RUNAS[elemento])) as RuneData
	var n: int = 0
	for o in arbol.root.find_children("*", "Node3D", true, false):
		if not is_instance_valid(o) or not o.has_method("on_spell_hit") or o.is_in_group("combate3d") or o is Lanzable3D:
			continue
		if Terreno3D.celda_de((o as Node3D).global_position) != c:
			continue
		# Unos piden (runa, dirección) y otros además el Hechizo: se llama con los que admita.
		if o.get_method_argument_count("on_spell_hit") >= 3:
			o.call("on_spell_hit", runa, Vector3.ZERO, null)
		else:
			o.call("on_spell_hit", runa, Vector3.ZERO)
		n += 1
	return n


static func _danar_enemigos(arbol: SceneTree, punto: Vector3, dano: float) -> int:
	if arbol == null:
		return 0
	var n: int = 0
	for e in arbol.get_nodes_in_group("combate3d"):
		if not is_instance_valid(e) or not (e is Node3D) or bool(e.get("muerto")):
			continue
		var d: Vector3 = (e as Node3D).global_position - punto
		d.y = 0.0
		if d.length() > RADIO_ENEMIGO_CASILLAS * Terreno3D.casilla:
			continue
		if e.has_method("receive_damage"):
			e.call("receive_damage", dano)
			n += 1
	return n
