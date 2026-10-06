class_name MsAtlas
extends RefCounted

## LOS PERSONAJES GENERADOS POR EL PIPELINE, LISTOS PARA USAR EN EL JUEGO.
##
## Cada personaje vive en res://export_godot/characters/<id>/ con un meta.json y,
## por cada animación, un atlas de 8 filas (una por dirección) y tantas columnas
## como fotogramas. Esto lo LEE tal cual lo hace la escena demo del pipeline
## (export_godot/demo/demo_arte.gd): el contrato está en CONTRATO_GODOT.md.
##
## Aquí solo hay datos y funciones sin estado visible: leer el meta, trocear un
## atlas en fotogramas (AtlasTexture) y, para el héroe, montar el SpriteFrames que
## espera player.gd ("idle_<DIR>", "walk_<DIR>", "cast_spell_<DIR>").
##
## DIRECCIONES. El pipeline renderiza cada fila con la etiqueta "al revés" en el eje
## este-oeste, y el meta.json trae la tabla que lo arregla (mapeo_direcciones_godot).
## player.gd ya calcula su etiqueta con ese mismo volteo, así que para el héroe la
## etiqueta ES la fila del atlas. Para el resto de actores, ver MsActor.

const RAIZ: String = "res://export_godot/characters"

## Las casillas del pack se hicieron de 128 px de ancho y las de este juego miden 116
## (ver IsoGrid). Todo lo que se dibuja se encoge en esa proporción para que el
## personaje siga teniendo el tamaño correcto respecto al suelo.
const ESCALA_MUNDO: float = 116.0 / 128.0

static var _meta: Dictionary = {}
static var _anim: Dictionary = {}


static func _json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(ruta))


## El meta.json de un personaje, o {} si no existe.
static func meta(id: String) -> Dictionary:
	if _meta.has(id):
		return _meta[id]
	var m: Variant = _json("%s/%s/meta.json" % [RAIZ, id])
	if not (m is Dictionary):
		push_warning("MsAtlas: no encuentro %s/%s/meta.json" % [RAIZ, id])
		m = {}
	_meta[id] = m
	if not (m as Dictionary).is_empty():
		_validar(id, m as Dictionary)
	return m


## --- VALIDAR UN PERSONAJE AL CARGARLO (tarea 1.8) ---
##
## Que un clip mal exportado se vea al arrancar, no cortado en pantalla. Solo AVISA por
## consola (push_warning), como hacía ActorAnimator._check_sheets; no cambia nada.
## Compara lo que PROMETE meta.json con el PNG real, leyendo solo la cabecera del PNG
## (ancho y alto), así que no cuesta cargar los atlas.
const TOPE_TEXTURA_PX: int = 4096
const CLIPS_UNA_VEZ: Array = ["death", "fall", "hit_reaction", "cast", "slash", "chop", "attack",
		"shot", "collect", "open_door", "climb", "bookwrite", "combo", "thrust", "electrocution"]


## Ancho y alto de un PNG sin decodificarlo (están en los bytes 16-23 de la cabecera).
static func _tam_png(ruta: String) -> Vector2i:
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return Vector2i.ZERO
	f.big_endian = true
	f.seek(16)
	var w: int = int(f.get_32())
	var h: int = int(f.get_32())
	return Vector2i(w, h)


