extends RefCounted
## MUROS FINOS DE RUINA CON EL PACK «Stylescape: Ruins» (Fab, 25/11/2026). Con `estilo = "ruinas"` (PruebaTest2), cada casilla `#` que toca
## suelo (también en diagonal) se viste con muros del pack de 0,5 m (0,29 u) que van por el EJE de la casilla, en vez del árbol del bosque.
## La casilla sigue bloqueada entera (igual que antes); solo cambia lo que se ve: el muro ocupa una sexta parte y la sala respira.
## Lo usan los mapas del GENERADOR (estilo «Ruinas») y el laboratorio LabStylescape (tecla 4). Sin `class_name`: se carga con preload.
##
## Cómo decide (`muros(c, es_suelo, es_muro, y)`):
##   · une la casilla con cada vecina `#` (N, S, E, O) que también se viste, pero SOLO si ese tramo tiene suelo a algún lado (si no, dos
##     anillos de muro pegados se cosían con muros cruzados);
##   · recto (solo E+O o solo N+S) = un tramo entero de 4 m (una casilla); si dobla, acaba o se cruza = medios tramos de 2 m y un POSTE
##     en el centro que tapa la junta; una casilla suelta = un poste;
##   · un tramo horizontal que es la pared SUR de una sala o de un pasillo (la que queda entre la cámara y lo de dentro) va BAJO (1,5 m) para
##     no taparlo. Es sala si al norte hay suelo y, a FONDO_SALA_MIN..FONDO_SALA_MAX filas, otro muro que la cierra (que no sea el borde del mapa).
##     25/11 (Pablo: «pon bajos los que tapen»): antes bajaba todo tramo con suelo al norte, y en unas ruinas al aire libre casi todos salían bajos.
##     Ahora un muro con hierba abierta detrás (hasta el borde del mapa) o con un callejón de una fila se queda ALTO.
##     El resto, alto (3 m), con ventanas y desperfectos al azar (estable por casilla).
## Las piezas (arte/stylescape/piezas/ss_*.tscn) las crea herramientas/generar_piezas_stylescape.gd con el material horneado al beige de
## nuestros muros; el musgo de arriba lo pone la maqueta (`musgo_ruina` del shader común). Si el pack no está generado, se salta.
##
## TRAMPAS DE PARED (25/11): una trampa (`trampa_flechas`, `trampa_dragon`) va pegada a la CARA de su casilla `#` (media casilla hacia el suelo), pero
## el muro fino va por el EJE: sin más, la trampa flotaba a 1 u del muro. En esa casilla se pone además un CONTRAFUERTE (`contrafuerte` = hacia dónde
## mira la trampa) que llena desde el muro hasta la cara de la casilla; la trampa queda apoyada en él. Y el tramo de esa casilla es liso (sin ventanas:
## una ventana detrás de la trampa se veía por los lados). 25/11 (Pablo: «integra la base de la trampa en el muro, que parezcan del mismo sitio»): el
## contrafuerte ya no es un pilar (otro dibujo de piedra) sino dos tramos de MURO GRUESO del pack (el mismo ladrillo que el muro fino), uno detrás de otro,
## de una casilla de ancho: la casilla de la trampa se lee como un trozo de muro macizo. Y `integrar_trampa` pasa la piedra de la propia trampa (la losa
## del mascarón o del dragón) al beige de los muros (presentacion/piedra_ruinas.gdshader).

const RUTA: String = "res://arte/stylescape/piezas/"
const S: float = 2.3

