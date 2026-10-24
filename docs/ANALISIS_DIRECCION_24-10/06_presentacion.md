# Revisión de la capa de presentación de Magic Symbols

24/10/2026 · revisión de dirección técnica de arte, **solo lectura** (no se ha tocado el repo). Repo: worktree `proyecto-analisis-profundo-bf47f8`, HEAD `7a91ea36`.

**Cómo se ha medido.** Los GLB se han leído con un script propio que abre el JSON de cada `.glb` y cuenta triángulos, huesos, clips y texturas incrustadas. Las 696 imágenes que Godot importa (las que no están bajo un `.gdignore`) se han medido con Pillow, junto con su `.import` (`compress/mode`, mipmaps, `size_limit`). Los 67 shaders escritos en cadenas dentro de `.gd` se han extraído y medido. El uso de cada pieza se ha cruzado con los 14 `.tscn` de `mundo/datos_nivel/`, con los mapas `.txt` y con el código. Se han mirado 19 capturas recientes. Los scripts y las tablas en bruto están en el scratchpad (`glb_modelos.tsv`, `glb_piezas.tsv`, `tscn_piezas.tsv`, `texturas.tsv`, `shaders.tsv`, `uso_piezas.txt`).

**Lo que NO se puede juzgar sin GPU ni ventana** (y está marcado como tal en cada punto):
- cómo se ven de verdad en Forward+ el bloom, el SSAO, el DOF y el tilt-shift;
- los FPS en la máquina objetivo;
- la VRAM real (aquí solo se estima con bytes por píxel);
- los tirones de compilación de shaders;
- el audio.

Las capturas del repo son de sesiones anteriores y algunas son de fondo liso de laboratorio.

---

## Resumen en cinco líneas

1. **El nivel de arranque (`PruebaBosque01_v01`) se ve como una build de desarrollo.** El HUD de depuración (3 líneas de teclas, FPS y triángulos) y la paleta F1 están siempre visibles, y las placas llevan rótulos de prueba como «PÍSAME». Es lo primero que hay que quitar.
2. **No hay una sola dirección de arte en pantalla.** En el mismo bosque conviven dos familias de árbol (hojas detalladas de 12 k y bolas lisas tipo arcilla de 3,7 k) y dos pinos (verde y turquesa). Las piezas de puzle del juego son primitivas (cajas y cilindros) aunque existen tres láminas de Meshy montadas en `PiezaPuzle3D` que nadie llama. Rayo y hielo tienen un color en el libro y otro en el VFX.
3. **El presupuesto está entre 3× y 15× por encima del de EoW**, y el nivel de arranque deshace la decisión V8: hay 262 árboles y pinos de 12 000 triángulos, ≈ 3,1 M solo de árboles. La maqueta carga al montar cualquier nivel los 144 GLB de `arte/meshy/piezas` (≈ 240 MB de VRAM estimada) y hay ~235 MB de texturas sin comprimir en personajes, piezas pequeñas y clips.
4. **La base técnica es buena y reaprovechable.** Material común real (`Ocluso3D`, con tramado, quemado, disolución y viento), `LuzZona3D` con ambiente de dos colores, posproceso EoW, tabla de reacciones y de logros, tema de interfaz con contraste medido. Lo que falta es **coherencia, poda y enganchar lo que ya existe**, no sistemas nuevos.
5. **Audio:** el foley está grabado y las pisadas van por material, pero **no hay música ni ambiente por bioma**, ni buses de audio.

---

## 1. Assets 3D

### 1.1 Inventario (disco)

| carpeta | archivos | MB | nota |
|---|---|---|---|
| `arte/meshy/` (sin `entrada/`, `aprobacion3d/` ni `referencias/`, que llevan `.gdignore`) | ~1 100 | ~517 | `piezas/` 851 archivos y 266 MB (144 GLB, 297 JPEG extraídos) |
| `arte/modelos/` | 235 | 303 | 38 GLB de personajes, clips y ropa |
| `arte/equipo/` | 71 | 23 | 10 GLB |
| `arte/piezas/` (`.tscn`) | 104 | 33 | **17 escenas de 1,0–1,6 MB con la malla incrustada** (ver 1.3) |
| `presentacion/grimorio/` | 29 | 22+ | prueba de concepto `GrimorioUI` **sin uso** (3 GLB de 6–7 MB y 9 JPEG de 2048²) |
| `presentacion/vfx/` | 55 imágenes y 7 GLB | ~12 | anillos y fuegos GLB; `anillo_piedra` con textura de **4096²** |
| `art/` (era 2D) | 290 | 7 | sí se usan `art/ui/` (glifos y láminas del libro) y `art/fx/` (en los `*_rune.tres`); **`art/forest` (73 PNG de Sketch Town), `art/bosque`, `art/particles` y `art/recogibles` no los referencia nada** |

### 1.2 Personajes y equipo: triángulos frente al presupuesto de EoW

Presupuesto de EoW: protagonista 9–11 k, enemigo ~1,8 k, objetos 0,7–1,5 k, sin LOD. **Todo lo de esta tabla está a más de 2× de ese presupuesto.**

| id (ruta `arte/…`) | triángulos | × EoW | huesos | texturas | uso |
|---|---|---|---|---|---|
| `modelos/jugadora_base.glb` + `ropa_capa` 12 376 + `ropa_tunica` 9 000 + `ropa_capucha` 7 624 | **31 127 + 29 000 = 60 127** | 5,5–6,7× | 66 | cuerpo 3×1024² **sin comprimir** (`compress/mode=0`); ropa 3×512² sin comprimir | protagonista desde el 24/10 |
| `modelos/woodland_wanderer(_suave).glb` | 102 635 | 9–11× | 32 | 3×2048² (límite 1024) | respaldo y fuente de clips (`_suave`); `PRESUPUESTO.md` aún la da como protagonista con 117 k (dato viejo) |
| `goblin_warrior_chibi` / `goblin_archer_chibi` | 31 391 / 31 373 | **17×** | 28 | 1024² / 2048²→1024 | enemigos comunes |
| `goblin_asesino` · `goblin_base` | 19 228 · 19 808 | 11× | 65 | 512² sin comprimir | asesino (Alt+F11) · todavía no lo usa ningún NPC |
| `emberheart` (loberno) · `elemental_bosque` · `lince` | 30 368 · 30 382 · 31 415 | 17× | 51 · 28 · 51 | 2048² (límite 1024) | enemigos y mascota |
| `marimanta` + `baston_marimanta` · `elfo_base` · `bookseller_chibi` · `ranger_human` | 20 885 + 7 150 · 19 678 · 31 424 · 31 434 | NPC | 66 · 65 · 28 · 66 | marimanta 1024² sin comprimir | NPC |
| `goblin_behit_flyup` · `goblin_stand_up` | 31 391 cada uno | — | 28 | **3×2048² sin comprimir cada uno** | **solo se cargan para sacar 2 clips** (`Pj3D.FUENTE_EMPUJADO/LEVANTARSE`): ≈ 128 MB de VRAM estimada que no hacen falta |
| `equipo/grimorio_1..3` | 14 287–15 470 | **10×** | — | 3×1024² | el libro colgado del cinto |
| `equipo/armas_goblin` · `arco` · `escudo` · `garrote` | 13 996 · 9 874 · 5 484 · 5 162 | 3–9× | — | 2048² / 1024² | equipo |
| `equipo/flecha` · `daga` · `daga_goblin` | 3 982 · 3 350 · 3 000 | 2–3× | — | 1024² | **la flecha se instancia en cada disparo** |
| `meshy/escritura/pluma` · `mano_agarre` | 15 963 · 16 021 | 10× | — | 3×2048² cada uno | mano 3D del libro (ARTE §19: unos 108 MB de textura medidos) |

