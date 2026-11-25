extends "res://herramientas/escenario_base.gd"
## Zona temporal en Bosque02 real. Guarda solo flags de QA en output/.
const DIR = "res://output/revision_zona_blender_2026-11-25/"
const OFFSETS = [Vector2i(0,0),Vector2i(2,0),Vector2i(4,0),Vector2i(0,2),Vector2i(2,2),Vector2i(4,2),Vector2i(2,4)]
var celdas: Array[Vector2i]=[]
var piezas: Dictionary={}
var puzle: Puzle3D
var rotulo: Label
var cam: Camera3D
var zoom: float
var hoja: Image
var fotos: Array=[]
var flag_tocon: String
var flag_apagado: String

func _escenario() -> void:
	Flags.nuevo(); Estado.nuevo()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(960,600)
	await cargar("res://escenas/PruebaBosque02.tscn",true)
	if maqueta==null or jugador==null: return
	celdas=_buscar_claro()
	_ok("Existe un claro con siete posiciones libres al mismo nivel",celdas.size()==7,str(celdas))
	if celdas.size()!=7: return
	var datos:=FileAccess.open(DIR+"zona.json",FileAccess.WRITE)
	datos.store_string(JSON.stringify(celdas.map(func(c: Vector2i)->Array:return [c.x,c.y]),"  "))
	rotulo=Label.new(); rotulo.position=Vector2(20,16)
	rotulo.add_theme_font_size_override("font_size",25)
	rotulo.add_theme_constant_override("outline_size",6); rotulo.z_index=4096
	root.add_child(rotulo)
	hoja=Image.create(2880,2400,false,Image.FORMAT_RGBA8)
	_preparar_escena()
	_montar_zona()
	await avanzar_s(3.0)
	await foto("01 · Zona inicial","Bosque02 · cámara y luz del juego",_centro(),zoom)
	var fuego: RuneData=load("res://nucleo/fire_rune.tres")
	var agua: RuneData=load("res://nucleo/water_rune.tres")
	var tierra: RuneData=load("res://nucleo/earth_rune.tres")
	var tocon: Reactivo3D=piezas.tocon
	var apagado: Reactivo3D=piezas.apagado
	flag_tocon=tocon.flag_consumido; flag_apagado=apagado.flag_consumido
	tocon.on_spell_hit(fuego); apagado.on_spell_hit(fuego)
	await avanzar_s(1.2)
	_ok("Ambos tocones prenden por impacto de fuego",tocon.is_lit and apagado.is_lit)
	await foto("02 · Madera ardiendo","Dos tocones · combustión real, sin adelantar el reloj",tocon.global_position,5.5)
	apagado.on_spell_hit(agua)
	_ok("Agua interrumpe la combustión del segundo tocón",not apagado.is_lit and apagado.estado!=Reactivo3D.EstadoObj.CONSUMIDO)
	_ok("Apagar conserva carbonización parcial",apagado._combustion.progreso>0 and apagado._combustion.progreso<1)
	var carbonizacion_apagada: Dictionary=apagado._combustion.estado_carbonizacion()
	await foto("03 · Fuego apagado con agua","El tocón se conserva; quedan humedad y marcas",apagado.global_position,5.5)
	var cristal: CristalPulso3D=piezas.cristal
	cristal.on_spell_hit(tierra); await avanzar_s(0.7); cristal.on_spell_hit(tierra)
	_ok("El cristal entrega recurso y cambia de geometría",cristal.esquirla_dada and cristal._geometria_agotada)
	await avanzar_s(0.8)
	var latidos:=cristal.latidos
	cristal.latir()
	_ok("El cristal agotado sigue emitiendo pulsos",cristal.latidos==latidos+1)
	await foto("04 · Cristal agotado","Geometría truncada · conserva la función de emisor",cristal.global_position,5.5)
	var roca: MuroAgrietado3D=piezas.roca
	roca.on_spell_hit(tierra)
	_ok("Primer impacto abre grietas geométricas",roca.recibidos==1 and not roca.roto_ya and roca._cuerpo.get_meta("variante_blender","")=="roca_agrietada")
	await avanzar_s(0.4)
	await foto("05 · Roca dañada","Primer impacto · la casilla continúa bloqueada",roca.global_position,5.5)
	roca.on_spell_hit(tierra)
	await avanzar_s(0.7)
	_ok("Romper la roca libera el paso",roca.roto_ya and not Terreno3D.bloqueada(celdas[1]))
	await foto("06 · Paso abierto","Ocho fragmentos de piedra asentados",roca.global_position,5.5)
	var caldera=piezas.caldera
	caldera.on_spell_hit(fuego); caldera.on_spell_hit(tierra)
	_ok("Caldera abollada mantiene el calor",caldera.abollada and caldera.calor>0.9)
	await foto("07 · Caldera dañada y caliente","Abolladura permanente · emisión térmica",caldera.global_position,5.0)
	caldera.on_spell_hit(agua)
	_ok("Agua enfría sin reparar la abolladura",caldera.calor==0 and caldera.abollada)
	var barril=piezas.barril
	colocar_jugador(celdas[3]+Vector2i(0,1))
	await avanzar(2)
	_tecla(KEY_E,true); await avanzar(2); _tecla(KEY_E,false)
	await avanzar_s(0.7)
	_ok("E abre el barril en la escena real",barril.abierto)
	await foto("08 · Barril abierto con E","Bisagra y rótulo de interacción en el juego",barril.global_position,5.0)
	await avanzar_s(3.0)
	_ok("Tocón consumido deja restos persistentes",Flags.i().tiene(flag_tocon) and not is_instance_valid(tocon))
	_ok("El tocón apagado no se consume después",is_instance_valid(apagado) and not Flags.i().tiene(flag_apagado))
	await foto("09 · Tocón consumido","Carbón y ceniza · paso libre",Terreno3D.centro_de(celdas[4],Terreno3D.y_pies(celdas[4])),5.5)
	colocar_jugador(celdas[6])
	await foto("10 · Zona después de interactuar","Estados finales · cámara del juego",_centro(),zoom)
	_ok("Se guarda una copia de QA de las flags",Flags.i().guardar(DIR+"flags_revision.json"))
	var pose_roca: Array=[]
	var restos:=maqueta.find_child("RestosRoca",true,false)
	if restos!=null:
		for m: Node3D in restos.find_children("*","MeshInstance3D",true,false): pose_roca.append(m.transform)
	var inventario_antes: int=Estado.i().cuenta("esquirla_cristal")
	maqueta.free(); maqueta=null
	await avanzar(3)
	Flags.nuevo()
	_ok("Las flags se leen desde el archivo de QA",Flags.i().cargar(DIR+"flags_revision.json"))
	await cargar("res://escenas/PruebaBosque02.tscn",true)
	_preparar_escena(); _montar_zona()
	await avanzar_s(1.0)
	_ok("Al volver, el cristal sigue agotado",piezas.cristal.esquirla_dada and piezas.cristal._geometria_agotada)
	_ok("Al volver, la roca rota no bloquea",piezas.roca.roto_ya and not Terreno3D.bloqueada(celdas[1]))
	_ok("Al volver, permanecen la abolladura y la tapa abierta",piezas.caldera.abollada and piezas.barril.abierto)
	_ok("Al volver, el tocón consumido no se reconstruye",not is_instance_valid(piezas.tocon) and Flags.i().tiene(flag_tocon))
	_ok("El tocón apagado vuelve sin fuego y conserva su carbonización",is_instance_valid(piezas.apagado) and not piezas.apagado.is_lit and is_equal_approx(piezas.apagado._combustion.progreso,float(carbonizacion_apagada.progreso)))
	var origen_apagado:=Vector3(carbonizacion_apagada.origen[0],carbonizacion_apagada.origen[1],carbonizacion_apagada.origen[2])
	_ok("Origen de quemadura restaurado, sin calor ni humedad",piezas.apagado._combustion.origen.is_equal_approx(origen_apagado) and piezas.apagado._combustion.calor==0 and piezas.apagado._combustion.humedad==0)
	_ok("Reentrar no vuelve a entregar la esquirla",Estado.i().cuenta("esquirla_cristal")==inventario_antes)
	restos=maqueta.find_child("RestosRoca",true,false)
	var mismas: bool=restos!=null and pose_roca.size()==8
	if restos!=null:
		var meshes:=restos.find_children("*","MeshInstance3D",true,false)
		mismas=mismas and meshes.size()==pose_roca.size()
		for i in mini(meshes.size(),pose_roca.size()): mismas=mismas and meshes[i].transform.is_equal_approx(pose_roca[i])
	_ok("Los fragmentos conservan su pose después de salir y volver",mismas)
	await foto("11 · Salir y volver al nivel","Daños y apertura restaurados desde archivo",_centro(),zoom)
	await foto("12 · Quemadura parcial al volver","Mismas marcas · sin reactivar llamas, calor ni humedad",piezas.apagado.global_position,5.5)
	if DisplayServer.get_name()!="headless": hoja.save_png(DIR+"lamina_revision.png")
	var manifest:=FileAccess.open(DIR+"capturas.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(fotos,"  "))
	print("REVISION COMPLETA · fotos=",fotos.size()," · fallos=",_fallos)

func _buscar_claro() -> Array[Vector2i]:
	var mapa: PackedStringArray=maqueta.get("_mapa")
	var elegidas: Array[Vector2i]=[]
	var distancia:=1.0e20
	var spawn:=celda_jugador()
	var arboles: Array[Vector3]=[]
	# La vegetación de borde se monta por lotes y no siempre figura en registro.
	var lotes: Dictionary=maqueta.get("_lotes")
	for id_lote in lotes:
		var nombre: String=String(id_lote)
		if nombre.contains("arbol") or nombre.contains("pino") or nombre.contains("sauce") or nombre.contains("abedul"):
			for tf: Transform3D in lotes[id_lote]: arboles.append(tf.origin)
	for r: Array in maqueta.get("_registro"):
		var id: String=String(r[0])
		if id.contains("arbol") or id.contains("pino") or id.contains("sauce") or id.contains("abedul"):
			arboles.append((r[2] as Transform3D).origin)
	for y in range(2,mapa.size()-5):
		for x in range(2,mapa[y].length()-5):
			var base:=Vector2i(x,y)
			var h:=Terreno3D.altura_en(base)
			var candidatas: Array[Vector2i]=[]
			for off: Vector2i in OFFSETS:
				var c:=base+off
				if Terreno3D.altura_en(c)!=h or Terreno3D.es_agua(c) or not Terreno3D.pisable(c,h,false,h,false): break
				candidatas.append(c)
			if candidatas.size()!=7: continue
			var centro: Vector3=(Terreno3D.centro_de(candidatas[0])+Terreno3D.centro_de(candidatas[5]))*0.5
			var cerca_cofre:=false
			for cofre: Node3D in get_nodes_in_group("cofre_magico"):
				for c: Vector2i in candidatas:
					if PistaProximidad.dist_plana(cofre.global_position,Terreno3D.centro_de(c))<5.0: cerca_cofre=true
			if cerca_cofre: continue
			var tapados:=0
			for arbol: Vector3 in arboles:
				var rel: Vector3=arbol-centro
				if absf(rel.x)<6.5 and rel.z>-4 and rel.z<8: tapados+=1
			var puntuacion: float=tapados*10000.0+base.distance_squared_to(spawn)
			if puntuacion<distancia:
				distancia=puntuacion; elegidas=candidatas
	return elegidas

func _preparar_escena() -> void:
	# Conservar escena, suelo, paleta, luz y cámara reales; aislar la prueba de combate.
	for n in get_nodes_in_group("combate3d"): n.muerto=true
	maqueta.set_process(false)
	jugador.set_physics_process(false)
	cam=maqueta.get("_camara") as Camera3D
	# Usar el giro de cámara disponible en el juego para mirar el claro desde
	# el camino, evitando que la masa de pinos del borde tape la revisión.
	maqueta.set("_giro_cam",180.0)
	zoom=maxf(8.0,float(maqueta.get("_tam_camara")))
	for ui in maqueta.find_children("*","CanvasLayer",true,false): ui.visible=false
	colocar_jugador(celdas[6])

func _montar_zona() -> void:
	puzle=Puzle3D.new(); maqueta.add_child(puzle)
	var texto: String="; pieza revision_cristal cristal %d %d cada=0\n; pieza revision_roca muro %d %d modelo=roca_est_1 golpes=2\n; pieza revision_caldera caldera %d %d\n; pieza revision_barril barril_almacen %d %d" % [celdas[0].x,celdas[0].y,celdas[1].x,celdas[1].y,celdas[2].x,celdas[2].y,celdas[3].x,celdas[3].y]
	puzle.iniciar(maqueta,"qa_revision",texto)
	piezas={}
	for id in ["cristal","roca","caldera","barril"]: piezas[id]=puzle._piezas["revision_"+id].nodo
	for i in 2:
		var c:=celdas[4+i]
		var tf:=Transform3D(Basis.IDENTITY,Terreno3D.centro_de(c,Terreno3D.y_pies(c)))
		maqueta._tocon_reactivo("tocon",tf)
		var encontrado: Reactivo3D=null
		for r in get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
			if r.has_meta("tocon") and r.celda==c:
				encontrado=r
				r.hierba_cerca=Callable()
		piezas["tocon" if i==0 else "apagado"]=encontrado
	print("ZONA MONTADA · ",celdas)

func _centro() -> Vector3:
	return (Terreno3D.centro_de(celdas[0],Terreno3D.y_pies(celdas[0]))+Terreno3D.centro_de(celdas[5],Terreno3D.y_pies(celdas[5])))*0.5

func foto(titulo: String, nota: String, foco: Vector3, tam: float) -> void:
	rotulo.text=titulo+"\n"+nota
	maqueta.set("_giro_cam",0.0 if titulo.begins_with("07") else 180.0)
	# Solo ocultar avisos de sala y paneles de HUD para esta captura. La pista E
	# común queda visible y sigue usando su flujo real.
	for capa: CanvasLayer in root.find_children("*","CanvasLayer",true,false):
		capa.visible=capa.layer==PistaProximidad.CAPA
	maqueta.set("_foco",foco+Vector3.UP*0.5)
	maqueta._colocar_camara()
	cam.size=tam
	Ocluso3D.actualizar(jugador.global_position+Vector3.UP*0.7,1.0)
	for i in 12: await process_frame
	var ruta: String="captura_%02d.png"%fotos.size()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var im:=root.get_texture().get_image(); im.convert(Image.FORMAT_RGBA8)
		im.save_png(DIR+ruta)
		hoja.blit_rect(im,Rect2i(0,0,960,600),Vector2i((fotos.size()%3)*960,(fotos.size()/3)*600))
	fotos.append({"titulo":titulo,"nota":nota,"archivo":ruta,"tam_camara":tam})
	print("FOTO ",fotos.size()," · ",titulo)
