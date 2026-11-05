class_name ContrasteLuz3D
extends RefCounted
## CAPA 1 DE CONTRASTE DE LUZ (5/11, «Juego 5/11»). Un PRESET conmutable que sube el contraste de la luz del mapa para compararlo con la luz de antes.
##
## MEDIDO (5/11, prado a las 17 h, sol 20° más bajo, relación luminancia en sombra / al sol sobre los píxeles que cambian al apagar la sombra): antes 77 %; la capa 1 con el ambiente
## ×0,5 escrito en la energía del cielo deja la sombra en ≈ 50 % (ver `LuzZona3D.AMBIENTE_FACTOR`). Hasta hoy el factor de ambiente no actuaba y la capa 1 solo aclaraba lo iluminado. La hierba con sombra no baja los FPS (57 → 59 medido).
##
## QUÉ CAMBIA (capa 1 / de antes):
##   · LuzZona3D.AMBIENTE_FACTOR  0,5 / 1,0   · LuzZona3D.SOL_FACTOR  1,3 / 1,0   · Hierba3D.RECIBE_SOMBRA  true / false
##   · LuzZona3D.SOMBRA_BLUR  0,5 / 1,6        · Posproceso3D.SSAO_INTENSIDAD  2,0 / 1,2   · Posproceso3D.SSAO_RADIO  1,4 / 1,0
## `ACTIVO = true` (capa 1) es el valor de serie. `poner(false)` devuelve la luz de antes. Las filas sueltas del panel F3 (PanelLuz3D) siguen mandando por encima del preset.
## «bosque = antes» (las pruebas que miden energías exactas de la zona) se mide con el preset APAGADO.

## El preset: true = capa 1; false = la luz de antes.
static var ACTIVO: bool = true

## Capa 1.
static var AMBIENTE_FACTOR_C1: float = 0.5
static var SOL_FACTOR_C1: float = 1.3
static var HIERBA_SOMBRA_C1: bool = true
static var SOMBRA_BLUR_C1: float = 0.5
static var SSAO_INTENSIDAD_C1: float = 2.0
static var SSAO_RADIO_C1: float = 1.4

## La luz de antes.
const AMBIENTE_FACTOR_ANTES: float = 1.0
const SOL_FACTOR_ANTES: float = 1.0
const HIERBA_SOMBRA_ANTES: bool = false
const SOMBRA_BLUR_ANTES: float = 1.6
const SSAO_INTENSIDAD_ANTES: float = 1.2
const SSAO_RADIO_ANTES: float = 1.0


## Escribe las seis variables según `ACTIVO`. Con `maqueta`: reescribe la hierba (`_hierba`) y reaplica el SSAO al Environment (`_env`). Idempotente.
static func aplicar(maqueta: Node3D = null) -> void:
	LuzZona3D.AMBIENTE_FACTOR = AMBIENTE_FACTOR_C1 if ACTIVO else AMBIENTE_FACTOR_ANTES
	LuzZona3D.SOL_FACTOR = SOL_FACTOR_C1 if ACTIVO else SOL_FACTOR_ANTES
	LuzZona3D.SOMBRA_BLUR = SOMBRA_BLUR_C1 if ACTIVO else SOMBRA_BLUR_ANTES
	var sombra: bool = HIERBA_SOMBRA_C1 if ACTIVO else HIERBA_SOMBRA_ANTES
	Hierba3D.RECIBE_SOMBRA = sombra
	Posproceso3D.SSAO_INTENSIDAD = SSAO_INTENSIDAD_C1 if ACTIVO else SSAO_INTENSIDAD_ANTES
	Posproceso3D.SSAO_RADIO = SSAO_RADIO_C1 if ACTIVO else SSAO_RADIO_ANTES
	if maqueta == null:
		return
	var h: Variant = maqueta.get("_hierba")
	if h is Hierba3D and is_instance_valid(h):
		(h as Hierba3D).poner_recibe_sombra(sombra)
	var env: Variant = maqueta.get("_env")
	if env is Environment:
		Posproceso3D.aplicar_ssao(env as Environment)


## Enciende o apaga el preset y lo aplica.
static func poner(activo: bool, maqueta: Node3D = null) -> void:
	ACTIVO = activo
	aplicar(maqueta)
