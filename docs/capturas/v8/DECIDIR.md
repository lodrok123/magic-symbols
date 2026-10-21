# V8 «presupuesto» — lo que decide Pablo (21/10/2026)

Medido con ventana (GPU: NVIDIA GeForce RTX 3070, Forward+, 1152×648, vsync apagado). Herramientas: `herramientas/captura_presupuesto_v8.gd` (árboles) y
`herramientas/captura_texturas_v8.gd` + `herramientas/comparar_capturas_v8.py` (texturas). Los números en bruto están en `medidas_arboles.txt`,
`medidas_texturas_1024.txt` y `comparacion_texturas.txt` (esta carpeta).

**Aviso de honestidad sobre el tiempo:** mientras medía había otro Godot abierto (el juego, `Magic_Symbols (DEBUG)`) y otros agentes usando la GPU, así que los
milisegundos bailan entre pasadas (p. ej. «actual · jugador» salió 2,4 / 2,5 / 4,2 / 4,7 ms de GPU en cuatro pasadas). En las tablas pongo el **mejor valor de
varias pasadas** (el menos contaminado) y, en triángulos, valores exactos que no dependen de eso.

---

## 1. Árboles `_2` en el Bosque 01 — DECIDE PABLO (aspecto)

**No he tocado el nivel ni ninguna pieza.** La sustitución vive solo en la herramienta de captura: una vez montada la maqueta, cambia la malla de los lotes
(MultiMesh) de `arbol_redondo` y `pino` por las de `arbol_redondo_2` y `pino_2`, con la misma colocación, giro y escala.

Corrección a `PRESUPUESTO.md`: el nivel **ya mezcla** los dos modelos. De 307 árboles, 133 `arbol_redondo` y 89 `pino` son de 12 k, pero **43 `arbol_redondo_2` y
42 `pino_2` ya están puestos** (cada pieza instancia su `.tscn` de `arte/piezas/`). Los triángulos de árbol hoy son **2,90 M**, no 3,66 M; el total de lotes del
nivel, **4,66 M** (559 piezas con las del borde).

| Opción | Copias (rojo/pino de 12 k → `_2`) | Triángulos de árboles | Triángulos de todos los lotes | Triángulos dibujados en el fotograma (con sombras): jugador · denso · amplia | GPU ms (mejor): jugador · denso · amplia | Capturas |
|---|---|---|---|---|---|---|
| **Actual** (el nivel tal cual) | 133 + 89 de 12 k, 85 ya `_2` | 2 897 903 | 4 661 031 | 3,73 M · 3,39 M · 5,47 M | 2,43 · 3,02 · 5,39 | `bosque_{jugador,denso,amplia}_actual.png` |
| **Mitad** (alternos: 1 de cada 2 de los de 12 k pasa a `_2`) | 75 + 55 de 12 k, 177 `_2` | 2 069 081 | 3 832 209 | 2,75 M · 2,29 M · 4,10 M | 1,98 · 2,38 · 3,68 | `bosque_*_mitad.png` |
| **Todo `_2`** | 0 de 12 k, 307 `_2` | 884 556 | 2 647 684 | 1,43 M · 1,05 M · 2,24 M | 1,51 · 1,71 · 2,48 | `bosque_*_todo2.png` |

- «jugador» = la vista de la jugadora con zoom 16; «denso» = el punto del mapa con más árboles a menos de 9 unidades, zoom 16 (mismo punto en las tres opciones);
  «amplia» = la vista de la jugadora con zoom 34.
- Ahorro de triángulos del nivel entero: mitad −0,83 M (−18 %), todo `_2` −2,01 M (−43 %); coincide con lo que decía `PRESUPUESTO.md` (≈ 2 M).
- Ahorro de GPU (mejor valor): todo `_2` baja de 2,4–5,4 ms a 1,5–2,5 ms (≈ −40 a −55 %). En una 3070 el nivel ya iba sobrado (>200 fps en la vista normal);
  **el ahorro importa en máquinas más flojas**, no aquí. No he podido medir en ninguna otra GPU.
