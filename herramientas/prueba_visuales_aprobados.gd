extends SceneTree
## QA de la aplicación del lote A. El control físico usa las cuatro escenas
## originales copiadas a output/opcion_a_aplicada_2026-11-24/antes antes de hornear.
const P = preload("res://herramientas/propuesta_sustituciones_assets.gd")
const FABRICA = preload("res://presentacion/prueba_test2.gd")
const DATOS = {"setas_amarillas":[1500,0.35],"caja":[4684,0.8],"caja_pequena":[4684,0.6],"barril":[816,0.8]}
var fallos: int = 0
func comprobar(b: bool, mensaje: String) -> void:
	print("OK " if b else "FALLO ",mensaje)
	if not b: fallos += 1
func _initialize() -> void:
	call_deferred("correr")
func correr() -> void:
	Pieza3D._cargar_bibliotecas()
	var fabrica = FABRICA.new()
	for id in DATOS:
		for via in ["visual","maqueta","horneada"]:
			var n: Node3D
			if via == "visual": n = Pieza3D.crear_visual(id)
			elif via == "maqueta": n = fabrica._pieza(id)
			else: n = (load("res://arte/piezas/"+id+".tscn") as PackedScene).instantiate()
			comprobar(n != null,id+" disponible: "+via)
			if n == null: continue
			var caja: AABB = Pieza3D._caja(n,Transform3D.IDENTITY)
			comprobar(P.triangulos(n) == DATOS[id][0],id+" geometría A: "+via)
			comprobar(absf(caja.size.y-DATOS[id][1])<0.002 and absf(caja.position.y)<0.002,id+" altura y base: "+via)
			if via != "horneada":
				comprobar(n.find_children("*","CollisionObject3D",true,false).is_empty(),id+" visual sin cuerpos extra")
			else:
				var anterior: Node3D = (load("res://output/opcion_a_aplicada_2026-11-24/antes/"+id+".tscn") as PackedScene).instantiate()
				var nuevas: Array[Node] = n.find_children("*","CollisionShape3D",true,false)
				var previas: Array[Node] = anterior.find_children("*","CollisionShape3D",true,false)
				comprobar(nuevas.size()==previas.size(),id+" cantidad de colisiones conservada")
				for i in mini(nuevas.size(),previas.size()):
					comprobar(var_to_str(nuevas[i].shape.points)==var_to_str(previas[i].shape.points) and nuevas[i].transform==previas[i].transform,id+" contorno físico conservado")
				for k in anterior.get_meta_list(): comprobar(n.get_meta(k)==anterior.get_meta(k),id+" metadato "+k)
				anterior.free()
			n.free()
	fabrica.free()
	comprobar(PiezaPuzle3D.MODELO_ARCHIVO["barril"]=="puzle_terrain","Pólvora conserva el modelo con calavera")
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
