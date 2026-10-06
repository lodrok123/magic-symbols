# Hierba 3D — por qué bloquea y cómo no cargar todo el mapa (5 de octubre de 2026)

> **Aplicado el 5/10 por la noche (Pipeline, copia `paranda`):** §2.1 y §2.2 tal cual (bloques de 9,2 u,
> `radio_sembrar` 2 / `radio_liberar` 4, un bloque por fotograma, semilla por bloque; lo de la pantalla al
> empezar y tras `ir_a` se siembra de golpe). Extra: el radio crece con el zoom (`set_radio`) para que al alejar
> la cámara no se vea el borde. `sembrar(..., alrededor = false)` sigue sembrando todo (en bloques) para el
> laboratorio de VFX y el prerender del Test 2D (`hierba_completa = true`). De §2.3: `visibility_range_end`
> **no** se usa (la cámara ortográfica está a ~40 u: con 22 u desaparecería toda la hierba); las tarjetas ya
> recortaban con `discard` (sin ordenación); briznas 9 y densidad 10 sin tocar (es el aspecto validado).
> HUD de la maqueta: "hierba N bloques / M matojos". Falta medir en el PC de Pablo (§4).

Confirmado por Pablo: con la hierba apagada (G) la maqueta va fluida. Esto es el estudio y la
solución, para que el Pipeline la aplique en `poc_25d/hierba_3d.gd` y `prueba_test2.gd`.

## 1. Medido en el código

| dato | valor | de dónde |
|---|---|---|
| zona sembrada | 40 casillas × 2,3 = **92 × 92 unidades** (8 464 u²), todo el mapa de golpe | `_sembrar_hierba()` |
| muestras de briznas | `densidad = 10`/u² → **84 600** llamadas a `peso` al arrancar | `sembrar()` |
| matojos que quedan | ~50 % del mapa es hierba → **~40 000** matojos de **9 briznas** (18 triángulos) → ~720 000 triángulos | `_malla_matojo()`: `range(9)` |
| tarjetas pintadas | `densidad_tarjetas = 3` → ~12 000 billboards con alfa (relleno/overdraw) | `_sembrar_tarjetas()` |
| flores | `0,18`/u² × 8 464 → ~1 500 × 1–3 | |
| cámara | ortográfica, `size = 6` → en pantalla caben ~**8 × 5 casillas = 1 % del mapa** | `ZOOM_INICIAL` |
| culling | **ninguno**: 3 `MultiMeshInstance3D` con un AABB cada uno que abarca el mapa entero; además `custom_aabb` de las tarjetas cubre toda la zona | `_multimalla()`, `_sembrar_tarjetas()` |
| sombras | ya apagadas en la hierba (`cast_shadow = OFF`) | ✔ |
| por fotograma (CPU) | nada: el viento va por shader | ✔ |
| al arrancar (CPU) | ~100 000 llamadas a `_peso_hierba()` con dos lecturas bilineales de `Image` cada una, en GDScript → segundos de tirón antes de que aparezca nada | `_peso_hierba()` |

Resultado: la GPU integrada dibuja **720 000 triángulos + 12 000 billboards con alfa cada fotograma**
para mostrar el 1 % de ellos. No es un bug: es el diseño de "un MultiMesh para todo".

## 2. La solución, en tres capas (de más a menos rendimiento ganado)

### 2.1 Trocear por bloques de casillas → Godot descarta lo que no se ve
Un `MultiMeshInstance3D` por **bloque de 4 × 4 casillas** (9,2 u) y por capa (briznas, tarjetas, flores).
Mapa de 40 → 10 × 10 = 100 bloques. Cada bloque tiene su AABB, así que el *frustum culling* de Godot
dibuja solo los 4–6 bloques que tocan la pantalla: **~5 % de lo de hoy**, sin tocar el aspecto.

### 2.2 Sembrar solo alrededor del jugador y liberar lo lejano → no cargar todo el mapa
Los bloques no se crean al arrancar: se crean cuando el jugador se acerca (radio de 2 bloques = 18 u,
más que la pantalla) y se liberan cuando se aleja (radio 4). Con un bloque por fotograma como máximo, el
arranque pasa de ~100 000 llamadas a `peso` a ~4 000 y el resto se reparte al andar sin tirones.
Como la siembra es determinista (`semilla` + coordenadas del bloque), un bloque que se libera y vuelve
a crearse sale **idéntico**.

### 2.3 Menos coste por matojo (solo si la integrada sigue sufriendo tras 2.1 + 2.2)
- `visibility_range_end` en las briznas (p. ej. 22 u, con `fade`): más lejos quedan solo las tarjetas,
  que son 6 triángulos.
- `_malla_matojo()`: 9 briznas → 5 (10 triángulos): a 0,27 u de alto no se nota.
- Tarjetas con `alpha_scissor` en vez de alfa suave: sin ordenación ni overdraw.
- `densidad` 10 → 7 en hierba plena manteniendo 10 en el borde (es el borde el que dibuja el camino).

## 3. Código (para `hierba_3d.gd`; el resto de la clase no cambia)

Sustituye `sembrar()` por una siembra por bloques y añade `actualizar()`; `_sembrar_tarjetas` y la
construcción de materiales se reutilizan tal cual (los materiales se crean **una vez**, no por bloque).

