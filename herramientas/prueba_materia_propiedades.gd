extends SceneTree
## H6 · Materia (nucleo/materia.gd): las propiedades físicas de los seis .tres, la fuente (Hechizo / RuneData con .tres / RuneData solo de etiquetas / elemento de laboratorio sin
## etiquetas), los predicados con umbral y la tabla material × elemento de MEJORAS_POTENCIA §5. Sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_materia_propiedades.gd

const ELEMENTOS: Array = ["fuego", "agua", "hielo", "rayo", "viento", "tierra"]
const TRES: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "viento": "wind", "tierra": "earth"}
## ESPEC_HECHIZO §2: temperatura, humedad, conductividad, densidad
const FISICA: Dictionary = {
	"fuego": [1.0, 0.0, 0.0, 0.2], "agua": [0.0, 1.0, 0.3, 1.0], "hielo": [-1.0, 0.5, 0.0, 0.9],
	"rayo": [0.0, 0.0, 1.0, 0.0], "viento": [0.0, 0.0, 0.0, 0.1], "tierra": [0.0, 0.2, 0.0, 2.0],
}
## material → [fuego, agua, hielo, rayo, viento, tierra] con la pieza sana
const TABLA: Dictionary = {
	"madera": ["prende", "moja", "escarcha", "chamusca", "", "astilla"],
	"vegetal": ["prende", "crece", "congela", "", "agita", ""],
	"piedra": ["calienta", "moja", "", "", "", "desprende"],
	"metal": ["calienta", "oxida", "", "conduce", "", ""],
	"cristal": ["funde", "brilla", "crece", "carga", "", "rompe"],
	"tela": ["prende", "pesa", "rigida", "", "ondea", ""],
}

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _rune(el: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % TRES[el]) as RuneData


func _solo_etiquetas(tags: Array[String]) -> RuneData:
	var r := RuneData.new()
	r.tags = tags
	return r