## Tramos de 4 m (una casilla) y de 2 m (media), altos y bajos. Nombres de malla del pack: la pieza es "ss_" + nombre en minúsculas.
const ALTOS_4: Array = ["SM_Wall_04", "SM_Wall_Dmg_02", "SM_Wall_Windows_01", "SM_Wall_Dmg_04", "SM_Wall_Dmg_03", "SM_Wall_04"]
const ALTOS_2: Array = ["SM_Wall_02", "SM_Wall_Dmg_03_Alt", "SM_Wall_Dmg_04_Alt", "SM_Wall_Windows_Half", "SM_Wall_02"]
const BAJOS_4: Array = ["SM_Wall_Half_04"]      ## (SM_Wall_Dmg_02_Half_01 mide 3 m, no una casilla: fuera)
const BAJOS_2: Array = ["SM_Wall_Half_02", "SM_Wall_Dmg_03_Half_01", "SM_Wall_Dmg_04_Half_02"]
const POSTE_ALTO: String = "SM_Wall_01_Corner"
const POSTE_BAJO: String = "SM_Wall_Half_Corner"
const CONTRAFUERTE: String = "SM_Wall_Thick_04"        ## 4 × 1 × 3 m = 2,3 × 0,575 × 1,72 u (alto)
const CONTRAFUERTE_BAJO: String = "SM_Wall_Thick_Half_04"   ## 4 × 1 × 1,5 m (en una pared sur, que va baja)
const CONTRAFUERTE_FONDO: float = 0.575               ## u: dos tramos llenan la media casilla (1,15 u) del eje a la cara
## Todas las mallas que usa (el generador de piezas las crea).
const TODAS: Array = ["SM_Wall_04", "SM_Wall_Dmg_02", "SM_Wall_Windows_01", "SM_Wall_Dmg_04", "SM_Wall_Dmg_03",
	"SM_Wall_02", "SM_Wall_Dmg_03_Alt", "SM_Wall_Dmg_04_Alt", "SM_Wall_Windows_Half",
	"SM_Wall_Half_04", "SM_Wall_Half_02", "SM_Wall_Dmg_03_Half_01", "SM_Wall_Dmg_04_Half_02",
	"SM_Wall_01_Corner", "SM_Wall_Half_Corner", "SM_Wall_Thick_04", "SM_Wall_Thick_Half_04"] + ADORNOS
## 25/11 (Pablo: «pon los assets nuevos, no solo el muro»): adornos del pack, sin cuerpo (no bloquean). Ver `adornos_muro` y `adornos_suelo`.
const HIEDRAS: Array = ["SM_HangingIvy_05", "SM_HangingIvy_06", "SM_HangingIvy_01", "SM_HangingIvy_03"]
const ESCOMBROS: Array = ["SM_Rubble_01", "SM_Rubble_02", "SM_Stone_01", "SM_Stone_02", "SM_Stone_03", "SM_Stone_01"]
const LOSAS: Array = ["SM_Floor_4x4_TopFace_01", "SM_Floor_4x4_TopFace_02", "SM_Floor_4x4_TopFace_03"]
const CORNISA: String = "SM_Wall_LedgeDetail_04"
## Alto y fondo (u) de cada hiedra (medidos de las piezas): cuelga con su parte de arriba en lo alto del muro.
const DIM_HIEDRA: Dictionary = {"SM_HangingIvy_05": Vector2(1.03, 0.01), "SM_HangingIvy_06": Vector2(0.49, 0.02), "SM_HangingIvy_01": Vector2(0.59, 0.20), "SM_HangingIvy_03": Vector2(0.56, 0.20)}
const ALTO_MURO: float = 1.72        ## u (3 m)
const MEDIO_GRUESO: float = 0.145    ## u: medio grueso del muro fino
const CORNISA_ALTO: float = 0.16
const CORNISA_FONDO: float = 0.09
## Cuántos tramos rectos altos llevan hiedra y cuántos cornisa (1 de cada n), y cuántas casillas de suelo junto a un muro llevan escombros (1 de cada n).
const CADA_HIEDRA: int = 3
const CADA_CORNISA: int = 2
const CADA_ESCOMBRO: int = 4
const CADA_CAJA: int = 9            ## de los escombros, 1 de cada n es una caja de madera
const CAJA: String = "SM_Crate_01"
const ADORNOS: Array = ["SM_HangingIvy_05", "SM_HangingIvy_06", "SM_HangingIvy_01", "SM_HangingIvy_03", "SM_Rubble_01", "SM_Rubble_02",
	"SM_Stone_01", "SM_Stone_02", "SM_Stone_03", "SM_Floor_4x4_TopFace_01", "SM_Floor_4x4_TopFace_02", "SM_Floor_4x4_TopFace_03",
	"SM_Wall_LedgeDetail_04", "SM_Crate_01"]