static func _validar(id: String, m: Dictionary) -> void:
	var base: String = "%s/%s" % [RAIZ, id]
	for campo in ["frame_px", "ancla_suelo_px", "offset_visual_px", "mapeo_direcciones_godot", "animaciones"]:
		if not m.has(campo):
			push_warning("MsAtlas[%s]: meta.json no trae '%s'." % [id, campo])
			return
	var fw: int = int(m["frame_px"][0])
	var fh: int = int(m["frame_px"][1])
	var ax: float = float(m["ancla_suelo_px"][0])
	var ay: float = float(m["ancla_suelo_px"][1])
	if ax < 0.0 or ax > fw or ay < 0.0 or ay > fh:
		push_warning("MsAtlas[%s]: ancla_suelo_px (%s, %s) cae fuera del fotograma %sx%s." % [id, ax, ay, fw, fh])

	var anims: Dictionary = m["animaciones"]
	for nombre in anims:
		var info: Dictionary = anims[nombre]
		if bool(info.get("loop", true)):
			for token in CLIPS_UNA_VEZ:
				if String(nombre).contains(String(token)):
					push_warning("MsAtlas[%s]: '%s' parece de una sola vez pero loop = true." % [id, nombre])
					break
		var total: int = 0
		for ruta_md in info.get("metadata", []):
			var md: Variant = _json("%s/%s" % [base, ruta_md])
			if not (md is Dictionary) or not (md as Dictionary).has("parts"):
				push_warning("MsAtlas[%s/%s]: metadata ilegible o sin 'parts' (%s)." % [id, nombre, ruta_md])
				continue
			for parte in md["parts"]:
				var png: String = "%s/%s/%s" % [base, String(ruta_md).get_base_dir(), parte["file"]]
				var tam: Vector2i = _tam_png(png)
				if tam == Vector2i.ZERO:
					push_warning("MsAtlas[%s/%s]: no existe el atlas %s." % [id, nombre, png])
					continue
				var dirs: Dictionary = parte["directions"]
				var cols: int = (dirs.values()[0]["frames"] as Array).size()
				if tam.x != cols * fw or tam.y != dirs.size() * fh:
					push_warning("MsAtlas[%s/%s]: el PNG mide %sx%s y meta.json promete %sx%s (%s fotogramas, %s direcciones, celda %sx%s)." % [
							id, nombre, tam.x, tam.y, cols * fw, dirs.size() * fh, cols, dirs.size(), fw, fh])
				if tam.x > TOPE_TEXTURA_PX or tam.y > TOPE_TEXTURA_PX:
					push_warning("MsAtlas[%s/%s]: el atlas mide %sx%s y pasa del tope declarado de %s px." % [
							id, nombre, tam.x, tam.y, TOPE_TEXTURA_PX])
				total += cols
		if total != 0 and int(info.get("frames", 0)) != 0 and total != int(info.get("frames", 0)):
			push_warning("MsAtlas[%s/%s]: meta.json dice %s fotogramas y los atlas suman %s." % [
					id, nombre, info.get("frames"), total])


static func tiene(id: String, animacion: String) -> bool:
	var m: Dictionary = meta(id)
	return m.has("animaciones") and (m["animaciones"] as Dictionary).has(animacion)


static func fps(id: String, animacion: String) -> float:
	if not tiene(id, animacion):
		return 10.0
	return float(meta(id)["animaciones"][animacion].get("fps", 10))


static func en_bucle(id: String, animacion: String) -> bool:
	if not tiene(id, animacion):
		return true
	return bool(meta(id)["animaciones"][animacion].get("loop", true))


## Tamaño al que hay que dibujar a este personaje: su escala relativa, ajustada a
## 192 px de ancho de fotograma (igual que la demo), y encogida al tamaño de casilla.
static func escala(id: String) -> float:
	var m: Dictionary = meta(id)
	if m.is_empty():
		return ESCALA_MUNDO
	var rel: float = float(m.get("escala_relativa", 1.0))
	var base: float = 192.0 / float(m["frame_px"][0])
	return rel * base * ESCALA_MUNDO


## Los fotogramas de una animación: {"E": [AtlasTexture...], "SE": [...], ...}.
## Vacío si el atlas no existe. Se cachea: cargar un atlas son varios megas.
static func animacion(id: String, nombre: String) -> Dictionary:
	var clave: String = id + "/" + nombre
	if _anim.has(clave):
		return _anim[clave]

	var resultado: Dictionary = {}
	var m: Dictionary = meta(id)
	if m.is_empty() or not tiene(id, nombre):
		_anim[clave] = resultado
		return resultado

	var base: String = "%s/%s" % [RAIZ, id]
	var info: Dictionary = m["animaciones"][nombre]
	for ruta_md in info["metadata"]:
		var md: Variant = _json("%s/%s" % [base, ruta_md])
		if not (md is Dictionary):
			push_warning("MsAtlas: metadata ilegible: %s" % ruta_md)
			continue
		for parte in md["parts"]:
			var png: String = "%s/%s/%s" % [base, String(ruta_md).get_base_dir(), parte["file"]]
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(png))
			if img == null or img.is_empty():
				push_warning("MsAtlas: no puedo cargar %s" % png)
				continue
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			for d in parte["directions"].keys():
				if not resultado.has(d):
					resultado[d] = []
				for fr in parte["directions"][d]["frames"]:
					var r: Dictionary = fr["region_px"]
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
					resultado[d].append(at)

	_anim[clave] = resultado
	return resultado