**Texturas de personaje.** EoW usa 256². Aquí la jugadora va a 1024² sin comprimir: unos 4 MB por mapa más mipmaps, ~16 MB entre albedo, normal y ORM. El resto va a 2048² limitado a 1024 en 38 `.import` (lo aplicó V8). Lo que llegó después de V8 (jugadora, marimanta, ropa, elfo, goblin base y asesino) entró **sin comprimir y sin límite**. Es incoherente y es lo más fácil de arreglar.

### 1.3 Escenas de pieza (`arte/piezas/*.tscn`): los 1,6 MB

Hay dos clases de escena. Ninguna de las grandes se ha vuelto a hornear después de corregir el generador.

| clase | cuántas | qué contiene | ejemplos |
|---|---|---|---|
| **instancia del GLB + una COPIA horneada (`ArrayMesh`) del mismo subárbol, con los mismos nombres** | **17** | 1,0–1,6 MB de malla en texto. Es el fallo que arregló el commit `3a178de5` (23/10) en `GeneradorPiezas._dueno`; ese commit volvió a hornear solo 30 piezas. Quedan las de colisión por contorno | `arbol_redondo`, `pino`, `tronco`, `valla`, `brasero`, `totem_runico`, `puesto`, `arco_puerta`, `arco_ruina` (1,6 MB, 12 k triángulos); `caja`, `cartel`, `fogata`, `tocon`, `seto_seco`, `arbusto_otono` (1,0 MB, 8 k); `barril` (1,0 MB); `arbusto` (0,2 MB) |
| malla incrustada **legítima** (pieza sacada de una lámina, sin GLB propio) | ~40 | 15–580 KB | `arbol_redondo_2`, `pino_2` (de `arboles_2_*.jpg`), `tinaja_ruina`, `canal_*`, `campamento_*`, `tienda_goblin`, `seta_reactiva`… |
| solo referencia al GLB | ~45 | 0,5–4 KB | `roca_musgosa`, `troncos_apilados`, `cueva_*`, `helecho`… |
| colisión de malla | 1 | `pasadero.tscn`: `ConcavePolygonShape3D` de **862 KB** (8 000 triángulos) para una piedra pasadera | — |

**Efecto real de los duplicados.** En el juego **no** se dibujan dos veces. Con `decorado_por_lotes = true` (`prueba_test2.gd:711`), la maqueta dibuja el decorado en MultiMesh desde la biblioteca (`_plantilla(id)`), y del `.tscn` solo usa el `cuerpo` de colisión (`_instanciar_nivel`, líneas 4078–4131). El coste está en otro sitio: ~20 MB de texto que se analiza al cargar, el doble de malla en el editor y en cualquier ruta que instancie la escena, y `prueba_piezas_sin_duplicar` en rojo. **El arreglo es re-hornear con Godot abierto** (el generador ya está bien).

**Duplicados que pedía revisar el encargo:**
- `roca_musgosa.tscn` (4 KB, la buena) frente a `_anteriores_v8/roca_musgosa.tscn` (1,6 MB, la vieja de 12 k): la carpeta lleva `.gdignore`, así que no molesta.
- `arbol_redondo` frente a `arbol_redondo_2` y `pino` frente a `pino_2` **no son duplicados sino dos estilos distintos que conviven en el mismo nivel** (ver §5).

### 1.4 Piezas: uso, sobras y faltas

**Uso en el nivel de arranque** (`Nivel_Bosque_01_v01.tscn`): `arbol_redondo` **151**, `arbol_redondo_2` 135, `pino` **111**, `pino_2` 34, `arbusto` 82, `arbusto_otono` 26, `helecho` 24, `roca_musgosa` 24, `matas` 24, `troncos_apilados` 19, `tronco_musgoso` 17…

**Cómo se dibujan.** `_id_real` aplica primero la sustituta (`arbol_redondo` → `arbol_redondo_2`), **salvo que exista el GLB suelto** con el id viejo, y `arte/meshy/piezas/arbol_redondo.glb` existe. Por eso esas 151 copias se dibujan con el árbol de **12 000** triángulos, y lo mismo pasa con `pino`. **V8 se aplicó al `Nivel_Bosque_01` viejo, pero el v01 (el de arranque) lo deshace.**

**Triángulos de decorado colocados en el v01** (cálculo con los triángulos de cada GLB × copias; lo que se dibuja de verdad depende de la cámara y de la sombra reducida, y no está medido en ventana):

| pieza | copias × triángulos | total |
|---|---|---|
| árboles y pinos | 151×12 000 + 111×12 000 + 135×3 701 + 34×1 780 | **≈ 3,70 M** |
| arbustos, helechos, rocas y troncos | 82×2 858 + 26×8 000 + 24×8 000 + 24×6 000 + 36×6 000 + 10×8 000 | ≈ 1,07 M |
| **total del decorado** | | **≈ 4,8–5 M** |

**Piezas que no usa nada** (ni los niveles, ni los mapas, ni el código del juego): `llave_pequena`, `columna_agrietada`, `estatua_piedra`, `bloque_enlace`, `muro_ruina`, `cueva_pared_baja`, `raices_musgo`, `raices_secas`, `ramas_suelo`, `flores_amarillas`, `flores_colores`, `laja_piedra`, `setas_amarillas`, `planta_violeta`, `planta_hojas`, `hierba_espesa`, `helecho_ancho`, `nenufar_flor` y las tres `losa_runas_*` (solo existe su `.tscn`). Son unos 15 MB de GLB, **y aun así se cargan** (ver 7.2). Varias son justo las que necesitan los biomas futuros (§C).

**Piezas que pide un mapa y no existen:** ninguna. Las líneas `; pieza …` de los mapas son piezas lógicas de `Puzle3D` (pulsador, brasero, puerta, cuenca…), y las letras se resuelven con `Pieza3D.MEDIDA`. La única falta visible es la **boca de la Cueva**: en el v01 es una losa (PENDIENTES:152), y `boca_cueva.glb` (6 000 triángulos) existe, tiene su `.tscn` y no está colocada.

**Presupuesto de las piezas sueltas.** Hay 144 GLB que suman 831 k triángulos. **83 superan los 3 000** (2× el techo de EoW para objetos). **50 tienen exactamente 8 000 y 17 exactamente 12 000.** Son los objetivos por defecto de `recibir_assets.py`, no un presupuesto pensado para el tamaño en pantalla. Ejemplos que más chocan:

| pieza | triángulos | altura en el juego |
|---|---|---|
| `setas` | 8 000 | 0,35 u |
| `hojas_caidas` | 8 000 | 0,23 u |
| `helecho` | 8 000 | 0,5 u |
| `hierba_alta` | 8 000 | — |
| `barril` | 8 000 | 0,8 u |
| `caja` | 8 000 | — |
| `cartel` | 8 000 | — |
| `tocon` | 8 000 | 0,6 u |
| `totem_runico` | 12 000 | — |
| `brasero` | 12 000 | — |
| `valla` | 12 000 | 0,8 u |