- Llamadas de dibujo: 291 → 337 (mitad) → 287 (todo `_2`) en «jugador»: la mitad parte cada lote en dos, es un coste pequeño y real.

**Lo que se ve (ábrelo tú):** `bosque_denso_actual.png`, `bosque_denso_mitad.png`, `bosque_denso_todo2.png`.
- `arbol_redondo_2` es una copa de bolas con el mismo tono que el `arbol_redondo` de 12 k: a esta distancia se parece mucho (pierde las hojas sueltas del de 12 k,
  que se ven como un follaje más «picudo»).
- `pino_2` **no se parece al `pino` de 12 k**: sale **azul turquesa**, con pisos de ramas lisos, frente al pino verde oscuro de agujas del de 12 k. Con «todo `_2`» el
  bosque entero pasa de verde a verde + turquesa. (El nivel ya tiene 42 turquesas hoy, son las que se ven en «actual».) Si el turquesa no es lo que quieres, el
  problema es el color/textura de `pino_2`, no su número de triángulos.

**Recomendación:** (a) **cambiar `arbol_redondo` → `arbol_redondo_2` en todos** (ahorro calculado ≈ 133 × (12 000 − 3 700) ≈ 1,1 M, sin cambio de especie), y (b) **`pino`
dejarlo como está o cambiarlo solo si arreglas el color de `pino_2`** (≈ 0,9 M más de ahorro: 89 × (12 000 − 1 800)). Ese «solo `arbol_redondo`» NO lo he medido: son
cuentas sobre los números de arriba. Si quieres un solo cambio sin pensar, «mitad» da un bosque con más variedad pero cuesta más llamadas de dibujo que «todo `_2`».

Cómo aplicarlo cuando decidas (no lo he hecho): en `Nivel_Bosque_01.tscn`, cambiar el `ext_resource` `2_arbol_redondo` (y, si procede, `19_pino`) para que apunte a
`res://arte/piezas/arbol_redondo_2.tscn` (`pino_2.tscn`); es un cambio de 1 línea por recurso.

Incidental: al cargar el nivel Godot avisa de dos UID obsoletos (`uid://bi20hna1xj8yd` = `arbol_redondo_2.tscn` y `uid://cv1anqonwbtep` = `pino_2.tscn`) y usa la ruta
de texto: funciona, pero conviene que el editor los vuelva a guardar.

---

## 2. Texturas de 2048 de personajes y bestias → 1024 — APLICADO (reversible)

Medido con la memoria de textura de la GPU (`Performance.RENDER_TEXTURE_MEM_USED`, con ventana), cargando los 15 GLB uno a uno con `Pj3D`:

| Modelo | Antes (2048) | Después (1024) |
|---|---|---|
| alchemist_elf | +10,7 MB | +2,7 MB |
| canouro | +8,0 MB | +2,0 MB |
| elemental_bosque | +6,7 MB | +2,7 MB |
| emberheart (el «loberno» del juego) | +10,7 MB | +2,7 MB |
| emberstride | +10,7 MB | +2,7 MB |
| gato_guardabosques | +10,7 MB | +2,7 MB |
| goblin_archer_chibi | +13,3 MB | +5,3 MB |
| grandmaster | +10,7 MB | +2,7 MB |
| lince / lince_gato | +10,7 MB cada uno | +2,7 MB cada uno |
| woodland_wanderer (= `_suave`, la jugadora) | +16,7 MB | +8,7 MB |
| woodland_wanderer_v1 | +10,7 MB | +2,7 MB |
| **Los 15 a la vez** | **+130,1 MB** | **+40,1 MB (−90 MB, −69 %)** |

(`loberno`, `woodland_wanderer_suave` salen +0: comparten modelo con `emberheart` / `woodland_wanderer` por `Pj3D.MODELO_DE`; `canouro_anim` no carga con `Pj3D`
—no se midió su memoria—; la lista de arriba solo toca las texturas con nombre `canouro_*`, y si `canouro_anim.glb` trae las suyas, quedan en 2048.) Lo que se tiene cargado a la vez en el Bosque 01 (jugadora + goblins +
lobo) es un subconjunto: la jugadora sola baja ≈ 8 MB, el arquero ≈ 8 MB, el lobo ≈ 8 MB.

