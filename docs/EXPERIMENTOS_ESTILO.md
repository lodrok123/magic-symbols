# Dos experimentos de estilo — protocolo (4 de octubre de 2026)

Pablo quiere probar los dos caminos antes de validar el plan de
homogeneización:

- **E1 · Acercar la maga al entorno**: una maga chibi/toon sobre el
  escenario pintado. Si funciona, el resto de personajes siguen el mismo
  camino.
- **E2 · Acercar el entorno a la maga**: renderizar en 3D lo ya creado
  (bloques, props) con la misma luz y acabado que los personajes, y ver si
  así el proyecto se iguala.

Los dos se juzgan **en la misma escena** y con **las mismas medidas**, si no
cada uno gana en su propia foto.

---

## 0. Lo que ya existe y cuenta como punto de partida

Medido hoy:

| Hallazgo | Dónde | Qué significa para los experimentos |
|---|---|---|
| El Pipeline ya probó toon sobre personajes el 2/10: `pipeline/arte/comparativa_acabados.png` (raw / outline_only / toon_soft / toon_strong sobre la hierba cel) | `pipeline/arte/` | E1-a (acabado) está medio hecho; falta decidir y **exportar** con él. Hoy se exporta `raw` porque `styles/personaje_toon.json` no existe |
| Hay 12 bloques y 6 props en `pipeline/assets3d/terreno/` que no se usan. Los bloques son **los mismos de la hoja cel** (grass V 0,82 S 0,73, desviación 7,4: idénticos a los exportados); los props sí son renders 3D con sombreado suave (barril V 0,38, desviación 23) | `pipeline/assets3d/` | E2 tiene los props ya renderizados en 3D; **los bloques no existen en 3D**, hay que modelarlos (un cubo biselado con material, nada más) |
| En el montaje `prueba2_entorno3d.png` (props 3D + bloques cel + personajes raw) los props 3D ya se acercan a la maga; los bloques cel siguen siendo lo que desentona | adjunto | E2 se decide en los bloques, no en los props |
| En `paso1_chibi_mock.png` la maga de la referencia a 95 px es del mismo mundo que los cubos; a 118 px es grande | adjunto | E1 tiene altura objetivo: **95 px** |

---

## 1. La escena de juicio (común a los dos)

Una sola composición, generada por el pipeline como
`pipeline/arte/juicio_<E1|E2>.png` y, cuando se pueda, cargada en Godot en
una bahía de `VfxLabMundo`:

- Rejilla 5×4: hierba, tierra, camino, piedra, agua (los cinco bloques
  que más se ven), con un escalón de altura 1.
- Props: barril, roca, tocón, un árbol `tree_oak_2`, un tótem de `art/`
  (para ver si lo pintado aguanta en cada camino).
- Personajes: la maga en `idle` S, un goblin en `walk` W, el guardabosques.
- Fondo: el `default_clear_color` del juego (`#0D1210`), no blanco: la guía
  es oscura y sobre blanco todo parece más claro de lo que es.

Medidas por escena (script en `pipeline/tools/`, el mismo del
`style_report` del plan):

| Medida | Cómo | Objetivo |
|---|---|---|
| **Dispersión de valor** | V media de cada pieza (cara superior en losas, figura entera en personajes); se anota el rango máx−mín entre losas, props y personajes | **≤ 0,15**. Hoy: losas 0,82 / personajes 0,45 / `art/` 0,50 → 0,37 |
| **Contorno** | ¿tienen todas las piezas el mismo tratamiento de borde? (sí/no por pieza) | uniforme |
| **Detalle** | desviación típica de color por pieza | losas y personajes en la misma década (10–30) |
| **Escala** | altura de la maga en px y altura del cubo | maga 1,6–1,8 casillas |
| **Repetición** | las 20 losas en rejilla: ¿se ve un patrón de sombra? | no |
| **A ojo (Pablo)** | la escena en Godot, con `CanvasModulate` del bosque puesto | "¿parece el mismo juego?" en una frase |

---

## 2. E1 — Acercar la maga al entorno (Pipeline, 2 sesiones + Meshy)

**Hipótesis:** con proporción chibi y acabado toon, la maga entra en el
mundo pintado sin tocar las losas.

### E1-a · Acabado (media sesión, sin modelo nuevo)
1. Crear `pipeline/profiles/styles/personaje_toon.json`:
   ```json
   {"name": "personaje_toon", "color_management": "Standard",
    "toon": {"bands": 3, "threshold": 0.45, "shadow_color": [0.55, 0.50, 0.72],
             "saturation": 1.20, "value": 0.95},
    "outline": {"px": 1.0, "color": [0.10, 0.06, 0.05]},
    "lights": {"energy_scale": 0.9, "fill_energy": 300}}
   ```
   (3 bandas y no 2 como el árbol: con 2 la cara es una mancha; contorno
   1 px y no 1,5: al 0,9 de escala en pantalla tiene que medir lo mismo
   que el de las losas).
2. Renderizar solo `idle` S y `walk` W del **goblin_warrior** con él.
   Elegir entre `toon_soft` y `toon_strong` de la comparativa del día 2
   mirando la escena de juicio, no la comparativa (que está sobre blanco
   y sobre la hierba cel).

