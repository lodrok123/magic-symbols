class_name CofreEstrellas3D
extends Node3D
## Emblemas físicos: el número identifica la calidad incluso sin color.
const NUMERO := {"comun": 1, "epico": 2, "legendario": 3}
var estrellas: Array[MeshInstance3D] = []
var color: Color = Color.WHITE

func preparar(calidad: String, caja: AABB) -> void:
	color = Objetos.CALIDADES.get(calidad, Objetos.CALIDADES["comun"])["color"]
	var cantidad: int = int(NUMERO.get(calidad, 1))
	var radio: float = minf(caja.size.x / (cantidad * 3.5), caja.size.y * 0.17)
	var placa := MeshInstance3D.new()
	var caja_placa := BoxMesh.new()
	caja_placa.size = Vector3(radio * (cantidad * 2.65 + 0.5), radio * 2.6, 0.025)
	placa.mesh = caja_placa
	placa.position = Vector3(caja.get_center().x, caja.position.y + caja.size.y * 0.32, caja.end.z + 0.03)
	var fondo := StandardMaterial3D.new()
	fondo.albedo_color = Color(0.055, 0.04, 0.03)
	placa.material_override = fondo
	add_child(placa)
	for i in cantidad:
		var m := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 10:
			for v: Vector3 in [Vector3.ZERO, _punta(k, radio), _punta((k + 1) % 10, radio)]:
				st.set_normal(Vector3.BACK)
				st.add_vertex(v)
		m.mesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.25
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.metallic = 0.35
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		m.position = Vector3(caja.get_center().x + (i - (cantidad - 1) * 0.5) * radio * 2.65, caja.position.y + caja.size.y * 0.32, caja.end.z + 0.047)
		add_child(m)
		estrellas.append(m)

func _punta(k: int, radio: float) -> Vector3:
	var a: float = PI * 0.5 + k * TAU / 10.0
	var r: float = radio if k % 2 == 0 else radio * 0.43
	return Vector3(cos(a) * r, sin(a) * r, 0)

func iluminar(progreso: float, abierto: bool = false) -> void:
	for i in estrellas.size():
		var mat := estrellas[i].material_override as StandardMaterial3D
		var pulso: float = clampf(progreso * estrellas.size() - i, 0.0, 1.0)
		mat.emission_energy_multiplier = 0.12 if abierto else lerpf(0.25, 1.6, pulso)
