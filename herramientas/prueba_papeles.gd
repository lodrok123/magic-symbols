extends SceneTree
## Prueba (21/10, Juego; A1 de docs/PLAN_EOW.md): los PAPELES de Reactivo3D. Sin escena ni ventana: `--headless --fixed-fps 30`.
## Qué mide:
##   1. La tabla PAPELES_POR_TIPO: cada tipo tiene los papeles que le tocan y todos son del vocabulario; lo que tiene números
##      (COMBUSTIBLES / FUENTES) tiene también el papel que los usa.
##   2. Lo de serie reacciona como siempre: el seto arde con calor o rayo y el agua lo apaga; la fogata se enciende solo con calor; el tótem
##      se activa solo con SU elemento; el surtidor brota con agua.
##   3. Las variantes son DIFERENCIAS de papeles, sin tocar código: un seto con `-inflamable` no prende, con `-apaga` el agua no lo apaga,
##      con `-propaga_llama` no pasa la llama; una telaraña con `+mojable` se moja; una pieza cualquiera con `+inflamable` / `+fuente_fuego` /
##      `+pesado` hace de lo que dice.
##   4. `mojable` sigue funcionando como propiedad (Puzle3D la escribe), la caché de papeles se invalida al cambiar `papeles` o `tipo`, y un
##      papel con errata se ignora.
## El «no cambia nada» de verdad (el mismo diario de puzles de fuego y agua antes y después) lo comprueba la comparación de los escenarios
## `escenario_puzles_fuego*`, `escenario_puzles_agua`, `escenario_telarana`… (ver diario 236).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_papeles.gd

var _fallos: int = 0
var _fx: Vfx3D = null
var _x: float = 0.0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_fx = Vfx3D.new()
	root.add_child(_fx)
	_tabla()
	_de_serie()
	_variantes()
	_propiedades()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Un Reactivo3D como lo coloca la maqueta (`preparar` y luego al árbol), sin visual. `retoques`: lo que lleva `papeles`.
func _nuevo(tipo: String, elemento: String = "", retoques: Array = []) -> Reactivo3D:
	var r := Reactivo3D.new()
	var p := PackedStringArray()
	for t in retoques:
		p.append(String(t))
	r.papeles = p
	r.preparar(tipo, Vector2i(int(_x / 10.0), 0), elemento, _fx, null)
	r.position = Vector3(_x, 0.0, 0.0)
	_x += 10.0                      # lejos unos de otros: ningún contagio por casualidad
	root.add_child(r)
	return r


