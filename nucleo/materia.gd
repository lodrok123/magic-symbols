class_name Materia
extends RefCounted
## H6 (PLAN_SISTEMA_HECHIZOS §1.6): lo que un objeto del mundo necesita saber de un hechizo para reaccionar, expresado en PROPIEDADES FÍSICAS y no en etiquetas ni en nombres.
## Estática y pura: no toca el árbol, no construye hechizos y no cambia nada.
##
##   Materia.de(fuente)              → {temperatura, humedad, conductividad, densidad, empuje, estado, elemento}
##   Materia.calienta(m) / enfria / moja / riega / conduce / empuja / sopla / golpea / es_solido     → los predicados con umbral
##   Materia.reaccion(m, material, estado) → «prende», «apaga», «moja»… o «» (la tabla de MEJORAS_POTENCIA §5)
##
## `fuente` es un `Hechizo` (sus campos físicos), un `RuneData` con .tres (sus `modificadores` dicen temperatura, humedad, conductividad y densidad) o un `RuneData` suelto
## que solo trae etiquetas (el fuego de un brasero, `Objetos3D.carried_element`). Las ETIQUETAS valen siempre como respaldo y se funden con los números por el valor mayor:
## un elemento nuevo con `temperatura +1` y sin etiquetas calienta, y uno con la etiqueta «calor» y sin números también.

const T_CALOR: float = 0.5      ## temperatura ≥ esto: calienta (prende, enciende, funde)
const T_FRIO: float = -0.5      ## temperatura ≤ esto: enfría (apaga, hiela, agrieta)
const H_MOJA: float = 0.5       ## humedad ≥ esto: moja
const C_CONDUCE: float = 0.5    ## conductividad ≥ esto: conduce (rayo)
const E_EMPUJA: float = 0.5     ## empuje ≥ esto: empuja
const D_PESADA: float = 1.5     ## densidad ≥ esto, y sólido: golpea (la tierra; el hielo, 0,9, no)

const MATERIALES: PackedStringArray = ["madera", "vegetal", "piedra", "metal", "cristal", "tela"]


## Normaliza una fuente a números. Una fuente nula da todo a cero (no reacciona con nada).
static func de(fuente: Variant) -> Dictionary:
	var m: Dictionary = {"temperatura": 0.0, "humedad": 0.0, "conductividad": 0.0, "densidad": 1.0, "empuje": 0.0, "estado": "solido", "elemento": ""}
	var etiquetas: Array = []
	if fuente is Hechizo:
		var h: Hechizo = fuente
		m["temperatura"] = h.temperatura
		m["humedad"] = h.humedad
		m["conductividad"] = h.conductividad
		m["densidad"] = h.densidad
		m["empuje"] = h.empuje
		m["estado"] = h.estado_materia
		m["elemento"] = h.elemento
		etiquetas = h.etiquetas
	elif fuente is RuneData:
		var r: RuneData = fuente
		m["empuje"] = r.empuje
		m["estado"] = r.estado
		m["elemento"] = Objetos.elemento_de(r)
		for campo in ["temperatura", "humedad", "conductividad", "densidad"]:
			if r.modificadores.has(campo):
				m[campo] = _aplicar(float(m[campo]), r.modificadores[campo])
		etiquetas = r.tags
	_fundir_etiquetas(m, etiquetas)
	return m


static func _aplicar(base: float, mod: Variant) -> float:
	if not (mod is Dictionary):
		return base
	var v: float = float(mod.get("valor", 0.0))
	match String(mod.get("op", "fija")):
		"suma":
			return base + v
		"multiplica":
			return base * v
		"minimo":
			return maxf(base, v)
	return v


## Lo que dicen las etiquetas, como números: calor → temperatura +1, frio → −1, agua → humedad 1, rayo/electrico → conductividad 1, viento → empuje 1 (y gas).
static func de_etiquetas(etiquetas: Array) -> Dictionary:
	var m: Dictionary = {"temperatura": 0.0, "humedad": 0.0, "conductividad": 0.0, "empuje": 0.0}
	if etiquetas.has("calor"):
		m["temperatura"] = 1.0
	elif etiquetas.has("frio"):
		m["temperatura"] = -1.0
	if etiquetas.has("agua"):
		m["humedad"] = 1.0
	if etiquetas.has("rayo") or etiquetas.has("electrico"):
		m["conductividad"] = 1.0
	if etiquetas.has("viento"):
		m["empuje"] = 1.0
	return m


