extends SceneTree
const ACTOR = preload("res://objetos/interaccion_blender_3d.gd")
const B = preload("res://presentacion/estados_blender_3d.gd")
var fallos:=0
class LanzadorPrueba extends Node:
	var jugador: Node3D
class FabricaTocon extends "res://presentacion/prueba_test2.gd":
	func _pieza(_id: String) -> Node3D:
		var raiz:=Node3D.new()
		raiz.add_child(Pieza3D.crear_visual("tocon"))
		return raiz
func ok(cond: bool, mensaje: String) -> void:
	print("OK " if cond else "FALLO ",mensaje)
	if not cond: fallos+=1
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	Flags.nuevo(); Estado.nuevo()
	Terreno3D.cargar_datos(PackedStringArray(["..........","..........","..........","..........",".........."]),{})
	Terreno3D.alto_suelo=0.0
	Pieza3D._cargar_bibliotecas(); Ocluso3D.preparar()
	var mundo:=Node3D.new(); root.add_child(mundo)
	var tierra:=RuneData.new(); tierra.estado="solido"
	tierra.modificadores={"densidad":{"op":"fija","valor":2.0}}
	var cristal:=CristalPulso3D.new()
	cristal.name="cristal"; cristal.nivel="qa"; cristal.cada=0
	mundo.add_child(cristal)
	var luces:=cristal.find_children("*","Light3D",true,false).size()
	cristal._contar_golpe(); cristal._contar_golpe()
	ok(cristal.esquirla_dada and cristal._geometria_agotada,"Extraer cambia la geometría del cristal")
	ok(Flags.i().tiene(cristal.flag_esquirla()) and not cristal._mats.is_empty(),"Cristal guarda agotamiento y conserva material de pulso")
	ok(cristal.find_children("*","Light3D",true,false).size()==luces,"Agotar no duplica luces")
	var latidos:=cristal.latidos; cristal._enfriando=0; cristal.latir()
	ok(cristal.latidos==latidos+1,"Cristal agotado sigue emitiendo pulsos")
	cristal.free()
	var recarga:=CristalPulso3D.new(); recarga.name="cristal"; recarga.nivel="qa"; recarga.cada=0
	mundo.add_child(recarga)
	ok(recarga._geometria_agotada,"Cristal agotado se restaura por flag")
	var roca:=MuroAgrietado3D.new()
	roca.modelo_id="roca_est_1"; roca.flag_dano="qa.roca.estado"
	roca.preparar(Vector2i(2,2),2); mundo.add_child(roca)
	roca.on_spell_hit(tierra)
	ok(roca.recibidos==1 and roca._cuerpo.get_meta("variante_blender","")=="roca_agrietada","Primer impacto abre las grietas de la roca")
	roca.free()
	roca=MuroAgrietado3D.new(); roca.modelo_id="roca_est_1"; roca.flag_dano="qa.roca.estado"
	roca.preparar(Vector2i(2,2),2); mundo.add_child(roca)
	ok(roca.recibidos==1 and not roca.roto_ya,"Roca restaura el daño intermedio")
	roca.on_spell_hit(tierra)
	ok(roca.roto_ya and not Terreno3D.bloqueada(Vector2i(2,2)),"Último impacto libera la casilla")
	var restos: Node3D=mundo.get_node("RestosRoca")
	ok(restos.find_children("*","MeshInstance3D",true,false).size()==8,"Rotura usa ocho fragmentos de piedra reales")
	await create_timer(0.65).timeout
	var poses: Array[Transform3D]=[]
	for p: Node3D in restos.find_children("*","MeshInstance3D",true,false): poses.append(p.transform)
	restos.free(); roca.free()
	roca=MuroAgrietado3D.new(); roca.modelo_id="roca_est_1"; roca.flag_dano="qa.roca.estado"
	roca.preparar(Vector2i(2,2),2); mundo.add_child(roca)
	ok(roca.roto_ya and roca.collision_layer==0,"Roca rota no vuelve a bloquear al recargar")
	var meshes:=mundo.get_node("RestosRoca").find_children("*","MeshInstance3D",true,false)
	var mismas:=true
	for i in meshes.size(): mismas=mismas and meshes[i].transform.is_equal_approx(poses[i])
	ok(mismas,"Fragmentos de roca conservan la pose al recargar")
	var caldera=ACTOR.new(); caldera.preparar(Vector2i(4,2),"caldera","qa.caldera.dano"); mundo.add_child(caldera)
	ok(caldera.spell_reacts(tierra),"La previsión anuncia el impacto sólido sobre la caldera")
	caldera.poner_calor(0.8); caldera.on_spell_hit(tierra)
	ok(caldera.abollada and caldera.calor==0.8 and caldera.visual.get_meta("variante_blender","")=="caldera_abollada","Caldera se abolla y conserva su calor")
	ok(caldera._hierro.any(func(m: StandardMaterial3D)->bool: return m.emission_enabled),"La caldera dañada conserva emisión térmica")
	ok(not caldera.spell_reacts(tierra) and caldera.spell_reacts(load("res://nucleo/fire_rune.tres")),"La previsión distingue daño agotado de calor todavía reactivo")
	caldera.free(); caldera=ACTOR.new(); caldera.preparar(Vector2i(4,2),"caldera","qa.caldera.dano"); mundo.add_child(caldera)
	ok(caldera.abollada,"Abolladura permanente al recargar")
	var barril=ACTOR.new(); barril.preparar(Vector2i(6,2),"barril_almacen","qa.barril.abierto"); mundo.add_child(barril)
	barril.poner_abierto(true)
	await create_timer(0.65).timeout
	ok(barril.abierto and absf(barril._bisagra.rotation.x)>1.7,"Barril abre su tapa con bisagra")
	barril.free(); barril=ACTOR.new(); barril.preparar(Vector2i(6,2),"barril_almacen","qa.barril.abierto"); mundo.add_child(barril)
	ok(barril.abierto and absf(barril._bisagra.rotation.x)>1.7,"Barril restaura apertura sin repetir animación")
	barril.poner_abierto(false,false)
	ok(not Flags.i().tiene("qa.barril.abierto") and is_zero_approx(barril._bisagra.rotation.x),"Cerrar limpia la flag y devuelve la tapa")
	var lanzador:=LanzadorPrueba.new(); lanzador.jugador=Node3D.new()
	mundo.add_child(lanzador.jugador); mundo.add_child(lanzador); lanzador.add_to_group("spellcaster")
	var tecla:=InputEventAction.new(); tecla.action="interactuar"; tecla.pressed=true
	lanzador.jugador.global_position=barril.global_position+Vector3(8,0,0)
	barril._unhandled_input(tecla)
	ok(not barril.abierto,"E fuera de alcance no abre el barril")
	lanzador.jugador.global_position=barril.global_position+Vector3(0,0,1)
	barril._unhandled_input(tecla)
	ok(barril.abierto,"E cerca abre el barril")
	barril._unhandled_input(tecla)
	ok(not barril.abierto,"Otra pulsación de E cierra el barril")
	lanzador.jugador.free(); lanzador.free()
	var fx:=Vfx3D.new(); mundo.add_child(fx)
	var tocon:=Reactivo3D.new(); tocon.set_meta("tocon","tocon"); tocon.flag_consumido="qa.tocon.consumido"
	var visual:=Pieza3D.crear_visual("tocon"); tocon.add_child(visual)
	tocon.preparar("tronco",Vector2i(8,2),"",fx,visual); mundo.add_child(tocon)
	tocon._consumir()
	ok(Flags.i().tiene("qa.tocon.consumido"),"Consumir tocón guarda su flag")
	var quemado: Node3D=mundo.get_node("RestosQuemados")
	ok(quemado.get_node_or_null("tocon_quemado")!=null and quemado.get_node_or_null("ceniza")!=null,"Tocón consumido deja tocón quemado y ceniza")
	ok(quemado.find_children("*","CollisionObject3D",true,false).is_empty(),"Restos quemados no crean obstáculos")
	var fabrica:=FabricaTocon.new()
	fabrica._props=Node3D.new(); mundo.add_child(fabrica._props); fabrica._fx=fx
	var tf:=Transform3D(Basis(Vector3.UP,0.5),Vector3(2,0,2))
	ok(fabrica._tocon_reactivo("tocon",tf),"Fábrica del nivel coloca un tocón reactivo")
	var tronco: Reactivo3D=fabrica._props.get_child(0)
	var clave: String=tronco.flag_consumido
	tronco._consumir()
	ok(Flags.i().tiene(clave),"Fábrica usa una clave estable y válida")
	fabrica._props.free(); fabrica._bloqueadas.clear()
	fabrica._props=Node3D.new(); mundo.add_child(fabrica._props)
	fabrica._tocon_reactivo("tocon",tf)
	ok(fabrica._props.get_child_count()==1 and fabrica._props.get_child(0).name=="RestosQuemados" and fabrica._bloqueadas.is_empty(),"Recargar tocón restaura restos sin recrear combustible ni bloqueo")
	fabrica.free()
	var parsed:=Puzle3D.parsear("; pieza cal caldera 1 1\n; pieza ba barril_almacen 2 1\n; pieza ro muro 3 1 modelo=roca_est_1 flag=qa.roca.otro")
	ok(parsed.avisos.is_empty() and parsed.piezas.size()==3,"Gramática acepta caldera, barril y roca destructible")
	var falso=preload("res://herramientas/prueba_puzle.gd").MundoFalso.new()
	falso._props=Node3D.new(); falso.add_child(falso._props); root.add_child(falso)
	var puzle:=Puzle3D.new(); falso.add_child(puzle)
	puzle.iniciar(falso,"qa_montaje","; pieza cal caldera 1 4\n; pieza ba barril_almacen 2 4\n; pieza ro muro 3 4 modelo=roca_est_1\n; puzle abre cuando=ba.abierto hace=cal.abollar")
	var ba: Node=puzle._piezas["ba"].nodo
	var cal: Node=puzle._piezas["cal"].nodo
	ok(ba!=null and cal!=null and puzle._piezas["ro"].nodo!=null,"Puzle coloca los tres actores nuevos")
	ba.abrir()
	ok(cal.abollada,"Señal de apertura dispara una acción de puzle")
	falso.free()
	# Esperar bajas diferidas antes de cerrar el servidor gráfico.
	mundo.free()
	await process_frame
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
