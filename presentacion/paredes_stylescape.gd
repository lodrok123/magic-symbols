extends RefCounted
## MUROS FINOS DE RUINA CON EL PACK «Stylescape: Ruins» (Fab, 25/11/2026). Con `estilo = "ruinas"` (PruebaTest2), cada casilla `#` que toca
## suelo (también en diagonal) se viste con muros del pack de 0,5 m (0,29 u) que van por el EJE de la casilla, en vez del árbol del bosque.
## La casilla sigue bloqueada entera (igual que antes); solo cambia lo que se ve: el muro ocupa una sexta parte y la sala respira.
## Lo usan los mapas del GENERADOR (estilo «Ruinas») y el laboratorio LabStylescape (tecla 4). Sin `class_name`: se carga con preload.
##
## Cómo decide (`muros(c, es_suelo, es_muro, y)`):
##   · une la casilla con cada vecina `#` (N, S, E, O) que también se viste, pero SOLO si ese tramo tiene suelo a algún lado (si no, dos
##     anillos de muro pegados se cosían con muros cruzados);
##   · recto (solo E+O o solo N+S) = un tramo entero de 4 m (una casilla); si dobla, acaba o se cruza = medios tramos de 2 m y un POSTE
##     en el centro que tapa la junta; una casilla suelta = un poste;
##   · un tramo horizontal con suelo al norte es la pared SUR de una sala (la que queda entre la cámara y la sala): va BAJA
##     (1,5 m) para no tapar el interior. El resto, alto (3 m), con ventanas y desperfectos al azar (estable por casilla).
## Las piezas (arte/stylescape/piezas/ss_*.tscn) las crea herramientas/generar_piezas_stylescape.gd con el material horneado al beige de
## nuestros muros; el musgo de arriba lo pone la maqueta (`musgo_ruina` del shader común). Si el pack no está generado, se salta.

const RUTA: String = "res://arte/stylescape/piezas/"
const S: float = 2.3

## Tramos de 4 m (una casilla) y de 2 m (media), altos y bajos. Nombres de malla del pack: la pieza es "ss_" + nombre en minúsculas.
const ALTOS_4: Array = ["SM_Wall_04", "SM_Wall_Dmg_02", "SM_Wall_Windows_01", "SM_Wall_Dmg_04", "SM_Wall_Dmg_03", "SM_Wall_04"]
const ALTOS_2: Array = ["SM_Wall_02", "SM_Wall_Dmg_03_Alt", "SM_Wall_Dmg_04_Alt", "SM_Wall_Windows_Half", "SM_Wall_02"]
const BAJOS_4: Array = ["SM_Wall_Half_04"]      ## (SM_Wall_Dmg_02_Half_01 mide 3 m, no una casilla: fuera)
const BAJOS_2: Array = ["SM_Wall_Half_02", "SM_Wall_Dmg_03_Half_01", "SM_Wall_Dmg_04_Half_02"]
const POSTE_ALTO: String = "SM_Wall_01_Corner"
const POSTE_BAJO: String = "SM_Wall_Half_Corner"
## Todas las mallas que usa (el generador de piezas las crea).
const TODAS: Array = ["SM_Wall_04", "SM_Wall_Dmg_02", "SM_Wall_Windows_01", "SM_Wall_Dmg_04", "SM_Wall_Dmg_03",
	"SM_Wall_02", "SM_Wall_Dmg_03_Alt", "SM_Wall_Dmg_04_Alt", "SM_Wall_Windows_Half",
	"SM_Wall_Half_04", "SM_Wall_Half_02", "SM_Wall_Dmg_03_Half_01", "SM_Wall_Dmg_04_Half_02",
	"SM_Wall_01_Corner", "SM_Wall_Half_Corner"]

const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]      ## E, O, S, N
const OCHO: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


static func id_de(malla: String) -> String:
	return "ss_" + malla.to_lower().trim_prefix("sm_")