**¿Se ve? No.** Comparación píxel a píxel con una escena mínima y fija (luz y suelo fijos, animación parada), a la distancia del juego (`ZOOM_INICIAL` = 6,0, la
jugadora mide ≈ 100 px de alto) y a la más cercana que permite el juego (`ZOOM_MINIMO` = 2,0, ≈ 320 px de alto):

| Vista | Píxeles del personaje distintos (>0) | Distintos >8/255 | Diferencia media sobre el personaje | Diferencia media en la imagen |
|---|---|---|---|---|
| zoom 6 (juego, 4 personajes) | 81,8 % | 25,3 % | 7,4/255 (2,9 %) | 0,14/255 |
| zoom 2, jugadora y arquero | 81,6 % | 13,2 % | 4,5/255 (1,8 %) | 0,36/255 |
| zoom 2, goblins | 75,5 % | 10,1 % | 3,3/255 (1,3 %) | 0,38/255 |

Casi todos los píxeles cambian un poco, pero la diferencia media es del 1–3 %, y la imagen de diferencias multiplicada ×8 (`texturas_*_dif_x8.png`) muestra solo
contornos y bordes del atlas (el máximo, 200+, está en aristas de 1 px: antialiasing y mipmaps), no zonas lavadas. Mirando las capturas lado a lado
(`texturas_zoom2_jugadora_actual.png` / `_1024.png`) no veo diferencia. **Por eso lo dejo aplicado.**

Límites de la prueba (dicho para que no se tome por más): el ojo lo juzga mi lectura de las capturas, no Pablo; con la ventana a 1152×648. En un monitor 4K a
pantalla completa el personaje sale ≈ 3× más grande: si ves blandura ahí, vuelve a `size_limit=0` solo en los de la jugadora (`woodland_wanderer_suave_*`).

**Archivos cambiados** (`process/size_limit=0` → `1024` en cada `.import` de `arte/modelos/`; la lista exacta, 38 texturas, está en `texturas_1024_archivos.txt`):
`alchemist_elf_Image_{0,1,2}`, `canouro_{0,1}`, `elemental_bosque_g_Idle_11_Image_2`, `emberheart_{0,1,2}`, `emberstride_{0,1,2}`,
`gato_guardabosques_Image_{0,1,2}`, `goblin_archer_chibi_Image_{0,1,2}`, `grandmaster_Image_{0,1,2}`, `lince_{0,1,2}`, `lince_gato_{0,1,2}`, `loberno_{0,1}`,
`woodland_wanderer_{normal,texture_0,texture_0_metallic_roughness}`, `woodland_wanderer_suave_{normal,texture_0,texture_0_metallic_roughness}`,
`woodland_wanderer_v1_{normal,texture_0,texture_0_metallic_roughness}` (todos `.jpg`). Reimportado con `--headless --import`. Para deshacer: poner `=0` y reimportar.
No se han tocado los GLB ni los JPG originales.

**No incluido, por si quieres:** `chibi_elf_texture_0_metallic_roughness.png` mide **4096×4096** (7,6 MB en disco, ≈ 21 MB de VRAM) y `chibi_elf_normal.png` /
`chibi_elf_texture_0.png` 2048; `chibi_elf` no estaba en las 15 y solo lo nombra `pj_3d.gd` en tablas de postura (parece un modelo antiguo). Si ya no se usa, es la
textura más grande del repositorio.

---

## 3. Piezas de 12 k (`roca_musgosa`, `tronco_musgoso`, `troncos_apilados`) — SOLO PROPUESTA

| Pieza | Copias | Triángulos (cada una) | Total | Alto en el juego | Alto en pantalla con zoom 6 | Con 6 k |
|---|---|---|---|---|---|---|
| `roca_musgosa` | 29 | 12 000 | 348 000 | 0,5 u | ≈ 54 px | 174 000 |
| `tronco_musgoso` | 20 | 12 000 | 240 000 | 0,38 u | ≈ 41 px | 120 000 |
| `troncos_apilados` | 19 | 12 000 | 228 000 | 0,45 u | ≈ 49 px | 114 000 |
| **Suma** | 68 | | **816 000** (17,5 % de los 4,66 M del nivel) | | | **408 000 (ahorro −0,41 M)** |