---

## 2. Texturas

### 2.1 Resumen

| hallazgo | evidencia | efecto |
|---|---|---|
| **3 texturas de más de 2048** | `arte/modelos/chibi_elf_texture_0_metallic_roughness.png` 4096² (7,6 MB, suelta, de la elfa vieja) · `presentacion/vfx/anillo_piedra_…basecolor.jpg` 4096² (un anillo de VFX) · `arte/suelo_meshy/Screenshot_1.png` 5760×1080 importada sin comprimir (una captura dentro de la carpeta de texturas del suelo) | disco y tiempo de importación; el anillo, además, VRAM |
| **Sin comprimir en VRAM** (`compress/mode=0`) donde no toca | 88 en `arte/meshy/piezas` (terrones, cascotes, hielo, algas, rocas de río, cofres de la Cueva, prisma…), ≈ **107 MB de VRAM estimada** con RGBA8 y mipmaps; 33 en `arte/modelos` (jugadora, marimanta, ropa, elfo, goblins base y asesino, y **los dos GLB de clips a 2048²**) | `PRESUPUESTO.md` dice «pasarlas a VRAM comprimida ahorraría poco»; medido aquí **no es poco** (~235 MB estimados entre las dos carpetas). Pendiente de confirmar con el monitor de VRAM en ventana |
| Resolución en `arte/` | 512²: 181 · 1024²: 109 · **2048²: 126** (38 de ellas limitadas a 1024) | las láminas (puzle, fuego, bosque, escritura, telaraña, enredadera, árboles_2…) siguen a 2048² |
| Texturas que no son potencia de 2 | ~40 en `piezas/` (485×510, 180×335, 228×160…: recortes por pieza que hace `recibir_assets.py`) | funciona, pero la compresión por bloques las rellena hasta múltiplos de 4 y los mipmaps no salen limpios. Pulido |
| **VFX en 3D sin mipmaps y sin comprimir** | 19 en `presentacion/vfx` (p. ej. `grietas_impacto.png`, 1024², 1,4 MB, sin mipmaps; `viento_atlas.png`; `runas/runa_suelo_*.png`) | parpadeo y aliasing al alejar; peso |
| Interfaz | `presentacion/ui` y `art/ui` sin comprimir y sin mipmaps (correcto para 2D). `mochila_lamina_panel.png` (1015×533, 712 KB) es la más pesada; 9 PNG de `presentacion/ui` aún sin `.import` | bien |
| Importado y sin uso | `presentacion/grimorio/*` (~60 MB de VRAM si se cargara; nadie la carga) · `mundo/datos_nivel/Meshy_AI_Wolfwood_Ranger…_Image_*.jpg` (6×2048², **14 MB, su GLB ya no existe**: quedan los `.glb.import` huérfanos) · `docs/*.png` y `docs/qa/vfx/*` (12 PNG de ~1 MP): `docs/` no tiene `.gdignore` en la raíz, y `docs/capturas/escritura_glifo` y `docs/capturas/salida_mano` tampoco lo tienen | importación lenta, caché `.godot` más gorda, y riesgo de que entren en una exportación |
| Suelo (`arte/suelo_meshy`) | 1024² sobre una casilla de 2,3 u (445 px/u); `joints_atlas`, `lecho_rio` y `veta_mineral*` sin comprimir | bien; pasar esas tres a VRAM comprimida es un pulido |

### 2.2 ¿Sigue vigente `docs/auditoria_texturas.tsv` (6/10)?

**No.** De sus 257 ficheros únicos, **162 ya no existen** (sprites de `art/` de la era 2D, `Sprites/`, los GLB de grimorio que se movieron). Además juzga las piezas como trozos de lámina de ~1 000 triángulos, cuando hoy son GLB sueltos de 8–12 k con su propia textura de 512–1024². Hay que regenerarla o archivarla. Lo mismo pasa con **`QA_ARTE.md`, `PLAN_HOMOGENEIZAR_ARTE.md`, `EXPERIMENTOS_ESTILO.md` y `ASSETS_PENDIENTES.md` §0–§6**: son de la era 2D (losas de 128×64, `MsAtlas`, `art/`) y confunden a quien busque el estado del arte. Hay que moverlos a `docs/historia/`.

---

## 3. Shaders y materiales

### 3.1 Inventario

- **No hay ni un `.gdshader` en el repo.** Hay **67 shaders en cadenas dentro de 41 `.gd`, con 3 757 líneas en total.**
- Los más grandes:

| shader | líneas |
|---|---|
| `agua_render_3d.gd:207` | 809 |
| `prueba_test2.gd:157` (`CODIGO_SUELO`) | 406 |
| `ocluso_3d.gd:54` | 197 |
| `agua_capa_3d.gd:164` | 136 |
| `prueba_test2.gd:567` (`CODIGO_AGUA`) | 117 |
| `vfx_kit_3d.gd:34` | 102 |
| `lava_3d.gd` | 98 |

- **Variantes casi iguales:**
  - **3 aguas:** `AguaRender3D.CODIGO`, `PruebaTest2.CODIGO_AGUA` y `AguaCapa3D.CODIGO_SUPERFICIE`, más 2 «cortinas» (`agua_render`, `agua_capa`).
  - **3 llamas:** `Formas3D.CODIGO_FUEGO`, `Vfx3D.CODIGO_FUEGO_ETAPAS` y `VfxKit3D.CODIGO`.
  - **3 «aros y ondas» aditivos** (`conjuro_vfx_3d`, `pulso_3d`, `vfx_3d.CODIGO_ONDA_AGUA`).
  - **4 «billboards suaves»** (`vfx_estado.CODIGO_SUAVE`, `hilo_luz`, `rastrojo`, `sombra_contacto`).
- **`Shader.new()` por material, sin caché:**
  - `Vfx3D._material_etapas()` crea un Shader en cada pulso del aro de fuego;
  - `VfxEstado3D.material_cascara()` y `material_burbuja()` crean uno por llamada;
  - `Vfx3D.CODIGO_ENERGIA` crea uno al cargar.
  - Lo hacen bien con caché estática: `VfxKit3D` (`_sh`, `_sh_plano`), `ConjuroVfx3D`, `Ocluso3D` (`_shaders` por variante de culling) y `material_suave`.
  - Cada `Shader.new()` con el mismo código es un recurso nuevo: es un riesgo de tirón de compilación, que solo tapa el precalentado. **No se puede medir sin ventana.**
- **`smoothstep` con los bordes invertidos** (la regla de ARQUITECTURA dice que en Vulkan rompía). Siguen **5**:

| archivo:línea | código |
|---|---|
| `objetos/secuencia_cofre_legendario_3d.gd:79` | `smoothstep(0.07, 0.0, …)` |
| `presentacion/conjuro_vfx_3d.gd:77` | `smoothstep(0.55, 0.0, r)` |
| `presentacion/hilo_luz_3d.gd:28` | `smoothstep(0.40, 0.0, a)` |
| `presentacion/hilo_luz_3d.gd:29` | `smoothstep(1.0, 0.0, a)` |
| `presentacion/vfx_3d.gd:1799` | `smoothstep(1.0, 0.8, d)` |

  Se arreglan con `1.0 - smoothstep(b, a, x)`.