```gdscript
## Tamaño de un bloque de hierba, en unidades. 4 casillas de 2,3: cabe un bloque y pico en pantalla.
@export var lado_bloque: float = 9.2
## Radio (en bloques) en el que se siembra alrededor del jugador y a partir del cual se libera.
@export var radio_sembrar: int = 2
@export var radio_liberar: int = 4
## Bloques creados por fotograma como máximo (reparte el coste al andar).
@export var bloques_por_fotograma: int = 1

var _zona: Rect2
var _y: float = 0.0
var _peso: Callable
var _bloques: Dictionary = {}          # Vector2i -> Node3D (padre de los 3 MultiMeshInstance3D del bloque)
var _pendientes: Array[Vector2i] = []
var _centro_actual: Vector2i = Vector2i(999999, 999999)


## Antes sembraba todo el mapa; ahora solo guarda los datos y prepara materiales y mallas.
func sembrar(zona: Rect2, y: float, peso: Callable) -> void:
	_zona = zona
	_y = y
	_peso = peso
	_preparar_materiales()        # lo que hoy hace sembrar() de la línea "_mat_matojo = ..." en adelante,
	                              # SIN crear MultiMesh: deja _mat_matojo, _malla, _mat_tarjeta, _mat_flor listos


## Llamar desde _process del nivel cada ~0,2 s (o cuando el jugador cambie de bloque).
func actualizar(pos_jugador: Vector3) -> void:
	var centro := Vector2i(floori((pos_jugador.x - _zona.position.x) / lado_bloque),
		floori((pos_jugador.z - _zona.position.y) / lado_bloque))
	if centro != _centro_actual:
		_centro_actual = centro
		# Encolar los que faltan, del más cercano al más lejano.
		_pendientes.clear()
		for dz in range(-radio_sembrar, radio_sembrar + 1):
			for dx in range(-radio_sembrar, radio_sembrar + 1):
				var b := centro + Vector2i(dx, dz)
				if _dentro(b) and not _bloques.has(b):
					_pendientes.append(b)
		_pendientes.sort_custom(func(a, b): return (a - centro).length_squared() < (b - centro).length_squared())
		# Liberar los que quedaron lejos.
		for b in _bloques.keys():
			if (b - centro).length_squared() > radio_liberar * radio_liberar:
				_bloques[b].queue_free()
				_bloques.erase(b)
	# Crear como mucho N por fotograma.
	for i in range(bloques_por_fotograma):
		if _pendientes.is_empty():
			break
		_crear_bloque(_pendientes.pop_front())


func _dentro(b: Vector2i) -> bool:
	return b.x >= 0 and b.y >= 0 and float(b.x) * lado_bloque < _zona.size.x \
		and float(b.y) * lado_bloque < _zona.size.y


## Un bloque: la siembra de siempre, pero sobre su rectángulo y con una semilla propia (determinista).
func _crear_bloque(b: Vector2i) -> void:
	var rect := Rect2(_zona.position + Vector2(b) * lado_bloque, Vector2(lado_bloque, lado_bloque))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semilla, b.x, b.y])
	var padre := Node3D.new()
	padre.name = "Hierba_%d_%d" % [b.x, b.y]
	add_child(padre)
	_bloques[b] = padre
	# --- briznas: el bucle actual de sembrar(), con `rect` en vez de `zona` y este `rng` ---
	var matojos: Array[Transform3D] = []
	var tintes_m := PackedColorArray()
	# ... (idéntico a hoy) ...
	var mi_b := _multimalla(_malla_matojo_compartida, matojos, tintes_m, padre)
	mi_b.visibility_range_end = 22.0            # capa 2.3: lejos solo quedan las tarjetas
	mi_b.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# --- tarjetas y flores: igual, sobre `rect`, colgadas de `padre` ---
	_sembrar_tarjetas(rect, _y, _peso, rng, padre)
	_sembrar_flores(rect, _y, _peso, rng, padre)
	# AABB del bloque (las tarjetas miran a la cámara y sobresalen): rect + 1 u de margen.
	for h in padre.get_children():
		(h as MultiMeshInstance3D).custom_aabb = AABB(
			Vector3(rect.position.x - 1.0, _y - 0.5, rect.position.y - 1.0),
			Vector3(rect.size.x + 2.0, 2.5, rect.size.y + 2.0))


## _multimalla gana un padre y devuelve el nodo (hoy devuelve el MultiMesh y cuelga de self).
func _multimalla(malla: Mesh, trs: Array[Transform3D], tintes: PackedColorArray, padre: Node3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = trs.size()
	for i in range(trs.size()):
		mm.set_instance_transform(i, trs[i])
		mm.set_instance_custom_data(i, tintes[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi
```

Y en `prueba_test2.gd`:
```gdscript
# _sembrar_hierba(): igual (llama a sembrar), y en _process, cada 0,2 s junto al HUD:
if _hierba != null and _jugador != null:
	_hierba.actualizar(_jugador.position)
```
`set_modo()` y `set_viento()` pasan a recorrer `_bloques` en vez de los dos nodos únicos; `numero_de_matojos()`
suma los bloques vivos (el HUD mostrará solo lo cargado, que es lo que interesa).

**Costes de esta solución:** la primera vez que el jugador entra en una zona hay un bloque nuevo por
fotograma (≈ 800 llamadas a `peso` cada uno; con dos lecturas bilineales son ~1–2 ms en GDScript: por
debajo de un fotograma). Si aun así se nota, `_peso_hierba` puede precalcularse una vez en una
`PackedFloat32Array` de 320 × 320 (la resolución de `_img_campo`) y leerse por índice.

## 4. Cómo se comprueba (QA)

Misma posición (fogata, mirando al bosque), HUD de la maqueta:
- FPS con hierba ≥ 0,9 × FPS sin hierba (hoy: la hierba lo hunde).
- `numero_de_matojos()` ≈ 25 bloques × ~400 = ~10 000 (hoy ~40 000).
- Monitor *Rendering → Primitives* con hierba: < 150 000 (hoy ~720 000).
- Andar 20 s en línea recta sin tirón visible (perfilador: ningún fotograma > 20 ms).
- Volver a una zona ya visitada: la hierba es idéntica (semilla por bloque).
