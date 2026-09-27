# Contrato de hoja de animación

Esto es lo que `actor_animator.gd` sabe leer. **El animador no sabe nada
del mago**: sabe leer hojas con esta forma. Cambiar de personaje —a uno
dibujado a mano, o renderizado desde un modelo 3D— es cambiar los PNG y
nada más.

El mago actual es de relleno y lo genera `tools/gen_actor.py`, que sirve
además como implementación de referencia del contrato.

---

## La forma de la hoja

| | |
|---|---|
| Celda | **64 × 64 px** |
| Filas | **8**, una por dirección |
| Columnas | los fotogramas de *ese* clip |
| Los pies | en **y = 52** de la celda |

El ancho del PNG es `columnas × 64` y el alto siempre `8 × 64 = 512`.

`ActorAnimator` comprueba esto al arrancar y avisa por consola si algo
no cuadra. No es paranoia: un desajuste de una fila o de cuatro píxeles
de celda no se ve como un error, se ve como fotogramas cortados y
direcciones cruzadas, y eso cuesta una tarde diagnosticarlo a ojo.

## El orden de las filas

```
fila 0   E      derecha
fila 1   SE     derecha-abajo
fila 2   S      abajo          <- la de frente, y la de reposo
fila 3   SO     izquierda-abajo
fila 4   O      izquierda
fila 5   NO     izquierda-arriba
fila 6   N      arriba
fila 7   NE     derecha-arriba
```

No es un capricho. Sale de medir el ángulo del movimiento desde
"derecha" girando hacia abajo de 45 en 45, que es literalmente lo que
calcula `_row_for()`:

```gdscript
fila = round(angulo / 45 grados)
```

Si un pack futuro trae las direcciones en otro orden, **se reordenan las
filas al importarlo**, no se toca el animador.

### Ojo: el ángulo de pantalla miente

La proyección isométrica aplasta la vertical — una casilla avanza 58 px
a lo ancho pero solo 27,5 a lo alto. El ángulo que se ve en pantalla no
es el del mundo, así que antes de medirlo hay que deshacer el
aplastamiento multiplicando la Y por **2,109**. Sin eso el personaje
mira mal justo en las diagonales, que es donde más se nota.

## Los clips

| clip | columnas | lo mueve | notas |
|---|---|---|---|
| `walk` | 8 | **distancia** | en bucle |
| `idle` | 4 | reloj, 4 fps | en bucle |
| `cast` | 6 | reloj, 14 fps | un disparo |
| `hurt` | 3 | reloj, 12 fps | un disparo |
| `death` | 6 | reloj, 8 fps | un disparo, se queda en el último |

### Por qué andar va con la distancia y el resto con el reloj

Es la decisión que sostiene todo lo demás.

Si el paso fuera por tiempo, **los pies patinarían** en cuanto cambiase
la velocidad: despacio se arrastran, deprisa resbalan hacia atrás. El
pie tiene que quedarse clavado en el suelo mientras el cuerpo pasa por
encima, y eso solo se consigue contando píxeles recorridos.

Al revés también falla: si respirar fuera por distancia, el personaje
dejaría de respirar al pararse.

Consecuencia práctica: **`stride` describe la anatomía del personaje**
—lo larga que es su zancada—, no su prisa. Para que vaya más lento se
toca `velocidad` en `player.gd` y el ciclo se ajusta solo. Tocar los dos
lo frena dos veces.

## Cómo se entera de cada cosa

| clip | cómo se dispara |
|---|---|
| `walk` / `idle` | **observado**: mira si su padre cambió de posición |
| `hurt` / `death` | **observado**: escucha la señal `health_changed` |
| `cast` | **avisado**: `spellcaster.gd` llama a `play("cast")` |

Los tres primeros no requieren que nadie coopere, y por eso el mismo
componente vale para el jugador, para un enemigo o para una caja
empujada por el viento. `cast` es la excepción honesta: "he empezado a
lanzar" no se deduce de una posición.

---

## Cambiar de personaje

1. Genera las cinco hojas cumpliendo la tabla de arriba.
2. Déjalas en `art/` con los mismos nombres (`hero_walk.png`…), o
   cambia las rutas en `ActorAnimator.hero()`.
3. Arranca y **mira la consola**: si alguna hoja no cuadra, lo dirá.
4. Ajusta `foot_offset` si el personaje flota o se hunde en el bloque
   (es `y_de_los_pies − 32`).
5. Ajusta `stride` mirándolo andar, hasta que los pies no patinen.

Si el personaje nuevo trae más animaciones (correr, nadar, saltar), es
una línea más en el diccionario de `ActorAnimator.hero()`. La máquina de
estados ya sabe encadenar ciclos y disparos.