- **Uniforms globales:** solo uno, `oc_jugador` (`Ocluso3D`). El viento del decorado, la hora o la zona podrían ser globales (`viento` hoy es un uniform por material).
- **Transparencia:**
  - **Bien resuelta** en lo que tapa: `Ocluso3D` descarta con ruido de gradiente entrelazado por píxel (no es Bayer, pero sirve igual), sin ordenar transparencias y sin romper la sombra.
  - La disolución de V6 también descarta.
  - Los VFX usan mezcla alfa o aditiva con `depth_draw_never`, que es lo correcto.
  - La silueta de la jugadora usa `depth_test_disabled`.

### 3.2 ¿Hay un material común de verdad?

**Sí, para el decorado.** `Ocluso3D.convertir()` cambia el `StandardMaterial3D` de Meshy por un `ShaderMaterial` con un solo shader (por variante de culling). Ese shader trae el tramado de oclusión, `quemado`, `disolver` (Voronoi), `viento` y `corte_y`, y `Albedos3D` corrige el albedo por encima (PENDIENTES:142 pide meterlo dentro del shader).

**Quedan fuera:**
- personajes: `MaterialPersonaje3D`, con `next_pass` de rim y silueta, y `CODIGO_JUGUETE`;
- suelo, agua y hierba: shaders propios;
- piezas de puzle con primitivas: `StandardMaterial3D.new()` por instancia en `pulsador_3d`, `barril_3d`, `compuerta_3d`…;
- `PiezaPuzle3D`, `PiezaFuego3D` y `PiezaBosque3D`: material de Meshy más ajustes.

Los objetos reactivos copian sus materiales (`Reactivo3D._recoger_materiales`), y eso es correcto porque cada uno se quema por su cuenta.

---

## 4. VFX

### 4.1 Arquitectura y presupuestos

- **Separación lógica → tabla → efecto bien hecha:** `ReaccionesVfx3D` y `Logros3D` son tablas. **Todo el VFX es código:** 20 scripts y unas 11 000 líneas (`vfx_3d.gd` 2 405, `vfx_estado_3d.gd` 1 614, `vfx_kit_3d.gd` 1 136, `hielo.gd` 740, `tierra.gd` 645, `viento.gd` 503…).
- Solo **GPUParticles3D** (≈ 15 fábricas), **ningún CPUParticles**. La mayor parte de las «partículas» son instancias de MultiMesh animadas, que es eficiente.
- Luces: **ninguna OmniLight con sombra** (bien).
- Topes:

| dónde | tope |
|---|---|
| general | 10 llamas, 3 luces de llama, 40 restos |
| por volumen de `VfxEstado3D` | 2 luces y 400 partículas |
| `VfxElemento3D` | 12 efectos a la vez |
| `VfxEstado3D` | 8 proyectiles dibujados y 24 ráfagas |

- **Sin pool:** los emisores se crean en cada encendido y se liberan al apagarse (`queue_free` en ~70 sitios). El tirón de la primera vez lo tapa el velo de «Preparando efectos…». Con los topes de arriba es aceptable; si sale hitch en la UHD 620, empezar el pool por las ráfagas y las llamas.
- **Respaldo de «punto suave»:** `fases_fuego_3d`, `consumo_fuego_3d`, `vfx_reaccion_3d` y `vfx_puzle_3d` generan su textura blanda si falta un PNG. Ningún efecto queda en blanco.

### 4.2 Elemento × figura (código y capturas)

| elemento | proyectil (bola) | haz (ᛁ + elemento) | barrera / cúpula | muro / columna | pulso / impacto | arte propio | acabado |
|---|---|---|---|---|---|---|---|
| **Fuego** | `FasesFuego3D`: nace de un punto y crece (diario 222–226). En el juego se lee bien (`lanzar_x_mano_instante.png`) | tira del kit: en `haz/fuego_juego_1.png` sale **crema pálido casi sin naranja** y con el final cortado a pico | cúpula del kit | tira del kit | aro por etapas con GLB (`fuego_1..4`, `anillo_fuego`), brasas y luz | sí (validado) | **alto** en la bola, **flojo** en el haz |
| **Agua** | `agua.gd` (burbuja) | chorro | kit | ola (`ajustar_tira`) | salpicadura | sí (validado) | medio-alto |
| **Tierra** | terrón GLB que gira | fila de pinchos GLB (`haz/tierra_juego_1.png`: se lee, aunque los pinchos quedan sueltos y con hueco) | bloques que emergen | bloques GLB con polvo | cascotes que caen y se quedan | sí: 26 piezas Meshy | medio-alto |
| **Viento** | cintas en espiral, hojas del atlas | cintas y hojas (`haz/viento_juego_1.png`: **el más acabado**) | remolino | tornado | ráfaga | atlas de 4×4 | **alto** |
| **Hielo** | esquirla GLB (en el diario, «la pieza más floja: dos puntas iguales») | **un prisma liso** con 4 esquirlas (`haz/hielo_juego_1.png`): parece una varilla de cristal | racimos GLB | racimos y escarcha | onda y placa rota | sí: 10 piezas | **flojo** en el haz |
| **Rayo** | kit genérico (rampa azul) | polilínea de grosor fijo, cian y blanca, con ramas rectas (`haz/rayo_juego_1.png`) | kit | kit | chispas y destello | no (solo `rayo.gd`, 177 líneas) | medio-bajo |
| **Tiempo** | kit genérico | kit genérico | kit | kit | anillos del kit | **no: `tiempo.gd` son 15 líneas con solo color** | **sin arte** y sin capturas |

**Coherencia de paleta con ARTE.md §1:**
- **Rayo.** `RuneData` y ARTE dicen amarillo `#F2C63C` (`lightning_rune.tres`). Pero `vfx_elementos/rayo.gd` define una **rampa azul** (0,12; 0,28; 0,9 → blanco) y `VfxEstado3D.COLORES["rayo"].c = (0,35; 0,62; 1,0)`, también azul. El glifo del libro es amarillo y el hechizo sale azul.
- **Hielo.** `VfxEstado3D` usa (0,62; 0,82; 0,96), y `RuneData` (0,37; 0,81; 0,96).
- **Fuego.** El haz se va a blanco antes de tiempo: la rampa termina en (1,0; 0,96; 0,78) y el shader suma.
- **Validación.** `VfxKit3D.VALIDADOS = ["fuego", "agua"]`: Pablo solo ha validado dos de siete.

**Escala y legibilidad:** se lee bien en el juego (bola de fuego), y los haces del laboratorio sobre fondo liso tienen buen tamaño respecto a la cápsula. **Sin juzgar:** el bloom y el aspecto en Forward+ de un elemento sobre la hierba neón del nivel; hay que verlo jugando.

---

## 5. El nivel real (capturas del 24/10)

Capturas miradas:
- `bosque_01_v01/region_tala.png`, `region_prado.png`, `vuelta_de_la_cueva_en_la_boca.png`;
- `cueva/C2_muro_agrietado.png`, `C6_tesoro.png`;
- `hud_eow/hud_lleno.png`, `menu_inventario.png`;
- `interfaz_eow/hierba_legendario_despues.png`;
- `jugadora_integrada/lanzar_x_mano_instante.png`.

