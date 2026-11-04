# Rocas empujables y placas de peso (5/11/2026)

Petición de Pablo tras el playtest del Bosque 02: «las rocas de tamaño medio y pequeño deberían ser empujables, podemos hacer pequeños puzles de peso». Rama `claude/rocas-empujables`.

## 1. Tamaños de roca (criterio numérico)

Se mide sobre el modelo ya a escala (alto = `Pieza3D.MEDIDA`; huella = lado mayor de la planta). Lo decide `RocasEstilizadas.tamano_de(id)`; las constantes están al principio de `mundo/rocas_estilizadas.gd`.

| Tamaño | Regla | Rocas (alto × huella, u) | Qué es |
|---|---|---|---|
| grande | alto ≥ 1,4 **o** huella ≥ 1,4 | `roca_est_0` 1,40 × 1,43 · `roca_est_4` 1,50 × 0,84 | muro fijo, como hasta ahora |
| mediana | 0,75 ≤ alto < 1,4 | `roca_est_1` 1,30 × 1,16 · `roca_est_2` 1,30 × 1,14 · `roca_est_3` 0,90 × 1,38 | **se empuja**, pesa 2 |
| pequeña | 0,45 < alto < 0,75 | `piedra_est_0` 0,50 × 0,51 | **se empuja**, pesa 1 |
| pisable | alto ≤ 0,45 (`ColisionPieza.ALTO_MIN_SOLIDO`) | `piedra_est_1..4` 0,40 … 0,26 | sin cuerpo: se pisa, no se empuja |

Las variantes `musgo` y `magma` miden igual que la neutra. La pequeña empujable **tiene colisión** (hay que chocar con ella para empujarla): solo lo muy bajito (guijarros, 0,45 o menos) sigue atravesándose.

## 2. Mecánica (no hay sistema paralelo)

Es el mismo `BloqueEmpujable3D` con un tercer material, `roca`: mismo clip `empujar`, mismo arranque (0,35 s apretando), misma velocidad (1 u/s), una casilla por empujón, encadena si se sostiene, se deshace a los 3 s si queda atascada, viento la mueve. Solo cambia el modelo (la roca estilizada de la variante del bioma) y el peso. No tiende los huecos de las vetas (eso es solo del bloque de piedra de enlace).

Peso (`peso_valor`): roca pequeña 1 · roca mediana 2 · bloque de piedra 3 · hielo 1 · cualquier otro «peso» sin valor (el bloque de tierra del hechizo) 1.

## 3. Placas de peso

`pulsador modo=presencia peso=<n>`: se pisa cuando lo que hay en SU casilla (grupo `peso`) suma `n` o más; la jugadora no cuenta. Si hay algo encima pero pesa menos, sale una vez el rótulo «POCO PESO (1 de 2)». Sin `peso=` la placa es la de siempre (cualquier cosa del grupo `peso`, o la jugadora).

## 4. Formato en el mapa

```
; pieza <id> roca_empujable <x> <y> [tam=mediana|pequena] [variante=musgo|neutra|magma] [forma=<n>]
```
- `tam` por defecto `mediana`. `tam=grande` se rechaza con aviso (las grandes son muro).
- `variante` por defecto la del bioma (`RocasEstilizadas.variante_actual()`: bosque = musgo, cueva = neutra).
- `forma` = índice del modelo (`roca_est_<n>` para la mediana, `piedra_est_<n>` para la pequeña); si no es del tamaño pedido se usa el de por defecto (mediana 1, pequeña 0).
- Mismas señales y condiciones que `bloque` (`movido`, `reaparece`; `quieto`, `en_marcha`).

Las rocas de decorado (`; decorado roca_est_musgo_N x y`) siguen siendo fijas: están horneadas en el nivel. Para hacer empujable una concreta, sustituirla por una `pieza … roca_empujable` en su casilla.

## 5. Puzle nuevo: la balanza del claro (Bosque 02, sección 14)

Orilla este, al norte del camino (y = 31, que queda libre). Dos placas de peso en x = 22: la de arriba (22,30) pide **2**, la de abajo (22,32) pide **1**. Pista de arriba: roca mediana (19,30) y, delante, una piedrecita (21,30). Pista de abajo: piedra pequeña (19,32). Se empuja desde el oeste (x = 18, el camino).

1. La piedrecita sola sobre la placa de 2 no basta («POCO PESO»): hay que seguir empujándola hasta (23,30).
2. La mediana (3 empujones) a la placa de 2. La pequeña (3 empujones) a la placa de 1.
3. Con las dos placas pisadas aparece el cofre común (22,34, `tabla:cofre_pequeno`, flag `bosque02.balanza.cofre`).

Si la mediana se queda en la placa de 1 se saca hacia el norte empujando desde (22,33). El archivo `Nivel_Bosque_02.tscn` no se ha horneado: las piezas y reglas se leen del `.txt` en ejecución, así que el puzle funciona sin hornear; al integrar basta con hornear como siempre.

## 6. Pruebas

`herramientas/prueba_rocas_empujables.gd` (tamaños, 4 direcciones, límites, placas de peso, empuje real con teclas en la Sala del Empuje, balanza del Bosque 02). `prueba_bosque_02_recorrido.gd` incluye el paso `3b` (la balanza) y cuenta ahora 12 cofres (8 comunes).
