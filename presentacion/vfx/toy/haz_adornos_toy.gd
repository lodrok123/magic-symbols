extends RefCounted

## ADORNOS DEL HAZ DE FUEGO Y DE AGUA (25/11/2026, revisión del haz con Laser01 / Laser02 de Effekseer). En el juego el chorro lo dibuja el gas (HazGasJuego); esto pone,
## con las piezas de los impactos (ImpactoCapasToy: halo, sprites de Le Lu con la rampa del elemento, chispas, gotas, humo toon), lo que el gas no tiene:
##   · BOQUILLA (en la mano): un FOGONAZO al soltar (Laser02: Charge / Laser01: LaserCore) y, mientras vive, lenguas cortas de llama (fuego) o rocío y vaho (agua) que unen la
##     mano con el chorro: el gas empieza fino y transparente cerca de la boquilla y el haz parecía salir de delante de la jugadora.
##   · PUNTA (donde la lógica dice que choca con un MURO): mientras vive, chispas, llamas y un brillo (fuego) o salpicadura y espuma (agua) contra la cara (Laser02: Burst).
## Duran lo que el haz (`vida`) y se liberan solos. Uso: HazAdornosToy.poner(padre, hz, elemento, vida, suelo)

const ImpactoCapasToy = preload("res://presentacion/vfx/toy/impacto_capas_toy.gd")
const RADIO: float = 0.4                     ## los tamaños de las recetas están en m para este radio (el de ImpactoCapasToy)
const MANO_ADELANTE: float = 0.3             ## m de los pies a la mano, a lo largo del haz


## `hueco`: m entre la mano y donde empieza el chorro (las lenguas / el rocío lo cubren).
static func receta_boquilla(elemento: String, vida: float, hueco: float = 0.6) -> Dictionary:
	var alt: float = (hueco * 0.5 + 0.1) / RADIO          # centro del tramo mano → chorro, en radios
	var disp: float = hueco * 0.5 / RADIO * 0.4             # repartidas a lo largo de ese tramo
	if elemento == "agua":
		return {"id": "haz_boquilla_agua", "capas": [
			{"pieza": "halo", "nombre": "fogonazo", "t0": 0.0, "vida": 0.12, "tam": [0.3, 0.9], "curva": "sal", "brillo": 0.8, "caida": 2.4, "altura": 0.5, "se_va": 0.08},
			{"pieza": "gotas", "nombre": "rocio", "n": maxi(int(vida * 40.0), 8), "t0": 0.0, "emision": vida, "vida": [0.25, 0.45], "cono": [0.75, 1.0], "vel": [2.5, 4.5], "g": 0.6,
				"roce": 0.8, "largo": [0.1, 0.2], "ancho": [0.05, 0.08], "h0": 0.1},
			{"pieza": "humo", "nombre": "vaho", "n": maxi(int(vida * 12.0), 3), "t0": 0.0, "emision": vida, "vida_media": 0.4, "tam": [0.12, 0.3], "vel": [1.5, 2.6],
				"cono": [0.85, 1.0], "h0": 0.1, "deriva": 0.1}]}
	return {"id": "haz_boquilla_fuego", "capas": [
		{"pieza": "halo", "nombre": "fogonazo", "t0": 0.0, "vida": 0.14, "tam": [0.3, 1.0], "curva": "sal", "brillo": 1.8, "caida": 2.4, "altura": 0.4, "se_va": 0.1},
		{"pieza": "sprite", "nombre": "estrella", "tex": "destello", "modo": "aditivo", "t0": 0.0, "vida": 0.1, "tam": [0.6, 0.2], "curva": "lineal", "brillo": 1.3,
			"tramo": Vector2(0.45, 0.85), "altura": 0.5, "se_va": 0.0},
		{"pieza": "sprite", "nombre": "lenguas", "tex": "bola", "modo": "mezcla", "n": clampi(int(vida * 22.0), 4, 24), "t0": 0.0, "emision": vida, "vida": [0.12, 0.22],
			"tam": [0.35, 0.6], "curva": "sal", "disperso": disp, "altura": alt, "tramo": Vector2(0.0, 0.55), "recorte": Vector2(0.24, 0.62), "luminancia": Vector2(0.2, 0.9), "se_va": 0.1},
		{"pieza": "chispas", "nombre": "chispas", "n": maxi(int(vida * 30.0), 6), "t0": 0.0, "emision": vida, "vida": [0.2, 0.4], "cono": [0.75, 1.0], "vel": [2.5, 4.5],
			"roce": 3.0, "g": 0.3, "largo": [0.2, 0.4], "ancho": [0.03, 0.05], "h0": 0.1}]}


