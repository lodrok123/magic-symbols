class_name GolpeCuerpo
extends RefCounted

## C1 · GOLPE CUERPO A CUERPO de la jugadora (28/10; docs/PROPUESTA_COMBATE.md §2 y §7). Pablo: «No gasta tinta; debe ser un golpe débil pero que empuje mucho.»
## Tecla F (la pone `Jugador3D._gestionar_acciones`; aquí vive la zona de impacto y lo que le pasa a cada cosa que cae dentro).
##
## LA ZONA: un cono delante de la jugadora (hacia `_mirada`), `ALCANCE_CASILLAS` de largo MEDIDO HASTA EL BORDE de lo que toca (centro − radio de la pieza) y `ANGULO` grados de
## ancho TOTAL. Toca a TODO lo que haya dentro, a la vez:
##   · enemigos (`Combate3D`, grupo «combate3d»):  `recibir_golpe_cuerpo` (daño `DANO`, sin debilidades, y empujón fuerte `EMPUJE` por la reacción `empujado` de siempre);
##   · rompibles (jarrón, caja): `golpear()`;
##   · bloques empujables: UNA casilla en la dirección cardinal del golpe (`empujar`), con su perfil de peso; el hielo resbala como con el viento;
##   · el resto (placas, fuegos, agua, plantas, palancas…): nada. El golpe no enciende ni moja.
## No ve a través de las paredes de verdad: solo cuenta que el centro de la pieza esté dentro del cono y a ≤ `ALTO_MAX` de diferencia de altura.

const DUR: float = 0.45                  ## s que dura el golpe entero (anticipación + impacto + recuperación); no se anda mientras
const CD: float = 0.8                    ## s desde que se pulsa F hasta poder volver a golpear
const ALCANCE_CASILLAS: float = 1.0      ## casillas de largo, hasta el borde de lo golpeado
const ANGULO: float = 70.0               ## grados de ancho TOTAL del cono
const ALTO_MAX: float = 1.2              ## u de diferencia de altura como mucho entre ella y lo golpeado
const DANO: float = 5.0                  ## débil a propósito: no usa debilidades ni elementos
## La fuerza que se pasa a `Combate3D.push` (con `suelo` = true). Medido con `prever_empuje` en suelo libre: un goblin recorre ≈ 2,2 casillas (5,1 u); ver prueba_golpe_cuerpo.
const EMPUJE: float = 5000.0
const FACTOR_ESCUDO: float = 0.5         ## con un escudo ACTIVO de frente, el golpe se para en él: sin daño y con esta fracción del empuje
## Radio de cada tipo de pieza (u): el alcance se mide hasta su borde. El bloque ocupa una casilla entera (2,3 u): se cuenta medio lado, algo menos.
const RADIO_ENEMIGO: float = 0.32
const RADIO_ROMPIBLE: float = 0.45
const RADIO_BLOQUE: float = 0.9
const SONIDO: String = "clavar"          ## golpe seco existente (Sfx); con algo tocado suena además «dano» más grave
const SONIDO_TOCA: String = "dano"
const TEMBLOR: float = 0.12              ## intensidad (0-1) del temblor de cámara (Vfx3D.temblor, el mismo mecanismo que los golpes de hechizo)


## ¿Cae `p` (posición de una pieza de radio `radio`) dentro del cono de quien está en `origen` mirando a `mirada`?
static func en_cono(origen: Vector3, mirada: Vector3, p: Vector3, radio: float) -> bool:
	var m := Vector3(mirada.x, 0.0, mirada.z)
	var v := Vector3(p.x - origen.x, 0.0, p.z - origen.z)
	if m.length() < 0.001:
		return false
	var d: float = v.length()
	if d - radio > ALCANCE_CASILLAS * Terreno3D.casilla:
		return false
	if absf(p.y - origen.y) > ALTO_MAX:
		return false
	if d <= radio + 0.25:
		return true                                    # pegada al cuerpo: el ángulo ya no tiene sentido
	return rad_to_deg(m.angle_to(v)) <= ANGULO * 0.5


