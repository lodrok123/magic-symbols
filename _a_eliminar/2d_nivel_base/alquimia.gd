class_name Alquimia
extends RefCounted

## LAS MEJORAS DEL ALQUIMISTA. Cada una tiene varios niveles y cada nivel cuesta ORO y
## INGREDIENTES (los que se sacan haciendo reaccionar plantas con elementos).
##
##   vida       +20 de vida máxima por nivel                    (3 niveles)
##   huecos     +4 huecos de mochila por nivel: 8 -> 20         (3 niveles)
##   cura       las pociones curan +10 más                      (2 niveles)
##   velocidad  +10 de velocidad                                (2 niveles)

const MEJORAS: Dictionary = {
	"vida": {"nombre": "Vida máxima", "niveles": [
		{"oro": 30, "mats": {"seta_asada": 2}, "texto": "+20 de vida"},
		{"oro": 50, "mats": {"flor_rocio": 2}, "texto": "+20 de vida"},
		{"oro": 70, "mats": {"raiz_cenizas": 2}, "texto": "+20 de vida"}]},
	"huecos": {"nombre": "Huecos de mochila", "niveles": [
		{"oro": 30, "mats": {"raiz_hinchada": 2}, "texto": "+4 huecos"},
		{"oro": 50, "mats": {"seta_helada": 2}, "texto": "+4 huecos"},
		{"oro": 70, "mats": {"flor_escarcha": 2}, "texto": "+4 huecos"}]},
	"cura": {"nombre": "Cura de las pociones", "niveles": [
		{"oro": 25, "mats": {"flor_rocio": 1, "seta_humeda": 1}, "texto": "pociones +10"},
		{"oro": 45, "mats": {"flor_ardiente": 2}, "texto": "pociones +10"}]},
	"velocidad": {"nombre": "Velocidad", "niveles": [
		{"oro": 25, "mats": {"seta_electrificada": 2}, "texto": "+10 de velocidad"},
		{"oro": 45, "mats": {"flor_chispa": 2}, "texto": "+10 de velocidad"}]},
}


static func _mats_texto(mats: Dictionary, e: Estado) -> String:
	var t: Array = []
	for id in mats:
		t.append("%d %s (tienes %d)" % [int(mats[id]), Objetos.nombre(id), e.cuenta(id)])
	return ", ".join(t)


## La lista para la ventana de compra (el mismo formato que la tienda).
static func articulos(e: Estado) -> Array:
	var l: Array = []
	for id in MEJORAS:
		var d: Dictionary = MEJORAS[id]
		var niv: int = e.nivel(id)
		var lista: Array = d["niveles"]
		if niv >= lista.size():
			l.append({"id": id, "nombre": d["nombre"], "desc": "nivel máximo", "precio": 0, "agotado": true})
			continue
		var n: Dictionary = lista[niv]
		l.append({"id": id, "nombre": "%s  (nivel %d)" % [d["nombre"], niv + 1],
			"desc": "%s. Pide %s" % [n["texto"], _mats_texto(n["mats"], e)], "precio": int(n["oro"])})
	return l


## Intenta comprar. Devuelve "" si salió bien o el motivo del fallo.
static func comprar(e: Estado, id: String) -> String:
	if not MEJORAS.has(id):
		return "Eso no lo tengo."
	var lista: Array = MEJORAS[id]["niveles"]
	var niv: int = e.nivel(id)
	if niv >= lista.size():
		return "Ya está al máximo."
	var n: Dictionary = lista[niv]
	if e.oro < int(n["oro"]):
		return "Te falta oro."
	for m in n["mats"]:
		if e.cuenta(m) < int(n["mats"][m]):
			return "Te faltan ingredientes: %s." % Objetos.nombre(m)
	for m in n["mats"]:
		e.quitar(m, int(n["mats"][m]))
	e.gastar_oro(int(n["oro"]))
	e.mejoras[id] = niv + 1
	match id:
		"vida":
			e.vida_max += 20.0
		"huecos":
			e.subir_capacidad(4)
		"cura":
			e.cura_pocion += 10.0
		"velocidad":
			e.vel_extra += 10.0
	e.cambiado.emit()
	return ""