const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]      ## E, O, S, N
const FONDO_SALA_MIN: int = 2       ## filas de suelo detrás del muro para que sea una sala o pasillo (con 1 es un callejón: el muro sigue alto)
const FONDO_SALA_MAX: int = 12      ## más allá, lo de detrás es campo abierto (el muro sigue alto)
const OCHO: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


static func id_de(malla: String) -> String:
	return "ss_" + malla.to_lower().trim_prefix("sm_")


## ¿Está el pack generado en esta máquina?
static func disponible() -> bool:
	return ResourceLoader.exists(RUTA + id_de("SM_Wall_04") + ".tscn")


## ¿Se viste esta casilla de muro? (toca suelo en alguna de las 8 direcciones)
static func se_viste(c: Vector2i, es_suelo: Callable, es_muro: Callable) -> bool:
	if not es_muro.call(c):
		return false
	for d in OCHO:
		if es_suelo.call(c + d):
			return true
	return false


## Las piezas de la casilla de muro `c`: Array de [id, Transform3D] (origen = base de la pieza, en el centro de la casilla).
## `es_suelo` y `es_muro` son Callable(Vector2i) -> bool; `y` es la altura del suelo (ALTO de la maqueta). `contrafuerte` = hacia dónde mira la
## trampa de pared que va en esta casilla (ZERO = ninguna).
static func muros(c: Vector2i, es_suelo: Callable, es_muro: Callable, y: float, contrafuerte: Vector2i = Vector2i.ZERO) -> Array:
	var res: Array = []
	if not se_viste(c, es_suelo, es_muro):
		return res
	var une: Array = []        ## por dirección: [une, bajo]
	for d in DIRS:
		var otra: Vector2i = c + d
		var u: bool = se_viste(otra, es_suelo, es_muro) and _tramo_con_suelo(c, d, es_suelo)
		une.append([u, u and _es_bajo(c, d, es_suelo, es_muro)])
	var centro := Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)
	var h: int = _hash(c, 1)
	var e: bool = une[0][0]
	var o: bool = une[1][0]
	var s: bool = une[2][0]
	var n: bool = une[3][0]
	if e and o and not s and not n:
		var bajo: bool = une[0][1] or une[1][1]
		var liso: String = "SM_Wall_Half_04" if bajo else "SM_Wall_04"
		res.append([id_de(liso if contrafuerte != Vector2i.ZERO else _de(BAJOS_4 if bajo else ALTOS_4, h)), _xf(centro, 0.0, h)])
		if not bajo and contrafuerte == Vector2i.ZERO:
			res.append_array(_adornos_tramo(c, Vector2i(0, 1) if es_suelo.call(c + Vector2i(0, 1)) else Vector2i(0, -1), centro, h))
	elif s and n and not e and not o:
		res.append([id_de("SM_Wall_04" if contrafuerte != Vector2i.ZERO else _de(ALTOS_4, h)), _xf(centro, 90.0, h)])
		if contrafuerte == Vector2i.ZERO:
			res.append_array(_adornos_tramo(c, Vector2i(1, 0) if es_suelo.call(c + Vector2i(1, 0)) else Vector2i(-1, 0), centro, h))
	else:
		var todos_bajos: bool = true
		for i in range(4):
			if not une[i][0]:
				continue
			var d: Vector2i = DIRS[i]
			var bajo2: bool = une[i][1]
			todos_bajos = todos_bajos and bajo2
			var mitad: Vector3 = centro + Vector3(float(d.x), 0.0, float(d.y)) * S * 0.25
			res.append([id_de(_de(BAJOS_2 if bajo2 else ALTOS_2, h + i * 7)), _xf(mitad, 0.0 if d.y == 0 else 90.0, h + i)])
		res.append([id_de(POSTE_BAJO if todos_bajos and res.size() > 0 else POSTE_ALTO), Transform3D(Basis.IDENTITY, centro)])
	if contrafuerte != Vector2i.ZERO:
		res.append_array(contrafuerte_de(c, contrafuerte, y, bool(une[0][1]) or bool(une[1][1])))
	return res