| aspecto | veredicto | evidencia |
|---|---|---|
| **Paleta** | **demasiado saturada y clara** frente a la paleta cerrada y a la del bioma | hierba medida en pantalla: RGB (147, 213, 104), saturación 0,51 y valor 0,84; `Paleta3D.HIERBA` es `9FD180` (saturación 0,39) y la paleta del Bosque de ARTE §2 tiene el valor en ~0,47. Lee como «verde neón», no como pastel |
| **Familias de arte** | **chocan** | en `region_tala` se ven a la vez árboles de hojas detalladas (`arbol_redondo` de 12 k), árboles de bolas lisas tipo plastilina (`arbol_redondo_2`), pinos verdes (`pino`) y pinos turquesa (`pino_2`, PENDIENTES:137). Al lado, la tienda goblin roja y saturada |
| **Escala** | árboles enormes frente a la chibi | copas de ~4,2 u frente a una jugadora de 1,0 u; en `region_tala` y `region_prado` **la jugadora apenas se ve**: el círculo de tramado se intuye, pero la copa la tapa casi entera. La silueta V5 no destaca en estas tomas |
| **Contraste suelo / piezas / personaje** | hierba y copas en el mismo verde amarillo, así que **todo se funde**; la jugadora (capucha verde oscuro) se lee sobre la piedra, pero no sobre la hierba | las tres capturas del bosque |
| **Sombras y posproceso** | sombras suaves y correctas; el tilt-shift desenfoca mucho arriba y abajo (`hierba_legendario_despues`), y está pendiente de que Pablo decida (PENDIENTES:121) | — |
| **Lo que rompe la ilusión** | (1) el **HUD de depuración** de 3 líneas y la **paleta F1** siempre en pantalla, con textos que se pisan («Las cuatro tareas» sobre la lista de runas, «Pág. 1» sobre «Lanza con…»); (2) **la boca de la Cueva es una losa de piedra plana** con una columna; (3) en la Cueva, el **muro agrietado es un bloque de arenisca amarilla** que no casa con la pared verde grisácea, y la **placa «PÍSAME» es un rectángulo amarillo de primitiva con su rótulo de prueba** (`C6_tesoro.png`); (4) las **paredes de la Cueva** son un módulo verde lima que se repite a la vista, fuera de la paleta Cueva (`#465E86`…), y el suelo es azul y de alto contraste (mucho detalle, al revés que los albedos de bajo contraste de EoW); (5) el **cauce oscuro** de `region_prado` tiene losas emborronadas con manchas pálidas rectangulares (PENDIENTES:74); (6) la **tapa del cofre legendario** flota (PENDIENTES:54); (7) una **esfera rosa translúcida** rodea a la jugadora al lanzar (`lanzar_x_mano_instante`): no he podido saber qué efecto es, pero tapa a la jugadora | — |
| **HUD nuevo (EoW)** | **bien**: menú de pestañas crema con borde marrón, rejilla, marco legendario morado, botones Q/E, contador de oro, consumible Q/R con frascos | `menu_inventario.png` |

---

## 6. Interfaz 2D

- **Fuente:**
  - **no hay ningún `.ttf` ni `.otf` en el repo**;
  - `TemaInterfaz` usa `SystemFont` (Trebuchet MS → Segoe UI → Noto Sans → Verdana): **depende del sistema** y en otro equipo u otra plataforma la tipografía cambia;
  - **`spellbook.gd` (1 825 líneas), `diario_misiones.gd`, `ejes_receta_ui.gd` y `page_hud.gd` usan `ThemeDB.fallback_font`**, es decir, una segunda fuente distinta;
  - ARTE §11 ya pedía un `.ttf` OFL.
- **Tema:**
  - `TemaInterfaz` (panel oscuro translúcido con borde dorado y contraste WCAG ≥ 7 medido) lo usan `hud_eow`, `barra_hud`, `pista_interaccion`, `menu_pestanas` y `bolsa_ui`.
  - `spellbook`, `diario_misiones`, `page_hud`, `rune_palette`, `mision_hud` y `pantalla_muerte` **no lo usan** (colores y tamaños sueltos).
  - Conviven **dos lenguajes**: panel oscuro (HUD y rótulos) y pergamino crema (menú y mochila). Es defendible (EoW hace algo parecido), pero hay que escribirlo como regla.
- **Escalado:** `window/stretch/mode="canvas_items"` y `aspect="expand"` son correctos. Pero **no hay resolución base** en `project.godot` (queda la de serie, 1152×648) y el libro escala la mano a mano (`escala = book.size.x / BOOK_SIZE.x`).
- **Láminas de Pillow:** las 53 de `presentacion/ui/laminas/` están bien organizadas, con sus scripts al lado; las de pergamino y mochila pesan 0,1–0,7 MB.
- **Español y tildes:** correctos en lo revisado (`Pociones`, `Síntesis`, «El prado del estanque»). El laboratorio de recetas enseña ids crudos (`raido`), según PENDIENTES:59.
- **Lo viejo frente a lo nuevo:**
  - `page_hud` (94 líneas) y los círculos 1/2/3 conviven con el HUD EoW;
  - `rune_palette` es de pruebas y está visible.
  - Hay que decidir qué queda en la build de jugador.

---

## 7. Rendimiento

### 7.1 Lo que se sabe (de `PRESUPUESTO.md`, el diario 247 y el HUD de las capturas)

- En la UHD 620, el cuello era **la sombra del sol** (4,35 M triángulos dibujados por fotograma). Con `MallaReducida3D` bajó a 1,6–1,7 M.
- V8 bajó el Bosque 01 viejo de 4,66 M a 3,15 M de triángulos en lotes, y la GPU de 2,4–5,4 ms a 1,7–2,7 ms.
- **El nivel de arranque v01 no está medido** y vuelve a usar los árboles de 12 k (ver 1.4).
- El HUD de `hud_eow` marca 330 llamadas y 1 633 k primitivas (60 FPS en la máquina de Pablo, que no es la UHD 620).
- `escala_render` sigue en 1,0 (con 0,75 se medía ≈ +20 %).

### 7.2 Cuellos nuevos que he encontrado

1. **`PruebaTest2._cargar_bibliotecas()` (línea 2531) carga e instancia TODOS los GLB de `arte/meshy/piezas` (144) más 5 láminas al montar cualquier nivel**, incluidas unas 20 piezas sin uso. Con sus texturas son ≈ 240 MB de VRAM estimada solo de piezas, lo que encaja con los ≈ 333 MB medidos en el Bosque. **Arreglo:** cargar solo los ids que pide el nivel (los `Pieza3D` del `.tscn` más lo que pida el código) o hacerlo en diferido.
2. **Texturas sin comprimir** (2.1): ~235 MB estimados.
3. **Antialiasing doble:** MSAA 4× (`prueba_test2.gd:1101`) **y además** FXAA (`posproceso_3d.gd:56`), más SSAO, glow, DOF y tilt-shift. Con hierba de recorte alfa y cientos de miles de briznas, el MSAA 4× en una GPU integrada es caro y no suaviza el recorte alfa. **No medido:** probar «MSAA desactivado y FXAA» frente a «MSAA 2×» con `medir_rendimiento.gd`.
4. **Equipo pesado repetido:** la flecha tiene 3 982 triángulos por disparo y el grimorio 15 k en cada personaje que lo lleva.

