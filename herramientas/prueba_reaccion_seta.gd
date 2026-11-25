extends SceneTree
var fallos: int = 0
func comprobar(b: bool,t: String) -> void:
	print("OK " if b else "FALLO ",t)
	if not b: fallos += 1
func runa(via: String) -> RuneData:
	var r := RuneData.new()
	match via:
		"viento": r.estado = "gas"; r.empuje = 1.0
		"agua": r.modificadores = {"humedad":{"op":"fija","valor":1.0}}
		"hielo": r.modificadores = {"temperatura":{"op":"fija","valor":-1.0}}
		"fuego": r.modificadores = {"temperatura":{"op":"fija","valor":1.0}}
	return r
func crear(variante: String = "roja") -> Recolectable3D:
	var r := Recolectable3D.new()
	r.preparar(Vector2i.ZERO,variante)
	r.madura = true
	root.add_child(r)
	return r
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	Terreno3D.cargar_datos(PackedStringArray(["....","....","....","...."]),{})
	Terreno3D.alto_suelo = 0.0
	comprobar(Objetos.PLANTAS["seta_resonante"]["tabla"] == {"viento":"esporas_luminosas","hielo":"seta_cristalizada"},"La cadena resonante sale de las filas existentes de fuentes.tsv")
	var pulso := Pulso3D.new()
	for variante in ["roja","azul","marron"]:
		for via in ["viento","hielo","agua"]:
			Estado.nuevo()
			var r: Recolectable3D = crear(variante)
			var forma: CollisionShape3D = r.find_children("*","CollisionShape3D",true,false)[0]
			var radio: float = forma.shape.radius
			r.on_spell_hit(runa(via),Vector3.RIGHT)
			var esperado: String = {"viento":"esporas","hielo":"seta_helada","agua":"seta_humeda"}[via]
			comprobar(r.objeto == esperado and r._reaccion_seta.tipo == via,variante+" "+via+" entrega el ingrediente correcto")
			comprobar(not r._reaccion_seta.materiales.is_empty() and r._reaccion_seta.particulas.size()>0,"Materiales y reacción propios: "+variante+" "+via)
			comprobar(forma.shape.radius==radio and r.collision_layer==Lanzador3D.CAPA_REACTIVO,"La presentación no cambia el acierto")
			comprobar(not r.spell_reacts(runa(via)) and not r.on_pulso(pulso),"Una transformación normal no encadena ni madura")
			if via == "hielo":
				await create_timer(0.35).timeout
				comprobar(r._reaccion_seta.materiales[0].get_shader_parameter("seta_hielo")>0.95,"Escarcha persistente en el material visible")
			elif via == "agua":
				comprobar(r._reaccion_seta.materiales[0].get_shader_parameter("seta_agua")==1.0,"Acabado húmedo en el material visible")
			elif via == "viento":
				await create_timer(0.07).timeout
				comprobar(r._reaccion_seta.materiales[0].get_shader_parameter("seta_contraccion")>0.1,"El sombrero se contrae durante la salida de esporas")
			if via != "hielo":
				r._reaccion_seta._process(2.0)
				comprobar(r._reaccion_seta.particulas.is_empty(),"Las partículas transitorias se retiran sin cambiar el ingrediente")
			comprobar(r.recoger() and Estado.i().cuenta(esperado)==1 and not r.visible_en_mundo(),"Se recoge exactamente el ingrediente mostrado")
			r.free()
	for via in ["viento","hielo"]:
		Estado.nuevo()
		var r: Recolectable3D = crear()
		comprobar(r.on_pulso(pulso) and r.objeto=="seta_resonante","Pulso madura la seta")
		comprobar(r.spell_reacts(runa(via)) and not r.spell_reacts(runa("agua")) and not r.spell_reacts(runa("fuego")),"Resonante admite solo sus dos vías declaradas")
		r.on_spell_hit(runa(via))
		var resultado: String = "esporas_luminosas" if via=="viento" else "seta_cristalizada"
		comprobar(r.objeto==resultado and r._reaccion_seta.luminosa,"Pulso + "+via+" da "+resultado)
		comprobar(not r.spell_reacts(runa("viento")) and not r.spell_reacts(runa("hielo")) and not r.on_pulso(pulso),"El resultado resonante es terminal")
		comprobar(r.recoger() and Estado.i().cuenta(resultado)==1,"Resultado encadenado recogible")
		r.free()
	Estado.nuevo()
	var r: Recolectable3D = crear()
	r.rebrota = 0.1
	r.on_spell_hit(runa("agua"))
	r.recoger()
	r._process(0.2)
	comprobar(r.objeto=="seta" and not r.recogido_ya and r._reaccion_seta.tipo=="","Rebrotar restaura ingrediente y presentación base")
	comprobar(r._reaccion_seta.materiales[0].get_shader_parameter("seta_agua")==0.0,"La nueva seta no hereda humedad de la anterior")
	r.free()
	r = crear()
	r.disponible = false
	r.on_spell_hit(runa("viento"))
	comprobar(r.objeto=="seta" and not r.on_pulso(pulso),"Una seta no disponible no reacciona ni madura")
	r.free()
	pulso.free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