### E1-b · La maga chibi (1 sesión + créditos de Meshy)
1. Pedido a Meshy **con `docs/referencia_personaje.png` como imagen de
   entrada**, texto corto: *elfa, proporción chibi de 3 cabezas, dos
   trenzas rubias, capa azul con ribete dorado, zurrón al cinto, botas,
   T-pose, lista para rig, sin armas*. Lo que importa es la imagen; el
   texto solo repite lo que ya se ve.
2. `altura_unidades` para que salga a **95 px en pantalla**: hoy 1,7
   unidades → 118 px, así que **1,37**. Mantener `frame_px` 192×240 y que
   el pipeline recalcule `ancla_suelo_px`.
3. Rig Mixamo; retarget **solo** `idle` y `walk` (16 + 8 fotogramas × 8
   direcciones). Los 15 clips se procesan si pasa.
4. Render con `personaje_toon`. Aprobar la hoja `review/sprite_8dir.png`
   **contra la referencia** antes de nada más (paso de `ARTE.md` §4).
5. Si Meshy no da la proporción: en Blender, antes de renderizar, escalar
   el hueso `mixamorig:Head` ×1,6 y `UpperLeg`/`LowerLeg` ×0,75. Se ve raro
   en el visor y bien a 95 px.

**Resultado esperado:** dispersión de valor baja de 0,37 a ~0,30 (solo
por el personaje: las losas siguen a 0,82). Es decir, **E1 solo no cierra
la dispersión**; cierra proporción y contorno. Hay que saberlo antes de
mirar: si E1 "gana", gana con la hoja de losas nueva de la fase 2 del
plan, no con la actual.

**Coste:** créditos de Meshy, 2 sesiones de Pipeline, 0 del Juego (la
maga nueva entra por `meta.json`).

---

## 3. E2 — Acercar el entorno a la maga (Pipeline, 1–2 sesiones)

**Hipótesis:** si bloques y props se renderizan en 3D con la **misma
escena de luz** que los personajes (sin toon, sin contorno), el conjunto
se iguala aunque la maga siga siendo realista.

1. **Bloques en 3D.** Un cubo biselado (bisel 2 px al tamaño final) por
   tipo, con material de textura: las de `pipeline/assets3d/terreno/_*.png`
   (`_bark`, `_stone`, `_madera`) ya están; hierba y tierra se añaden.
   Cámara y escala **las de `character.template.json`** (misma ortográfica,
   mismo ángulo), para que la luz caiga igual que en la maga. Salida
   128×102 con la cara en y=33 (contrato). Agua: plano con material
   semitransparente sobre el cubo de tierra, no un cubo azul.
2. **Props**: los 6 de `assets3d/terreno/props/` valen; renderizar los
   que faltan (`bush`, `fern`, `signpost`, `campfire`…) a 1x al tamaño
   final.
3. **Luz**: una escena de luz compartida (`profiles/luz_mundo.json`):
   clave arriba-izquierda, relleno frío suave, sin sombra proyectada al
   suelo (la repetición la delata; `ARTE.md` §6). Personajes y bloques se
   renderizan **con este mismo archivo**.
4. **Sin toon ni contorno en nadie** en E2: el camino es "todo realista
   suave". Si se quiere comparar también "todo toon", es una variante E2',
   que es casi la fase 1+2 del plan.
5. Montar la escena de juicio y medir.

**Resultado esperado:** dispersión de valor ≤ 0,15 casi seguro (es lo
que pasa cuando todo sale de la misma lámpara); detalle en la misma
década. **Lo que se pierde:** la guía (pintado, oscuro) y la proporción
chibi de la guía y de `art/`; los tótems/seto/puesto pintados se verán de
otro mundo y habría que rehacerlos en 3D también (son unos 12 modelos).
Hay que mirar en la escena de juicio el tótem de `art/` precisamente para
ver cuánto desentona.

**Coste:** 1–2 sesiones de Pipeline (Blender, sin Meshy), 0 del Juego
(mismas rutas y contrato). A medio plazo: rehacer `art/` en 3D.

---

## 4. Cómo se decide

Las dos escenas de juicio en Godot, una al lado de la otra, con la misma
luz ambiente, y la tabla de medidas rellena. Reglas:

1. Si **E2** baja la dispersión a ≤ 0,15 y a Pablo le parece "el mismo
   juego", se gana en coste (sin modelo nuevo, sin Meshy) — pero se
   cambia la guía: hay que reescribir `ARTE.md` §1 y §6 y asumir que
   `art/` se rehace en 3D. Decisión de dirección, no técnica.
2. Si **E1** gana a ojo pero la dispersión sigue alta, lo que falta son
   las losas (fase 2 del plan), no la maga: se sigue el plan con la maga
   chibi ya aprobada.
3. Si ninguno convence, la variante **E2' (todo toon: bloques 3D + perfil
   toon en todo)** es el punto medio y coincide con el plan de
   homogeneización original.

Lo que no vale: comparar E1 sobre la hierba cel actual con E2 sobre sus
bloques nuevos. La hierba cel es el peor de los tres mundos y hace ganar a
cualquiera que la quite.

---

## 5. Reparto

- **Pipeline**: E1-a, E1-b (pasos 1–5), E2 (1–5), el script de medidas y
  las dos `juicio_*.png`.
- **Pablo**: créditos de Meshy; mirar las dos escenas en Godot; la
  decisión del §4.
- **Juego/QA**: bahía en `VfxLabMundo` que cargue una carpeta de
  `pipeline/arte/juicio_<E>/` con el mismo plano (sin tocar
  `export_godot/`); rellenar la tabla de medidas de §1 para las dos.