### 7.3 Objetivo propuesto por categoría (UHD 620, 1152×648, 60 FPS)

| categoría | triángulos | textura | nota |
|---|---|---|---|
| protagonista (cuerpo + ropa) | **≤ 15 k** (EoW 9–11 k) | 1024² albedo comprimido; normal opcional a 512² | hoy 60 k |
| enemigo común | **3–5 k** | 512² | hoy 31 k |
| jefe o bestia | 8–12 k | 1024² | — |
| NPC | 5–8 k | 512² | — |
| árbol que se ve | **1,5–3 k** | atlas de 512–1024² compartido | la sombra con 1/8 (ya está) |
| arbusto, helecho, flores, setas, hojas | **300–800** | 256–512² | hoy 8 k |
| rocas, troncos, tocones | 500–1 500 | 512² | — |
| objetos de puzle e interactivos | 700–1 500 (EoW) | 512² | — |
| arma | 500–1 500 | 512² | — |
| flecha | ≤ 300 | 256² | — |
| grimorio | ≤ 3 k | 512² | — |
| malla de VFX | ≤ 500 | ≤ 512², comprimida y con mipmaps | — |
| **escena** | **≤ 1 M dibujados por fotograma (con sombra)** | **VRAM ≤ 300 MB** | **≤ 400 llamadas** |

---

## 8. Audio (breve)

- **Grabado:** el foley CC0 de Kenney (37 `.ogg`: pisadas ×3 materiales con 4–6 variantes, puertas, libro, páginas, voces de murmullo, goblin y gato) y 2 bucles (`agua_loop`, `fuego_loop`). **Las pisadas ya van por material** (hierba, tierra, roca: `jugador_3d.gd:488`). **Sintetizado:** los 46 `.wav` de elementos, cargas, impactos, puzles y logros (`gen_sfx_*.py`), más lo que genera en caliente `nucleo/sonidos.gd`.
- **Para que suene acabado falta:**
  - **música**: no hay ni una pista ni un reproductor;
  - **ambiente por bioma o zona**: viento y pájaros en el bosque, goteo y eco en la cueva;
  - **buses**: no hay `default_bus_layout.tres`, así que no se pueden poner sliders de Música, Efectos y Ambiente ni reverberación en la cueva;
  - pisadas en **agua y piedra mojada**;
  - un sonido propio del pulso (hoy es `sello_ok`);
  - afinar de oído los 4 jingles de logros (PENDIENTES:123).
- **No he escuchado nada.**

---

## (A) Problemas, de más a menos grave

Dueños: **Pipeline** (presentación, maqueta y assets), **Pablo** (Meshy, Blender y decisiones), **Juego** (objetos y lógica).

### Rompe calidad

| # | problema | ruta | evidencia | arreglo | coste | dueño |
|---|---|---|---|---|---|---|
| A1 | HUD de depuración y paleta F1 siempre visibles en el nivel de arranque, con textos que se pisan | `presentacion/prueba_test2.gd:1195`, `:5191`; `presentacion/ui/rune_palette.gd` | capturas `hud_eow/*`, `interfaz_eow/*` | export `modo_desarrollo` (apagado en `main_scene`, F3 lo enciende); la paleta oculta de serie | **S** | Pipeline |
| A2 | Rótulos de prueba en piezas del juego («PÍSAME», «CUALQUIER MAGIA», «SOLO AGUA») | `objetos/pulsador_3d.gd:68` | `cueva/C6_tesoro.png` | rótulo solo en modo desarrollo; en el juego, runa o icono pintado | **S** | Juego |
| A3 | Piezas de puzle del juego hechas con primitivas (caja amarilla, cilindros, esferas) **aunque existen las láminas de Meshy montadas** | `objetos/pulsador_3d.gd`, `barril_3d.gd`, `compuerta_3d.gd`, `molino_3d.gd`, `nivel_agua_3d.gd`…; `presentacion/pieza_puzle_3d.gd` (0 usos fuera de `presentacion/` y `herramientas/`) | grep; los mapas piden 40 pulsadores, 10 compuertas y 9 barriles; el propio `barril_3d.gd` dice «dibujo bueno: el Pipeline tiene barril» | que cada objeto pida su visual con `PiezaPuzle3D.crear(familia)` (mismos ids de estado, ARTE §9) | **M** | Juego + Pipeline |
| A4 | Dos familias de árbol y dos pinos en el mismo nivel | `mundo/datos_nivel/Nivel_Bosque_01_v01.tscn` (151 `arbol_redondo`, 135 `_2`, 111 `pino`, 34 `pino_2`) | `region_tala.png` | elegir **una** familia por especie (recomiendo las hojas de `arbol_redondo` pero decimadas a ~3 k, y un pino de un solo color) y re-hornear | **M** | Pablo decide · Pipeline |
| A5 | La jugadora desaparece bajo las copas | `presentacion/ocluso_3d.gd` (`ALFA_MIN` 0,12, el radio), `material_personaje_3d.gd`; escala de los árboles | `region_tala.png`, `region_prado.png` | radio del círculo mayor y `alfa_min` 0; silueta (V5) más marcada sobre el follaje; árboles a ×0,8 junto a las sendas | **S** | Pipeline |
| A6 | La boca de la Cueva es una losa | v01; `arte/meshy/piezas/boca_cueva.glb` sin usar | PENDIENTES:152; `vuelta_de_la_cueva_en_la_boca.png` | colocar `boca_cueva` (S×2 de ancho, ya en `MEDIDA_ANCHO`) | **S** | Pipeline |

### Se nota

