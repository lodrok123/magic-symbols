class_name Dano
extends RefCounted

## DAÑO Y TINTA POR POTENCIA (29/10, decisión de Pablo; docs/DANO_Y_TINTA.md). EL ÚNICO SITIO donde se calcula cuánto daña un hechizo y cuánta tinta cuesta.
## Funciones estáticas puras: sin nodos, sin estado, sin leer el juego. Las usan `Hechizo` (daño base y coste en tinta), `Lanzador3D.Receta3D` (el coste antes de construir el hechizo),
## `Combate3D.decidir_golpe` y sus subclases (limo, gólem, chamán) y, por tanto, la previsión del indicador y los números flotantes.
##
## DAÑO (H3, decisión de Pablo): B sale del recuento OFENSIVO (`n_glifos_dano`: los glifos con `Sigils.cuenta_dano`; ᛁ y ᛏ no), con cortes propios: 1-2 ligera · 3-4 media · 5-6 alta
## (`nivel_dano`, GLIFOS_MEDIA_DANO / GLIFOS_ALTA_DANO). La TINTA sigue saliendo del nº TOTAL de glifos (`nivel`, cortes de abajo).
##
## POTENCIA (de la TINTA) = nº de glifos de la receta (los que el juego conoce; el elemento no cuenta): 0-1 ligera · 2-3 media · ≥4 alta (el libro admite 6, `Hechizo.MAX_GLIFOS`).
##
## DAÑO POR IMPACTO:  D = B × E × G × X × R   y después la defensa:  D_final = máx(SUELO_DEF · D, D − DEF)
##   B  daño base de la potencia (BASE)             E  multiplicador del elemento (MULT_ELEMENTO)
##   G  glifos con efecto propio sobre el impacto (`Hechizo.potencia`; hoy 1,0: ningún glifo lo toca, el gancho está listo)
##   X  la reacción (rayo sobre mojado ×1,5); hielo sobre mojado SUMA 15 (`suma_x`, dentro de R:  (B·E·G·X + suma) × R)
##   R  lo que le pasa a ESE enemigo con ese elemento: débil ×1,5 · resiste ×0,75 · gólem de pie 0 · núcleo expuesto ×1,5
##   DEF  defensa plana del enemigo. El suelo (20 % de D) impide que una defensa alta deje un golpe en 0: con DEF > D queda D × SUELO_DEF.
## El daño CONTINUO (quemadura, veneno, pulsos) pasa por R pero NO por DEF (`continuo`).
## HIELO y RAYO están APARCADOS: conservan su daño de siempre (`base_elemental` con `fija`) pero pasan por el mismo cálculo final (R y DEF), para que todos los enemigos lean igual.
##
## TINTA (H4):  T = (T_base(potencia) + Σ aporte_glifo) × (1 + recargo_instancias + recargo_periodico); `tinta_de(h)` / `desglose_tinta(h)`. Hoy solo cuesta el continuo ᚱ (`Sigils.COSTE_CONTINUO_V2`):
## aportes y K_* están a 0 hasta que Pablo ponga números. El nº de glifos entra únicamente por T_base: no hay doble conteo. La rebaja del pigmento (`Tinta.coste_efectivo`) se aplica encima, fuera de aquí.

const LIGERA: int = 0
const MEDIA: int = 1
const ALTA: int = 2
const NOMBRES: PackedStringArray = ["ligera", "media", "alta"]

## Cortes de potencia: glifos mínimos para ser media y alta.
const GLIFOS_MEDIA: int = 2
const GLIFOS_ALTA: int = 4

## Cortes del DAÑO sobre el recuento ofensivo (0-2 ligera · 3-4 media · ≥5 alta).
const GLIFOS_MEDIA_DANO: int = 3
const GLIFOS_ALTA_DANO: int = 5

## Por potencia [ligera, media, alta].
const BASE: Array = [12.0, 24.0, 40.0]           ## B: daño base
const TINTA_BASE: Array = [8.0, 18.0, 34.0]      ## T_base: tinta (la barra es de 100)

## E: multiplicador de cada elemento con tabla. Hielo y rayo NO están (aparcados): conservan su daño propio (`base_elemental` con `fija`).
## Propuesta para cuando se retomen (no aplicada): rayo ×1,00 y hielo ×0,90 sobre la misma tabla de B.
const MULT_ELEMENTO: Dictionary = {"fuego": 1.10, "agua": 0.80, "tierra": 1.15, "viento": 0.80}
const PROPUESTA_RAYO: float = 1.00
const PROPUESTA_HIELO: float = 0.90

## R genérico (la tabla de debilidades de cada enemigo vive en `Combate3D.multiplicador`).
const MULT_DEBIL: float = 1.5
const MULT_RESISTE: float = 0.75

## X: la reacción del rayo sobre un enemigo mojado, y lo que SUMA el hielo sobre un mojado.
const X_RAYO_MOJADO: float = 1.5
const SUMA_HIELO_MOJADO: float = 15.0