const CLIPS_MUERTE: Array = ["shot_in_the_back_and_fall", "death", "hit_reaction_to_waist"]


static func _clip_muerte() -> String:
	for c in CLIPS_MUERTE:
		if tiene("hero", c):
			return c
	return "hit_reaction_to_waist"


## Último fotograma de la muerte. Con el clip bueno (shot_in_the_back_and_fall, o "death") se
## reproduce entero (-1). Con el provisional, hit_reaction_to_waist, SOLO hasta el fotograma 5:
## es el punto más bajo (la figura baja de 135 a 97 px) y el clip entero se vuelve a incorporar,
## con lo que "HAS MUERTO" salía con la maga de pie. Medido sobre el atlas, filas S y E.
## CUANDO LLEGUE shot_in_the_back_and_fall ESTO SE DESACTIVA SOLO.
const FIN_MUERTE_PROVISIONAL: int = 5


static func _fin_muerte() -> int:
	return FIN_MUERTE_PROVISIONAL if _clip_muerte() == "hit_reaction_to_waist" else -1


## El SpriteFrames del héroe para player.gd: una animación por clip y dirección.
##   idle, walk ........ las de siempre
##   cast_spell ........ el gesto de lanzar (charged_spell_cast_001)
## Los nombres de dirección son las FILAS del atlas, que es lo que player.gd pide.
static func frames_heroe() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	# clip -> [animación del pipeline, primer fotograma, último (-1 = todos), fps (0 = los del meta)]
	var clips: Dictionary = {
		"idle": ["idle", 0, -1, 0.0],
		"walk": ["walk", 0, -1, 0.0],
		"cast_spell": ["charged_spell_cast_001", 0, -1, 0.0],    # hechizos que viajan a un lado
		"cast_spell2": ["charged_spell_cast_002", 0, -1, 0.0],   # barrera y los que envuelven
		"write": ["bookwrite", 0, -1, 0.0],                      # elementos estáticos
		"collect": ["collect_object", 0, -1, 0.0],               # recoger del suelo
		# El golpe recibido es CORTO: solo el tramo central del clip, más rápido.
		"hit": ["hit_reaction", 2, 5, 20.0],
		# Muerte: cae de rodillas y se desploma (shot_in_the_back_and_fall, de Meshy). Mientras
		# el pipeline no lo haya procesado se usa "death" o, en último caso, la caída a la cintura.
		"death": [_clip_muerte(), 0, _fin_muerte(), 0.0],
	}
	for clip in clips:
		var cfg: Array = clips[clip]
		var origen: String = cfg[0]
		var a: Dictionary = animacion("hero", origen)
		if a.is_empty():
			push_warning("MsAtlas: el héroe no tiene la animación '%s'." % origen)
			continue
		for d in a.keys():
			var nombre: String = "%s_%s" % [clip, d]
			sf.add_animation(nombre)
			sf.set_animation_speed(nombre, fps("hero", origen) if float(cfg[3]) <= 0.0 else float(cfg[3]))
			sf.set_animation_loop(nombre, en_bucle("hero", origen) if clip != "death" else false)
			var fotos: Array = a[d]
			var fin: int = fotos.size() - 1 if int(cfg[2]) < 0 else mini(int(cfg[2]), fotos.size() - 1)
			for i in range(mini(int(cfg[1]), fin), fin + 1):
				sf.add_frame(nombre, fotos[i])
	return sf