## La dirección cardinal (±X o ±Z) más cercana a `mirada`.
static func cardinal(mirada: Vector3) -> Vector2i:
	if absf(mirada.x) >= absf(mirada.z):
		return Vector2i(1 if mirada.x >= 0.0 else -1, 0)
	return Vector2i(0, 1 if mirada.z >= 0.0 else -1)


## Lo que hay dentro del cono, SIN tocarlo: {enemigos: [Combate3D], rompibles: [Rompible3D], bloques: [BloqueEmpujable3D]}.
static func objetivos(arbol: SceneTree, origen: Vector3, mirada: Vector3) -> Dictionary:
	var r: Dictionary = {"enemigos": [], "rompibles": [], "bloques": []}
	for n in arbol.get_nodes_in_group("combate3d"):
		var c := n as Combate3D
		if c != null and is_instance_valid(c) and not c.muerto and en_cono(origen, mirada, c.global_position, RADIO_ENEMIGO):
			(r["enemigos"] as Array).append(c)
	for n in arbol.get_nodes_in_group("rompible"):
		var o := n as Rompible3D
		if o != null and is_instance_valid(o) and not o.roto_ya and en_cono(origen, mirada, o.global_position, RADIO_ROMPIBLE):
			(r["rompibles"] as Array).append(o)
	for n in arbol.get_nodes_in_group("empujable"):
		var b := n as BloqueEmpujable3D
		if b != null and is_instance_valid(b) and en_cono(origen, mirada, b.global_position, RADIO_BLOQUE):
			(r["bloques"] as Array).append(b)
	return r


## Da el golpe: aplica a todo lo del cono lo que le toca y devuelve un resumen {enemigos, escudos, rompibles, bloques, hundira…} (lo que se apunta en el PlayLog).
## `jugador` pone el origen (sus pies) y el árbol; `mirada` la dirección del golpe.
static func impactar(jugador: Node3D, mirada: Vector3) -> Dictionary:
	var dir := Vector3(mirada.x, 0.0, mirada.z).normalized()
	var res: Dictionary = {"enemigos": 0, "escudos": 0, "rompibles": 0, "bloques": 0, "movidos": 0}
	if dir.length() < 0.5 or not jugador.is_inside_tree():
		return res
	var ob: Dictionary = objetivos(jugador.get_tree(), jugador.global_position, dir)
	for c in ob["enemigos"]:
		var rc: Dictionary = (c as Combate3D).recibir_golpe_cuerpo(dir, DANO, EMPUJE, FACTOR_ESCUDO)
		res["enemigos"] = int(res["enemigos"]) + 1
		if bool(rc.get("escudo", false)):
			res["escudos"] = int(res["escudos"]) + 1
	for o in ob["rompibles"]:
		(o as Rompible3D).golpear(jugador.global_position)
		res["rompibles"] = int(res["rompibles"]) + 1
	var cd: Vector2i = cardinal(dir)
	for b in ob["bloques"]:
		res["bloques"] = int(res["bloques"]) + 1
		if (b as BloqueEmpujable3D).empujar(cd, false):
			res["movidos"] = int(res["movidos"]) + 1
	# Sonido y temblor: el golpe seco siempre; el temblor y el «dano» solo si tocó algo.
	var toco: bool = int(res["enemigos"]) + int(res["rompibles"]) + int(res["bloques"]) > 0
	Sfx.play(jugador, SONIDO, 0.85)                # más grave que el clavar de siempre: un golpe seco
	if toco:
		Sfx.play(jugador, SONIDO_TOCA)
		var fx: Variant = (jugador.get("mundo") as Object).get("_fx") if jugador.get("mundo") != null else null
		if fx is Vfx3D:
			(fx as Vfx3D).temblor(TEMBLOR)
	return res
