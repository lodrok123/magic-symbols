extends Node2D
## DEMO ARTE: prueba los personajes exportados sobre muchos entornos (cubos isometricos de distintos acabados)
## y con distintas luces. Lee res://export_godot/{characters,enemies}/<id>/ igual que demo.tscn.
##
## WASD/flechas mover | Shift correr | Tab/E, Q cambiar personaje | 1/2/3 forzar idle/walk/run
## B / V entorno siguiente / anterior (0 = mezcla de 12 acabados) | N luz (dia/atardecer/noche/cueva)
## [ ] tamano del sprite | M mapa del bosque (si esta exportado) | +/- zoom | H ayuda | F foto (PNG en user://)

const CD := preload("res://export_godot/demo/cube_draw.gd")
const ROOT := "res://export_godot"
const DIRS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const WALK_SPEED := 120.0
const RUN_SPEED := 220.0
const ZW := 4
const ZH := 3
const TINTS := [["dia", Color(1, 1, 1)], ["atardecer", Color(1.0, 0.82, 0.66)], ["noche", Color(0.45, 0.50, 0.80)], ["cueva", Color(0.50, 0.55, 0.65)]]
const MAPS := ["", "map_sano.png", "map.png"]


class Ground extends Node2D:
	var cells: Array = []
	func _draw() -> void:
		CD.draw_ground(self, cells, 14.0)


class Cube extends Node2D:
	var tt := 0
	var hh := 64.0
	var sd := 1
	func _draw() -> void:
		CD.draw_cube(self, Vector2(0, -32.0 - hh), CD.TYPES[tt], hh + 14.0, sd)


var chars: Array = []
var cur := 0
var pos := Vector2.ZERO
var facing := "S"
var anim := "idle"
var forced := ""
var t := 0.0
var show_help := true
var spr_scale := 1.0
var dir_shift := 0      # AJUSTE EN VIVO: giro extra (en pasos de 45 grados) entre direccion y fila del atlas
var mirror := false     # AJUSTE EN VIVO: invierte el sentido de giro
const RING := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
var env := 0
var tint_i := 0
var map_i := 0
var sprite: Sprite2D
var cam: Camera2D
var label: Label
var world: Node2D
var ground: Ground
var mapspr: Sprite2D
var modul: CanvasModulate
var cubes: Array = []


