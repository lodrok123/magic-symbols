extends Node2D
## ESCENA DEMO de export_godot: valida que un personaje exportado es coherente
## (meta.json, atlas, metadata, 8 direcciones, idle, correr, ancla de pies).
## Lee directamente res://export_godot/{characters,enemies}/<id>/ sin importar nada.
##
## Controles: WASD / flechas = mover | Shift = correr | Tab / Q,E = cambiar personaje
##            G = rejilla | H = ayuda/checks | 1..3 = forzar idle/walk/run | +/- = zoom

const ROOT := "res://export_godot"
const DIRS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]   # angulo 0,45,90... (y hacia abajo)
const WALK_SPEED := 120.0
const RUN_SPEED := 220.0

var chars: Array = []            # [{id, tipo, meta, anims:{name:{dir:[AtlasTexture]}}, checks:[]}]
var cur := 0
var pos := Vector2.ZERO
var facing := "S"
var anim := "idle"
var forced := ""
var t := 0.0
var show_grid := true
var show_help := true
var sprite: Sprite2D
var cam: Camera2D
var label: Label


func _ready() -> void:
	sprite = Sprite2D.new()
	add_child(sprite)
	cam = Camera2D.new()
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(12, 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	_scan()
	if chars.is_empty():
		label.text = "No hay personajes en %s/characters ni /enemies.\nExporta uno con EXPORTAR_GODOT.cmd" % ROOT
		return
	_select(0)


func _scan() -> void:
	for tipo in ["characters", "enemies"]:
		var d := DirAccess.open("%s/%s" % [ROOT, tipo])
		if d == null:
			continue
		for id in d.get_directories():
			var c = _load_char(tipo, id)
			if c != null:
				chars.append(c)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _load_char(tipo: String, id: String) -> Variant:
	var base := "%s/%s/%s" % [ROOT, tipo, id]
	var meta = _read_json(base + "/meta.json")
	var c := {"id": id, "tipo": tipo, "meta": meta, "anims": {}, "checks": []}
	var checks: Array = c["checks"]
	if meta == null:
		checks.append("FALLO meta.json ausente o ilegible")
		return c
	for k in ["frame_px", "ancla_suelo_px", "offset_visual_px", "mapeo_direcciones_godot", "animaciones", "direcciones"]:
		if not meta.has(k):
			checks.append("FALLO meta.json sin '%s'" % k)
	if checks.size() > 0:
		return c
	var fp: Array = meta["frame_px"]
	var anc: Array = meta["ancla_suelo_px"]
	var off: Array = meta["offset_visual_px"]
	# el ancla debe coincidir con el offset: offset = centro - ancla
	var exp_y: float = fp[1] / 2.0 - anc[1]
	var exp_x: float = fp[0] / 2.0 - anc[0]
	if absf(exp_y - off[1]) > 1.0 or absf(exp_x - off[0]) > 1.0:
		checks.append("AVISO offset_visual %s no cuadra con ancla %s (esperado %s)" % [str(off), str(anc), str(Vector2(exp_x, exp_y))])
	for name in meta["animaciones"].keys():
		var info: Dictionary = meta["animaciones"][name]
		var res := _load_anim(base, info, fp, meta["direcciones"], checks, name)
		if not res.is_empty():
			c["anims"][name] = res
	for need in ["idle", "walk"]:
		if not c["anims"].has(need):
			checks.append("FALLO falta la animacion '%s'" % need)
	if not c["anims"].has("run"):
		checks.append("AVISO sin 'run': se usa walk acelerado")
	if checks.is_empty() or not checks.any(func(s): return s.begins_with("FALLO")):
		checks.push_front("OK estructura coherente (%d anims, %d direcciones, frame %s)" % [c["anims"].size(), meta["direcciones"].size(), str(fp)])
	return c


func _load_anim(base: String, info: Dictionary, fp: Array, dirs: Array, checks: Array, name: String) -> Dictionary:
	var out := {}   # dir_render -> Array[AtlasTexture]
	for mpath in info["metadata"]:
		var md = _read_json("%s/%s" % [base, mpath])
		if md == null:
			checks.append("FALLO %s: metadata ilegible (%s)" % [name, mpath])
			return {}
		for part in md["parts"]:
			var png: String = "%s/%s" % [base, String(mpath).get_base_dir() + "/" + part["file"]]
			var img := Image.load_from_file(ProjectSettings.globalize_path(png))
			if img == null or img.is_empty():
				checks.append("FALLO %s: no se pudo cargar %s" % [name, png])
				return {}
			var tex := ImageTexture.create_from_image(img)
			var sz: Array = part["atlas_size_px"]
			if img.get_width() != int(sz[0]) or img.get_height() != int(sz[1]):
				checks.append("AVISO %s: atlas %dx%d != metadata %s" % [name, img.get_width(), img.get_height(), str(sz)])
			for d in part["directions"].keys():
				if not out.has(d):
					out[d] = []
				for fr in part["directions"][d]["frames"]:
					var r: Dictionary = fr["region_px"]
					if r["x"] + r["w"] > img.get_width() or r["y"] + r["h"] > img.get_height():
						checks.append("FALLO %s/%s: region fuera del atlas" % [name, d])
						return {}
					if int(r["w"]) != int(fp[0]) or int(r["h"]) != int(fp[1]):
						checks.append("FALLO %s/%s: frame %dx%d != frame_px %s" % [name, d, r["w"], r["h"], str(fp)])
						return {}
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
					out[d].append(at)
	for d in dirs:
		if not out.has(d):
			checks.append("FALLO %s: falta la direccion %s" % [name, d])
			return {}
	var n: int = out[dirs[0]].size()
	for d in dirs:
		if out[d].size() != n:
			checks.append("FALLO %s: la direccion %s tiene %d frames y %s tiene %d" % [name, d, out[d].size(), dirs[0], n])
			return {}
	if int(info["frames"]) != n:
		checks.append("AVISO %s: meta dice %d frames, atlas tiene %d" % [name, int(info["frames"]), n])
	return out


func _select(i: int) -> void:
	cur = wrapi(i, 0, chars.size())
	pos = Vector2.ZERO
	cam.position = Vector2.ZERO
	t = 0.0
	var c: Dictionary = chars[cur]
	var off: Array = c["meta"]["offset_visual_px"] if c["meta"] != null else [0, 0]
	sprite.offset = Vector2(off[0], off[1])
	var rel: float = float(c["meta"].get("escala_relativa", 1.0)) if c["meta"] != null else 1.0
	sprite.scale = Vector2.ONE * rel   # el sprite se renderiza a tamano de encuadre; la escala devuelve su tamano real


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null:
		return
	_key(k)


func _key(e: InputEventKey) -> void:
	if not e.pressed or e.echo or chars.is_empty():
		return
	match e.keycode:
		KEY_TAB, KEY_E: _select(cur + 1)
		KEY_Q: _select(cur - 1)
		KEY_G: show_grid = not show_grid
		KEY_H: show_help = not show_help
		KEY_1: forced = "idle" if forced != "idle" else ""
		KEY_2: forced = "walk" if forced != "walk" else ""
		KEY_3: forced = "run" if forced != "run" else ""
		KEY_EQUAL, KEY_KP_ADD: cam.zoom *= 1.25
		KEY_MINUS, KEY_KP_SUBTRACT: cam.zoom /= 1.25


func _dir_name(v: Vector2) -> String:
	var a := rad_to_deg(v.angle())
	return DIRS[posmod(int(roundf(a / 45.0)), 8)]


func _process(delta: float) -> void:
	if chars.is_empty():
		return
	var c: Dictionary = chars[cur]
	if c["meta"] == null or not c["anims"].has("idle"):
		label.text = "[%s]\n%s" % [c["id"], "\n".join(c["checks"])]
		sprite.texture = null
		return
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_W): v.y -= 1
	if Input.is_key_pressed(KEY_S): v.y += 1
	v = v.limit_length(1.0)
	var running := Input.is_key_pressed(KEY_SHIFT)
	var want := "idle"
	var speed := 0.0
	if v.length() > 0.1:
		facing = _dir_name(v)
		want = "run" if running else "walk"
		speed = RUN_SPEED if running else WALK_SPEED
		if want == "run" and not c["anims"].has("run"):
			speed = RUN_SPEED   # fallback: walk
		pos += v.normalized() * speed * delta
	if forced != "":
		want = forced
	var key := want
	var rate := 1.0
	if not c["anims"].has(key):
		key = "walk" if key == "run" else "idle"
		rate = 1.6 if want == "run" else 1.0
	var info: Dictionary = c["meta"]["animaciones"][key]
	var fps: float = float(info["fps"]) * rate
	t += delta * fps
	# direccion de render que corresponde a la direccion de pantalla (mapeo inverso)
	var map: Dictionary = c["meta"]["mapeo_direcciones_godot"]
	var rdir := facing
	for k in map.keys():
		if map[k] == facing:
			rdir = k
	var frames: Array = c["anims"][key][rdir]
	var n := frames.size()
	var idx := int(t) % n if bool(info["loop"]) else mini(int(t), n - 1)
	sprite.texture = frames[idx]
	sprite.position = pos
	cam.position = cam.position.lerp(pos, clampf(delta * 6.0, 0.0, 1.0))
	anim = key
	queue_redraw()
	var txt := "[%d/%d] %s (%s)   dir %s -> render %s   anim %s %d/%d   fps %.1f%s\n" % [
		cur + 1, chars.size(), c["id"], c["tipo"], facing, rdir, key, idx + 1, n, fps,
		"  (run = walk x1.6)" if want == "run" and key == "walk" else ""]
	if show_help:
		txt += "WASD/flechas mover | Shift correr | Tab/Q cambiar | 1/2/3 forzar idle/walk/run | G rejilla | +/- zoom | H ocultar\n"
		txt += "\n".join(c["checks"])
	label.text = txt


func _draw() -> void:
	if show_grid:
		for ix in range(-12, 13):
			for iy in range(-12, 13):
				var p := Vector2((ix + iy) * 64, (ix - iy) * 32)
				var col := Color(1, 1, 1, 0.07 if (ix + iy) % 2 == 0 else 0.03)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -32), p + Vector2(64, 0), p + Vector2(0, 32), p + Vector2(-64, 0)]), col)
	# cruz en el ancla (pies): el personaje debe pisar aqui
	draw_line(pos + Vector2(-14, 0), pos + Vector2(14, 0), Color(1, 0.2, 0.2), 1.0)
	draw_line(pos + Vector2(0, -7), pos + Vector2(0, 7), Color(1, 0.2, 0.2), 1.0)