static func receta_punta(elemento: String, vida: float) -> Dictionary:
	if elemento == "agua":
		return {"id": "haz_punta_agua", "capas": [
			{"pieza": "gotas", "nombre": "salpicadura", "n": maxi(int(vida * 50.0), 10), "t0": 0.05, "emision": vida, "vida": [0.35, 0.6], "cono": [0.2, 0.9], "vel": [2.5, 5.0],
				"g": 1.0, "roce": 0.6, "largo": [0.14, 0.26], "ancho": [0.07, 0.12], "h0": 0.1},
			{"pieza": "humo", "nombre": "espuma", "n": maxi(int(vida * 10.0), 3), "t0": 0.05, "emision": vida, "vida_media": 0.55, "tam": [0.3, 0.65], "vel": [0.6, 1.4],
				"cono": [0.3, 1.0], "h0": 0.15, "deriva": 0.2}]}
	return {"id": "haz_punta_fuego", "capas": [
		{"pieza": "halo", "nombre": "brillo", "t0": 0.05, "vida": vida, "tam": [0.8, 1.2], "curva": "suave", "brillo": 1.2, "caida": 2.2, "aparece": 0.08, "se_va": 0.2, "altura": 0.6},
		{"pieza": "chispas", "nombre": "chispas", "n": maxi(int(vida * 40.0), 8), "t0": 0.05, "emision": vida, "vida": [0.25, 0.5], "cono": [0.1, 1.0], "vel": [2.0, 4.5],
			"roce": 2.5, "g": 0.6, "brasas": 0.3, "largo": [0.2, 0.4], "ancho": [0.03, 0.05], "h0": 0.1},
		{"pieza": "sprite", "nombre": "llamas", "tex": "bola", "modo": "mezcla", "n": clampi(int(vida * 14.0), 3, 16), "t0": 0.05, "emision": vida, "vida": [0.2, 0.35],
			"tam": [0.3, 0.7], "curva": "sal", "disperso": 0.25, "altura": 0.6, "sube": 0.6, "tramo": Vector2(0.0, 0.55), "recorte": Vector2(0.24, 0.62),
			"luminancia": Vector2(0.2, 0.9), "se_va": 0.12}]}


## Pone la boquilla en `hz.desde` (mirando a lo largo del haz) y, si la lógica dice que choca con un muro, la punta en ese punto (mirando por su normal). Devuelve los nodos.
## `origen`: los pies de la jugadora (la lógica pone `hz.desde`, donde empieza el chorro, por delante de ella): la boquilla va en la MANO, a MANO_ADELANTE m de los pies.
static func poner(padre: Node, hz: Dictionary, elemento: String, vida: float, suelo: float, origen: Vector3 = Vector3.INF) -> Array:
	var r: Array = []
	if padre == null or not (elemento == "fuego" or elemento == "agua") or not hz.has("desde") or not hz.has("hasta"):
		return r
	var desde: Vector3 = hz["desde"]
	var hasta: Vector3 = hz["hasta"]
	var dir: Vector3 = Vector3(hasta.x - desde.x, 0.0, hasta.z - desde.z)
	if dir.length() < 0.01:
		return r
	dir = dir.normalized()
	var v: float = maxf(vida, 0.3)
	var mano: Vector3 = desde
	if origen != Vector3.INF:
		mano = Vector3(origen.x, desde.y, origen.z) + dir * MANO_ADELANTE
	var hueco: float = clampf(Vector2(desde.x - mano.x, desde.z - mano.z).dot(Vector2(dir.x, dir.z)), 0.0, 2.0) + 0.35      # + lo que el gas tarda en verse
	var b: Node3D = ImpactoCapasToy.crear(receta_boquilla(elemento, v, hueco), elemento, dir, RADIO)
	b.set("suelo_y", suelo)
	padre.add_child(b)
	b.global_position = mano
	r.append(b)
	for ch in (hz.get("choques", []) as Array):
		var c: Dictionary = ch
		if String(c.get("tipo", "")) != "muro":
			continue
		var n: Vector3 = c.get("normal", -dir)
		n = Vector3(n.x, 0.0, n.z).normalized() if Vector2(n.x, n.z).length() > 0.01 else -dir
		var p: Node3D = ImpactoCapasToy.crear(receta_punta(elemento, v), elemento, n, RADIO)
		p.set("suelo_y", suelo)
		padre.add_child(p)
		var punto: Vector3 = c["punto"]
		p.global_position = Vector3(punto.x, desde.y, punto.z)
		r.append(p)
		break
	return r