| # | problema | ruta | evidencia | arreglo | coste | dueño |
|---|---|---|---|---|---|---|
| A7 | El nivel de arranque deshace V8: ~3,7 M triángulos de árboles colocados | `Nivel_Bosque_01_v01.tscn`; `_id_real` prefiere el GLB suelto de 12 k | cálculo en 1.4 | lo mismo que A4, más la decimación de `arbol_redondo` y `pino` (`MallaReducida3D` conservando UV, o Blender) | **M** | Pablo · Pipeline |
| A8 | La maqueta carga los 144 GLB de piezas y 5 láminas en todos los niveles | `prueba_test2.gd:2531` | ≈ 240 MB de VRAM estimada; ~20 piezas sin uso entre ellas | cargar por ids del nivel, de forma diferida | **M** | Pipeline |
| A9 | Texturas sin comprimir en personajes, piezas pequeñas y clips (~235 MB estimados) | 88 `.import` en `arte/meshy/piezas`, 33 en `arte/modelos`; `goblin_behit_flyup` y `goblin_stand_up` (6×2048²) | `texturas.tsv` | `compress/mode=2` y `size_limit` 1024 (512 en lo pequeño); sacar los 2 clips a una librería de animación sin malla (como `jugadora_clips.glb`) | **S** | Pipeline (Pablo reimporta) |
| A10 | Paleta del nivel saturada y clara frente a `Paleta3D` y ARTE §2 | `presentacion/paleta_3d.gd` (`aplicar_ajuste` con saturación 1,1); albedo de la hierba y briznas | hierba medida: saturación 0,51 frente a 0,39 de la paleta | saturación 1,0, bajar la hierba un 10–15 % de valor, briznas al mismo tono; **comprobar en Forward+** | **S** | Pipeline (decide Pablo con antes/después) |
| A11 | Colores de rayo y hielo distintos en el libro y en el VFX | `vfx_elementos/rayo.gd` (rampa azul), `vfx_estado_3d.gd:116–117` | `lightning_rune.tres` dice amarillo | decidir: rayo amarillo (ARTE) con núcleo blanco; unificar las tablas en una sola (`Paleta3D` o `RuneData`) | **S** | Pablo decide · Pipeline |
| A12 | Acabado desigual entre elementos: haz de hielo (prisma liso), haz de fuego pálido, rayo de grosor fijo y ramas rectas, tiempo sin arte | `vfx_elementos/hielo.gd` (`material_haz`), `rayo.gd`, `tiempo.gd` | `haz/*.png`; `VALIDADOS = ["fuego", "agua"]` | haz de hielo con racimos o esquirlas a lo largo y fresnel; rampa del haz de fuego con más naranja y menos suma; rayo con ancho que varía y ramas que se ramifican; tiempo: anillos de arena y relojes (lámina pequeña) | **M** | Pipeline (Pablo valida) |
| A13 | La Cueva fuera de paleta y con muro de «caja amarilla» | `muro_agrietado.glb`, `cueva_pared*.glb`, `roca_cueva_arriba.png` | `C2_muro_agrietado.png`, `C6_tesoro.png` | tinte de `Paleta3D.PIEZAS` hacia los azules y grises de §2; muro agrietado con el mismo material que la pared y grietas con emisión; suelo con menos contraste; variar el módulo de pared (girar o espejar) | **M** | Pipeline |
| A14 | Dos fuentes, y ninguna dentro del proyecto | `tema_interfaz.gd:35`; `spellbook.gd`, `diario_misiones.gd`, `ejes_receta_ui.gd`, `page_hud.gd` (`fallback_font`) | grep | añadir un `.ttf` OFL (p. ej. Nunito o Fredoka para el HUD y una serif para el libro) en `presentacion/ui/fuentes/`; `TemaInterfaz.fuente()` lo devuelve y todo pasa por `tema()` | **S** | Pipeline (Pablo elige la fuente) |
| A15 | 17 escenas de pieza con la malla duplicada (1,0–1,6 MB) | `arte/piezas/{arbol_redondo,pino,tronco,valla,brasero,totem_runico,puesto,arco_*,caja,cartel,fogata,tocon,seto_seco,arbusto_otono,arbusto,barril}.tscn` | `tscn_piezas.tsv`; commit `3a178de5`; `prueba_piezas_sin_duplicar` | re-hornear con Godot abierto (el generador ya está arreglado) | **S** | Pablo (Godot) / Pipeline |
| A16 | Presupuesto de triángulos (ver 1.2 y 1.4) | personajes, equipo y 83 piezas de más de 3 k | `glb_*.tsv` | decimar con los objetivos de 7.3: primero la jugadora y la ropa, los goblins, la flecha, el grimorio y las plantas de 8 k | **L** | Pablo (Blender o Meshy) |
| A17 | Agua del cauce hondo lleno: color menta opaco y manchas rectangulares | `agua_render_3d.gd` / `lecho_rio_3d.gd` | PENDIENTES:74; `region_prado.png` | revisar la profundidad y el color del cauce lleno | **M** | Pipeline |
| A18 | Tapa del cofre legendario flotando | `cofre_legendario(_tapa).glb`, `Cofre3D` | PENDIENTES:54 | bisagra o pivote de la tapa | **S** | Pablo / Pipeline |

### Pulido

| # | problema | ruta | arreglo | coste | dueño |
|---|---|---|---|---|---|
| A19 | 5 `smoothstep` con los bordes invertidos | ver 3.1 | `1.0 - smoothstep(b, a, x)` | **S** | Pipeline |
| A20 | 67 shaders en cadenas (3 757 líneas), 3 aguas y 3 llamas casi iguales, `Shader.new()` por material | ver 3.1 | pasar los grandes a `.gdshader` (suelo, agua, ocluso, kit) con `#include` común (ruido, Voronoi, rampa); caché estática en `vfx_3d` y `vfx_estado`; elegir una sola agua | **M** | Pipeline (el suelo es del Juego) |
| A21 | Peso muerto importado | `art/forest`, `art/bosque`, `art/particles`, `art/recogibles` (sin referencias); `presentacion/grimorio/` (`GrimorioUI` sin uso); `mundo/datos_nivel/Meshy_AI_Wolfwood_*` (14 MB, sin su GLB); `arte/suelo_meshy/Screenshot_1.png`; `arte/modelos/chibi_elf_texture_0_metallic_roughness.png` (4096²); modelos sin uso (`loberno`, `emberstride`, `woodland_wanderer_v1`…) | borrar o mover bajo `.gdignore`; `.gdignore` en `docs/` | **S** | Pablo (borrar con Godot cerrado) |
| A22 | Texturas de VFX sin mipmaps (`grietas_impacto` a 1024² sin comprimir) y el anillo de piedra a 4096² | `presentacion/vfx/*.import` | mipmaps encendidos y VRAM comprimida; anillo a 1024² | **S** | Pipeline |
| A23 | Colisión de malla de 862 KB en la piedra pasadera | `arte/piezas/pasadero.tscn` | caja o cilindro | **S** | Pipeline |
| A24 | Documentos de arte obsoletos | `docs/auditoria_texturas.tsv` (162 de 257 ficheros ya no existen), `QA_ARTE.md`, `PLAN_HOMOGENEIZAR_ARTE.md`, `EXPERIMENTOS_ESTILO.md`, `ASSETS_PENDIENTES.md` §0–§6; `PRESUPUESTO.md` con la jugadora de 117 k | archivar en `docs/historia/`; regenerar la auditoría con el script de este informe | **S** | Pipeline |
| A25 | MSAA 4× y FXAA a la vez (sin medir) | `prueba_test2.gd:1101`, `posproceso_3d.gd:56` | medir: MSAA desactivado + FXAA, o MSAA 2× | **S** | Pipeline |
| A26 | Audio: sin música, sin ambiente y sin buses | `audio/`, `nucleo/sfx.gd` | ver (B) 9 | **M** | Pablo (fuentes CC0) · Pipeline |

---

## (B) Las 10 mejoras que más calidad percibida dan por su coste

1. **Quitar lo de desarrollo de la build** (A1, A2): HUD de teclas, paleta F1 y rótulos de prueba. **S.** Es lo que más grita «prototipo».
2. **Una sola familia de árbol y de pino en el Bosque 01 v01, decimada** (A4 y A7). **M.** Arregla de golpe la coherencia visual y la mitad del presupuesto de triángulos.
3. **Enganchar `PiezaPuzle3D` a los objetos del juego** (A3). **M.** Los puzles dejan de ser cajas y cilindros; el arte ya está pagado.
4. **Paleta: saturación 1,0 y hierba un poco más oscura** (A10), con capturas antes y después en Forward+. **S.** El «neón» es lo que más aleja del pastel de la referencia.
5. **Que la jugadora se vea siempre** (A5): oclusión más generosa y silueta más fuerte. **S.**
6. **Fuente propia y tema único** (A14). **S.** El libro, el diario y el HUD pasan a ser del mismo juego.
7. **Colores de elemento unificados y los tres haces flojos retocados** (A11, A12). **S–M.**
8. **Cueva: boca con modelo, paredes y muro agrietado en paleta, sin placa amarilla** (A6, A13, A2). **M.**
9. **Música y ambiente por bioma, con buses** (A26). **M.** Con 2 pistas CC0 (exterior y cueva) y 2 bucles de ambiente el juego «suena terminado».
10. **Comprimir texturas y cargar las piezas en diferido** (A8, A9). **S–M.** Menos tirones al entrar en un nivel y margen de VRAM para los biomas nuevos.