## Hiedra colgando y cornisa en la cara de un tramo recto ALTO que da al suelo `lado` (estable por casilla). Array de [id, Transform3D].
static func _adornos_tramo(c: Vector2i, lado: Vector2i, centro: Vector3, h: int) -> Array:
	var res: Array = []
	var n := Vector3(float(lado.x), 0.0, float(lado.y))
	var giro: float = 0.0 if lado.y != 0 else 90.0
	var a_lo_largo := Vector3(1.0, 0.0, 0.0) if lado.y != 0 else Vector3(0.0, 0.0, 1.0)
	var h2: int = _hash(c, 9)
	if h2 % CADA_CORNISA == 0:
		res.append([id_de(CORNISA), Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), centro + n * (MEDIO_GRUESO + CORNISA_FONDO * 0.5) + Vector3(0.0, ALTO_MURO - CORNISA_ALTO - 0.04, 0.0))])
	if (h2 >> 2) % CADA_HIEDRA == 0:
		var hiedra: String = String(HIEDRAS[(h2 >> 4) % HIEDRAS.size()])
		var dim: Vector2 = DIM_HIEDRA[hiedra]
		var desliza: float = (float((h2 >> 7) % 61) / 60.0 - 0.5) * 0.9
		var pos: Vector3 = centro + n * (MEDIO_GRUESO + CORNISA_FONDO + dim.y * 0.5 + 0.01) + a_lo_largo * desliza + Vector3(0.0, ALTO_MURO - dim.x - 0.02, 0.0)
		res.append([id_de(hiedra), Transform3D(Basis(Vector3.UP, deg_to_rad(giro + (180.0 if lado.y < 0 or lado.x < 0 else 0.0))), pos)])
	return res


## Adornos de una casilla de SUELO del estilo ruinas (`letra` = su letra del mapa): junto a un muro, de vez en cuando,
## escombros, piedras sueltas o una caja, del lado del muro. No bloquean. Array de [id, Transform3D].
static func adornos_suelo(c: Vector2i, letra: String, es_muro: Callable, y: float) -> Array:
	var res: Array = []
	var centro := Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)
	var h: int = _hash(c, 13)
	# 25/11 (Pablo: «no me convence el suelo»): las losas del pack (SM_Floor_4x4_TopFace) se veían lisas desde la cámara; las «R» se quedan con el
	# suelo enlosado del juego. Las piezas siguen generándose (LOSAS) por si se vuelven a probar.
	var muros_al_lado: Array = []
	for d in DIRS:
		if es_muro.call(c + d):
			muros_al_lado.append(d)
	if muros_al_lado.is_empty() or (h >> 4) % CADA_ESCOMBRO != 0:
		return res
	var d0: Vector2i = muros_al_lado[(h >> 6) % muros_al_lado.size()]
	var hacia := Vector3(float(d0.x), 0.0, float(d0.y))
	var lado := Vector3(-hacia.z, 0.0, hacia.x)
	var cual: String = CAJA if (h >> 8) % CADA_CAJA == 0 else String(ESCOMBROS[(h >> 9) % ESCOMBROS.size()])
	var pos: Vector3 = centro + hacia * (S * 0.5 - 0.55) + lado * ((float((h >> 12) % 41) / 40.0 - 0.5) * 1.2)
	res.append([id_de(cual), Transform3D(Basis(Vector3.UP, deg_to_rad(float((h >> 3) % 360))), pos)])
	if cual != CAJA and (h >> 15) % 2 == 0:
		res.append([id_de("SM_Stone_0%d" % (1 + (h >> 16) % 3)), Transform3D(Basis(Vector3.UP, deg_to_rad(float((h >> 5) % 360))), pos + lado * 0.55 - hacia * 0.25)])
	return res


