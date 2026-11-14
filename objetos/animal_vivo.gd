class_name AnimalVivo
extends Node3D
## Un animal de Meshy que RESPIRA y se mueve en bucle (presentacion/animal_vivo.gdshader). Monta el .glb, le pone el shader con la
## textura original y los números de su especie (ESPECIES), lo escala a su tamaño y le da una fase propia.
##   AnimalVivo.poner(padre, "cerdo", posicion, giro_y)
## Los modelos miran a −X (la cabeza) y la cola va a +X; con giro_y = 0 la cabeza apunta al oeste.

const SHADER := preload("res://presentacion/animal_vivo.gdshader")
const ESPECIES: Dictionary = {
	# Vaca rubia gallega tumbada en la paja (arte/meshy/piezas/vaca_rubia.glb): dormita. La paja de debajo no respira: el tronco va de −0,3 a 0,3.
	"vaca": {"glb": "res://arte/meshy/piezas/vaca_rubia.glb", "largo": 1.9,
		"p": {"tinte": Color(0.86, 0.8, 0.74), "suelo_y": -0.24, "resp_periodo": 4.6, "resp_amp": 0.014, "resp_tronco": Vector2(-0.28, 0.3), "cabeza_x": -0.32, "cuello": Vector3(-0.32, 0.12, 0.0),
			"cabeceo_amp": 0.05, "cabeceo_periodo": 6.5, "lado_amp": 0.03, "lado_periodo": 4.3, "hocicar": 0.0,
			"cola_x": 0.36, "raiz_cola": Vector3(0.36, 0.0, 0.0), "cola_amp": 0.35, "cola_cada": 6.0}},
	# Porco celta (arte/meshy/piezas/cerdo_celta.glb): hocica el suelo.
	"cerdo": {"glb": "res://arte/meshy/piezas/cerdo_celta.glb", "largo": 1.1,
		"p": {"resp_periodo": 2.6, "resp_amp": 0.01, "resp_tronco": Vector2(-0.2, 0.32), "cabeza_x": -0.24, "cuello": Vector3(-0.24, 0.15, 0.0),
			"cabeceo_amp": 0.05, "cabeceo_periodo": 3.2, "lado_amp": 0.09, "lado_periodo": 2.3, "hocicar": 1.0,
			"cola_x": 0.42, "raiz_cola": Vector3(0.42, 0.2, 0.0), "cola_amp": 0.6, "cola_cada": 3.5}},
}

var especie := ""


static func poner(padre: Node3D, p_especie: String, posicion: Vector3, giro_y: float = 0.0) -> AnimalVivo:
	var a := AnimalVivo.new()
	a.especie = p_especie
	a.name = p_especie.capitalize()
	padre.add_child(a)
	a.position = posicion
	a.rotation.y = giro_y
	return a


func _ready() -> void:
	var d: Dictionary = ESPECIES.get(especie, {})
	if d.is_empty() or not ResourceLoader.exists(String(d["glb"])):
		push_warning("AnimalVivo: no hay modelo para «%s»" % especie)
		return
	var modelo := (load(String(d["glb"])) as PackedScene).instantiate() as Node3D
	add_child(modelo)
	var mi := modelo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bb := mi.get_aabb()
	var k := float(d["largo"]) / bb.size.x
	modelo.scale = Vector3.ONE * k
	modelo.position.y = -bb.position.y * k            # apoyado en el suelo
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var original := mi.mesh.surface_get_material(0) as BaseMaterial3D
	if original != null:
		mat.set_shader_parameter("textura", original.albedo_texture)
	for nombre in (d["p"] as Dictionary):
		mat.set_shader_parameter(nombre, d["p"][nombre])
	mi.material_override = mat
	mi.set_instance_shader_parameter("fase", randf())
