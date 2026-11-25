extends SceneTree
const DIR="res://output/carbonizacion_persistente_2026-11-25/"
var fallos:=0
class Fabrica extends "res://presentacion/prueba_test2.gd":
	func _pieza(id: String) -> Node3D:
		var raiz:=Node3D.new()
		raiz.add_child(Pieza3D.crear_visual(id))
		return raiz
func ok(cond: bool, mensaje: String) -> void:
	print("OK " if cond else "FALLO ",mensaje)
	if not cond: fallos+=1
func _initialize() -> void: call_deferred("correr")
func correr() -> void:
	Flags.nuevo(); Estado.nuevo(); Ocluso3D.preparar(); Pieza3D._cargar_bibliotecas()
	Terreno3D.cargar_datos(PackedStringArray(["..........","..........","..........","..........",".........."]),{})
	Terreno3D.alto_suelo=0
	var mundo:=Node3D.new(); root.add_child(mundo)
	var fx:=Vfx3D.new(); mundo.add_child(fx)
	var f:=Fabrica.new(); f._fx=fx
	f._props=Node3D.new(); mundo.add_child(f._props)
	var tf:=Transform3D(Basis(Vector3.UP,0.7).scaled(Vector3(1.2,0.9,1.1)),Vector3(3,0,3))
	f._tocon_reactivo("tocon",tf)
	var r: Reactivo3D=f._props.get_child(0)
	r.hierba_cerca=Callable()
	var clave: String=r.flag_consumido
	var impacto: Vector3=r.to_global(Vector3(0.1,0.2,0.1))
	r.ignite(impacto); r.set_process(false)
	r._process(float(r._num_combustible()[0])*0.35)
	r._apagar()
	var parcial: Dictionary=r._combustion.estado_carbonizacion()
	ok(parcial.progreso>0.3 and parcial.progreso<0.4,"Quemadura parcial real al apagar")
	ok(not Flags.i().tiene(clave) and Flags.i().tiene(clave+".carbonizacion"),"Estado parcial separado de consumo")
	ok(Flags.i().guardar(DIR+"flags_parciales.json"),"Guardar flags en archivo de QA")
	f._props.free(); await process_frame
	Flags.nuevo(); ok(Flags.i().cargar(DIR+"flags_parciales.json"),"Recuperar flags desde disco")
	f._props=Node3D.new(); mundo.add_child(f._props)
	f._tocon_reactivo("tocon",tf)
	r=f._props.get_child(0)
	ok(not r.is_lit and r.estado==Reactivo3D.EstadoObj.SANO,"Recargar no reactiva fuego ni consume el tocón")
	ok(absf(r._combustion.progreso-float(parcial.progreso))<0.00001,"Restaurar el mismo progreso")
	var origen:=Vector3(parcial.origen[0],parcial.origen[1],parcial.origen[2])
	ok(r._combustion.origen.is_equal_approx(origen) and is_equal_approx(r._combustion.radio,float(parcial.radio)),"Restaurar el mismo origen y radio en espacio local")
	ok(r._combustion.focos.is_empty() and r._combustion._luz==null and r._combustion.calor==0 and r._combustion.humedad==0,"No recrear llamas, luz, calor ni humedad")
	ok(r._combustion.materiales.all(func(m: ShaderMaterial)->bool:return is_equal_approx(float(m.get_shader_parameter("combustion_progreso")),float(parcial.progreso))),"El material visible conserva la quemadura")
	r._montar_combustion()
	ok(is_equal_approx(r._combustion.progreso,float(parcial.progreso)) and r._combustion.origen.is_equal_approx(origen),"Remontar el componente mantiene el frente")
	r.ignite(r.to_global(Vector3(-0.1,0.3,-0.1))); r.set_process(false)
	ok(is_equal_approx(r._combustion.progreso,float(parcial.progreso)) and r._combustion.origen.is_equal_approx(origen),"Reprender continúa desde las mismas marcas")
	r._process(float(r._num_combustible()[0])*0.2)
	ok(r._combustion.progreso>float(parcial.progreso),"La segunda combustión avanza")
	r._apagar()
	var avance: float=r._combustion.progreso
	ok(Flags.i().guardar(DIR+"flags_reapagado.json"),"Guardar el segundo apagado")
	f._props.free(); await process_frame
	Flags.nuevo(); Flags.i().cargar(DIR+"flags_reapagado.json")
	f._props=Node3D.new(); mundo.add_child(f._props); f._tocon_reactivo("tocon",tf)
	r=f._props.get_child(0)
	ok(is_equal_approx(r._combustion.progreso,avance) and not r.is_lit,"Segundo ciclo de recarga sin reiniciar el daño")
	var consumidos: Array=[0]
	r.consumido.connect(func(_c: Vector2i)->void: consumidos[0]+=1)
	r.ignite(); r.set_process(false); r._process(float(r._num_combustible()[0])+0.01)
	var botin: Array=r.soltado.duplicate(true)
	r._consumir()
	ok(consumidos[0]==1 and r.soltado==botin,"Consumir una sola vez sin duplicar botín")
	ok(Flags.i().tiene(clave) and not Flags.i().tiene(clave+".carbonizacion"),"Consumo definitivo limpia el estado parcial")
	ok(f._props.find_children("RestosQuemados*","Node3D",true,false).size()==1,"Un único conjunto de restos")
	f._props.free(); await process_frame
	f._props=Node3D.new(); mundo.add_child(f._props); f._tocon_reactivo("tocon",tf)
	ok(f._props.get_child_count()==1 and f._props.get_child(0).name=="RestosQuemados","Volver tras consumo restaura solo restos")
	var madera: Reactivo3D=f._reactivo_pieza("puerta_goblin","puerta_goblin",Vector2i(4,2),0.0,false,false)
	ok(madera!=null and madera.clave_carbonizacion!="","La madera de la fábrica recibe una clave estable")
	madera.hierba_cerca=Callable(); madera.ignite(); madera.set_process(false)
	madera._process(float(madera._num_combustible()[0])*0.25); madera._apagar()
	var clave_madera: String=madera.clave_carbonizacion
	var parcial_madera: float=madera._combustion.progreso
	madera.free()
	madera=f._reactivo_pieza("puerta_goblin","puerta_goblin",Vector2i(4,2),0.0,false,false)
	ok(madera.clave_carbonizacion==clave_madera and is_equal_approx(madera._combustion.progreso,parcial_madera) and not madera.is_lit,"El mismo sistema restaura la madera de puerta")
	var c:=madera._combustion
	var anterior: float=c.progreso
	ok(not c.restaurar_carbonizacion({"version":1,"origen":[0,0,0],"progreso":"invalido","radio":1}) and c.progreso==anterior,"Estado inválido no destruye el frente actual")
	ok(not c.restaurar_carbonizacion({"version":{},"origen":[0,0,0],"progreso":0.5,"radio":1}) and c.progreso==anterior,"Versión corrupta se ignora sin modificar la pieza")
	f.free(); mundo.free(); await process_frame
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
