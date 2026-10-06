class_name Pj2D
extends Node2D

## Un personaje PRERENDERIZADO (atlas de prerender_test2d.gd): 8 filas de dirección x N fotogramas por animación.
## El nodo está en los pies; la sombra la pone test_2d.gd. Se gira hacia donde se mueve con `mirar(vector)`.

const DIRS: Array = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]

var animacion: String = ""
var ignorar_camara_lenta: bool = false   ## sigue a velocidad normal aunque Engine.time_scale sea bajo
var _defs: Dictionary = {}
var _texturas: Dictionary = {}
var _sprite: Sprite2D = null
var _dir: int = 0
var _t: float = 0.0
var _fotograma: int = 0
var _al_acabar: String = ""        ## animación a la que vuelve una que no es en bucle


## `def` = la entrada del personaje en test2d.json; `carpeta` = donde están los atlas.
func preparar(def: Dictionary, carpeta: String) -> void:
	_defs = def.get("animaciones", {})
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var pies: Array = def.get("pies", [128, 176])
	_sprite.offset = -Vector2(float(pies[0]), float(pies[1]))
	add_child(_sprite)
	for a in _defs:
		var ruta: String = carpeta + String(_defs[a]["archivo"])
		if ResourceLoader.exists(ruta):
			_texturas[a] = load(ruta) as Texture2D
	jugar("idle")


func tiene(anim: String) -> bool:
	return _texturas.has(anim)


## Cambia de animación. `luego` = a cuál volver cuando acabe (solo para las que no son en bucle).
func jugar(anim: String, luego: String = "idle") -> void:
	if anim == animacion or not _texturas.has(anim):
		return
	animacion = anim
	_al_acabar = luego
	_t = 0.0
	_fotograma = 0
	_sprite.texture = _texturas[anim]
	_sprite.hframes = int(_defs[anim]["fotogramas"])
	_sprite.vframes = DIRS.size()
	_aplicar()


## Gira hacia `v` (en coordenadas de pantalla o de mundo x/z: es lo mismo en dirección).
func mirar(v: Vector2) -> void:
	if v.length() < 0.001:
		return
	# 0 = S (abajo), y en sentido antihorario visto en pantalla: SE, E, NE, N...
	var ang: float = atan2(v.x, v.y)
	_dir = posmod(int(roundf(ang / (PI / 4.0))), 8)
	_aplicar()


func _process(delta: float) -> void:
	if animacion == "":
		return
	var def: Dictionary = _defs[animacion]
	var dt: float = delta / maxf(Engine.time_scale, 0.01) if ignorar_camara_lenta else delta
	_t += dt * float(def.get("fps", 10.0))
	var n: int = int(def["fotogramas"])
	var f: int = int(_t)
	if f >= n:
		if bool(def.get("bucle", true)):
			_t = fmod(_t, float(n))
			f = int(_t)
		else:
			jugar(_al_acabar)
			return
	if f != _fotograma:
		_fotograma = f
		_aplicar()


func _aplicar() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	_sprite.frame = _dir * _sprite.hframes + clampi(_fotograma, 0, _sprite.hframes - 1)
