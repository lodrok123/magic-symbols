# Plan de acción — `PruebaTest2` validada como lockeo de arte (5 de octubre de 2026)

Dos frentes: **rendimiento** (tirones y memoria al 99 %) y **assets mejorables** con responsable.
Reparto: **Pablo** genera assets (Meshy / texturas) y decide; **Pipeline** valida arte, integra y programa
(incluido el Juego 2D mientras el 3D sea POC); **QA** (este contexto) mide y aprueba.

---

## 1. Rendimiento

### 1.1 Lo que se sabe sin medir (leído en `prueba_test2.gd`, `hierba_3d.gd` y los `.import`)

"Godot Engine (2)" con 2,8 GB son **dos procesos**: editor + juego. El editor solo ya se queda con
todo lo importado de `poc_25d\` (incluidos `hero`, `hero_v2`, `chibi_test`, `goblin_warrior`:
~110 MB de GLB y PNG que no usa ninguna escena viva). Lo que de verdad cuesta, por orden:

| # | Sospechoso | Evidencia | Efecto |
|---|---|---|---|
| 1 | **Texturas sin comprimir en VRAM** | `*.glb.import` y `*_Image_*.jpg.import` llevan `compress/mode=0` (lossless). Cada atlas 2048² RGBA = 16 MB sin comprimir; cada personaje trae 3 (color, normal, metal-rough) y cada biblioteca otros 3 | 6 GLB × 3 × 16 MB ≈ **300 MB** solo en atlas, ×1,33 con mipmaps. Comprimidas (VRAM compressed, BPTC/S3TC) serían ~75 MB |
| 2 | **Reimportación "detect 3D" en caliente** | `detect_3d/compress_to=1` en los PNG de `suelo_meshy` y `vfx`: la primera vez que un PNG se usa en 3D el editor lo marca y lo **reimporta al vuelo** (tirón de 1–3 s, luego nada) | parte de los tirones en el primer arranque de cada sesión |
| 3 | **Hierba: un solo MultiMesh para todo el mapa** | `Hierba3D` siembra `densidad=10`/unidad² sobre 92×92 unidades → ~40–50 k matojos + ~12 k tarjetas + flores en **tres** MultiMesh sin trocear. Un MultiMesh tiene un único AABB: se dibuja entero aunque la cámara vea un 10 % | GPU: cada fotograma dibuja toda la hierba del mapa; con sombras (abajo), dos veces |
| 4 | **Sombras direccionales a 60 m sobre todo** | `_sol.shadow_enabled = true`, `directional_shadow_max_distance = 60`; nadie pone `cast_shadow = OFF` salvo los VFX | el pase de sombra repite todo el decorado (centenares de `MeshInstance3D` de 300–3 400 tris) y toda la hierba |
| 5 | **Decorado como nodos sueltos** | `_pieza()` hace `duplicate()` por casilla: cada árbol, seto o piedra es su `MeshInstance3D` (los `#` del plano son ~un tercio de 1 600 casillas → 400–500 nodos) | 400–500 draw calls + 400–500 en el pase de sombra; el `duplicate()` masivo también cuesta al arrancar |
| 6 | **Mipmaps apagados** en PNG importados como 2D (`mipmaps/generate=false`) y usados en 3D | texturas de suelo y VFX | brillo/aliasing al alejar y más coste de muestreo; no es memoria |
| 7 | Memoria del editor | los 4 modelos descartados y sus texturas extraídas siguen en `poc_25d\` | ~110 MB en RAM del editor, sin usar |

Lo que **no** es el problema: el suelo (2 MultiMesh), el bucle `_process` (ligero), la hierba por CPU (el
viento va por shader), la física (no hay cuerpos: la colisión es por letra del plano).

### 1.2 Medir antes de tocar (Pablo, 10 minutos)

La maqueta ya tiene los interruptores. Con F6 sobre `PruebaTest2`, mirar los FPS del HUD en el mismo sitio
(junto a la fogata, mirando al bosque) y apuntar:

| paso | tecla | qué se apaga | si los FPS suben mucho → |
|---|---|---|---|
| 1 | — | nada (línea base) | |
| 2 | **H** | sombras | culpable #4: sombras |
| 3 | **G** | hierba | culpable #3: hierba sin trocear |
| 4 | **K** | decorado | culpable #5: draw calls |
| 5 | **P** | partículas | VFX (poco probable) |
| 6 | Monitor de Godot: *Depurador → Monitores → Rendering → Draw Calls, Primitives, Video Mem* | | números para la tabla |

Y para los tirones: `Depurador → Perfilador`, grabar 20 s andando. Si los picos coinciden con "primera
vez que aparece X" (primer hechizo, primera fogata en pantalla) es compilación de shader o reimportación
(#2); si son periódicos, es el recolector (`duplicate()`/strings) o la cámara lenta. Apuntar también si
el 99 % es CPU o GPU (Administrador de tareas, columna GPU).

### 1.3 Arreglos, por coste/beneficio (Pipeline programa, salvo lo marcado)

| # | arreglo | dónde | coste | beneficio esperado |
|---|---|---|---|---|
| A | **Comprimir texturas a VRAM**: en Godot, seleccionar los `.glb` y las texturas extraídas → Importar → `compress/mode = VRAM Compressed`, `mipmaps = on`; y poner un `poc_25d/.import_defaults` o preset de proyecto para que lo nuevo entre así | `.import` (los genera Godot) | 15 min | memoria ÷4 en texturas; menos tirones de detect-3D |
| B | **Mipmaps** en `suelo_meshy\*` y `vfx\*` (`mipmaps/generate = true`, `detect_3d` apagado) | `.import` | 5 min | sin aliasing, sin reimportación en caliente |
| C | **Trocear la hierba en bloques** de 8×8 casillas: un MultiMesh por bloque (≈25 por mapa), cada uno con su AABB; Godot descarta los que no se ven | `hierba_3d.gd` (`sembrar`) | 1 h | GPU: solo se dibuja la hierba en pantalla (10–20 % del mapa) |
| D | **Hierba sin sombra**: `cast_shadow = OFF` en los tres `MultiMeshInstance3D` de la hierba (las briznas no proyectan sombra legible a este tamaño) y `directional_shadow_max_distance` 60 → 30 | `hierba_3d.gd`, `prueba_test2.gd` | 10 min | pase de sombra a la mitad |
| E | **Decorado por MultiMesh**: agrupar las copias de cada `id` (todos los `arbol_redondo`, todos los `pino`…) en un MultiMesh por pieza en vez de `duplicate()`; las que necesitan girar (`_girar`) o animarse siguen sueltas | `prueba_test2.gd` (`_poner`, `_pieza`) | 2–3 h | 400–500 draw calls → ~25; arranque más rápido |
| F | **Limpiar `poc_25d\`** con `ORDENAR_POC.cmd` (ya está) | — (Pablo) | 1 min | ~110 MB fuera del editor |
| G | Sombras de contacto baratas: si tras A–E las sombras siguen pesando, cambiar la sombra direccional por un **disco oscuro** bajo cada personaje y decorado sin sombra | `pj_3d.gd` | 1 h | sombras casi gratis; es lo que hacen Link's Awakening y similares |

Orden: **A + B + F hoy** (sin código, son ajustes de importación), medir, y luego **D → C → E** según lo
que diga la tabla de 1.2. G solo si hace falta. Objetivo: 60 FPS estables con sombras en el PC de Pablo y
el proceso del juego por debajo de 1 GB.

---

## 2. Assets mejorables — tabla por responsable

Estado tras la validación: lo que está **bloquea la prueba** (B), lo que es **mejora** (M), lo que es
**pendiente conocido** (P). Columnas: quién genera, quién valida/integra.

### 2.1 Pablo — generar (Meshy / texturas)

| id | tipo | problema | qué generar | prio |
|---|---|---|---|---|
| `cartel` | decorado | es un poste sin tablón | poste + tabla rectangular, veta de madera, sin texto | B |
| `baldosa_guardado` | decorado | losa gris ilegible | losa de piedra con runa grabada que brilla (celeste), borde biselado | B |
| `pasadero` | decorado | placa plana beige | piedra pasadera redondeada, gris, musgo en el borde | B |
| `seto_seco` | decorado | plano, en fila parece un ciempiés | seto compacto redondeado, ramas secas; mientras, `arbusto_otono` | B |
| `arbusto` | decorado | manchas salmón en la copa | arbusto solo verde, dos tonos (`no flowers, no pink`) | M |
| `arbusto_flores` | decorado | flores = parches rosas planos | 5–7 flores pequeñas blancas/amarillas (no rosas: chocan con `flor_reactiva` y `pocion`) | M |
| `tocon` | decorado | cara cortada rosada | anillos marrón claro (`no pink`) | M |
| `matas` | decorado | rocas de cristal | retirar (las pone `Hierba3D`) o mata verde 3–4 manojos | M |
| `remolino_viento` | vfx | azul: se confunde con agua/hielo | mismo diseño en **verde claro** (`#8FD46A`) | B |
| `llama` | vfx | tocaba el borde del PNG | con margen, o se usa `llama_tira8` | M |
| `burbuja`, `gota`, `hoja`, `brasa`, `petalo` | vfx | traen "satélites" que como partícula se ven dobles | `single object, no extra pieces` | M |
| `goblin_warrior_chibi` | personaje | pelo tapa la cara, piel pálida; a 75 px es un bulto | pelo corto/recogido, piel verde saturada (`goblin_referencia.png`) | M |
| `enemy_goblin_archer` chibi | personaje | no existe en chibi; el arquero sigue siendo el realista | goblin arquero chibi, arco, mismas proporciones que el guerrero | P |
| `master_elf`/alquimista chibi | personaje | hoy es el guardabosques teñido | alquimista chibi (bata, frascos) | P |
| `garrote`, `escudo`, `daga` | equipo | sin origen ni orientación para `equipo\` | nada que generar: es preparación (Pipeline) | P |
| empujables `tierra`/`hielo` | decorado | `caja_cristal` no vale | nada que generar: cubos con `cuerpo.png` / textura de hielo (Pipeline) | P |
| oro | objeto | no salió en la lámina 4 | moneda/pila de monedas chibi | P |
| `suelo_meshy\*` | texturas | demasiado claras (V 0,8–0,99) | **no regenerar**: oscurecer ×0,78 en el PNG o en el shader (Pipeline) | M |
| canon de la maga | decisión | dos looks (master dorado/verde vs. arte pastel blanco/azul) | **decidir** cuál es la chibi antes de pedir más decorado "con su acabado" | B |

### 2.2 Pipeline — validar arte, integrar, programar

| tarea | archivos | qué | prio |
|---|---|---|---|
| Sustituciones sin Meshy | `prueba_test2.gd` | `puesto` → `puesto_mercado` (`mercado.glb`); `seto_seco` → `arbusto_otono` (`arboles_2.glb`); retirar `flores`, `caja_cristal`; usar `arco_ruina` como segunda puerta | B |
| Integrar lo regenerado | `meshy\<id>.glb`, `ESTADO.md` | `agrupar_3d.py` o renombrado; comprobar alto, origen y que la pieza pasa el catálogo (`CatalogoAssets`, tecla 1) | B |
| Rendimiento A–E de §1.3 | `.import`, `hierba_3d.gd`, `prueba_test2.gd` | ver arriba | B |
| Suelo | `prueba_test2.gd` (shader) o PNG | oscurecer texturas ×0,78 y devolver la luz a ambiente 0,6 / sol 1,0 | M |
| Equipo | `equipo\` | preparar `garrote`/`escudo`/`daga` (origen mango/centro, +Y) | P |
| Empujables | `prueba_test2.gd` | cubos con `cuerpo.png` y una textura de hielo (puede ser `water_arriba` desaturada) | P |
| Oro provisional | `prueba_test2.gd` | ya por código; cambiar cuando llegue el modelo | P |
| **Pipeline 2D** (sigue vivo mientras el 3D sea POC) | `styles/personaje_toon.json`, `EXPORTAR_GODOT.cmd`, `build_character.py`, `exportar_godot.py` | los 7 puntos del diario de hoy (jsonschema, `/dev/null`, fase de arte, cabecera `REPORTE.md`, atlas desde master, perfil toon, `walk_*` con desplazamiento) | M |
| Juego 2D | `goblin_guerrero.gd`, `goblin_arquero.gd`, `nivel_base.gd` | aplicar `docs/CAMBIOS_JUEGO_PENDIENTES.md` (los escribió el Juego; si el Pipeline los integra, anotarlo en el diario) | M |
| Licencias | `pipeline/catalogo.json`, créditos | `tree_ghibli_01` es CC-BY: acreditar; los Meshy, propios | P |

### 2.3 QA (este contexto)

| tarea | cuándo |
|---|---|
| Rellenar la tabla de 1.2 con los FPS de Pablo y confirmar culpables | tras la medición |
| Hoja de contacto de cada pieza regenerada junto a la chibi antes de integrar (`referencias\hoja_*.png`) | por tanda |
| Medir memoria del proceso del juego (no del editor) tras A+B+F | tras A+B+F |
| Cerrar E1 en `EXPERIMENTOS_ESTILO.md` con la captura de la chibi en `TestJugabilidad` (2D) y la de `PruebaTest2` (3D) | cuando acabe el render de `chibi_elf` |

---

## 3. Orden de la semana

1. **Hoy**: A + B + F (importación y limpieza), medir 1.2, decidir canon de la maga.
2. **Mañana**: Pablo genera los 4 B de decorado + `remolino_viento`; Pipeline hace sustituciones y D.
3. **Después**: C y E (hierba y decorado por MultiMesh); los M de decorado por tandas; los P cuando toque.

---

## 4. Hecho por el Pipeline (5 de octubre, noche; copia `paranda`)

| tarea §2.2 | estado | dónde |
|---|---|---|
| Sustituciones sin Meshy | hecho: `SUSTITUTAS` (árbol/pino `_2`, `arbusto_otono`, `puesto_mercado`, `arco_ruina` en la puerta X); retiradas `matas`, `flores`, `caja_cristal`. La "segunda puerta" no existe en el plano (solo hay una X): `arco_puerta` queda de reserva | `prueba_test2.gd` |
| Integrar lo regenerado | herramienta lista: `meshy/INTEGRAR_PIEZAS.cmd` → `meshy/piezas/<id>.glb` (gana a la lámina y a la sustituta) y hoja de contacto en `CatalogoAssets` (tecla H). No había piezas regeneradas todavía | `meshy/integrar_piezas.py`, `catalogo_assets.gd` |
| Rendimiento A | ya estaba: los `.import` de GLB y texturas extraídas están en VRAM (BPTC) con mipmaps; el 1.1 de la tabla no aplica en `paranda` | — |
| Rendimiento B | hecho: `suelo_meshy/*` y `vfx/*` a VRAM + mipmaps, sin detect_3d (Godot reimporta al abrir) | `.import` |
| Rendimiento C | hecho como `HIERBA_OPTIMIZACION.md` §2.1 + §2.2: bloques de 4×4 casillas con su caja, sembrados solo alrededor de la chibi y liberados al alejarse (el radio sigue al zoom) | `hierba_3d.gd`, `prueba_test2.gd` |
| Rendimiento D | hecho: la hierba ya no hacía sombra; sombra del sol 60 → 30 m | `prueba_test2.gd` |
| Rendimiento E | hecho: decorado en lotes (MultiMesh por pieza × malla × trozo de 7 casillas); el prerender 2D lo apaga (`decorado_por_lotes = false`) | `prueba_test2.gd` |
| F | `ORDENAR_POC.cmd` ahora pone `.gdignore` en `_descartado` (si no, Godot lo seguía importando) y aparta `arboles.glb` y `meshy/armas_goblin.glb` (repetidos) | `ORDENAR_POC.cmd` |
| Suelo | hecho: texturas ×0,78 en el shader (suelo, costados, agua, hierba) y luz a ambiente 0,6 / sol 1,0 | `prueba_test2.gd`, `hierba_3d.gd` |
| Equipo | hecho: `equipo/garrote.glb`, `escudo.glb`, `daga.glb` (agarre en el origen, +Y, textura 1024) | `equipo/` |
| Empujables | hecho (visual): cubo de tierra (`cuerpo.png`) y de hielo (agua desaturada) en sus cámaras | `prueba_test2.gd` |
| Pipeline 2D, 7 puntos | hecho, ver `DIARIO.md` 5/10 noche | `pipeline/` |
| Juego 2D | aplicados los tres diffs de `CAMBIOS_JUEGO_PENDIENTES.md` | `nivel_base.gd`, `goblin_guerrero.gd`, `goblin_arquero.gd` |

Para QA: la tabla de §1.2 se puede rellenar con el HUD nuevo de `PruebaTest2` (llamadas de dibujo, primitivas, MB de
vídeo). En la nube (renderizador de compatibilidad, sin sombras) la vista lejana pasó de 120 a 108 llamadas (544 k → 472 k primitivas);
lo que de verdad hay que medir es Forward+ con sombras en el PC de Pablo.