func _ready() -> void:
	ground = Ground.new()
	ground.z_index = -10
	add_child(ground)
	mapspr = Sprite2D.new()
	mapspr.z_index = -5
	mapspr.visible = false
	add_child(mapspr)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	sprite = Sprite2D.new()
	world.add_child(sprite)
	cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	add_child(cam)
	modul = CanvasModulate.new()
	add_child(modul)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(12, 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	_build_env()
	_scan()
	if chars.is_empty():
		label.text = "No hay personajes en %s/characters ni /enemies.\nExporta uno (PROCESAR.cmd)" % ROOT
		return
	_select(0)


func _build_env() -> void:
	for c in cubes:
		c.queue_free()
	cubes.clear()
	ground.cells.clear()
	var ntypes: int = CD.TYPES.size()
	var mixed := env == 0
	for iy in range(ZH * 3):
		for ix in range(ZW * 3):
			var tt: int = (floori(iy / 3.0) * ZW + floori(ix / 3.0)) % ntypes if mixed else (env - 1)
			ground.cells.append({"ix": ix, "iy": iy, "t": tt})
	ground.cells.sort_custom(func(a, b): return (a["ix"] + a["iy"]) < (b["ix"] + b["iy"]))
	# cubos altos (para comprobar oclusion): uno en la esquina de cada zona o tres sueltos
	var spots: Array = []
	if mixed:
		for zy in ZH:
			for zx in ZW:
				spots.append([zx * 3 + 2, zy * 3 + 2, (zy * ZW + zx) % ntypes])
	else:
		spots = [[3, 3, env - 1], [8, 5, env - 1], [5, 7, env - 1]]
	for s in spots:
		var tt: int = s[2]
		if String(CD.TYPES[tt]["k"]) == "water":
			tt = 2
		var cb := Cube.new()
		cb.tt = tt
		cb.hh = 64.0
		cb.sd = int(s[0]) * 7 + int(s[1])
		cb.position = CD.tile_pos(s[0], s[1]) + Vector2(0, 32)
		world.add_child(cb)
		cubes.append(cb)
	ground.queue_redraw()
	pos = CD.tile_pos(1, 1) if mixed else CD.tile_pos(5, 4)
	if sprite != null:
		sprite.position = pos
	_apply_map()


func _apply_map() -> void:
	var f: String = MAPS[map_i]
	if f == "":
		mapspr.visible = false
		ground.visible = true
		for c in cubes:
			c.visible = true
		return
	var path := ProjectSettings.globalize_path("%s/terrain/bosque_01/%s" % [ROOT, f])
	var img: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if img == null or img.is_empty():
		label.text = "No hay %s (ejecuta PROCESAR.cmd escena bosque_01)" % f
		map_i = 0
		_apply_map()
		return
	mapspr.texture = ImageTexture.create_from_image(img)
	mapspr.position = CD.tile_pos(5, 4)
	mapspr.visible = true
	ground.visible = false
	for c in cubes:
		c.visible = false


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
	t = 0.0
	var c: Dictionary = chars[cur]
	var off: Array = c["meta"]["offset_visual_px"] if c["meta"] != null else [0, 0]
	sprite.offset = Vector2(off[0], off[1])
	_apply_scale()
	sprite.position = pos
	cam.position = pos


func _apply_scale() -> void:
	var c: Dictionary = chars[cur]
	var rel: float = float(c["meta"].get("escala_relativa", 1.0)) if c["meta"] != null else 1.0
	# tamano base: un frame de 192 px de ancho se ve a escala 1.0 (los de 256 se reducen a 0.75)
	var base := 192.0 / float(c["meta"]["frame_px"][0]) if c["meta"] != null else 1.0
	sprite.scale = Vector2.ONE * rel * base * spr_scale


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
		KEY_H: show_help = not show_help
		KEY_PERIOD: dir_shift = posmod(dir_shift + 1, 8)
		KEY_COMMA: dir_shift = posmod(dir_shift - 1, 8)
		KEY_R: mirror = not mirror
		KEY_1: forced = "idle" if forced != "idle" else ""
		KEY_2: forced = "walk" if forced != "walk" else ""
		KEY_3: forced = "run" if forced != "run" else ""
		KEY_EQUAL, KEY_KP_ADD: cam.zoom *= 1.25
		KEY_MINUS, KEY_KP_SUBTRACT: cam.zoom /= 1.25
		KEY_B:
			env = wrapi(env + 1, 0, CD.TYPES.size() + 1)
			_build_env()
		KEY_V:
			env = wrapi(env - 1, 0, CD.TYPES.size() + 1)
			_build_env()
		KEY_N:
			tint_i = wrapi(tint_i + 1, 0, TINTS.size())
			modul.color = TINTS[tint_i][1]
		KEY_BRACKETLEFT:
			spr_scale = maxf(0.1, spr_scale / 1.1)
			_apply_scale()
		KEY_BRACKETRIGHT:
			spr_scale = minf(3.0, spr_scale * 1.1)
			_apply_scale()
		KEY_M:
			map_i = (map_i + 1) % MAPS.size()
			_apply_map()
		KEY_F:
			var im := get_viewport().get_texture().get_image()
			var p := "user://demo_arte_%d.png" % Time.get_ticks_msec()
			im.save_png(p)
			label.text = "Foto guardada: " + ProjectSettings.globalize_path(p)


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
		# movimiento isometrico 2:1: la velocidad en pantalla se aplasta en vertical (mitad), de modo que
		# las diagonales siguen las aristas de las casillas (pendiente 1:2) y la velocidad real en el
		# mundo es la misma en todas direcciones. La direccion (facing) sale del vector SIN aplastar.
		var dv := v.normalized()
		pos += Vector2(dv.x, dv.y * 0.5) * speed * delta
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
	var map: Dictionary = c["meta"]["mapeo_direcciones_godot"]
	var rdir := facing
	for k in map.keys():
		if map[k] == facing:
			rdir = k
	var ii: int = RING.find(rdir)
	if mirror:
		ii = -ii
	rdir = RING[posmod(ii + dir_shift, 8)]
	var frames: Array = c["anims"][key][rdir]
	var n := frames.size()
	var idx := int(t) % n if bool(info["loop"]) else mini(int(t), n - 1)
	sprite.texture = frames[idx]
	sprite.position = pos
	cam.position = cam.position.lerp(pos, clampf(delta * 6.0, 0.0, 1.0))
	anim = key
	queue_redraw()
	var env_name: String = "mezcla de acabados" if env == 0 else String(CD.TYPES[env - 1]["n"])
	var txt := "[%d/%d] %s   dir %s -> %s   anim %s %d/%d   sprite x%.2f   entorno: %s   luz: %s   AJUSTE dir: shift %d%s\n" % [
		cur + 1, chars.size(), c["id"], facing, rdir, key, idx + 1, n, spr_scale, env_name, TINTS[tint_i][0], dir_shift, " espejo" if mirror else ""]
	if show_help:
		txt += "WASD mover | Shift correr | Tab/Q personaje | 1/2/3 idle/walk/run | B/V entorno | N luz | [ ] tamano | M mapa | +/- zoom | F foto | , . girar fila | R espejo | H ocultar\n"
		txt += "\n".join(c["checks"])
	label.text = txt


func _draw() -> void:
	# sombra suave bajo los pies y cruz de ancla
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(pos + Vector2(cos(a) * 22.0, sin(a) * 8.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))
	# flecha amarilla = hacia donde DEBERIA mirar (direccion de pantalla pulsada, en perspectiva 2:1)
	var ai: int = DIRS.find(facing)
	if ai >= 0:
		var a := ai * PI / 4.0
		var tip := pos + Vector2(cos(a), sin(a) * 0.5) * 70.0
		var side := Vector2(cos(a), sin(a) * 0.5).normalized()
		draw_line(pos, tip, Color(1, 0.9, 0.1), 2.0)
		draw_line(tip, tip - side * 12.0 + Vector2(-side.y, side.x) * 6.0, Color(1, 0.9, 0.1), 2.0)
		draw_line(tip, tip - side * 12.0 - Vector2(-side.y, side.x) * 6.0, Color(1, 0.9, 0.1), 2.0)