func _initialize() -> void:
	await process_frame
	# 1. los números de cada .tres, por el Hechizo y por Materia.de(RuneData)
	for el in ELEMENTOS:
		var r: RuneData = _rune(el)
		var h: Hechizo = Hechizo.construir(r, {})
		var f: Array = FISICA[el]
		var bien: bool = absf(h.temperatura - f[0]) < 0.001 and absf(h.humedad - f[1]) < 0.001 and absf(h.conductividad - f[2]) < 0.001 and absf(h.densidad - f[3]) < 0.001
		_ok("hechizo de %s trae su física" % el, bien, "T %.2f H %.2f C %.2f D %.2f" % [h.temperatura, h.humedad, h.conductividad, h.densidad])
		var mh: Dictionary = Materia.de(h)
		var mr: Dictionary = Materia.de(r)
		var igual: bool = true
		for k in ["temperatura", "humedad", "conductividad", "densidad", "empuje"]:
			igual = igual and absf(float(mh[k]) - float(mr[k])) < 0.001
		igual = igual and mh["estado"] == mr["estado"] and mh["elemento"] == el and mr["elemento"] == el
		_ok("Materia.de(Hechizo) == Materia.de(RuneData) en %s" % el, igual, str(mr))
	# 2. los predicados
	var fu: Dictionary = Materia.de(_rune("fuego"))
	var ag: Dictionary = Materia.de(_rune("agua"))
	var hi: Dictionary = Materia.de(_rune("hielo"))
	var ra: Dictionary = Materia.de(_rune("rayo"))
	var vi: Dictionary = Materia.de(_rune("viento"))
	var ti: Dictionary = Materia.de(_rune("tierra"))
	_ok("calienta: solo el fuego", Materia.calienta(fu) and not Materia.calienta(ag) and not Materia.calienta(hi) and not Materia.calienta(ra))
	_ok("enfría: solo el hielo", Materia.enfria(hi) and not Materia.enfria(fu) and not Materia.enfria(ag))
	_ok("moja: agua y hielo (0,5); riega: solo el agua", Materia.moja(ag) and Materia.moja(hi) and Materia.riega(ag) and not Materia.riega(hi) and not Materia.moja(ti))
	_ok("conduce: solo el rayo (el agua, 0,3, no)", Materia.conduce(ra) and not Materia.conduce(ag) and not Materia.conduce(fu))
	_ok("empuja: viento, tierra y agua; sopla: solo el viento", Materia.empuja(vi) and Materia.empuja(ti) and Materia.empuja(ag) and Materia.sopla(vi) and not Materia.sopla(ti) and not Materia.sopla(ag))
	_ok("es_solido: tierra e hielo, no el fuego ni el viento", Materia.es_solido(ti) and Materia.es_solido(hi) and not Materia.es_solido(fu) and not Materia.es_solido(vi))
	_ok("golpea: la tierra, no el hielo", Materia.golpea(ti) and not Materia.golpea(hi))
	# 3. la fuente solo de etiquetas (el fuego de un brasero)
	var t_calor: Array[String] = ["fuego", "calor"]
	var t_frio: Array[String] = ["hielo", "frio"]
	var t_agua: Array[String] = ["agua"]
	var t_rayo: Array[String] = ["electrico"]
	var t_viento: Array[String] = ["viento"]
	_ok("etiqueta calor → calienta", Materia.calienta(Materia.de(_solo_etiquetas(t_calor))))
	_ok("etiqueta frio → enfría", Materia.enfria(Materia.de(_solo_etiquetas(t_frio))))
	_ok("etiqueta agua → moja", Materia.moja(Materia.de(_solo_etiquetas(t_agua))))
	_ok("etiqueta electrico → conduce", Materia.conduce(Materia.de(_solo_etiquetas(t_rayo))))
	var mv: Dictionary = Materia.de(_solo_etiquetas(t_viento))
	_ok("etiqueta viento → empuja y sopla", Materia.empuja(mv) and Materia.sopla(mv))
	_ok("fuente nula no reacciona", Materia.reaccion(Materia.de(null), "madera", {}) == "")
	# 4. el elemento de laboratorio: temperatura +1 y SIN etiquetas
	var lab := RuneData.new()
	lab.modificadores = {"temperatura": {"op": "fija", "valor": 1.0}}
	var ml: Dictionary = Materia.de(lab)
	_ok("lab sin etiquetas calienta (RuneData)", Materia.calienta(ml) and lab.tags.is_empty())
	_ok("lab sin etiquetas prende la madera", Materia.reaccion(ml, "madera", {}) == "prende", Materia.reaccion(ml, "madera", {}))
	var hl: Hechizo = Hechizo.construir(lab, {})
	_ok("lab sin etiquetas calienta (Hechizo)", hl != null and Materia.calienta(Materia.de(hl)), "T %.2f" % (hl.temperatura if hl != null else -9.0))
	# 5. la tabla material × elemento con la pieza sana, por el Hechizo
	var fuentes: Array = []
	for el in ELEMENTOS:
		fuentes.append(Materia.de(Hechizo.construir(_rune(el), {})))
	for material in TABLA:
		for i in range(ELEMENTOS.size()):
			var esperado: String = TABLA[material][i]
			var real: String = Materia.reaccion(fuentes[i], material, {})
			_ok("%s + %s" % [material, ELEMENTOS[i]], real == esperado, "«%s»" % real if real != esperado else "")
	# 6. con estado
	_ok("piedra mojada + hielo → agrieta", Materia.reaccion(fuentes[2], "piedra", {"mojado": true}) == "agrieta")
	_ok("madera mojada + fuego → nada", Materia.reaccion(fuentes[0], "madera", {"mojado": true}) == "")
	_ok("madera ardiendo + fuego → nada", Materia.reaccion(fuentes[0], "madera", {"ardiendo": true}) == "")
	_ok("madera ardiendo + agua → apaga", Materia.reaccion(fuentes[1], "madera", {"ardiendo": true}) == "apaga")
	_ok("madera ardiendo + hielo → apaga", Materia.reaccion(fuentes[2], "madera", {"ardiendo": true}) == "apaga")
	_ok("madera ardiendo + viento → aviva", Materia.reaccion(fuentes[4], "madera", {"ardiendo": true}) == "aviva")
	_ok("madera ardiendo + tierra → nada (la tierra no aviva)", Materia.reaccion(fuentes[5], "madera", {"ardiendo": true}) == "")
	_ok("tela helada + fuego → nada", Materia.reaccion(fuentes[0], "tela", {"helado": true}) == "")
	_ok("material desconocido no reacciona", Materia.reaccion(fuentes[0], "plasma", {}) == "")
	# 7. un elemento nuevo («vapor») con solo propiedades reacciona con la tabla sin tocar nada
	var vapor := RuneData.new()
	vapor.modificadores = {"temperatura": {"op": "fija", "valor": 0.8}, "humedad": {"op": "fija", "valor": 0.9}}
	var mvap: Dictionary = Materia.de(vapor)
	_ok("vapor (calor y humedad, sin etiquetas): prende la tela y calienta la piedra", Materia.reaccion(mvap, "tela", {}) == "prende" and Materia.reaccion(mvap, "piedra", {}) == "calienta")
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
