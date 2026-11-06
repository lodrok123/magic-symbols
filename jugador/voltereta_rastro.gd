## C6 · Voltereta con rastro (docs/PROPUESTAS_COMBATE_2026-11-06.md §2 bloque C; Wizard of Legend, Ignition Rush).
## Con una página de fuego, hielo o agua SELECCIONADA, rodar deja en la casilla de la que sales el estado de ese elemento.
##
## Por qué es un módulo aparte: `jugador_3d.gd` ya es enorme y esta regla se prueba sin jugadora (`herramientas/prueba_voltereta_rastro.gd`).
## No hay tabla propia de estados: el rastro es EL MISMO impacto que un hechizo sobre esa casilla (`Lanzador3D.marcar_celda`: maqueta + `Mundo3D.aplicar_accion`),
## así que `EstadosSuelo3D.puede_prender` (materiales de B4: el fuego no prende roca ni agua), la altura y el filtro de agua/hielo en altura se respetan solos.
class_name VolteretaRastro
extends RefCounted

## Tinta que cuesta dejar el rastro. Sin ella (la barra, sin gastar frascos) no hay rastro y no se cobra: una voltereta de huida no debe vaciar un frasco a escondidas.
const TINTA_RASTRO: float = 4.0

## Elemento de la página -> elemento que se deja en el suelo. Los derivados (rayo, naturaleza, magma) y viento/tierra no dejan rastro de momento: ampliar aquí.
const RASTRO_DE: Dictionary = {"fuego": "fuego", "hielo": "hielo", "agua": "agua"}

const ROTULO_DE: Dictionary = {"fuego": "Rastro de fuego", "hielo": "Rastro de hielo", "agua": "Rastro de agua"}
const COLOR_DE: Dictionary = {"fuego": Color(1.0, 0.45, 0.2), "hielo": Color(0.6, 0.9, 1.0), "agua": Color(0.35, 0.65, 1.0)}


## Elemento de la página seleccionada del lanzador ("" si no tiene o el lanzador no existe). Duck typing: `Grimorio.page` + `page_element_data`
## (devuelve el DERIVADO si la pareja de sellos reacciona: una página fuego+tierra es magma y no deja rastro, que es lo previsto).
static func elemento_seleccionado(lanz: Object) -> String:
	if lanz == null or not lanz.has_method("page_element_data"):
		return ""
	var rune: RuneData = lanz.call("page_element_data", int(lanz.get("page"))) as RuneData
	return Objetos.elemento_de(rune)


## Intenta dejar el rastro en la casilla `c`. Devuelve el elemento dejado, o "" si no hubo rastro (y entonces NO se ha cobrado nada).
## No hay rastro si: el elemento no está en `RASTRO_DE`, falta tinta, o el impacto no cambiaría nada en esa casilla (`ReaccionesSuelo3D.prever`:
## fuego sobre roca o tierra seca, casilla bloqueada…). Así no se paga por un rastro que no se ve.
static func dejar(lanz: Object, tinta: Tinta, c: Vector2i) -> String:
	var elemento: String = String(RASTRO_DE.get(elemento_seleccionado(lanz), ""))
	if elemento == "" or tinta == null or not Terreno3D.en_mapa(c):
		return ""
	if tinta.actual + 1e-4 < TINTA_RASTRO:
		return ""                                   # sin frascos: `Tinta.gastar` vaciaría uno si la barra no llega
	if ReaccionesSuelo3D.prever(elemento, c).is_empty():
		return ""
	if not tinta.gastar("rastro", TINTA_RASTRO):
		return ""
	lanz.call("marcar_celda", elemento, c)
	if lanz.has_method("avisar"):
		lanz.call("avisar", String(ROTULO_DE[elemento]), COLOR_DE[elemento])
	return elemento
