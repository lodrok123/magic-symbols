extends SceneTree
## MEDIDA de albedos (Pipeline, 22/10, PLAN_EOW_VISUAL §1.2): por TEXTURA, luminancia (Rec.709 sobre sRGB 0-255, como la de «25–45 niveles») media, desviación,
## percentiles 5/95 y rango p95-p5 de cada textura de suelo, de la hierba y de las piezas del decorado del Bosque 01 (con el número de instancias que las usan).
## Escribe un TSV (3.er argumento) y lo imprime. `activo` = 1 mide el valor EFECTIVO (con las constantes de Albedos3D aplicadas: compresión hacia la media + brillo).
##   godot --headless --path . --script res://herramientas/medir_albedos.gd -- <salida.tsv> [escena] [0|1]
const SUELO: String = "res://arte/suelo_meshy/"
const TEXTURAS_SUELO: Array = [["hierba", "hierba_arriba.png"], ["camino", "path_arriba.png"], ["tierra", "tierra_arriba.png"], ["piedra", "losas_piedra.png"],
	["hierba_matojos", "hierba_matojos.png"], ["cuerpo", "cuerpo.png"], ["lecho_rio", "lecho_rio.png"]]

var _salida: PackedStringArray = []


func _initialize() -> void:
	_correr()


## Estadística de luminancia (0-255, Rec.709 sobre el nivel sRGB final) de lo que el shader DEJA en el albedo: pasa a lineal, comprime hacia la media
## (por canal, como el shader: `m + (c - m) * k`), multiplica por `v` y por `b` (el `brillo` del suelo) y vuelve a sRGB. Los píxeles con alfa < 0,5 no cuentan.
## k = v = b = 1 da la estadística cruda de la imagen.
static func estadistica(img: Image, k: float = 1.0, v: float = 1.0, b: float = 1.0) -> Dictionary:
	var im: Image = img.duplicate()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var w: int = im.get_width()
	var h: int = im.get_height()
	var paso: int = maxi(1, int(sqrt(float(w * h) / 65536.0)))
	var lin: Array = []
	var m := Vector3.ZERO
	for y in range(0, h, paso):
		for x in range(0, w, paso):
			var c: Color = im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var l: Color = c.srgb_to_linear()
			lin.append(Vector3(l.r, l.g, l.b))
			m += Vector3(l.r, l.g, l.b)
	var n: int = lin.size()
	if n == 0:
		return {"n": 0, "media": 0.0, "desv": 0.0, "p5": 0.0, "p95": 0.0}
	m /= float(n)
	var lum := PackedFloat32Array()
	lum.resize(n)
	var suma: float = 0.0
	for i in n:
		var c2: Vector3 = (m + (lin[i] - m) * k) * v * b
		var s := Color(maxf(c2.x, 0.0), maxf(c2.y, 0.0), maxf(c2.z, 0.0)).linear_to_srgb()
		var l2: float = (0.2126 * s.r + 0.7152 * s.g + 0.0722 * s.b) * 255.0
		lum[i] = l2
		suma += l2
	var media: float = suma / float(n)
	var q: float = 0.0
	for l3 in lum:
		q += (l3 - media) * (l3 - media)
	var orden: PackedFloat32Array = lum.duplicate()
	orden.sort()
	return {"n": n, "media": media, "desv": sqrt(q / float(n)), "p5": orden[int(0.05 * float(n - 1))], "p95": orden[int(0.95 * float(n - 1))]}


## Crudo y efectivo en una línea: media/desv/rango de la imagen tal cual y de lo que queda tras el shader.
func _fila(familia: String, nombre: String, img: Image, k: float, v: float, b: float, usos: int = 0) -> Dictionary:
	var c: Dictionary = estadistica(img)
	var e: Dictionary = estadistica(img, k, v, b)
	var s: String = "%s\t%s\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f" % [familia, nombre, usos, c["media"], c["desv"], c["p95"] - c["p5"],
		e["media"], e["desv"], e["p5"], e["p95"], e["p95"] - e["p5"]]
	_salida.append(s)
	print(s)
	return e


static func familia_de_ruta(ruta: String) -> String:
	if "suelo_meshy" in ruta:
		return "bloque"
	if "/modelos/" in ruta or "/equipo/" in ruta or "/escritura/" in ruta or "magia_0" in ruta or "emberheart" in ruta:
		return "otro"
	return "pieza"