## Suelo de la defensa: fracción de D que siempre pasa.
const SUELO_DEF: float = 0.2

## DEF por tipo de enemigo (Combate3D la lee como atributo `defensa`).
const DEF_LIMO: float = 0.0
const DEF_CHAMAN: float = 0.0
const DEF_GOBLIN: float = 2.0          ## guerrero sin escudo, arquero y asesino
const DEF_ESCUDO: float = 5.0          ## el guerrero que lleva escudo (`Escudo3D.equipar`)
const DEF_ELEMENTAL: float = 6.0
const DEF_GOLEM: float = 10.0


## Nivel de potencia (LIGERA, MEDIA, ALTA) de un hechizo con `n_glifos` glifos.
static func nivel(n_glifos: int) -> int:
	if n_glifos >= GLIFOS_ALTA:
		return ALTA
	if n_glifos >= GLIFOS_MEDIA:
		return MEDIA
	return LIGERA


static func nombre_nivel(n_glifos: int) -> String:
	return NOMBRES[nivel(n_glifos)]


## Nivel de DAÑO (LIGERA, MEDIA, ALTA) de un hechizo con `n_glifos_dano` glifos ofensivos.
static func nivel_dano(n_glifos_dano: int) -> int:
	if n_glifos_dano >= GLIFOS_ALTA_DANO:
		return ALTA
	if n_glifos_dano >= GLIFOS_MEDIA_DANO:
		return MEDIA
	return LIGERA


static func nombre_nivel_dano(n_glifos_dano: int) -> String:
	return NOMBRES[nivel_dano(n_glifos_dano)]


## ¿Tiene este elemento tabla de potencia? (fuego, agua, tierra, viento; hielo y rayo, no)
static func tiene_tabla(elemento: String) -> bool:
	return MULT_ELEMENTO.has(elemento)


## E del elemento (1 si no tiene tabla).
static func mult_elemento(elemento: String) -> float:
	return float(MULT_ELEMENTO.get(elemento, 1.0))


## B del daño que dan `n_glifos_dano` glifos ofensivos.
static func base_dano(n_glifos_dano: int) -> float:
	return float(BASE[nivel_dano(n_glifos_dano)])


## B × E (B según el recuento ofensivo). Para un elemento sin tabla (hielo, rayo) devuelve `fija` (su daño de siempre) si es ≥ 0, y B × 1 si no hay `fija`.
static func base_elemental(n_glifos_dano: int, elemento: String, fija: float = -1.0) -> float:
	if tiene_tabla(elemento):
		return base_dano(n_glifos_dano) * mult_elemento(elemento)
	if fija >= 0.0:
		return fija
	return base_dano(n_glifos_dano)


## La defensa: máx(SUELO_DEF · D, D − DEF). Un daño ≤ 0 se queda en 0 (el gólem de pie, un golpe que no daña).
static func tras_defensa(d: float, defensa: float) -> float:
	if d <= 0.0:
		return 0.0
	return maxf(SUELO_DEF * d, d - maxf(defensa, 0.0))


## D antes de la defensa: (B·E · G · X + suma_x) × R. `base_elem` es B × E (ya con el pigmento de daño, si lo hay).
static func bruto(base_elem: float, g: float, x: float, r: float, suma_x: float = 0.0) -> float:
	return (base_elem * g * x + suma_x) * r


## El daño por impacto final desde un B × E ya calculado (lo que lleva `Hechizo.dano`).
static func aplicar(base_elem: float, g: float, x: float, r: float, defensa: float, suma_x: float = 0.0) -> float:
	return tras_defensa(bruto(base_elem, g, x, r, suma_x), defensa)


## El daño por impacto final desde la potencia: lo mismo que `aplicar(base_elemental(...))`. `fija` = el daño propio del elemento sin tabla (hielo, rayo).
static func calcular(n_glifos_dano: int, elemento: String, g: float, x: float, r: float, defensa: float, fija: float = -1.0, suma_x: float = 0.0) -> float:
	return aplicar(base_elemental(n_glifos_dano, elemento, fija), g, x, r, defensa, suma_x)


## Daño CONTINUO (quemadura, veneno, pulso): pasa por R, no por DEF.
static func continuo(d: float, r: float = 1.0) -> float:
	return maxf(d, 0.0) * r


## Tinta de un hechizo de `n_glifos` glifos con la suma de recargos de glifos especiales (0 si no hay): T_base × (1 + Σ recargos). Es ANTES de la rebaja del pigmento.
static func tinta(n_glifos: int, recargos: float = 0.0) -> float:
	return float(TINTA_BASE[nivel(n_glifos)]) * (1.0 + maxf(recargos, 0.0))


