extends Node2D
## FIGURA ESTATICA: un personaje exportado (export_godot/characters|enemies/<id>) que se queda quieto
## reproduciendo animaciones. Pensada para el laboratorio de VFX: el personaje respira al fondo y,
## cuando sale el hechizo, hace su animacion de lanzar. Los pies estan en la posicion del nodo.
##
## Uso:  var f = FIGURA.new();  f.cargar(FIGURA.listar()[0]);  f.mirar("E");  f.una_vez(["mage_soell_cast_001"])

const ROOT := "res://export_godot"
const RING := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
## animaciones de lanzar, por orden de preferencia
const LANZAR := ["mage_soell_cast_001", "charged_spell_cast_001", "mage_soell_cast_002", "charged_spell_cast_002"]

var c: Dictionary = {}
var facing := "S"
var escala := 1.0
var _sprite: Sprite2D
var _anim := "idle"
var _vuelta := "idle"
var _t := 0.0
var _una := false


## ---------- carga ----------

static func listar() -> Array:
	var out: Array = []
	for tipo in ["characters", "enemies"]:
		var d := DirAccess.open("%s/%s" % [ROOT, tipo])
		if d == null:
			continue
		var ids := Array(d.get_directories())
		ids.sort()
		for id in ids:
			var meta = _json("%s/%s/%s/meta.json" % [ROOT, tipo, id])
			if meta != null and meta.has("animaciones") and meta["animaciones"].has("idle"):
				out.append({"id": id, "tipo": tipo})
	return out


static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func cargar(ref: Dictionary) -> bool:
	var base := "%s/%s/%s" % [ROOT, ref["tipo"], ref["id"]]
	var meta = _json(base + "/meta.json")
	if meta == null:
		return false
	var fp: Array = meta["frame_px"]
	c = {"id": ref["id"], "meta": meta, "anims": {}}
	for name in meta["animaciones"].keys():
		var info: Dictionary = meta["animaciones"][name]
		var res := _cargar_anim(base, info, fp)
		if not res.is_empty():
			c["anims"][name] = res
	if not c["anims"].has("idle"):
		return false
	_sprite = Sprite2D.new()
	var off: Array = meta["offset_visual_px"]
	_sprite.offset = Vector2(off[0], off[1])
	add_child(_sprite)
	set_escala(1.0)
	_t = 0.0
	return true


func _cargar_anim(base: String, info: Dictionary, fp: Array) -> Dictionary:
	var out := {}
	for mpath in info["metadata"]:
		var md = _json("%s/%s" % [base, mpath])
		if md == null:
			return {}
		for part in md["parts"]:
			var png: String = "%s/%s" % [base, String(mpath).get_base_dir() + "/" + part["file"]]
			var img := Image.load_from_file(ProjectSettings.globalize_path(png))
			if img == null or img.is_empty():
				return {}
			var tex := ImageTexture.create_from_image(img)
			for d in part["directions"].keys():
				if not out.has(d):
					out[d] = []
				for fr in part["directions"][d]["frames"]:
					var r: Dictionary = fr["region_px"]
					if int(r["w"]) != int(fp[0]) or int(r["h"]) != int(fp[1]):
						return {}
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
					out[d].append(at)
	return out


## ---------- control ----------

func set_escala(s: float) -> void:
	escala = s
	if _sprite != null and not c.is_empty():
		# un frame de 192 px de ancho se ve a escala 1.0 (los de 256 se reducen a 0.75)
		var base := 192.0 / float(c["meta"]["frame_px"][0])
		_sprite.scale = Vector2.ONE * base * escala


func mirar(dir_godot: String) -> void:
	facing = dir_godot


func tiene(anim: String) -> bool:
	return c.has("anims") and c["anims"].has(anim)


## Reproduce una vez la primera animacion de la lista que exista y vuelve a idle. Devuelve su nombre.
func una_vez(preferidas: Array = LANZAR) -> String:
	for n in preferidas:
		if tiene(n):
			_anim = n
			_t = 0.0
			_una = true
			return n
	return ""


func bucle(anim: String) -> void:
	if tiene(anim):
		_anim = anim
		_vuelta = anim
		_t = 0.0
		_una = false


func nombre_anim() -> String:
	return _anim


func _fila(f: String) -> String:
	var map: Dictionary = c["meta"]["mapeo_direcciones_godot"]
	for k in map.keys():
		if map[k] == f:
			return k
	return f


func _process(delta: float) -> void:
	if _sprite == null:
		return
	var info: Dictionary = c["meta"]["animaciones"][_anim]
	var frames: Array = c["anims"][_anim][_fila(facing)]
	var n := frames.size()
	_t += delta * float(info["fps"])
	if _una and int(_t) >= n:
		_una = false
		_anim = _vuelta
		_t = 0.0
		info = c["meta"]["animaciones"][_anim]
		frames = c["anims"][_anim][_fila(facing)]
		n = frames.size()
	_sprite.texture = frames[int(_t) % n]


func _draw() -> void:
	# sombra suave bajo los pies
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * 34.0, sin(a) * 15.0) * escala)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))