func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var ruta_salida: String = a[0] if a.size() > 0 else "res://docs/capturas/albedos/medidas.tsv"
	var escena: String = a[1] if a.size() > 1 else "res://escenas/PruebaBosque01.tscn"
	var activo: bool = a.size() > 2 and a[2] == "1"
	Albedos3D.activo = activo
	var oscurecer: float = float((load("res://presentacion/prueba_test2.gd") as GDScript).get_script_constant_map()["OSCURECER_SUELO"])
	print("familia\tnombre\tusos\tcrudo_media\tcrudo_desv\tcrudo_rango\tefec_media\tefec_desv\tefec_p5\tefec_p95\tefec_rango  (luminancia 0-255 sRGB; albedos_eow=%s; brillo del suelo %.2f)" % [str(activo), oscurecer])
	for par in TEXTURAS_SUELO:
		var ruta: String = SUELO + str(par[1])
		if not ResourceLoader.exists(ruta):
			continue
		var t: Texture2D = load(ruta)
		var fam: String = str(par[0])
		_fila("suelo:" + fam, str(par[1]), t.get_image(), Albedos3D.k_de(fam) if activo else 1.0, Albedos3D.valor_de(fam) if activo else 1.0, oscurecer)
	# Piezas: se monta el nivel y se cuentan los materiales por textura.
	var m: Node = (load(escena) as PackedScene).instantiate()
	root.add_child(m)
	for _i in 60:
		await process_frame
	var usos: Dictionary = {}
	var tex: Dictionary = {}
	_recoger(m, usos, tex)
	var claves: Array = usos.keys()
	claves.sort_custom(func(x, y): return usos[x] > usos[y])
	var acum: Dictionary = {}     # familia -> [suma media, suma desv, suma rango, peso]
	for c in claves:
		var t2: Texture2D = tex[c]
		if t2 == null:
			continue
		var fam2: String = familia_de_ruta(str(c))
		var k: float = 1.0
		var v: float = 1.0
		var b: float = 1.0
		if fam2 == "bloque":
			b = oscurecer
			var f2: String = "piedra" if ("stone" in str(c) or "losas" in str(c)) else "tierra"
			k = Albedos3D.k_de(f2) if activo else 1.0
			v = Albedos3D.valor_de(f2) if activo else 1.0
		elif fam2 == "pieza":
			k = Albedos3D.k_de("piezas") if activo else 1.0
			v = Albedos3D.valor_de("piezas") if activo else 1.0
		var e: Dictionary = _fila(fam2, str(c), t2.get_image(), k, v, b, int(usos[c]))
		var p: float = float(usos[c])
		var s: Array = acum.get(fam2, [0.0, 0.0, 0.0, 0.0])
		s[0] += e["media"] * p
		s[1] += e["desv"] * p
		s[2] += (e["p95"] - e["p5"]) * p
		s[3] += p
		acum[fam2] = s
	for fam3 in acum.keys():
		var s2: Array = acum[fam3]
		var lin: String = "%s\t(ponderada por usos)\t%d\t\t\t\t%.1f\t%.1f\t\t\t%.1f" % [fam3, int(s2[3]), s2[0] / s2[3], s2[1] / s2[3], s2[2] / s2[3]]
		_salida.append(lin)
		print(lin)
	var f := FileAccess.open(ruta_salida, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_salida) + "\n")
		f.close()
	quit()


func _recoger(n: Node, usos: Dictionary, tex: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		_anotar(mi.mesh, mi.material_override, 1, usos, tex)
	elif n is MultiMeshInstance3D:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm != null:
			_anotar(mm.mesh, (n as MultiMeshInstance3D).material_override, mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count, usos, tex)
	for h in n.get_children():
		_recoger(h, usos, tex)


func _anotar(mesh: Mesh, mat_o: Material, cuantas: int, usos: Dictionary, tex: Dictionary) -> void:
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var mat: Material = mat_o if mat_o != null else mesh.surface_get_material(s)
		var t: Texture2D = null
		if mat is ShaderMaterial and Ocluso3D.es_comun(mat):
			t = (mat as ShaderMaterial).get_shader_parameter("tex_albedo") as Texture2D
		elif mat is StandardMaterial3D:
			t = (mat as StandardMaterial3D).albedo_texture
		if t == null or t.get_width() <= 4:
			continue
		var clave: String = t.resource_path if t.resource_path != "" else ("%s#%d" % [t.get_class(), t.get_rid().get_id()])
		usos[clave] = int(usos.get(clave, 0)) + cuantas
		tex[clave] = t

