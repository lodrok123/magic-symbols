extends SceneTree
## Godot --headless --path . --script res://herramientas/censo_conjuros.gd
## Tras `--` admite demo_inicio, demo, pruebas o motor para medir un solo repertorio.
## `-- demo fichas` también imprime una receta mínima por perfil.
## `-- ocho hasta_tres fichas` usa el kit de pruebas con los ocho elementos y hasta tres glifos.
## `-- ocho tres_exactos fichas` mide las recetas que ocupan exactamente tres huecos.

const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth",
	"hielo": "ice", "rayo": "lightning", "viento": "wind", "magma": "magma", "naturaleza": "naturaleza"}
const FIGURAS: Array[String] = ["bola", "muro", "pilar", "barrera", "haz"]


func _initialize() -> void:
	call_deferred("_medir")


func _medir() -> void:
	var seleccion := OS.get_cmdline_user_args()
	var tres_exactos: bool = seleccion.has("tres_exactos")
	for nombre in ["demo_inicio", "demo", "pruebas", "motor", "ocho"]:
		if nombre == "ocho" and not seleccion.has("ocho"):
			continue
		if not seleccion.is_empty() and not seleccion.has(nombre):
			continue
		var es_motor: bool = nombre == "motor"
		var kit: Dictionary = Lanzador3D.PROGRESIONES.get("pruebas" if nombre == "ocho" else nombre, {})
		var glifos: Array = Sigils.GLIFOS.keys() if es_motor else _glifos_del_kit(kit["glifos"])
		var elementos: Array = RUNAS.keys() if es_motor or nombre == "ocho" else kit["sellos"]
		var huecos: int = Hechizo.MAX_GLIFOS if es_motor else int(kit["glifos_por_pagina"])
		if seleccion.has("hasta_tres") or tres_exactos:
			huecos = mini(huecos, 3)
		var resultado: Dictionary = {}
		for elemento in elementos:
			var runa: RuneData = load("res://nucleo/%s_rune.tres" % RUNAS[elemento])
			var cuenta: Dictionary = {"candidatas": 0, "sin_glifos": 0, "rechazadas": 0, "admitidas": 0,
				"figuras": {}, "familias": {}, "perfiles": {}, "parametros": {}, "rafagas": 0, "latidos": 0}
			_barrer(glifos, huecos, 0, {}, runa, cuenta, nombre == "pruebas", tres_exactos)
			if seleccion.has("fichas"):
				for ficha in cuenta["perfiles"].values():
					print("FICHA ", JSON.stringify({"repertorio": nombre, "elemento": elemento, "perfil": ficha}))
			cuenta["perfiles"] = cuenta["perfiles"].size()
			cuenta["parametros"] = cuenta["parametros"].size()
			resultado[elemento] = cuenta
		print("CENSO ", JSON.stringify({"repertorio": nombre, "huecos": huecos, "tres_exactos": tres_exactos, "glifos": glifos, "elementos": resultado}))
	quit()


func _glifos_del_kit(ids: Array) -> Array:
	var resultado: Array = []
	for glifo in Sigils.GLIFOS:
		if ids.has(Sigils.repertorio_de(glifo)):
			resultado.append(glifo)
	return resultado


func _barrer(glifos: Array, restantes: int, desde: int, receta: Dictionary, runa: RuneData, cuenta: Dictionary, medir_orden: bool, tres_exactos: bool) -> void:
	if not tres_exactos or restantes == 0:
		_medir_receta(receta, runa, cuenta, medir_orden)
	if restantes == 0:
		return
	for i in range(desde, glifos.size()):
		var glifo: String = glifos[i]
		var anterior: int = int(receta.get(glifo, 0))
		receta[glifo] = anterior + 1
		_barrer(glifos, restantes - 1, i, receta, runa, cuenta, medir_orden, tres_exactos)
		if anterior == 0:
			receta.erase(glifo)
		else:
			receta[glifo] = anterior


