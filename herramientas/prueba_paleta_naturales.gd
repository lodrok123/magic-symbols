extends SceneTree
const AJUSTE = preload("res://presentacion/ajuste_naturales_3d.gd")
var fallos: int = 0
func comprobar(bien: bool, texto: String) -> void:
	print("OK " if bien else "FALLO ",texto)
	if not bien: fallos += 1

func _initialize() -> void:
	var blanco: Color = AJUSTE.color_roca(Color(0.95,0.95,0.95,0.6))
	comprobar(blanco.get_luminance() < 0.75 and is_equal_approx(blanco.a,0.6),"Piedra clara moderada, alfa conservado")
	var madera := Color(0.6,0.3,0.1,0.25)
	comprobar(AJUSTE.color_follaje(madera,0.62,0.9).is_equal_approx(madera),"La selección verde conserva la corteza")
	for id in LechoRio3D.IDS_ROCAS:
		var modelo: Dictionary = LechoRio3D._modelo(id,LechoRio3D.ROCA_DIAM,false,false,0.78)
		comprobar(not modelo.is_empty(),"Modelo real de "+id)
		for parte in modelo.get("partes",[]):
			var mat: ShaderMaterial = parte.mat
			var tex: Texture2D = mat.get_shader_parameter("t_albedo")
			comprobar(tex != null and tex.resource_path == AJUSTE.CARPETA_ROCAS+id+".png","El lecho usa el albedo derivado de "+id)
			var original: BaseMaterial3D = parte.malla.surface_get_material(0)
			comprobar(original.albedo_texture.get_size() == tex.get_size(),"Dimensiones fuente preservadas de "+id)
			comprobar(tex.get_image().has_mipmaps(),"Mipmaps de la roca bajo el agua: "+id)
	var alga: Dictionary = LechoRio3D._modelo("alga_0",0.5,true,true,0.78)
	comprobar(not alga.is_empty(),"Alga de control disponible")
	if not alga.is_empty():
		var mat: ShaderMaterial = alga.partes[0].mat
		var base: BaseMaterial3D = alga.partes[0].malla.surface_get_material(0)
		comprobar(mat.get_shader_parameter("t_albedo") == base.albedo_texture and is_equal_approx(mat.get_shader_parameter("mece"),1.0),"Alga conserva textura original y balanceo")
	for atlas in ["M_Atlas_1","M_Atlas_3"]:
		var base: StandardMaterial3D = load("res://arte/lostcave/materiales/"+atlas+".tres")
		var nuevo: StandardMaterial3D = load("res://arte/lostcave/materiales/"+atlas+"_natural.tres")
		comprobar(base.albedo_texture != nuevo.albedo_texture,"Material independiente de "+atlas)
		comprobar(base.normal_texture == nuevo.normal_texture and base.roughness_texture == nuevo.roughness_texture,"Normal y ORM conservados de "+atlas)
		var original: Image = base.albedo_texture.get_image()
		if original.is_compressed(): original.decompress()
		var derivada: Image = nuevo.albedo_texture.get_image()
		var alfa_igual: bool = true
		for y in range(0,original.get_height(),8):
			for x in range(0,original.get_width(),8):
				if absf(original.get_pixel(x,y).a-derivada.get_pixel(x,y).a) > 0.005: alfa_igual = false
		comprobar(alfa_igual and derivada.has_mipmaps(),"Alfa preservado y mipmaps disponibles en "+atlas)
		comprobar(is_equal_approx(nuevo.alpha_scissor_threshold,TablaLostCave.FOLLAJE_CORTE_ALFA),"Corte de hojas finas en "+atlas)
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