## ¿Está el pack generado en esta máquina?
static func disponible() -> bool:
	return ResourceLoader.exists(RUTA + id_de("SM_Wall_04") + ".tscn")


## ¿Se viste esta casilla de muro? (toca suelo en alguna de las 8 direcciones)
static func se_viste(c: Vector2i, es_suelo: Callable, es_muro: Callable) -> bool:
	if not es_muro.call(c):
		return false
	for d in OCHO:
		if es_suelo.call(c + d):
			return true
	return false


## Las piezas de la casilla de muro `c`: Array de [id, Transform3D] (origen = base de la pieza, en el centro de la casilla).
## `es_suelo` y `es_muro` son Callable(Vector2i) -> bool; `y` es la altura del suelo (ALTO de la maqueta).
static func muros(c: Vector2i, es_suelo: Callable, es_muro: Callable, y: float) -> Array:
	var res: Array = []
	if not se_viste(c, es_suelo, es_muro):
		return res
	var une: Array = []        ## por dirección: [une, bajo]
	for d in DIRS:
		var otra: Vector2i = c + d
		var u: bool = se_viste(otra, es_suelo, es_muro) and _tramo_con_suelo(c, d, es_suelo)
		une.append([u, u and _es_bajo(c, d, es_suelo)])
	var centro := Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)
	var h: int = _hash(c, 1)
	var e: bool = une[0][0]
	var o: bool = une[1][0]
	var s: bool = une[2][0]
	var n: bool = une[3][0]
	if e and o and not s and not n:
		var bajo: bool = une[0][1] or une[1][1]
		res.append([id_de(_de(BAJOS_4 if bajo else ALTOS_4, h)), _xf(centro, 0.0, h)])
	elif s and n and not e and not o:
		res.append([id_de(_de(ALTOS_4, h)), _xf(centro, 90.0, h)])
	else:
		var todos_bajos: bool = true
		for i in range(4):
			if not une[i][0]:
				continue
			var d: Vector2i = DIRS[i]
			var bajo2: bool = une[i][1]
			todos_bajos = todos_bajos and bajo2
			var mitad: Vector3 = centro + Vector3(float(d.x), 0.0, float(d.y)) * S * 0.25
			res.append([id_de(_de(BAJOS_2 if bajo2 else ALTOS_2, h + i * 7)), _xf(mitad, 0.0 if d.y == 0 else 90.0, h + i)])
		res.append([id_de(POSTE_BAJO if todos_bajos and res.size() > 0 else POSTE_ALTO), Transform3D(Basis.IDENTITY, centro)])
	return res


## El tramo de `c` hacia `d` tiene suelo a un lado (en `c` o en la vecina, a cualquiera de los dos costados).
static func _tramo_con_suelo(c: Vector2i, d: Vector2i, es_suelo: Callable) -> bool:
	var lado := Vector2i(d.y, d.x)       # perpendicular
	for p in [c, c + d]:
		if es_suelo.call(p + lado) or es_suelo.call(p - lado):
			return true
	return false


## Tramo horizontal con suelo al norte (y-1): pared sur de una sala, delante de la cámara. También si al sur hay otra sala (muro compartido):
## para la sala de arriba sigue estando delante (25/11: con «solo al norte» el muro entre dos salas salía alto y tapaba la de arriba).
static func _es_bajo(c: Vector2i, d: Vector2i, es_suelo: Callable) -> bool:
	if d.y != 0:
		return false
	return es_suelo.call(c + Vector2i(0, -1)) or es_suelo.call(c + d + Vector2i(0, -1))


## Las piezas están hechas con lo largo en X; 0 = a lo largo de X, 90 = a lo largo de Z. Media vuelta al azar para variar la cara.
static func _xf(pos: Vector3, giro: float, h: int) -> Transform3D:
	var g: float = giro + (180.0 if (h >> 3) % 2 == 0 else 0.0)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(g)), pos)


static func _de(lista: Array, h: int) -> String:
	return String(lista[absi(h) % lista.size()])


static func _hash(c: Vector2i, sal: int) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ (sal * 83492791))