Son piezas **pequeñas** (la mitad de una casilla de alto, ~100 px por unidad con el zoom de arranque): una roca de 12 k triángulos cubre del orden de 4 000 px, es
decir **más de 2 triángulos por píxel**. Con 6 k seguiría habiendo ≈ 1 por píxel; incluso con 2,5 k (la escalera más baja) la silueta aguantaría a esa distancia.
Su textura es de 512–1024.

**Propuesta:** bajar las tres a **6 k**, y probar 2,5 k en la roca (la más pequeña y la más repetida). No lo he hecho: `recibir_assets.py lote --tris 6000` necesita
la lámina original (`praderas.glb` para la roca, `bosque_flora.glb` para los troncos; están en `arte/meshy/piezas/`) y, en esta máquina, **le faltan `numpy` y
`PIL`** (`ModuleNotFoundError`), así que ni siquiera puedo ejecutarla en seco. Para comparar la calidad ya hay escaleras 2,5/6/12/24 k en
`arte/meshy/aprobacion3d/rock/escalera.png` y `.../s_vine_covered_log/escalera.png`. Orden de preferencia por ahorro/riesgo: roca (−0,17 M), tronco (−0,12 M), troncos
apilados (−0,11 M).

---

## 4. Comprobaciones (21/10, tras los cambios)

`escenario_bosque_01` (--fixed-fps 30): FALLOS 0 · `escenario_playtest_eow` (--fixed-fps 30): FALLOS 0 · `prueba_presentacion`: FALLOS 0. El mensaje
de PagedAllocator al salir es el aviso habitual de los scripts de prueba.


---

## 5. Aplicado (21/10) — decisiones de Pablo sobre 1 y 3

Medido con ventana, mismas vistas y herramienta (`captura_presupuesto_v8.gd`, modo «actual»), 3 pasadas (la GPU estaba menos contaminada que en la medición anterior: las tres pasadas coinciden a ±0,03 ms; números en `medidas_aplicado.txt`, capturas en `aplicado/`). Antes = fila «Actual» de la sección 1.

| | Antes | Después |
|---|---|---|
| Triángulos de árboles (lotes) | 2 897 903 | **1 794 136** (−1,10 M) |
| Triángulos de todos los lotes del nivel | 4 661 031 | **3 149 264** (−1,51 M, −32 %) |
| Triángulos dibujados en el fotograma · jugador / denso / amplia | 3,73 M · 3,39 M · 5,47 M | **2,15 M · 1,40 M · 2,39 M** |
| GPU ms · jugador / denso / amplia | 2,43 · 3,02 · 5,39 (mejor de varias pasadas) | **1,72 · 2,00 · 2,68** (mejor de 3) |
| Llamadas de dibujo (jugador / denso / amplia) | 280 / 258 / 443 | 291–302 / 166 / 335 |

Qué se aplicó: (a) `arbol_redondo` → `arbol_redondo_2` en las 133 copias (ahora 176 `_2`; `pino` 89 de 12 k y `pino_2` 42 sin cambios);
(b) `roca_musgosa`, `tronco_musgoso`, `troncos_apilados` de 12 k a 6 k (−0,41 M, justo lo calculado). El resto del ahorro (−1,10 M) es de los árboles.
Aviso de honestidad: los «antes» de GPU salen de pasadas con el sistema más cargado, así que la mejora en ms está algo inflada; los triángulos son exactos.
Cómo deshacerlo: `DESHACER.md`. Capturas de las piezas: `piezas_6k/` (ver ahí `zoom6`, `zoom2` y `lupa_*`).
Roca de 2,5 k: hecha y comparada, **no instalada** (la silueta aguanta, pero se ven las facetas y aparece una mancha naranja en un triángulo del musgo); instrucciones en `DESHACER.md` §3.