## --- TINTA DESDE EL HECHIZO (H4, 29/10; PLAN_SISTEMA_HECHIZOS §3): T = T_base(potencia) + Σ aporte_glifo;  T_final = T × (1 + recargo_instancias + recargo_periodico) ---
## Todas las constantes nuevas se entregan a 0 (el golden no cambia) hasta que Pablo ponga los números (propuesta en docs/DANO_Y_TINTA.md §2).
const K_COPIA: float = 0.0          ## recargo por cada copia de más (repetición): K_COPIA × (copias − 1)
const K_HIJO: float = 0.0           ## recargo por cada hijo previsto (suma de `cuantos` de las acciones `crear_hijo` de todos los eventos)
const K_PERIODICO: float = 0.0      ## recargo si el hechizo hiere por tics (`dano_periodico > 0` o `veneno > 0`)
## Recargo del pulso continuo ᚱ: con true se decide con `Hechizo.persistente` (cubre tierra/hielo y excluye el haz); con false, la condición de siempre por propiedades de la receta
## (ᚱ + no viaja + barrera o permanencia). A true cambian recetas del golden (tierra/hielo + ᚱ sin barrera suben +25 %; haz + permanencia + ᚱ baja): se deja a false hasta que Pablo decida (DANO_Y_TINTA §2).
const CONTINUO_POR_HECHIZO: bool = false


## Hijos previstos: la suma de `cuantos` de las acciones `crear_hijo` de todos los eventos del hechizo.
static func hijos_previstos(h: Hechizo) -> int:
	var n: int = 0
	for ev in h.eventos:
		for a in (h.eventos[ev] as Array):
			if a is Dictionary and String((a as Dictionary).get("accion", "")) == "crear_hijo":
				n += maxi(int((a as Dictionary).get("cuantos", 1)), 1)
	return n


## ¿El pulso ᚱ late mientras el volumen se queda (y por tanto recarga)? `por_hechizo` elige la condición (ver CONTINUO_POR_HECHIZO).
static func es_continuo(h: Hechizo, por_hechizo: bool = CONTINUO_POR_HECHIZO) -> bool:
	if h.resuena <= 0.0:
		return false
	if por_hechizo:
		return h.persistente
	var p: Dictionary = h.propiedades_usadas()
	return p.has("resuena") and not p.has("viaja") and (p.has("solidez") or p.has("permanencia"))


## Desglose de la tinta de un hechizo: {base, aportes: {glifo: x}, instancias, periodico, total}. `ajustes` (solo pruebas y laboratorio; vacío = el juego) puede traer
## `k_copia`, `k_hijo`, `k_periodico`, `continuo` (el recargo de ᚱ), `continuo_por_hechizo` y `aportes` ({glifo: {por_glifo, tope}} que sustituye al dato de `Sigils.GLIFOS`).
static func desglose_tinta(h: Hechizo, ajustes: Dictionary = {}) -> Dictionary:
	var base_t: float = float(TINTA_BASE[nivel(h.n_glifos)])
	var tablas: Dictionary = ajustes.get("aportes", {})
	var aportes: Dictionary = {}
	var suma: float = 0.0
	for k in h.glifos:
		var n: int = maxi(int(h.glifos[k]), 0)
		var cfg: Dictionary = {}
		if tablas.has(k):
			cfg = tablas[k]
		elif Sigils.GLIFOS.has(k):
			cfg = (Sigils.GLIFOS[k] as Dictionary).get("tinta", {})
		var por: float = float(cfg.get("por_glifo", 0.0))
		if n == 0 or por == 0.0:
			continue
		var x: float = minf(por * float(n), float(cfg.get("tope", INF)))
		aportes[k] = x
		suma += x
	var inst: float = float(ajustes.get("k_copia", K_COPIA)) * float(maxi(h.copias - 1, 0)) + float(ajustes.get("k_hijo", K_HIJO)) * float(hijos_previstos(h))
	var per: float = 0.0
	if es_continuo(h, bool(ajustes.get("continuo_por_hechizo", CONTINUO_POR_HECHIZO))):
		per += float(ajustes.get("continuo", Sigils.COSTE_CONTINUO_V2))
	if h.dano_periodico > 0.0 or h.veneno > 0.0:
		per += float(ajustes.get("k_periodico", K_PERIODICO))
	return {"base": base_t, "aportes": aportes, "instancias": inst, "periodico": per, "total": (base_t + suma) * (1.0 + maxf(inst + per, 0.0))}


## La tinta de un hechizo construido, ANTES de la rebaja del pigmento. Lo que cobra el juego (`Hechizo.coste_tinta`, `Receta3D.coste_tinta`).
static func tinta_de(h: Hechizo, ajustes: Dictionary = {}) -> float:
	return float(desglose_tinta(h, ajustes)["total"])


## Golpes iguales de daño `d_final` que hacen falta para matar una vida (cuenta de la tabla del doc; 0 daño = -1).
static func golpes_para_matar(vida: float, d_final: float) -> int:
	if d_final <= 0.0:
		return -1
	return int(ceil(vida / d_final - 1e-9))
