class_name NombreHechizo
extends RefCounted

## H16 · NOMBRE DE CADA HECHIZO (22/11, docs/PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md §H16; PLAN_HECHIZOS, junto a B5). Lo escribe la sesión HECHIZOS.
## El nombre AUTOMÁTICO de una página sale de su receta, no de una tabla de recetas: FORMA + ELEMENTO + UN RASGO, corto (dos o tres palabras más el «de»).
##   · forma: del perfil que ya decide la previsión del casteo (`PrevisionCasteo3D.perfil`): flecha → «Flecha», barrera local → «Escudo», barrera con flecha → «Muro que avanza»,
##     haz → «Chorro», suelo → «Trampa» o «Plataforma», órbita → «Orbes», bloque colocado → «Muro», el resto → «Esfera».
##   · elemento: «de fuego», «de agua», «de tierra»… (el `elemento` del Hechizo).
##   · rasgo: el primero que se cumpla de: copias → «doble»/«triple»; vuelve (ᛃ) → «que vuelve»; pulso ᚱ → «que pulsa»; alcance (2 o más ᛇ) → «largo»; altura o crecer → «grande».
##     Concuerda en género y número con la forma («Flecha larga», «Orbes que vuelven»).
## Si la jugadora pone el suyo (`Grimorio.renombrar_pagina`), manda el suyo; vacío vuelve al automático.

const LARGO_MAX: int = 18                         ## caracteres que admite un nombre propio
const ALCANCE_UNA_FLECHA: float = 2.0             ## `distancia_max` con un solo ᛇ: a partir de ahí es «largo»

## forma -> [texto, género («m»/«f»), plural]
const FORMAS: Dictionary = {
	"proyectil": ["Flecha", "f", false],
	"proteccion": ["Escudo", "m", false],
	"volumen_movil": ["Muro", "m", false],
	"haz": ["Chorro", "m", false],
	"trampa": ["Trampa", "f", false],
	"plataforma": ["Plataforma", "f", false],
	"orbita": ["Orbes", "m", true],
	"colocado": ["Muro", "m", false],
	"area": ["Esfera", "f", false],
}

const ELEMENTOS: Dictionary = {"fuego": "fuego", "agua": "agua", "tierra": "tierra", "viento": "viento", "rayo": "rayo", "hielo": "hielo",
	"magma": "magma", "naturaleza": "naturaleza"}


## El nombre automático de un hechizo ("" si no hay hechizo o no tiene elemento: página vacía).
static func automatico(h: Hechizo) -> String:
	if h == null or h.elemento == "":
		return ""
	var clave: String = forma_de(h)
	var f: Array = FORMAS.get(clave, FORMAS["area"])
	var texto: String = "%s de %s" % [String(f[0]), String(ELEMENTOS.get(h.elemento, h.elemento))]
	var rasgo: String = "que avanza" if clave == "volumen_movil" else rasgo_de(h, String(f[1]), bool(f[2]), clave)
	return texto if rasgo == "" else "%s %s" % [texto, rasgo]


## La forma, con el perfil de la previsión del casteo; el suelo se parte en trampa o plataforma, y la protección colocada (un bloque) es «colocado».
static func forma_de(h: Hechizo) -> String:
	var p: String = PrevisionCasteo3D.perfil(h)
	if p == "suelo":
		return "plataforma" if h.es_plataforma_tierra() or h.elemento == "tierra" or h.elemento == "hielo" else "trampa"
	if p == "colocado" and h.solidez <= 0.0:
		return "area"
	var sg: Vector3 = h.semiejes_glifos          # 23/11: lo que dieron los glifos (el escudo base de la barrera no cuenta: sola sigue siendo «Escudo»)
	if p == "proteccion" and maxf(sg.x, maxf(sg.y, sg.z)) > Sigils.RADIO_BASE_V2 + 0.001:
		return "colocado"                        # barrera con ejes (ᛁ, ᛏ): un muro, no el escudo de la barrera sola
	return p


## El rasgo, concordado. "" si no hay ninguno.
static func rasgo_de(h: Hechizo, genero: String, plural: bool, forma: String = "") -> String:
	if h.copias > 1 and forma != "orbita":
		var r: String = "doble" if h.copias == 2 else "triple"
		return r + ("s" if plural else "")
	if h.retorna and forma != "orbita":
		return "que vuelven" if plural else "que vuelve"
	if h.resuena > 0.0:
		return "que pulsan" if plural else "que pulsa"
	if h.viaja and h.distancia_max > ALCANCE_UNA_FLECHA + 0.001:
		return ("largas" if plural else "larga") if genero == "f" else ("largos" if plural else "largo")
	if h.semiejes_glifos.y > Sigils.RADIO_BASE_V2 + 0.001 or h.crece > 0.0:       # 23/11: la altura de los glifos (no el alto base del escudo)
		return "grandes" if plural else "grande"
	return ""


## Un nombre propio limpio: sin espacios a los lados y con `LARGO_MAX` caracteres como mucho. "" = no hay nombre propio (vuelve el automático).
static func limpiar(texto: String) -> String:
	return texto.strip_edges().substr(0, LARGO_MAX).strip_edges()