## El contrafuerte de una trampa: dos tramos de muro grueso de una casilla de ancho, uno pegado al eje y otro delante, hasta la cara de la casilla
## que da a `d`. Array de [id, Transform3D]. `bajo` = la pared sur (va baja).
static func contrafuerte_de(c: Vector2i, d: Vector2i, y: float, bajo: bool = false) -> Array:
	var centro := Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)
	var giro: float = 0.0 if d.y != 0 else 90.0           # lo largo del tramo, a lo largo del muro
	var id: String = id_de(CONTRAFUERTE_BAJO if bajo else CONTRAFUERTE)
	var res: Array = []
	for k in [CONTRAFUERTE_FONDO * 0.5, CONTRAFUERTE_FONDO * 1.5]:
		res.append([id, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), centro + Vector3(float(d.x), 0.0, float(d.y)) * k)])
	return res


## --- la piedra de la trampa, como la de los muros ---
const SHADER_PIEDRA = preload("res://presentacion/piedra_ruinas.gdshader")
const TEX_PIEDRA: String = "res://arte/stylescape/texturas/T_WallTrim_NoMoss_D_beige.res"
static var _color_piedra: Color = Color(0.0, 0.0, 0.0, 0.0)
static var _lum_tex: Dictionary = {}       ## textura -> luminancia media de su piedra (lineal)


## El color medio de la piedra de los muros (el beige horneado del pack), en sRGB.
static func color_piedra() -> Color:
	if _color_piedra.a > 0.0:
		return _color_piedra
	_color_piedra = Color(0.72, 0.63, 0.55)
	if ResourceLoader.exists(TEX_PIEDRA):
		var im: Image = (load(TEX_PIEDRA) as Texture2D).get_image()
		if im != null and not im.is_empty():
			im = im.duplicate()
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGB8)
			im.resize(32, 32, Image.INTERPOLATE_BILINEAR)
			var suma := Color(0, 0, 0)
			for yy in range(32):
				for xx in range(32):
					suma += im.get_pixel(xx, yy)
			_color_piedra = Color(suma.r / 1024.0, suma.g / 1024.0, suma.b / 1024.0)
	return _color_piedra


## Luminancia media (lineal) de los píxeles de PIEDRA (poco saturados) de una textura; 0,45 si no se puede leer.
static func _lum_piedra(tex: Texture2D) -> float:
	if tex == null:
		return 0.45
	if _lum_tex.has(tex):
		return _lum_tex[tex]
	var v: float = 0.45
	var im: Image = tex.get_image()
	if im != null and not im.is_empty():
		im = im.duplicate()
		if im.is_compressed():
			im.decompress()
		if not im.is_compressed():
			im.convert(Image.FORMAT_RGB8)
			im.resize(48, 48, Image.INTERPOLATE_BILINEAR)
			var suma: float = 0.0
			var n: int = 0
			for yy in range(48):
				for xx in range(48):
					var p: Color = im.get_pixel(xx, yy).srgb_to_linear()
					var mx: float = maxf(p.r, maxf(p.g, p.b))
					if mx > 0.001 and (mx - minf(p.r, minf(p.g, p.b))) / mx < 0.25:
						suma += p.r * 0.2126 + p.g * 0.7152 + p.b * 0.0722
						n += 1
			if n > 20:
				v = suma / float(n)
	_lum_tex[tex] = v
	return v