static func _fundir_etiquetas(m: Dictionary, etiquetas: Array) -> void:
	if etiquetas.is_empty():
		return
	var e: Dictionary = de_etiquetas(etiquetas)
	if absf(float(e["temperatura"])) > absf(float(m["temperatura"])):
		m["temperatura"] = e["temperatura"]
	for campo in ["humedad", "conductividad", "empuje"]:
		m[campo] = maxf(float(m[campo]), float(e[campo]))
	if etiquetas.has("viento") and String(m["estado"]) == "solido":
		m["estado"] = "gas"


static func calienta(m: Dictionary) -> bool:
	return float(m.get("temperatura", 0.0)) >= T_CALOR


static func enfria(m: Dictionary) -> bool:
	return float(m.get("temperatura", 0.0)) <= T_FRIO


static func moja(m: Dictionary) -> bool:
	return float(m.get("humedad", 0.0)) >= H_MOJA


## Moja de verdad: el hielo trae humedad 0,5 pero lo que hace es helar, no regar.
static func riega(m: Dictionary) -> bool:
	return moja(m) and not enfria(m)


static func conduce(m: Dictionary) -> bool:
	return float(m.get("conductividad", 0.0)) >= C_CONDUCE


static func empuja(m: Dictionary) -> bool:
	return float(m.get("empuje", 0.0)) >= E_EMPUJA


## Empuja siendo aire: lo que lleva una llama. La tierra (0,8) y el agua (0,5) empujan pero no avivan ni se llevan el fuego.
static func sopla(m: Dictionary) -> bool:
	return empuja(m) and String(m.get("estado", "")) == "gas"


static func es_solido(m: Dictionary) -> bool:
	return String(m.get("estado", "")) == "solido"


## Un sólido denso que cae o se clava: la tierra.
static func golpea(m: Dictionary) -> bool:
	return es_solido(m) and float(m.get("densidad", 0.0)) >= D_PESADA and not enfria(m)


## MEJORAS_POTENCIA §5 en propiedades. `estado` = {mojado, ardiendo, helado, encendido…} (lo que falte es false). Devuelve la reacción que tendría la pieza, sin aplicarla:
## «prende», «apaga», «moja», «aviva», «hiela», «escarcha», «chamusca», «astilla», «crece», «congela», «agita», «calienta», «agrieta», «desprende», «oxida», «conduce», «funde»,
## «brilla», «carga», «rompe», «pesa», «rigida», «ondea»; «» si no pasa nada. Un material desconocido no reacciona.
static func reaccion(m: Dictionary, material: String, estado: Dictionary = {}) -> String:
	var mojado: bool = bool(estado.get("mojado", false))
	var ardiendo: bool = bool(estado.get("ardiendo", false))
	var helado: bool = bool(estado.get("helado", false))
	var sano: bool = not mojado and not ardiendo and not helado
	match material:
		"madera", "vegetal", "tela":
			if ardiendo:
				if moja(m) or enfria(m):
					return "apaga"
				return "aviva" if sopla(m) else ""
			if calienta(m):
				return "prende" if sano else ""
			if material == "madera" and conduce(m):
				return "chamusca" if not mojado else ""
			if enfria(m):
				return {"madera": "escarcha", "vegetal": "congela", "tela": "rigida"}[material]
			if riega(m):
				return {"madera": "moja", "vegetal": "crece", "tela": "pesa"}[material]
			if sopla(m):
				return {"madera": "", "vegetal": "agita", "tela": "ondea"}[material]
			if material == "madera" and golpea(m):
				return "astilla"
			return ""
		"piedra":
			if calienta(m):
				return "calienta"
			if enfria(m):
				return "agrieta" if mojado else ""
			if riega(m):
				return "moja"
			return "desprende" if golpea(m) else ""
		"metal":
			if conduce(m):
				return "conduce"
			if calienta(m):
				return "calienta"
			return "oxida" if riega(m) else ""
		"cristal":
			if conduce(m):
				return "carga"
			if calienta(m):
				return "funde"
			if enfria(m):
				return "crece"
			if riega(m):
				return "brilla"
			return "rompe" if golpea(m) else ""
	return ""