func _runa(tags: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for g in tags:
		t.append(String(g))
	r.tags = t
	return r


func _arde(r: Reactivo3D) -> bool:
	return r.estado == Reactivo3D.EstadoObj.ARDIENDO


func _igual(r: Reactivo3D, esperados: Array) -> bool:
	var a: Array = []
	for p in r.papeles_efectivos():
		a.append(String(p))
	var b: Array = esperados.duplicate()
	b.sort()
	return a == b


# ---------------------------------------------------------------------------------------------------------------------

func _tabla() -> void:
	var madera: Array = [Reactivo3D.P_INFLAMABLE, Reactivo3D.P_PROPAGA_LLAMA, Reactivo3D.P_APAGA]
	for tipo in ["seto", "tronco", "puerta_goblin", "torre_goblin"]:
		_ok("1 %s: inflamable, propaga la llama y se deja apagar (y no es mojable de serie)" % tipo, _igual(_nuevo(tipo), madera))
	_ok("1 telarana: lo de la madera y, desde F1, helable (el hielo la hiela y da seda)", _igual(_nuevo("telarana"), madera + [Reactivo3D.P_HELABLE]))
	for tipo in ["fogata", "brasero"]:
		_ok("1 %s: fuente de fuego que se deja apagar" % tipo, _igual(_nuevo(tipo), [Reactivo3D.P_FUENTE_FUEGO, Reactivo3D.P_APAGA]))
	_ok("1 totem: activable", _igual(_nuevo("totem", "fuego"), [Reactivo3D.P_ACTIVABLE]))
	_ok("1 surtidor: recibe agua", _igual(_nuevo("surtidor"), [Reactivo3D.P_RECIBE_AGUA]))
	_ok("1 emisor_rayo: conduce", _igual(_nuevo("emisor_rayo"), [Reactivo3D.P_CONDUCE]))
	_ok("1 puente y placa no reaccionan a hechizos (sin papeles de reacción)", _igual(_nuevo("puente"), []) and (Reactivo3D.PAPELES_POR_TIPO["placa"] as Array).is_empty())
	var validos: bool = true
	for tipo in Reactivo3D.PAPELES_POR_TIPO.keys():
		for p in (Reactivo3D.PAPELES_POR_TIPO[tipo] as Array):
			validos = validos and Reactivo3D.PAPELES_VALIDOS.has(p)
	_ok("1 todos los papeles de la tabla están en PAPELES_VALIDOS", validos)
	var siete: Array = [Reactivo3D.P_INFLAMABLE, Reactivo3D.P_PROPAGA_LLAMA, Reactivo3D.P_APAGA, Reactivo3D.P_CONDUCE, Reactivo3D.P_CONGELABLE,
		Reactivo3D.P_MOJABLE, Reactivo3D.P_PESADO]
	_ok("1 los siete papeles del plan existen con sus nombres", siete == ["inflamable", "propaga_llama", "apaga", "conduce", "congelable", "mojable", "pesado"])
	var coherente: bool = true
	for tipo in Reactivo3D.COMBUSTIBLES.keys():
		coherente = coherente and (Reactivo3D.PAPELES_POR_TIPO.get(tipo, []) as Array).has(Reactivo3D.P_INFLAMABLE)
	for tipo in Reactivo3D.FUENTES.keys():
		coherente = coherente and (Reactivo3D.PAPELES_POR_TIPO.get(tipo, []) as Array).has(Reactivo3D.P_FUENTE_FUEGO)
	_ok("1 lo que tiene números en COMBUSTIBLES es inflamable y lo que está en FUENTES es fuente_fuego", coherente)


func _de_serie() -> void:
	var seto: Reactivo3D = _nuevo("seto")
	_ok("2 el seto está en el grupo de lo que arde", seto.is_in_group(Reactivo3D.GRUPO_ARDE) and seto.can_burn())
	_ok("2 el seto reacciona a calor, a rayo y al viento no (sano)", seto.spell_reacts(_runa(["calor"])) and seto.spell_reacts(_runa(["rayo"])) and not seto.spell_reacts(_runa(["viento"])))
	seto.on_spell_hit(_runa(["fuego", "calor"]))
	_ok("2 el calor prende el seto", _arde(seto) and seto.is_lit)
	_ok("2 ardiendo: el agua y el viento sí reaccionan, el calor ya no", seto.spell_reacts(_runa(["agua"])) and seto.spell_reacts(_runa(["viento"])) and not seto.spell_reacts(_runa(["calor"])))
	seto.on_spell_hit(_runa(["agua"]))
	_ok("2 el agua lo apaga: vuelve a estar sano", seto.estado == Reactivo3D.EstadoObj.SANO and not seto.is_lit)
	_ok("2 sano y sin `mojable`, el agua no le hace nada (ni lo moja)", not seto.esta_mojado() and not seto.spell_reacts(_runa(["agua"])))
	var rayo: Reactivo3D = _nuevo("tronco")
	rayo.on_spell_hit(_runa(["rayo"]))
	_ok("2 el rayo prende un tronco", _arde(rayo))

	var fogata: Reactivo3D = _nuevo("fogata")
	_ok("2 la fogata NO está en el grupo de lo que arde (no se consume ni contagia)", not fogata.is_in_group(Reactivo3D.GRUPO_ARDE) and not fogata.can_burn())
	fogata.on_spell_hit(_runa(["rayo"]))
	_ok("2 el rayo no enciende una fogata", not fogata.is_lit and not fogata.spell_reacts(_runa(["rayo"])))
	fogata.on_spell_hit(_runa(["calor"]))
	_ok("2 el calor la enciende y ya no reacciona al calor", fogata.is_lit and not fogata.spell_reacts(_runa(["calor"])))
	_ok("2 encendida, el viento no la contagia (no propaga): sigue sin reaccionar", not fogata.spell_reacts(_runa(["viento"])))
	fogata.on_spell_hit(_runa(["frio"]))
	_ok("2 el frío la apaga", not fogata.is_lit)
	var brasero: Reactivo3D = _nuevo("brasero")
	brasero.encender_llama()
	_ok("2 encender_llama / apagar_llama siguen funcionando en el brasero", brasero.is_lit)
	brasero.apagar_llama()
	_ok("2 …y lo apaga", not brasero.is_lit)

	var tfuego: Reactivo3D = _nuevo("totem", "fuego")
	var tagua: Reactivo3D = _nuevo("totem", "agua")
	_ok("2 el tótem de fuego reacciona al calor y no al agua", tfuego.spell_reacts(_runa(["calor"])) and not tfuego.spell_reacts(_runa(["agua"])))
	_ok("2 el tótem de agua reacciona al agua y no al calor", tagua.spell_reacts(_runa(["agua"])) and not tagua.spell_reacts(_runa(["calor"])))
	tfuego.on_spell_hit(_runa(["agua"]))
	_ok("2 un hechizo que no es el suyo no lo activa", not tfuego.activo)
	tfuego.on_spell_hit(_runa(["calor"]))
	_ok("2 el suyo lo activa y se queda (ya no reacciona)", tfuego.activo and not tfuego.spell_reacts(_runa(["calor"])))

	var surtidor: Reactivo3D = _nuevo("surtidor")
	_ok("2 el surtidor reacciona al agua y no al calor", surtidor.spell_reacts(_runa(["agua"])) and not surtidor.spell_reacts(_runa(["calor"])))
	var avisos: Array = []
	surtidor.activado.connect(func(t: String, e: String) -> void: avisos.append("%s/%s" % [t, e]))
	surtidor.on_spell_hit(_runa(["calor"]))
	_ok("2 el calor no hace brotar al surtidor", avisos.is_empty())
	surtidor.on_spell_hit(_runa(["agua"]))
	_ok("2 el agua lo hace brotar y avisa `activado(\"surtidor\", \"agua\")`", avisos == ["surtidor/agua"], str(avisos))

	var roca: Reactivo3D = _nuevo("roca")
	_ok("2 una pieza de un tipo sin papeles no reacciona a nada", not roca.spell_reacts(_runa(["calor"])) and not roca.spell_reacts(_runa(["agua"])) and not roca.spell_reacts(_runa(["rayo"])) and not roca.can_burn())


func _variantes() -> void:
	var sin_fuego: Reactivo3D = _nuevo("seto", "", ["-inflamable"])
	sin_fuego.on_spell_hit(_runa(["calor"]))
	_ok("3 seto `-inflamable`: no prende, no puede arder, no está en el grupo y el calor lo atraviesa",
		not _arde(sin_fuego) and not sin_fuego.can_burn() and not sin_fuego.is_in_group(Reactivo3D.GRUPO_ARDE) and not sin_fuego.spell_reacts(_runa(["calor"])))

	var sin_apagar: Reactivo3D = _nuevo("seto", "", ["-apaga"])
	sin_apagar.on_spell_hit(_runa(["calor"]))
	_ok("3 seto `-apaga`: el agua ya no reacciona…", _arde(sin_apagar) and not sin_apagar.spell_reacts(_runa(["agua"])))
	sin_apagar.on_spell_hit(_runa(["agua"]))
	_ok("3 …y no lo apaga (sigue ardiendo)", _arde(sin_apagar))
	var fogata_fija: Reactivo3D = _nuevo("fogata", "", ["-apaga"])
	fogata_fija.encender_llama()
	fogata_fija.on_spell_hit(_runa(["agua"]))
	_ok("3 fogata `-apaga`: el agua no la apaga", fogata_fija.is_lit and not fogata_fija.spell_reacts(_runa(["agua"])))

	# Contagio: con propaga_llama, el seto que arde prende al vecino; sin él, no.
	var a: Reactivo3D = _nuevo("seto")
	var b: Reactivo3D = _nuevo("seto")
	b.position = a.position + Vector3(2.0, 0.0, 0.0)
	a.on_spell_hit(_runa(["calor"]))
	a.call("_contagiar", Reactivo3D.CONTAGIO, Vector3.ZERO)
	_ok("3 un seto que arde prende al vecino de ≤ 1,7 casillas (de serie)", _arde(b))
	var c: Reactivo3D = _nuevo("seto", "", ["-propaga_llama"])
	var d: Reactivo3D = _nuevo("seto")
	d.position = c.position + Vector3(2.0, 0.0, 0.0)
	c.on_spell_hit(_runa(["calor"]))
	c.call("_contagiar", Reactivo3D.CONTAGIO, Vector3.ZERO)
	_ok("3 seto `-propaga_llama`: arde pero no pasa la llama al vecino", _arde(c) and not _arde(d))
	var e: Reactivo3D = _nuevo("seto", "", ["-propaga_llama"])
	e.on_spell_hit(_runa(["calor"]))
	_ok("3 …y el viento ya no le saca la llama (no reacciona)", not e.spell_reacts(_runa(["viento"])))

	# +mojable: el agua moja y no prende durante T_MOJADO s.
	var tela: Reactivo3D = _nuevo("telarana", "", ["+mojable"])
	_ok("3 telaraña `+mojable`: el agua reacciona", tela.spell_reacts(_runa(["agua"])))
	tela.on_spell_hit(_runa(["agua"]))
	_ok("3 …la moja: está empapada y no puede arder", tela.esta_mojado() and not tela.can_burn())
	tela.on_spell_hit(_runa(["calor"]))
	_ok("3 …y el calor ya no la prende mientras está mojada", not _arde(tela))
	var tela_seca: Reactivo3D = _nuevo("telarana")
	tela_seca.on_spell_hit(_runa(["agua"]))
	_ok("3 la telaraña de serie, regada, no se moja", not tela_seca.esta_mojado() and tela_seca.can_burn())

	# Papeles puestos a una pieza que no los tenía.
	var arde_roca: Reactivo3D = _nuevo("roca", "", ["+inflamable", "+propaga_llama", "+apaga"])
	_ok("3 una pieza `roca` con `+inflamable` está en el grupo de lo que arde", arde_roca.is_in_group(Reactivo3D.GRUPO_ARDE) and arde_roca.can_burn())
	arde_roca.on_spell_hit(_runa(["calor"]))
	_ok("3 …prende con los números de un seto, sin romperse por no tener fila en COMBUSTIBLES", _arde(arde_roca))
	var hoguera: Reactivo3D = _nuevo("roca", "", ["+fuente_fuego", "+apaga"])
	hoguera.on_spell_hit(_runa(["calor"]))
	_ok("3 una pieza con `+fuente_fuego` se enciende con calor (números de la fogata)", hoguera.is_lit)
	var pesa: Reactivo3D = _nuevo("roca", "", ["+pesado"])
	_ok("3 `+pesado` la mete en el grupo de lo que pesa (las placas la notan); sin él, no", pesa.is_in_group(Reactivo3D.GRUPO_PESO) and not _nuevo("roca").is_in_group(Reactivo3D.GRUPO_PESO))
	var totem_mudo: Reactivo3D = _nuevo("totem", "fuego", ["-activable"])
	_ok("3 tótem `-activable`: no reacciona a su elemento", not totem_mudo.spell_reacts(_runa(["calor"])))
	var cond: Reactivo3D = _nuevo("seto", "", ["+conduce", "+congelable"])
	_ok("3 `conduce` y `congelable` se pueden poner (solo se declaran: aún no los lee ninguna regla)", cond.tiene_papel(Reactivo3D.P_CONDUCE) and cond.tiene_papel(Reactivo3D.P_CONGELABLE))
	var orden: Reactivo3D = _nuevo("seto", "", ["-inflamable", "+inflamable"])
	_ok("3 los retoques se aplican en orden: el último gana", orden.tiene_papel(Reactivo3D.P_INFLAMABLE))
	var sin_signo: Reactivo3D = _nuevo("roca", "", ["inflamable"])
	_ok("3 un nombre sin signo añade", sin_signo.tiene_papel(Reactivo3D.P_INFLAMABLE))


func _propiedades() -> void:
	var s: Reactivo3D = _nuevo("seto")
	_ok("4 `mojable` es false de serie", not s.mojable)
	s.mojable = true
	_ok("4 `mojable = true` pone el papel (y lo deja como `+mojable`)", s.mojable and s.tiene_papel(Reactivo3D.P_MOJABLE) and Array(s.papeles) == ["+mojable"], str(s.papeles))
	s.on_spell_hit(_runa(["agua"]))
	_ok("4 …y entonces el agua lo moja (lo que escribe Puzle3D)", s.esta_mojado())
	s.mojable = false
	_ok("4 `mojable = false` lo quita y no deja retoques sueltos", not s.mojable and s.papeles.is_empty(), str(s.papeles))
	var t: Reactivo3D = _nuevo("seto", "", ["-apaga"])
	t.mojable = true
	_ok("4 poner `mojable` no toca los demás retoques", t.mojable and not t.tiene_papel(Reactivo3D.P_APAGA))

	# La caché se invalida sola.
	var c: Reactivo3D = _nuevo("seto")
	var antes: bool = c.tiene_papel(Reactivo3D.P_INFLAMABLE)
	c.papeles = PackedStringArray(["-inflamable"])
	_ok("4 cambiar `papeles` después de preguntar se nota (caché invalidada)", antes and not c.tiene_papel(Reactivo3D.P_INFLAMABLE))
	var r2: Reactivo3D = Reactivo3D.new()
	r2.tipo = "seto"
	var antes2: bool = r2.tiene_papel(Reactivo3D.P_INFLAMABLE)
	r2.tipo = "totem"
	_ok("4 cambiar `tipo` después de preguntar también se nota", antes2 and not r2.tiene_papel(Reactivo3D.P_INFLAMABLE) and r2.tiene_papel(Reactivo3D.P_ACTIVABLE))
	r2.free()

	# Una errata no pasa por buena.
	var m: Reactivo3D = _nuevo("seto", "", ["+inflamble", "-propaga_llama"])
	_ok("4 un papel con errata se ignora y el resto de retoques valen", m.tiene_papel(Reactivo3D.P_INFLAMABLE) and not m.tiene_papel(Reactivo3D.P_PROPAGA_LLAMA) and not m.papeles_efectivos().has("inflamble"))