## Cambia los materiales de PIEDRA de una trampa de pared (sus StandardMaterial3D con luz, opacos y sin emisión) por el de piedra de ruinas. Lo que
## brilla (ranura, ojos, garganta) o es transparente se queda como está.
static func integrar_trampa(t: Node) -> int:
	var cambiados: int = 0
	var hechos: Dictionary = {}
	for h in t.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = h as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(s)
			if not (m is StandardMaterial3D):
				continue
			var sm: StandardMaterial3D = m
			if sm.emission_enabled or sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if not hechos.has(sm):
				var nuevo := ShaderMaterial.new()
				nuevo.shader = SHADER_PIEDRA
				if sm.albedo_texture != null:
					nuevo.set_shader_parameter("tex_albedo", sm.albedo_texture)
				nuevo.set_shader_parameter("color", sm.albedo_color)
				if sm.normal_enabled and sm.normal_texture != null:
					nuevo.set_shader_parameter("tex_normal", sm.normal_texture)
					nuevo.set_shader_parameter("usa_normal", 1.0)
				nuevo.set_shader_parameter("rugosidad", maxf(sm.roughness, 0.6))
				nuevo.set_shader_parameter("piedra", color_piedra())
				# Sin textura (las piezas de primitivas): la referencia es la piedra clara de las trampas, así la oscura (dintel, jambas) sigue más oscura.
				var ref: Color = TrampaPared3D.COLOR_PIEDRA.srgb_to_linear()
				var lum: float = _lum_piedra(sm.albedo_texture) if sm.albedo_texture != null else (ref.r * 0.2126 + ref.g * 0.7152 + ref.b * 0.0722)
				nuevo.set_shader_parameter("lum_ref", lum)
				if sm.albedo_texture == null and ResourceLoader.exists(TEX_PIEDRA):
					# sin textura: el ladrillo de los muros, triplanar (la referencia de luz pasa a ser la del ladrillo)
					nuevo.set_shader_parameter("tex_muro", load(TEX_PIEDRA))
					nuevo.set_shader_parameter("usa_muro", 1.0)
					nuevo.set_shader_parameter("lum_ref", _lum_piedra(load(TEX_PIEDRA)) * 0.5)
				hechos[sm] = nuevo
			if mi.material_override == sm:
				mi.material_override = hechos[sm]          # las piezas de primitivas lo ponen para todo el objeto: manda sobre el de la superficie
			else:
				mi.set_surface_override_material(s, hechos[sm])
			cambiados += 1
	return cambiados


## El tramo de `c` hacia `d` tiene suelo a un lado (en `c` o en la vecina, a cualquiera de los dos costados).
static func _tramo_con_suelo(c: Vector2i, d: Vector2i, es_suelo: Callable) -> bool:
	var lado := Vector2i(d.y, d.x)       # perpendicular
	for p in [c, c + d]:
		if es_suelo.call(p + lado) or es_suelo.call(p - lado):
			return true
	return false


## Tramo horizontal que es la pared SUR de una sala o pasillo (ver la cabecera). Se mira la columna de `c` y la de la vecina: basta una.
static func _es_bajo(c: Vector2i, d: Vector2i, es_suelo: Callable, es_muro: Callable) -> bool:
	if d.y != 0:
		return false
	return _cierra_sala(c, es_suelo, es_muro) or _cierra_sala(c + d, es_suelo, es_muro)


## ¿Es el muro `c` el fondo sur de un espacio cerrado? Suelo justo al norte y, subiendo por la columna, otro muro a FONDO_SALA_MIN..FONDO_SALA_MAX
## filas que no sea el borde del mapa (el borde: un muro con nada encima, ni suelo ni muro).
static func _cierra_sala(c: Vector2i, es_suelo: Callable, es_muro: Callable) -> bool:
	if not es_suelo.call(c + Vector2i(0, -1)):
		return false
	for k in range(1, FONDO_SALA_MAX + 2):
		var q: Vector2i = c + Vector2i(0, -k)
		if es_muro.call(q):
			var fondo: int = k - 1
			var borde: bool = not es_muro.call(q + Vector2i(0, -1)) and not es_suelo.call(q + Vector2i(0, -1))
			return fondo >= FONDO_SALA_MIN and not borde
		if not es_suelo.call(q):
			return false
	return false


## Las piezas están hechas con lo largo en X; 0 = a lo largo de X, 90 = a lo largo de Z. Media vuelta al azar para variar la cara.
static func _xf(pos: Vector3, giro: float, h: int) -> Transform3D:
	var g: float = giro + (180.0 if (h >> 3) % 2 == 0 else 0.0)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(g)), pos)


static func _de(lista: Array, h: int) -> String:
	return String(lista[absi(h) % lista.size()])


static func _hash(c: Vector2i, sal: int) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ (sal * 83492791))
