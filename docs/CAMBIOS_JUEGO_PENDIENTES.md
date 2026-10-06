# Cambios del Juego pendientes de aplicar (5 de octubre de 2026)

> **APLICADOS los tres el 5/10 por la tarde en la copia `paranda`** (Pipeline, a petición de Pablo).
> Las líneas de contexto coincidían. Pendiente: F6 en `Test2.tscn` (hielo) y `Mundo.tscn` (goblins), y
> llevarlos a la copia `pablo` si esa es la que manda.

Los tres que pidió el Pipeline en el diario del 4/10 tras entregar los hielos
nuevos y `MsActor.jugar(..., quedarse)`. Son archivos del Juego. Están como
diff para aplicarlos **en la copia del repo que mande** (hay dos: `pablo` y
`paranda`) una vez se decida cuál; cada uno es independiente.

Antes de aplicar: leer el archivo del disco; las líneas de contexto deben
coincidir. Después: F6 sobre `Test2.tscn` (hielo) y `Mundo.tscn` (goblins).

---

## 1. `nivel_base.gd` — el hielo sale del pipeline (cierra QA_ARTE 1.1)

Los tres hielos nuevos están en
`export_godot/terrain/bosque_01/sprites/blocks/water_frozen_*.png` a 128×102
con la cara donde `water.png`, así que `_dibujar_bloque()` ya los deja a ras
sin tocar `water_block.gd`.

```diff
@@ func _agua(cell: Vector2i) -> Node2D:
 	agua.set("hielo_permanente", true)
 	agua.set("hielo", [
-		_tex_ruta(HIELO_ART + "hielo_1_nevado.png"),
-		_tex_ruta(HIELO_ART + "hielo_2_escarcha.png"),
-		_tex_ruta(HIELO_ART + "hielo_3_claro.png")])
+		_bloque("water_frozen_1_nevado"),
+		_bloque("water_frozen_2_escarcha"),
+		_bloque("water_frozen_3_claro")])
 	_dibujar_bloque(agua, _bloque("water"))
```

Y la constante deja de usarse: quitar la línea
`const HIELO_ART: String = "res://art/"` (línea ~106) si no la usa nadie más
(`grep HIELO_ART` → solo `_agua`). Después se pueden borrar
`art/hielo_1_nevado.png`, `hielo_2_escarcha.png`, `hielo_3_claro.png` y sus
`.import` (con Godot cerrado).

Comprobar: congelar agua junto a hierba en Test 2; la cara del hielo a la
altura de la hierba.

## 2. `goblin_guerrero.gd` y `goblin_arquero.gd` — morir con animación (cierra QA_ARTE 2.2)

`MsActor` en modo `ia` ya entiende `anim_orden = "death"`: elige el clip de
caída que tenga el modelo (`shot_and_fall_backward` en el guerrero) y se
queda en el último fotograma. El cuerpo tiene que dejar de moverse y de
hacer daño mientras cae, y liberarse al acabar (12 fotogramas a 12 fps = 1 s).

En **los dos** archivos, sustituir `_die()` entero:

```diff
 func _die() -> void:
 	set_physics_process(false)
+	monitoring = false                 # ya no hace daño por contacto ni recibe más golpes
+	monitorable = false
 	combate.morir()
-	queue_free()
+	anim_orden = "death"               # MsActor lo convierte en el clip de caída del modelo
+	# Si el modelo no tiene clip de muerte (el arquero, hoy), MsActor no hace nada y el goblin
+	# desaparece igual pasado el tiempo; no se queda un cadáver de pie.
+	var tw: Tween = create_tween()
+	tw.tween_interval(1.0)
+	tw.tween_property(self, "modulate:a", 0.0, 0.35)
+	tw.tween_callback(queue_free)
```

Por qué un `Tween` y no `await`: `queue_free` tras un `await` sobre un
nodo que puede haber salido del árbol (cambio de nivel, reaparición) da
error; el tween muere con el nodo.

Ojo con `goblin_escarcha.gd`: hereda de `goblin_arquero.gd` pero
**sobrescribe `_die()`** (reaparece a los 6 s con `visible = false`), así que
no le afecta; si se quiere que el dummy también caiga, es otro cambio.

Comprobar: matar un guerrero en Mundo; cae, se queda tumbado 1 s, se
desvanece. El botín (`combate.morir()`) sigue saliendo al instante.

## 3. `goblin_guerrero.gd` y `goblin_arquero.gd` — pararse al recibir un golpe (cierra QA_ARTE 2.3)

Hoy `interrupcion` solo la pone el viento; el goblin sigue andando con la
pose de golpe. `MsActor.RECORTES` ya acorta el clip de golpe a los
fotogramas 2–5 a 20 fps (0,2 s), así que basta con un parón del mismo orden.

En **los dos** archivos, en `receive_damage()`:

```diff
 	health -= amount
 	combate.herido(amount, health)
 	if stun_timer <= 0.0:
 		anim_orden = "hit"
+		# Un golpe interrumpe lo que hacía (como el viento, pero corto): sin esto el goblin
+		# sigue avanzando y atacando con la pose de golpe puesta.
+		interrupcion = maxf(interrupcion, 0.3)
 	if health <= 0.0:
 		_die()
```

Comprobar: agua a un guerrero que corre hacia ti; se frena un instante y
retoma. Si con 0,3 s el combate se siente "pegajoso" (el jugador puede
encadenar golpes y el goblin no llega nunca), bajar a 0,2.

---

## Después de aplicar

- Marcar en `docs/QA_ARTE.md` los puntos 1.1, 2.2 y 2.3 como hechos y
  anotar en `docs/DIARIO.md` en qué copia del repo se aplicaron.
- `ASSETS_PENDIENTES.md` §1 (Pipeline): el guerrero ya tiene muerte; queda
  la del arquero.
