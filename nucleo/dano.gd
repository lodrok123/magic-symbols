class_name Dano
extends RefCounted

## DAÑO Y TINTA POR POTENCIA (29/10, decisión de Pablo; docs/DANO_Y_TINTA.md). EL ÚNICO SITIO donde se calcula cuánto daña un hechizo y cuánta tinta cuesta.
## Funciones estáticas puras: sin nodos, sin estado, sin leer el juego. Las usan `Hechizo` (daño base y coste en tinta), `Lanzador3D.Receta3D` (el coste antes de construir el hechizo),
## `Combate3D.decidir_golpe` y sus subclases (limo, gólem, chamán) y, por tanto, la previsión del indicador y los números flotantes.
##
## POTENCIA = nº de glifos de la receta (los que el juego conoce; el elemento no cuenta): 0-1 ligera · 2-3 media · ≥4 alta (el libro admite 6, `Hechizo.MAX_GLIFOS`).
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
## TINTA:  T = T_base(potencia) × (1 + Σ recargos), y los recargos son SOLO de glifos especiales que ya encarecían (hoy: el efecto continuo ᚱ, `Sigils.COSTE_CONTINUO_V2`).
## El nº de glifos entra únicamente por T_base: no hay doble conteo. La rebaja del pigmento (`Tinta.coste_efectivo`) se aplica encima, fuera de aquí.

const LIGERA: int = 0
const MEDIA: int = 1
const ALTA: int = 2
const NOMBRES: PackedStringArray = ["ligera", "media", "alta"]

## Cortes de potencia: glifos mínimos para ser media y alta.
const GLIFOS_MEDIA: int = 2
const GLIFOS_ALTA: int = 4

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


## ¿Tiene este elemento tabla de potencia? (fuego, agua, tierra, viento; hielo y rayo, no)
static func tiene_tabla(elemento: String) -> bool:
	return MULT_ELEMENTO.has(elemento)


## E del elemento (1 si no tiene tabla).
static func mult_elemento(elemento: String) -> float:
	return float(MULT_ELEMENTO.get(elemento, 1.0))


## B de la potencia que da `n_glifos`.
static func base(n_glifos: int) -> float:
	return float(BASE[nivel(n_glifos)])


## B × E. Para un elemento sin tabla (hielo, rayo) devuelve `fija` (su daño de siempre) si es ≥ 0, y B × 1 si no hay `fija`.
static func base_elemental(n_glifos: int, elemento: String, fija: float = -1.0) -> float:
	if tiene_tabla(elemento):
		return base(n_glifos) * mult_elemento(elemento)
	if fija >= 0.0:
		return fija
	return base(n_glifos)


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
static func calcular(n_glifos: int, elemento: String, g: float, x: float, r: float, defensa: float, fija: float = -1.0, suma_x: float = 0.0) -> float:
	return aplicar(base_elemental(n_glifos, elemento, fija), g, x, r, defensa, suma_x)


## Daño CONTINUO (quemadura, veneno, pulso): pasa por R, no por DEF.
static func continuo(d: float, r: float = 1.0) -> float:
	return maxf(d, 0.0) * r


## Tinta de un hechizo de `n_glifos` glifos con la suma de recargos de glifos especiales (0 si no hay): T_base × (1 + Σ recargos). Es ANTES de la rebaja del pigmento.
static func tinta(n_glifos: int, recargos: float = 0.0) -> float:
	return float(TINTA_BASE[nivel(n_glifos)]) * (1.0 + maxf(recargos, 0.0))


## Golpes iguales de daño `d_final` que hacen falta para matar una vida (cuenta de la tabla del doc; 0 daño = -1).
static func golpes_para_matar(vida: float, d_final: float) -> int:
	if d_final <= 0.0:
		return -1
	return int(ceil(vida / d_final - 1e-9))
