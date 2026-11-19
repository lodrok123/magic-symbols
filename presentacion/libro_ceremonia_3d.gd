class_name LibroCeremonia3D
extends Node3D
## Recurso articulado generado localmente. Tapas, páginas y destino en el mismo espacio 3D.
var izquierda: Node3D
var derecha: Node3D
var pagina: Marker3D
var inscripcion: MeshInstance3D
var apertura: float = 0.0

func preparar(nivel: int = 1) -> void:
	var colores := [Color(0.24, 0.15, 0.07), Color(0.06, 0.22, 0.42), Color(0.36, 0.08, 0.12)]
	var cuero: Color = colores[clampi(nivel - 1, 0, 2)]
	_parte(self, Vector3(0.08, 0.09, 0.72), Vector3.ZERO, cuero)
	izquierda = Node3D.new()
	derecha = Node3D.new()
	add_child(izquierda)
	add_child(derecha)
	for par: Array in [[izquierda, -1.0], [derecha, 1.0]]:
		var pivote: Node3D = par[0]
		var signo: float = par[1]
		_parte(pivote, Vector3(0.48, 0.045, 0.74), Vector3(signo * 0.24, -0.035, 0), cuero)
		_parte(pivote, Vector3(0.44, 0.055, 0.68), Vector3(signo * 0.24, 0.015, 0), Color(0.68, 0.59, 0.43))
		for z: float in [-0.32, 0.32]:
			_parte(pivote, Vector3(0.40, 0.006, 0.012), Vector3(signo * 0.24, 0.045, z), Color(0.65, 0.43, 0.15))
		# Filetes del papel; se mueven junto a cada tapa.
		for y: float in [0.0, 0.013, 0.026]:
			_parte(pivote, Vector3(0.44, 0.002, 0.66), Vector3(signo * 0.24, y, 0), Color(0.66, 0.55, 0.36))
	pagina = Marker3D.new()
	pagina.name = "DestinoRuna"
	derecha.add_child(pagina)
	pagina.position = Vector3(0.24, 0.052, 0)
	poner_apertura(0.0)

func _parte(padre: Node3D, tam: Vector3, pos: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.75
	m.material_override = mat
	padre.add_child(m)

func poner_apertura(v: float) -> void:
	apertura = clampf(v, 0, 1)
	izquierda.rotation.z = lerpf(-PI * 0.49, -0.06, apertura)
	derecha.rotation.z = lerpf(PI * 0.49, 0.06, apertura)

func inscribir(tex: Texture2D, progreso: float) -> void:
	if inscripcion == null:
		inscripcion = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.34, 0.43)
		inscripcion.mesh = q
		pagina.add_child(inscripcion)
		inscripcion.rotation.x = -PI / 2.0
		inscripcion.position.y = 0.003
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		inscripcion.material_override = mat
	var material := inscripcion.material_override as StandardMaterial3D
	material.albedo_color = Color(0.20, 0.11, 0.035, clampf(progreso, 0, 1))
	material.emission_enabled = true
	material.emission = Color(1.0, 0.72, 0.18)
	material.emission_energy_multiplier = sin(clampf(progreso, 0, 1) * PI) * 0.8
