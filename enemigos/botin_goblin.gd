class_name BotinGoblin
extends RefCounted

## ENVOLTORIO DE COMPATIBILIDAD (F1 de docs/PLAN_BASE_DATOS.md, 29/10). El botín de materiales del goblin (docs/MATERIALES_CUEVA.md: el colmillo, C4 de la Cueva) vivía aquí, con su
## probabilidad (60 %) y su `tirada_forzada`. Desde F1 lo reparte `Combate3D._morir` con `Botin.tirar("goblin")` (la fila `colmillo_goblin`, `independiente=si`, `peso=0.6` de
## `nucleo/datos/botin_tablas.tsv`) y el colmillo CAE AL SUELO como `BotinObjeto3D` en vez de ir directo a la bolsa. Esta clase se queda solo para que `prueba_materiales_cueva` (y quien
## llame a `soltar` a mano) siga funcionando:
##   · `tirada_forzada` ES `Botin.tirada_forzada` (se lee y se escribe ahí);
##   · `PROB_COLMILLO` y `MATERIAL` se mantienen (la prueba `prueba_botin` comprueba que coinciden con la tabla);
##   · `soltar` hace la tirada con `Botin.tirar("goblin")` y, como antes, da el colmillo DIRECTO a la bolsa con su aviso. NO lo llama ningún enemigo.

const MATERIAL: String = "colmillo_goblin"
const PROB_COLMILLO: float = 0.6             ## igual que la fila de la tabla `goblin` (lo comprueba prueba_botin)
const ALTURA_TEXTO: float = 0.9              ## u sobre el cuerpo donde sale el texto flotante

## Solo para las pruebas: >= 0 sustituye al azar en todas las tiradas (la misma variable que `Botin.tirada_forzada`). -1 = al azar.
static var tirada_forzada: float:
	get:
		return Botin.tirada_forzada
	set(v):
		Botin.tirada_forzada = v


## ¿Gana esta tirada (0..1)? Pura, para poder medirla sin azar.
static func gana(tirada: float, probabilidad: float = PROB_COLMILLO) -> bool:
	return tirada < probabilidad


## Hace la tirada de la tabla `goblin` y, si sale el colmillo, lo da DIRECTO a la bolsa. Devuelve el id que se dio ("" si no salió o no cupo).
## `tirada` >= 0 fuerza esa tirada; < 0 = la forzada global o el azar.
static func soltar(mundo: Node3D, pos: Vector3, tirada: float = -1.0) -> String:
	var previa: float = Botin.tirada_forzada
	if tirada >= 0.0:
		Botin.tirada_forzada = tirada
	var lista: Array = Botin.tirar("goblin")
	Botin.tirada_forzada = previa
	var n: int = 0
	for it in lista:
		if String((it as Dictionary)["que"]) == MATERIAL:
			n += int((it as Dictionary)["n"])
	if n <= 0:
		return ""
	var lanz: Node = mundo.get_tree().get_first_node_in_group("spellcaster") if mundo != null and mundo.is_inside_tree() else null
	var entra: int = Estado.i().agregar(MATERIAL, n)
	if entra <= 0:
		if lanz != null and lanz.has_method("avisar"):
			lanz.call("avisar", "Mochila llena")
		return ""
	AvisoObjeto.mostrar(lanz, MATERIAL, entra)
	if mundo != null:
		Combate3D.flotante(mundo, pos + Vector3(0.0, ALTURA_TEXTO, 0.0), AvisoObjeto.texto(MATERIAL, entra), Objetos.color_calidad(MATERIAL))
	return MATERIAL