---

## (C) Lo que necesitarían los biomas pantano, montaña y desierto

**Base común que ya existe:**
- `LuzZona3D` (sol, ambiente de dos colores, mezcla al entrar en zona);
- `Paleta3D.PIEZAS` (tinte por pieza que multiplica el albedo);
- el shader del suelo (4 capas por máscara, joints, estados mojado, helado y quemado);
- `NieblaFoso3D` (bruma en manchas), `AguaRender3D` (profundidad, espuma, flujo), `Hierba3D`, `costra_hielo_3d`, `lava_3d`;
- las texturas de partícula en tira de 8 (`copo`, `polvo`, `humo`, `brasa`…);
- `VfxViento` (cintas y atlas).

**Lo que no existe en ningún bioma:**
- **niebla de profundidad o de altura en el `Environment`**: ningún script pone `fog_enabled`;
- **una lista de piezas y una textura de suelo por bioma**.

Convendría que `LuzZona3D.ZONAS` tuviera también `niebla` y `particulas_ambiente` por zona.

| | **Pantano** | **Montaña** | **Desierto** |
|---|---|---|---|
| Paleta (ARTE §2) | `#346A60` `#8CAF80` `#887F69` `#55434F` `#2B253C` | **no hay en ARTE §2**. Propuesta para decidir: `#6F8FA6` `#B9C6CF` `#EEF2F4` `#7C6E62` `#3B3F4A` (roca fría, nieve, liquen marrón) | `#D29850` `#DBA256` `#D59958` `#AC7748` `#7A5537` |
| Preset de `LuzZona3D` (propuesta) | sol (0,80; 0,90; 0,75) a 0,75, inclinación −62°; ambiente arriba (0,55; 0,68; 0,60), abajo (0,30; 0,34; 0,28), a 0,55; **niebla baja verdosa** | sol (1,0; 0,98; 0,95) a 1,1, −55°; ambiente arriba (0,78; 0,86; 1,0), abajo (0,86; 0,89; 0,94) a 0,7 (rebote de la nieve); niebla de altura muy suave y azul | sol (1,0; 0,90; 0,72) a 1,25, −75°; ambiente arriba (0,95; 0,88; 0,75), abajo (0,92; 0,72; 0,50) a 0,7; sin niebla, y bruma de calor en el horizonte (tilt) |
| Texturas de suelo | **nuevas:** `barro_arriba` y `musgo_arriba` (1024², sin costuras, contraste bajo); reutilizar `hierba_arriba` teñida, `lecho_rio` y `tierra_arriba` | **nuevas:** `nieve_arriba` y `roca_fria_arriba`; reutilizar `stone_arriba`, `losas_piedra` y el estado «helado» del shader (escarcha con fresnel) | **nuevas:** `arena_arriba` y `arena_dura_arriba` (con ondas); reutilizar `path_arriba` (ya es arena, `CAMINO_ARENA` `FDD495`), `losas_piedra` y `basalto_arriba` |
| Joints (tiras de transición) | barro ↔ hierba, agua ↔ barro | nieve ↔ roca | arena ↔ losa, arena ↔ roca |
| Piezas que ya hay (varias hoy **sin uso**) | `juncos`, `nenufar`, `nenufar_flor`, `planta_agua`, `alga_0..3`, `sauce`, `tronco_seco`, `raices_musgo`, `raices_secas`, `tocon_hueco`, `tronco_musgoso`, `setas_*`, `cuenco_piedra`, `tinaja_ruina`, `canal_*` | `pino` (verde), `roca_hueca`, `roca_rio_*`, `laja_piedra`, `estalagmitas_a/b` (como agujas de roca), `cueva_pared*` teñidas, `racimo_hielo_*`, `placa_hielo_rota*`, `columna_agrietada` | `tocon_seco`, `ramas_suelo`, `roca_hueca`, `laja_piedra`, `muro_ruina`, `columna_agrietada`, `estatua_piedra`, `jarron`, `jarron_alto`, `cristal_*` |
| Piezas que hay que pedir (lámina de Meshy, 300–1 500 triángulos, 512²) | pasarela de tablones, cañas altas, árbol de manglar, flor de pantano luminosa, casa sobre pilotes | abeto nevado (1,5–3 k), roca con nieve ×3, puente colgante, piedras de cornisa, cabaña de piedra | cactus ×3, palmera, toldo de tela, roca en arco, huesos y calavera, duna como borde del mapa |
| VFX ambientales (reutilizando) | `NieblaFoso3D` generalizada a «niebla baja de zona»; **luciérnagas** (motas del kit con un pulso de 2 s); burbujas que suben (`VfxPuzle3D.burbujas`); **agua estancada** = `AguaRender3D` con flujo 0, color `#346A60` y lentejas de agua (decal o MultiMesh) | **nieve** con GPUParticles y `copo.png` alrededor de la cámara (el patrón de las motas de `Logros3D`); ventisca = `VfxViento.cintas` en blanco; aliento y escarcha en el suelo con el estado «helado» | **arena voladora** = `VfxViento.cintas` y `polvo_tira8` en color arena; remolinos de polvo (`VfxViento.torbellino`); **calima** = distorsión de pantalla (reutilizar el shader de `PulsoPantalla3D` con baja amplitud y continuo) |
| Lo que cambia en el juego (ARTE §2: «el ambiente decide qué elemento importa») | el fuego dura poco (humedad); el agua manda | el hielo está por todas partes; el fuego derrite (las reacciones ya existen) | el fuego no ilumina nada nuevo; agua escasa; viento fuerte |
| Coste aproximado | **M** (2 texturas, 1 lámina, generalizar la niebla) | **M–L** (sin paleta todavía; nieve y lámina) | **M** (2 texturas y 1 lámina; los VFX salen casi gratis del viento) |

**Antes de cualquier bioma nuevo:** A8 (cargar solo las piezas del nivel) y A9 (comprimir). Si no, cada lámina nueva se suma a la VRAM de todos los niveles.

---

*Datos en bruto en este mismo scratchpad: `glb_modelos.tsv`, `glb_piezas.tsv`, `tscn_piezas.tsv`, `texturas.tsv` (696 imágenes con su `.import`), `shaders.tsv` (67 shaders), `uso_piezas.txt` (cada pieza × nivel). Los scripts (`glbinfo.py`, `tscninfo.py`, `texaudit.py`, `shaders.py`, `uso_piezas.py`, `huerfanas.py`) se pueden volver a ejecutar para regenerar `docs/auditoria_texturas.tsv` (A24).*