func _medir_receta(receta: Dictionary, runa: RuneData, cuenta: Dictionary, medir_orden: bool) -> void:
	cuenta["candidatas"] += 1
	if receta.is_empty() and Lanzador3D.elemento_de(runa) != "tierra":
		cuenta["sin_glifos"] += 1
		return
	var h := Hechizo.construir(runa, receta)
	if h == null or Lanzador3D.aviso_altura(h, runa) != "" or h.coste_tinta > Tinta.MAXIMA_INICIAL:
		cuenta["rechazadas"] += 1
		return
	cuenta["admitidas"] += 1
	var familia: String = _familia(h)
	var figura: String = _figura(h, familia)
	var perfil: Array = [familia, figura]
	var valores: Array = []
	match familia:
		"suelo":
			var caso: int = GlifoSuelo.Caso.CAPA_TIERRA if h.elemento == "tierra" else (
				GlifoSuelo.Caso.CAPA_HIELO if h.elemento == "hielo" else GlifoSuelo.Caso.TRAMPA)
			valores.append(GlifoSuelo.vida_de(caso, h))
			if caso == GlifoSuelo.Caso.TRAMPA:
				valores.append(h.dano)
		"plataforma":
			valores.append_array([h.longitud_plataforma_tierra(), h.persiste + h.permanencia])
		_:
			var rasgos: Dictionary = {"colocado": h.en_punto, "bloquea": h.protege,
				"copias": h.copias > 1 and not h.haz, "crece": h.crece > 0.0 and not h.haz,
				"retorno": h.retorna, "busca": h.busca > 0.0 and (h.proyectil or h.orbita),
				"rebote": h.rebota and (h.viaja or h.protege), "perfora": h.perfora > 0 and (h.proyectil or h.haz),
				"retardo": h.retardo > 0.0}
			for rasgo in rasgos:
				if rasgos[rasgo]:
					perfil.append(rasgo)
			if h.resuena > 0.0:
				perfil.append("pulso_" + h.momento_de("raido"))
			valores.append_array([h.dano, h.retardo, h.resuena])
			if h.haz:
				valores.append_array([h.alcance_haz, h.perfora])
			else:
				valores.append_array([h.semieje_x, h.semieje_y, h.semieje_z, h.elevacion, h.copias, h.crece,
					h.solidez, h.distancia_max, h.velocidad, h.persiste + h.permanencia, h.impulso_salida])
				if h.viaja or h.protege:
					valores.append(h.rebotes)
				if h.proyectil or h.orbita:
					valores.append(h.busca)
				if h.proyectil:
					valores.append(h.perfora)
	var figuras: Dictionary = cuenta["figuras"]
	figuras[figura] = int(figuras.get(figura, 0)) + 1
	var familias: Dictionary = cuenta["familias"]
	familias[familia] = int(familias.get(familia, 0)) + 1
	var clave: String = JSON.stringify(perfil)
	var fichas: Dictionary = cuenta["perfiles"]
	if not fichas.has(clave) or h.n_glifos < int(fichas[clave]["glifos"]):
		fichas[clave] = {"rasgos": perfil, "glifos": h.n_glifos, "receta": receta.duplicate()}
	for i in valores.size():
		valores[i] = snappedf(float(valores[i]), 0.00001)
	cuenta["parametros"][JSON.stringify([perfil, valores])] = true
	if medir_orden and h.proyectil and h.copias > 1 and not h.suelo:
		cuenta["rafagas"] += 1
	if medir_orden and h.protege and not h.viaja and not h.orbita and not h.suelo and familia != "plataforma" and receta.has("pulso"):
		cuenta["latidos"] += 1


func _familia(h: Hechizo) -> String:
	if h.suelo:
		return "suelo"
	if h.es_plataforma_tierra():
		return "plataforma"
	if h.orbita:
		return "orbita"
	if h.haz:
		return "haz"
	if h.volumen_viaja:
		return "volumen movil"
	if h.proyectil:
		return "proyectil"
	if h.estalla:
		return "estallido"
	if h.columna:
		return "columna creciente"
	return "volumen fijo"


func _figura(h: Hechizo, familia: String) -> String:
	if familia == "suelo" or familia == "plataforma" or familia == "orbita":
		return familia
	return FIGURAS[int(FuegoToy.describir(h)["figura"])]
