# Estructura del código: arquitectura de módulos (30/10/2026)

Encargo de Pablo (30/10): «revisa la estructura del código e identifica posibles mejoras». Lo escribe el contexto de
**dirección**, solo leyendo el código. Completa los tres análisis del 24/10 y **no los repite**:

| Ya está en | Tema | Aquí se usa para |
|---|---|---|
| `docs/ANALISIS_DIRECCION_24-10/01_codigo_muerto_y_duplicado.md` | funciones muertas, duplicación, armazón de pruebas (§3.2), privados ajenos (§3.4), casilla 2,3 (§3.5) | los pasos 4 y 6 del plan remiten a sus tablas |
| `…/02_estados_vs_eow.md` | los estados (suelo, zona, entidad) frente a EoW | no se toca aquí |
| `…/03_patron_hechizo_en_otros_sitios.md` | clases de datos (`Hechizo` como patrón) para enemigos, reactivos, glifos | §5 (registros por datos) se apoya en él |

Lo nuevo es la **vista de módulos**: capas, dependencias reales medidas, dónde se rompe el reparto Juego/Pipeline y
qué estructura conviene. Referencias: `docs/ARQUITECTURA_MODULAR.md` (capas y plan M1–M5) y `docs/PROPIETARIOS.md`.

**Foto del momento.** Todo se midió el 30/10 sobre el worktree `proyecto-analisis-profundo-bf47f8`, **mientras otro
agente borraba archivos sin uso**: 577 `.gd` (233 de juego y laboratorios, 344 en `herramientas/`). Las cifras pueden
bajar unas pocas unidades cuando acabe esa limpieza; las conclusiones no cambian. Los guiones y sus salidas están en
`C:\Users\pablo\AppData\Local\Temp\claude\C--Users-pablo-Documents-magic-symbols--claude-worktrees-proyecto-analisis-profundo-bf47f8\bbc0c028-6f87-4f66-b0a3-93d912d2e3fc\scratchpad\estructura\`
(`deps.py` → `dependencias.csv`, `matriz.txt`, `ciclos.txt`, `carpetas.dot`, `archivos_juego.dot`; `dioses.py`,
`secciones.py`, `convenciones.py`, `mudanza.py` → `mudanza.csv`). Se repiten con `python -I -X utf8 deps.py <repo> <salida>`.

---

## 0. Resumen: los cinco hallazgos

1. **Las capas existen como carpetas, no como dependencias.** Hay **674 referencias «hacia arriba»** (211 parejas de
   archivos) en el código de juego. Y **127 archivos** de juego y presentación (`nucleo`, `mundo`, `objetos`, `magia`,
   `jugador`, `enemigos`, `escenas`, `presentacion`, `ui`) forman **un solo componente fuertemente conexo**: desde
   cualquiera de ellos se llega a cualquier otro. Hoy no hay capa que se pueda probar, cambiar o entender por separado.
2. **La maqueta del Pipeline (`presentacion/prueba_test2.gd`) es el centro real del juego.** La leen 40 archivos de
   juego: **255 `get("_x")`** y 62 accesos `obj._x` sobre sus privados. `Terreno3D` (la fachada que se construyó en M1)
   todavía pregunta a la maqueta por `_bloqueadas` y `_lado` (`mundo/terreno_3d.gd:171`, `:217`). `mundo/` la hereda
   (`vista_suelo_editor.gd:2`) y la carga para leer constantes (`marcador_3d.gd:238`). M5 sigue sin empezar: el
   archivo ha pasado de 183 KB (13/10) a **297 KB y 5 842 líneas**.
3. **La magia monta la interfaz y la presentación.** `Lanzador3D` crea el libro, la paleta, las páginas, el menú y el HUD
   de misión (`magia/lanzador_3d.gd:601-622`), y `Jugador3D` crea el HUD EoW y la pantalla de muerte
   (`jugador_3d.gd:112`, `:82`). Quien compone la partida está en la capa equivocada: son solo 14 aristas directas a la
   UI, pero bastan para atar la magia a toda la interfaz. Otras 71 apuntan a 9 archivos **del Juego** que viven en
   `presentacion/` (`Sensacion3D`, `Apuntado3D`, `Logros3D`, `PrevisionReaccion3D` y 5 de `ui/` fuera de los 4 que declara
   PROPIETARIOS). Con mudarlos no cambia el código, pero sí queda claro de quién es cada uno. Por último, **296 de las 674** (el 44 %) apuntan a la maqueta.
4. **Para añadir una cosa hay que tocar muchos sitios.** Una pieza de decorado: **4 scripts y hasta 13 tablas**. Un personaje: 6 scripts
   de juego y unas 13 tablas, contando 2 constantes de la maqueta que `Marcador3D` lee por reflexión. Un elemento: unos 35 archivos mencionan
   `"viento"`. Un glifo es lo que mejor está (6 scripts + `.tres` + PNG). Un nivel: 5 archivos, y uno de ellos es una escena raíz que se copia
   a mano con 10 `@export`.
5. **`herramientas/` mezcla 344 scripts de seis clases distintas** (163 pruebas, 111 capturas, 36 escenarios, 22 de medida o
   diagnóstico, 12 de arte). La batería completa no tiene tiempo medido. Estimándolo con los logs de Godot y el diario, tarda
   **40–50 min**. Las 115 pruebas que no cargan escena podrían ser una batería corta de 1–2 min si se lanzan en paralelo.

Los tres primeros pasos del plan (§8): **(1) un trinquete de capas** en `tools/grafo.py`, para que las 674 no suban
(S); **(2) mudar los 9 archivos del Juego que están en `presentacion/` y separar `herramientas/`** en `pruebas/`,
`capturas/` y `herramientas/` (S–M, sin tocar código de juego); **(3) terminar M1**, es decir, `nucleo/medidas.gd` y
`nucleo/capas.gd` y borrar los 35 reenvíos de `Lanzador3D` (S).

---

## 1. Método (para poder repetirlo)

`deps.py` recorre todos los `.gd` y `.tscn`, quitando antes los comentarios y las cadenas, y anota una arista
archivo→archivo con su **vía** y su **línea**:

| Vía | Cómo se detecta | Aristas (juego) |
|---|---|---|
| `class_name` | palabra con mayúscula que coincide con un `class_name` de otro archivo | la mayoría |
| `preload`/`load`/`extends`/ruta | `"res://…gd"`. Una ruta a un `.tscn` se resuelve a los scripts que monta | 31 |
| `grupo` | `get_nodes_in_group("g")`/`is_in_group`/`call_group`, hacia quien hace `add_to_group("g")` (también en `.tscn`) | — |
| `privado` | `get/call/set/has_method("_x")`, hacia el archivo que declara `_x` (si lo declara la maqueta, se elige la maqueta) | — |
| `privado_directo` | `obj._x` cuando `_x` no es del propio archivo | — |
| `senal` | `x.connect(` / `connect("x"` hacia quien declara `signal x` | — |

Límites: un nombre privado o un grupo declarado en varios sitios se atribuye a todos (hasta 3) y se marca con `?` en el
CSV. Por eso las aristas de `privado?` son una cota superior. Las rutas a recursos de `arte/` no se cuentan. Un `class_name`
usado solo como tipo cuenta igual que una llamada, porque al compilar también ata.

**Capas declaradas** (ARQUITECTURA_MODULAR §2, de abajo arriba): `nucleo` (0) → `mundo` (1) → `objetos` (2) →
`magia`/`jugador`/`enemigos`/`escenas` (3) → `presentacion` y `presentacion/*` (4) → `laboratorios`/`herramientas` (5).
Una arista es una **violación** cuando el origen está en una capa más baja que el destino. Entre `presentacion/*` no cuenta, y
entre carpetas de la capa 3 tampoco.

---

## 2. El grafo real

### 2.1 Matriz carpeta → carpeta (parejas de archivos distintas)

Filas: quién depende. Columnas: de quién. En **negrita**, las celdas que van hacia arriba.

| origen \ destino | nucleo | mundo | objetos | magia | jugador | enemigos | escenas | presentacion | p/ui | p/vfx_elem |
|---|---|---|---|---|---|---|---|---|---|---|
| **nucleo** | 59 | **7** | **3** | **5** | . | **3** | **3** | **2** | **2** | . |
| **mundo** | 9 | 31 | **2** | **2** | **1** | **4** | **1** | **5** | . | . |
| **objetos** | 113 | 47 | 51 | **46** | . | **11** | **7** | **51** | **1** | . |
| **magia** | 43 | 12 | 10 | 10 | 2 | 5 | . | **8** | **8** | **1** |
| **jugador** | 15 | 9 | 4 | 5 | 18 | 6 | . | **8** | **2** | . |
| **enemigos** | 35 | 14 | 8 | 9 | 9 | 21 | . | **13** | . | . |
| **escenas** | 37 | 18 | 41 | 8 | . | 12 | 4 | **13** | . | . |
| presentacion | 22 | 28 | 8 | 14 | 12 | 14 | 7 | 74 | 1 | 15 |
| presentacion/ui | 41 | . | 1 | 9 | . | . | 1 | 4 | 19 | . |
| presentacion/vfx_elementos | . | . | . | 1 | 1 | . | 1 | 10 | . | 9 |
| laboratorios | 29 | 18 | 17 | 10 | 11 | 8 | 5 | 28 | 1 | . |
| herramientas | 476 | 286 | 248 | 177 | 150 | 186 | 161 | 403 | 54 | 17 |

(Grafo de carpetas para Graphviz: `carpetas.dot`, con las aristas que suben en rojo. El de archivos de juego:
`archivos_juego.dot`.)

Tres datos que se leen en la tabla:

- **`objetos` depende de `magia` en 46 parejas y de `presentacion` en 51**, pero `magia` solo depende de `objetos` en 10.
  Debería ser al revés: el objeto reactivo es la capa de abajo. La mayor parte de esas 46 son la constante de física
  `Lanzador3D.CAPA_REACTIVO` (30 usos en el juego), el grupo `"spellcaster"` (32 aristas) y `Lanzador3D.celda_de`.
- **`presentacion` → juego suma 105 parejas.** La regla dice que la presentación puede depender de todo, pero
  «por señales». Lo que se ve es `class_name` directo y la maqueta haciendo de mundo.
- **Ninguna carpeta del juego depende de `herramientas/` ni de `laboratorios/`** (solo 2 aristas: `nivel_pruebas.gd:52` usa
  `GeneradorPiezas`, y `lanzador_3d.gd:3115` busca el grupo `flammable3d`, que solo añade `herramientas/prueba_barrera.gd`, así que es un grupo
  muerto en el juego). Es lo único del reparto que se cumple de forma limpia.

### 2.2 Las violaciones, por pareja de capas (674 aristas)

| Origen → destino | Aristas | Qué es, sobre todo | Ejemplos (archivo:línea) |
|---|---|---|---|
| escenas → presentacion | 193 | las reglas de nivel leen privados de la maqueta | `jugabilidad_3d.gd` ×48, `bosque_01_v01_3d.gd` ×42, `bosque_3d.gd` ×27, `bosque_01_3d.gd` ×26, `terra_fina_3d.gd` ×19, `puzle.gd` ×16 (`:675` `_pieza`, `:1248` `_jugador`, `:1863` `_props`); `puzle.gd:2500-2539` usa `AguaRender3D` |
| objetos → presentacion | 135 | ocultación y modelos dibujados a mano | `enredadera_3d.gd:115-193` y `objetos_3d.gd:1639-1697` → `Ocluso3D` (23); `escudo_3d.gd`, `cuerda_3d.gd` → `PiezaFuego3D` (17); `surtidor_3d.gd:68,125,176,223` → `_letra`, `_es_canal`, `_fx`, `_mapa` de la maqueta |
| enemigos → presentacion | 63 | gamefeel y VFX directos | `combate_3d.gd` → `Sensacion3D` ×19 (`:479`, `:502`…), `Vfx3D` (`:1026-1033`), maqueta `_personaje` (`:347`, `:359`), `_goblins` (`:350`, `:2430`), `_fx` (`:1025`) |
| objetos → magia | 62 | constante de capa, grupo `spellcaster`, celdas | 21 archivos usan `Lanzador3D.CAPA_REACTIVO`/`celda_de`; `objetos_3d.gd:691,705,720` buscan el grupo `spellcaster` |
| magia → presentacion | 51 | el lanzador compone UI y VFX | `lanzador_3d.gd:601,610,622` (`load` de `page_hud`, `rune_palette`, `spellbook`), `:615` `MenuPestanas`, `:617` `MisionHud`, `:179,1588-1679` `Apuntado3D` ×11, `Sensacion3D` ×8, `:277-285` privados de la maqueta (`_es_agua`, `_es_hierba`, `_precalentando`, `_letra`, `_bloqueadas`), `:332` `_liberar`, `:2253` `_al_impactar` |
| jugador → presentacion | 32 | HUD y privados de la maqueta | `jugador_3d.gd:179` `_jugador`, `:205` `_fx`, `:208` `_camara`, `:230` `_goblins`, `:262,675` `_velo`, `:827` `_tipo_suelo`, `:942` `_giro_cam`; `:82,238` `PantallaMuerte`; `:112,1186` `HudEoW`; `pj_3d.gd:650-672` `MaterialPersonaje3D` |
| **nucleo → mundo** | 26 | datos puros que preguntan al terreno | `playlog_3d.gd:220-227` `Terreno3D` ×16; `botin.gd:192-204`; `sigils.gd:329,487`; `hechizo.gd:163`; `niveles.gd:201`; `tinta_reaccion.gd:18,29` `Mundo3D` |
| mundo → presentacion | 19 | el mundo lee o hereda la maqueta | `terreno_3d.gd:171` `_bloqueadas`, `:217,366,381` `_lado`, `:238` grupo `bloquea`; `vista_suelo_editor.gd:2` **`extends` maqueta**; `marcador_3d.gd:238` `load` maqueta; `reacciones_suelo_3d.gd:159` `_hf`; `estado_zona_3d.gd:176` `_jugador` |
| nucleo → presentacion(+ui) | 18 | datos puros que dependen de la UI o de la maqueta | `aviso_objeto.gd:22,117,124,147` `TemaInterfaz`, `:92` `MarcoCalidad`; `playlog_3d.gd:230,257` `_jugador`, `:264,325` `_hf`, `:325` `_pisadas` |
| objetos → enemigos / escenas | 23 | grupo `combate3d` (10), `Puzle3D` (8), `_logro` (3) | `salida_nivel_3d`, `receptor_pulso_3d`, `pared_hueca_pulso_3d`, `estatuas_pulso_3d` → `Puzle3D` |
| nucleo → escenas/magia/enemigos/objetos | 21 | registro de niveles por ruta y grupos | `niveles.gd:20-25` (rutas a `Prueba*.tscn`), `:180` grupo `spellcaster`, `:186` `entrada_nivel`; `botin.gd:150,168,170`; `hechizo.gd:487` `CastPoints`; `tinta_reaccion.gd:36-43` `Escudo3D`/`Combate3D`; `tinta.gd:367` grupo `muneco` |
| mundo → objetos/magia/enemigos/jugador/escenas | 12 | el previsualizador del editor lee constantes del juego | `marcador_3d.gd:239` `pj_3d`, `:250` `objetos_3d`, `:267` `bosque_3d`, `:271` `Formas3D`; `nube_veneno_3d.gd:70` `Lanzador3D`, `:145` grupo `combate3d`; `estado_zona_3d.gd:334,393` |

**Por vía:** `class_name` 293 · privados 292 (`privado` 127 + `privado?` 111 + `privado_directo` 54) · grupo 59 ·
rutas 23 · señal 8. Que solo haya 8 por señal dice mucho: el contrato «la presentación escucha» (ARQUITECTURA_MODULAR §3.4)
casi no se usa en la dirección en que haría falta.

### 2.3 Ciclos

- **Un componente fuertemente conexo de 127 archivos.** Contiene todo `enemigos/` (10), todas las reglas de `escenas/`
  (6), `magia/` (6: lanzador, grimorio, spellcaster, hechizo_vivo, previsión, runa), 10 de `mundo/`, 17 de `nucleo/`, 38 de
  `objetos/`, 3 de `jugador/` (`pj_3d`, `chaman_ritual`, `tiempo_bruja`), 23 de `presentacion/`, 9 de `ui/` y 5 de
  `vfx_elementos/` (la lista completa está en `ciclos.txt`). Fuera quedan las hojas: la UI de tema, `agua_sim_3d`, gestos,
  `runes` y `jugador_3d`, que depende de todo pero de quien nadie depende.
- **Ciclos directos entre carpetas** (A→B y B→A a la vez): **29 parejas** de carpetas de juego. Entre ellas `nucleo↔mundo`
  (7/9), `nucleo↔objetos` (3/113), `nucleo↔presentacion/ui` (2/41), `mundo↔objetos` (2/47), `objetos↔magia` (46/10),
  `objetos↔presentacion` (51/8), `enemigos↔objetos`, `enemigos↔magia`, `magia↔presentacion/ui` (8/9) y `jugador↔presentacion` (8/12).
- **Ciclo pequeño de presentación, dentro del grande:** `vfx_kit_3d.gd` ↔ `vfx_elementos/{agua,hielo,rayo,tierra,viento}.gd`.
  El kit conoce a los elementos y los elementos llaman al kit. No es grave porque los 6 archivos son del mismo dueño, pero indica
  que el kit es a la vez fábrica y biblioteca.

Por qué importa: con un ciclo así **ninguna prueba sin ventana puede cargar una capa sola**. `prueba_agua_sim` funciona
porque `AguaSim3D` es una hoja. Las 48 pruebas que montan la maqueta lo hacen porque no hay otra forma de tener un `Terreno3D`
completo (§6).

### 2.4 Cómo va el plan M1–M5 (medido hoy)

| Paso | Estado | Prueba de ello |
|---|---|---|
| M1 `Terreno3D` | **a medias** | `mundo/terreno_3d.gd` existe (619 l.), pero `Lanzador3D` conserva **35 reenvíos** (`lanzador_3d.gd:428-518`) y el juego los sigue usando: `Lanzador3D.celda_de` ×20, `y_pies` ×5, `en_mapa` ×5, `LECHO_AGUA` ×5, `bloqueada` ×3, `bloquear_celda` ×3. Y `Terreno3D` lee la maqueta (`:171`, `:217`) |
| M2 `Mundo3D` con señales | **hecho en lo básico** | `mundo/mundo_3d.gd` tiene `casilla_cambio`, `impacto`, `reaccion` y `logro`, y `_helada` aparece 1 vez en la maqueta (eran 8). Pero la maqueta crea el `Mundo3D` y el juego sigue pidiéndole `_fx` y `_jugador` a la maqueta |
| M3 `AccionElemental` | **empezado** | `mundo/accion_elemental.gd` (27 l.), 18 menciones en el juego y 6 llamadas a `aplicar_accion`. `hechizo_sobre_agua` sigue en el lanzador (`:299-427`) |
| M4 cortar el 2D | **casi** | `Lanzador3D extends Grimorio`. `magia/spellcaster.gd` (808 l.) sigue vivo como `class_name` y como grupo `"spellcaster"`, del que dependen 21 archivos (01 §3.1 propone borrarlo) |
| M5 partir la maqueta | **sin empezar** | 5 842 líneas, 212 funciones, 44 `@export` y 176 variables miembro |

---

## 3. Los «dioses»

Las cifras de líneas son las reales (con vacías y comentarios). «Lectores» son los archivos de juego que dependen
de él (sin contar herramientas ni laboratorios) y entre paréntesis va el total con ellos.

### 3.1 Tabla resumen

| Archivo | Líneas (código) | Func (static) | Clases internas | Lectores juego (total) | Vía principal | Prioridad |
|---|---|---|---|---|---|---|
| `presentacion/prueba_test2.gd` | 5 842 (4 659) | 212 (4) | 0 · 542 l. de shader | **40 (188)** | **privados**: 255 `get` + 62 directos | 1 |
| `magia/lanzador_3d.gd` | 3 374 (2 431) | 162 (57) | 6 | **42 (147)** | `class_name` 150 | 2 |
| `escenas/puzle.gd` | 3 167 (2 536) | 63 (21) | 5 | 13 (108) | `class_name` 13, ruta 6 | 4 |
| `enemigos/combate_3d.gd` | 2 627 (2 064) | 117 (6) | 2 | 30 (113) | `class_name` 67, grupo 23 | 3 |
| `presentacion/vfx_3d.gd` | 2 427 (1 979) | 88 (1) | 0 · 116 l. de shader | 21 (57) | `class_name` 61 | 5 |
| `jugador/pj_3d.gd` *(no pedido, pero es del mismo tamaño)* | 2 343 | 125 (13) | 0 | 5 (44) | privados 7 | — |
| `presentacion/agua_render_3d.gd` | 2 087 (1 786) | 33 (1) | 0 · **928 l. de shader** | 3 (23) | `class_name` 12 | 6 |
| `presentacion/ui/spellbook.gd` | 1 949 (1 078) | 85 (1) | 0 | 1 (11) | `load` + `_libro` | 8 |
| `objetos/objetos_3d.gd` | 1 717 (1 259) | 91 (7) | 0 | 18 (60) | `class_name` 65, señal 10 | 4 |
| `magia/hechizo_vivo.gd` | 1 667 (1 262) | 81 (17) | 1 | 4 (36) | `class_name` 16 | 9 |
| `presentacion/vfx_estado_3d.gd` | 1 614 (1 316) | 17 (3) | 2 (una de 1 115 l.) | 1 (21) | `class_name` 2 | 7 |

La prioridad depende de cuántos lectores tiene y por qué vía, no del tamaño. Un archivo grande con un solo lector
(`spellbook`, `vfx_estado`) solo molesta a quien lo edita. Uno con 40 lectores por privados rompe cosas en los dos
contextos.

### 3.2 Reparto propuesto, archivo por archivo (sin cambiar comportamiento)

La técnica es siempre la misma (ARQUITECTURA_MODULAR §4): **mover funciones, dejar reenvíos de una línea** en el sitio
viejo mientras queden llamadas, y quitar los reenvíos cuando `grep` dé 0. Una clase interna se saca a su archivo con
`class_name` y en el padre queda `const Nombre = preload("res://…")`, así que `Lanzador3D.GeometriaV2` sigue compilando.

#### `presentacion/prueba_test2.gd` → M5 en 6 archivos

Hoy (secciones del archivo, funciones por tema): constantes, `@export` y estado (l. 1-1252: 137 `const`, 44 `@export`,
176 `var`) · rejilla 5 · **suelo** 20 + orilla 2 + diorama/bordes/lecho 13 + hielo pulido 16 · **decorado Meshy** 13 ·
**reactivos** 27 (l. 2729-3279) · **letras del plano** 8 + nivel editable 8 + `Nivel_<X>.tscn` 16 (l. 3280-4297) ·
personajes 6 · efectos 9 · **estado del suelo** 25 (l. 4543-4946) · bucle 12 · **«API del Bosque»** 30 (l. 5245-5842, «la usa el Juego»).

| Archivo nuevo | Dueño | Qué se mueve | Contrato que queda |
|---|---|---|---|
| `mundo/cargador_nivel.gd` | Juego | letras, marcadores, `Nivel_<X>.tscn` → `Terreno3D`/`Mundo3D` (l. 3280-4297, unas 32 funciones). Absorbe `_mapa`, `_bloqueadas`, `_lado`, `_letra`, `_marcas`, `_celdas_*` | `Mundo3D.cargar(nivel)` (ARQUITECTURA_MODULAR §3.1). `Terreno3D` deja de leer la maqueta |
| `objetos/colocador_reactivos.gd` | Juego | crear y enlazar `Reactivo3D` desde letras y marcadores (l. 2729-3279, 27 funciones) | `reactivos() -> Array[Reactivo3D]` |
| `presentacion/maqueta/suelo_3d.gd` | Pipeline (shader `CODIGO_SUELO`: Pablo) | suelo, orilla, diorama, biseles, *joints*, los 542 l. de shader → `.gdshader` | escucha `Mundo3D.casilla_cambio` |
| `presentacion/maqueta/decorado_3d.gd` | Pipeline | bibliotecas Meshy, lotes, sombras de contacto, viento (l. 2541-2728 y las tablas `SOMBRA_*`, `VIENTO_DECORADO`) | `pieza(id, c) -> Node3D` |
| `presentacion/maqueta/estado_suelo_vista.gd` | Pipeline | hielo pulido, hierba que arde y pisadas: el **dibujo** del estado (l. 2261-2540, 4543-4946) | lee `Mundo3D.estados` y deja de tener `_hf`, `_pisadas`, `_mojada` como dato |
| `presentacion/maqueta_3d.gd` (raíz, con el nombre viejo como reenvío) | Pipeline | `_ready`, `@export`, bucle, cámara, personajes, efectos | **fachada pública** que sustituye a los privados: `jugador()`, `fx()`, `enemigos()`, `props()`, `reactivos()`, `camara()`, `luz_sol()`, `entorno()`, `hay_velo()`, `crear_personaje(ids, pos)`, `pos_marca(c, y)`, `camara_tam` (la tabla de 01 §3.4 dice cuál sustituye a cuál) |

`mundo/vista_suelo_editor.gd` deja de heredar la maqueta y hereda `suelo_3d.gd` (pasa a ser del Pipeline, §4.1).

#### `magia/lanzador_3d.gd` → 6 archivos

Hoy: utilidades de casilla 3 + **reenvíos M1 26** (l. 257-518) · agua 10 · arranque **que monta la UI** 6 (l. 541-669) ·
reglas del libro 3 · **modo lanzar 51** (l. 731-1583) + marcadores 4 · **materializar 25** · campos 3 · materia V2 22 ·
caducidad 6 · y seis clases internas al final (l. 2711-3374): `GeometriaV2`, `Receta3D`, `Campo`, `ZonaV2`,
`SolidezV2`, `BarreraFuego`.

| Archivo nuevo | Qué se mueve | Contrato |
|---|---|---|
| `magia/geometria_v2.gd`, `magia/receta_3d.gd`, `magia/campo_3d.gd`, `magia/zona_v2.gd` (+`SolidezV2`), `objetos/barrera_fuego_3d.gd` | las 6 clases internas (unas 660 l.). Es mecánico y sin riesgo | `const GeometriaV2 = preload(...)` en `Lanzador3D` mientras haya `Lanzador3D.GeometriaV2` (9 usos), `ZonaV2` (8), `Receta3D` (3) |
| `nucleo/capas.gd` | `CAPA_*` (30 usos de `CAPA_REACTIVO` fuera) | `Capas.REACTIVO`… |
| (borrar) | los 35 reenvíos M1 | 0 usos de `Lanzador3D.celda_de/y_pies/en_mapa/bloqueada/LECHO_AGUA` |
| `mundo/reacciones_agua_3d.gd` (ya existe) | `hechizo_sobre_agua` y compañía (l. 299-427): es M3 | `Mundo3D.aplicar(AccionElemental)` |
| `magia/modo_lanzar.gd` | apuntar, marcadores y previsión (l. 731-1689, 55 funciones) | señal `apuntado(punto, valido)` para `Apuntado3D` y `PrevisionReaccion3D` |
| `magia/materializar.gd` | receta → volumen, materia V2, campos, caducidad, deshacer (l. 1690-2710, 57 funciones) | `materializar(hechizo, origen) -> Array[Campo]` |

En `Lanzador3D` queda el arranque, las reglas del libro y el ciclo página → hechizo, más o menos 600 líneas. El montaje de la UI
(l. 595-622) sale a quien compone la partida (paso 5 del plan).

#### `presentacion/vfx_3d.gd` → por familia (lo anunciaba ARQUITECTURA_MODULAR §5.6)

Hoy: utilidades de cabecera 15 · formas 6 · pulso que crece 7 · **cúpula y perfiles** 9 + tierra `stone_ring` 3 + rayo
`energy_ring` 13 · fases 6 · impactos 6 · **piezas 23**. Lo leen 21 archivos de juego (61 `class_name` y 6 por señal).

Propuesta: `presentacion/vfx/barreras_vfx.gd` (cúpula, piedra, energía: 25 funciones), `pulso_vfx.gd` (7),
`impactos_vfx.gd` (impactos y fases: 12), `piezas_vfx.gd` (23) y `vfx_3d.gd` como **fachada con la misma API**
(reenvíos). Los 21 lectores no cambian en este paso. Después, el Juego cambia las llamadas directas por la señal
`Mundo3D.impacto` o `reaccion` (§3.4 del contrato), que ya existe.

#### `enemigos/combate_3d.gd` → 5 archivos

Hoy: contrato de reacciones y «cae al agua» 5 · `on_spell_hit`/empuje/niveles 11 · daño y efectos 20 · fotograma (IA,
movimiento, animación) 9 · estados del mundo 4 · **«el fuego pasa por contacto» 37** (l. 1182-1937: el rótulo se ha
quedado viejo y dentro está casi toda la IA) · aspecto 7 · **elemental de bosque** 15 (l. 2079-2333) · barra grande 2 ·
muerte y botín 7 · clases internas `EnlaceEnredadera` y `Botin3D`. 30 lectores de juego, 23 de ellos por el grupo `combate3d`.

Propuesta: `combate_3d.gd` queda como cuerpo (vida, daño, contrato `on_spell_hit`, empuje y muerte), `enemigos/ia_goblin_3d.gd`
(IA de guerrero, arquero y asesino: la mayor parte del bloque l. 951-1937), `enemigos/elemental_bosque_3d.gd`
(`extends Combate3D`, como ya hacen `golem`, `limo` y `chaman`: el comentario de l. 2080 explica por qué no se hizo y hoy
la herencia ya está abierta), `enemigos/aspecto_enemigo_3d.gd` (tinte y barras), `enemigos/botin_3d.gd` y
`enemigos/enlace_enredadera.gd`. Los datos por tipo van a `.tres` (03 §a).

#### `magia/hechizo_vivo.gd` → 4 archivos (prioridad baja)

Hoy: hechizo que se mueve y eventos 40 · golpe con eventos 9 · momento de ejecución 11 · proyectil 21 · clase interna
`Linaje`. Solo lo leen 4 archivos de juego y tiene sus pruebas (`prueba_hechizo_vivo`, la suite «hechizos»). Propuesta:
`hechizo_vivo.gd` (ciclo de vida), `proyectil_hechizo.gd`, `momentos_ejecucion.gd` y `linaje_hechizo.gd`. Merece la pena
cuando se toque, no antes.

#### `objetos/objetos_3d.gd` (`Reactivo3D`) → base + 4 familias

Hoy: papeles 11 · contrato con los hechizos 11 · «reaccionar da algo» 6 · **objetos que arden 13** + tótems 2 + fogatas 3
+ relé 4 · fuente eléctrica y surtidor 5 · **tinaja 22** · puente y placa 4 · materiales 9. Todo va en un archivo y se
reparte por `if tipo == "…"`.

Propuesta: `objetos/reactivo_3d.gd` (base: contrato, papeles, materiales, recompensa), `objetos/inflamable_3d.gd`
(arden, fogatas, braseros, relé, leña), `objetos/tinaja_3d.gd`, `objetos/totem_fuente_3d.gd` y
`objetos/puente_placa_3d.gd`, con una fábrica `Reactivo3D.crear(tipo)` para que la maqueta (o `colocador_reactivos`) no cambie. 
Así, cada subclase declara lo que antes decidía el `tipo` (03 §b).

#### `presentacion/ui/spellbook.gd` → 5 archivos (Juego)

Hoy: láminas 11 · mano que escribe 6 · captura del trazo 7 + trazo recto 2 + **asistencia 11** · dónde cae el libro 8 ·
dibujo 7 (y 28 `_draw*` en total) · **página derecha 15** · color del núcleo 3 · **corona 13** · coste H7 1 · pestañas 1.
Tiene un 29 % de comentarios. Lo carga solo `lanzador_3d.gd:622` (y `:1535` lee su `_libro`).

Propuesta (en `interfaz/libro/`): `libro_ui.gd` (Control raíz, entrada, abrir y cerrar, pestañas), `trazo_libro.gd`
(captura, recto y asistencia: 20 funciones), `pagina_derecha.gd` (15), `corona_sectores.gd` (corona y núcleo: 16) y
`laminas_libro.gd` (11). Contrato: señales `glifo_reconocido(id, sector)` y `pagina_confirmada(pagina)` en vez de leer `_libro`.

#### `presentacion/agua_render_3d.gd` → shaders fuera y 3 archivos

El 44 % del archivo (928 líneas) son shaders en cadenas `"""`, y tiene 106 `const` de ajuste. Propuesta:
`presentacion/agua/*.gdshader` (superficie, lado y cascada: el editor los colorea y los recarga en caliente),
`agua_ajustes.tres` (las 106 constantes como recurso editable), `agua_render_3d.gd` (montaje y `_process`) y
`agua_flujo_3d.gd` (enlazar, flujo y fuentes). Solo lo leen 3 archivos de juego, así que el riesgo es bajo.

#### `presentacion/vfx_estado_3d.gd` → 3 archivos

17 funciones de despacho arriba y dos clases internas: `EfectoHechizo` (l. 439-1550, **1 115 líneas**) y `Rafaga`.
Propuesta: `presentacion/vfx/efecto_hechizo_3d.gd` (y, si sigue creciendo, uno por estado de la materia: líquido, sólido y
gas), `rafaga_3d.gd` y `vfx_estado_3d.gd` como despachador. Tiene 1 lector de juego.

#### `escenas/puzle.gd` (`Puzle3D`) → `niveles/puzle/`

Hoy: gramática documentada en cabecera (l. 12-468) · clases internas `Pieza`, `PuertaPuzle`, `VigiaPuzle`, `CerrojoPuzle` y
`CofrePuzle` (l. 469-~1200) · consultas 8 · **leer la gramática 17** («sin mundo: se prueba con texto») · **montar piezas 24** ·
conectar reglas 9. Lo leen 13 archivos de juego.

Propuesta: `niveles/puzle/gramatica_puzle.gd` (parser puro y `static`: se prueba sin escena, y así entra en la batería corta),
`montador_puzle.gd` (24), `reglas_puzle.gd` (9), `piezas/{puerta,vigia,cerrojo,cofre}_puzle.gd` y `puzle.gd` como nodo
fachada. Los 16 privados de la maqueta que usa (`_pieza`, `_props`, `_jugador`, `_fx`) pasan a la fachada pública de M5.

#### `jugador/pj_3d.gd` (no estaba en la lista, pero tiene el mismo tamaño)

2 343 líneas, 125 funciones y unas 30 tablas `const` por modelo (`CLIPS_DE`, `RAIZ_ANULADA`, `VEL_CLIP_PJ`,
`MODELOS_EMPUJABLES`, `MOMENTOS_CORTE`…). Es el registro de personajes y el animador a la vez. Lo que más arregla es §5: sacar
las tablas a un `.tres` por personaje.

---

## 4. Carpetas y nombres

### 4.1 Incoherencias medidas

| # | Incoherencia | Dato |
|---|---|---|
| 1 | **Juego dentro de `presentacion/`**, fuera de lo que declara PROPIETARIOS | `sensacion_3d.gd`, `apuntado_3d.gd`, `logros_3d.gd` y `prevision_reaccion_3d.gd` dicen «Dueño: Juego» en la cabecera; en `ui/`, además de los 4 declarados, también `hud_eow.gd`, `menu_pestanas.gd`, `pantalla_muerte.gd`, `diario_misiones.gd` y `mision_hud.gd` (cabecera «Juego»). Son **9 archivos sin dueño claro según la carpeta** y 71 de las 674 violaciones |
| 2 | **Pipeline dentro de carpetas del Juego** | `magia/formas_3d.gd` (geometría de VFX, «Pipeline»), `mundo/vista_suelo_editor.gd` (hereda la maqueta), `escenas/jugabilidad_3d.gd` (nació «Pipeline», hoy son reglas), `objetos/vfx_calidad_3d.gd` (VFX), `escenas/titan_3d.gd` (modelo procedural) |
| 3 | **Audio del Pipeline en `nucleo/`** | `nucleo/sfx.gd`, `sonidos.gd` y `sfx_3d.gd` son del Pipeline (PROPIETARIOS §2) en la carpeta de datos puros del Juego |
| 4 | **`nucleo/` no es «datos puros»** | 33 archivos: además de los datos, `playlog_3d.gd` (Node que lee la maqueta), `aviso_objeto.gd` (UI con `TemaInterfaz`), `niveles.gd` (viaje entre escenas con fundido), `partida.gd`. Depende de 6 carpetas de encima (§2.2) |
| 5 | **`magia/` frente a `nucleo/`** | la lógica pura del hechizo está en `nucleo/` (`hechizo.gd` 640 l., `sigils.gd`, `dano.gd`, `materia.gd`, `tinta.gd`) y su ejecución en `magia/`. Tiene sentido como datos y ejecución, pero no está escrito en ningún sitio, y `nucleo/hechizo.gd:487` ya llama a `magia/CastPoints` |
| 6 | **`escenas/` hace tres cosas** | 22 `Prueba*.tscn` jugables, 6 scripts de reglas, el motor de puzles `puzle.gd` (3 167 l.) y un escenario de prueba (`prueba_titan.gd`). La carpeta `niveles/` que pedía ARQUITECTURA_MODULAR §2 no llegó a crearse |
| 7 | **`laboratorios/` frente a `escenas/`** | 17 `Lab*.tscn` en `laboratorios/`, pero `escenas/` tiene `PruebaLimo`, `PruebaChaman`, `PruebaSalaGolem`… que también son laboratorios, y `presentacion/prueba_limo.gd` es «escena de muestra, ábrela con F6». La propiedad de `laboratorios/` va archivo por archivo (5 Pipeline según PROPIETARIOS, 12 Juego según su cabecera) |
| 8 | **`herramientas/`: 344 scripts de seis clases** | 163 `prueba_*`, 111 `captura_*`, 36 `escenario_*`, 22 de medida o diagnóstico (`medir_`, `medidas_`, `diag_`, `banco_`), 12 de arte (`generador_piezas`, `generar_*`, `hornear_*`, `convertir_`, `partir_`, `separar_`, `repesar_`, `pesos_`, `montar_`, `rig/`). Son 68 091 líneas, el 40 % del proyecto |
| 9 | **`mundo/datos_nivel/` con copias y basura** | 4 `Nivel_*_copia_*.tscn` (495 KB), 2 `mapas/*_copia_*.txt`, `test2.tscn` y `jugabilidad.tscn` (¿siguen vivas?) y **6 `.jpg` de Meshy (14,7 MB)** que no son datos de nivel |
| 10 | **Sufijo `_3d`** | 142 de 233 archivos de juego y 136 de 212 `class_name` llevan `3D`, sin que quede 2D salvo `mano_pluma_2d`/`tinta_pluma_2d` (que son UI) |
| 11 | **Mezcla de idiomas** | 14 archivos en inglés (`spellbook`, `page_hud`, `rune_palette`, `runes`, `rune_data`, `spell_recipe`, `gesture_*`, `sfx*`, `flags`, `spellcaster`) frente a todo lo demás en español |
| 12 | **El nombre de la maqueta** | `prueba_test2.gd` / `PruebaTest2` es el script raíz de **todos** los niveles, incluido el `main_scene`. «Prueba» y «test2» confunden a cualquiera que llegue nuevo |

### 4.2 Estructura objetivo (la misma propiedad Juego/Pipeline, ahora por carpeta sin excepciones)

```
nucleo/                 Juego    datos y reglas puras, sin nodos ni escena
  hechizo/                       runes, rune_data, *_rune.tres, sigils, spell_recipe, hechizo, materia, dano, tinta, recetas, sintesis
  gestos/                        gesture_* (+ gesture_library.tres)
  partida/                       estado, flags, misiones, niveles (solo el REGISTRO), repertoire, consumibles, objetos, mejoras, botin, playlog
  medidas.gd, capas.gd           S = 2,3 · ALTO_NIVEL · ALTURA_MANO · CAPA_* (hoy en 16 sitios y en Lanzador3D)
mundo/                  Juego    terreno, agua_sim, estados_suelo, estado_zona, reacciones_*, accion_elemental, mundo_3d, caminos
  nivel/                         cargador_nivel (M5), hornear_nivel, marcador_3d, pieza_3d, colision_pieza
  datos_nivel/          Pablo    Nivel_*.tscn, mapas/*.txt, suelo_tipos.tres (Pipeline), luz_juego.tscn  — sin copias ni .jpg
objetos/                Juego    reactivo_3d + familias (inflamable, tinaja, puente…); objetos/pulso/ (11 *_pulso)
magia/                  Juego    lanzador, grimorio, modo_lanzar, materializar, geometria_v2, receta_3d, campo_3d, hechizo_vivo, prevision, cast_points
personajes/             Juego    pj_3d, clips_familia, equipo_3d, ropa_3d, capa_muelles_3d, proporcion_chibi, arbol_anim_pj, chaman_ritual + datos/<id>.tres
jugador/                Juego    jugador_3d (control), brazo_libro_3d, pieza_apoyada_3d, tiempo_bruja, ataque_doble
enemigos/               Juego    combate_3d (cuerpo), ia_goblin_3d, elemental_bosque_3d, golem/limo/chaman/gatopedro, escudo, botin_3d + datos/<tipo>.tres
niveles/                Juego    reglas/ (bosque_3d, bosque_01*_3d, jugabilidad_3d, terra_fina_3d, nivel_pruebas) · puzle/ (Puzle3D partido)
escenas/                Pablo    solo los .tscn que se juegan (Prueba*.tscn hoy; Nivel_<X>.tscn de raíz mañana, §5)
interfaz/               Juego    libro/ (spellbook partido, page_hud, rune_palette) · hud/ (hud_eow, barra, mision, pista, muerte, aviso_objeto) · menus/ (menu_pestanas, diario, bolsa)
  tema/                 Pipeline tema_interfaz, marco_calidad, laminas/, mano_pluma_*, tinta_pluma_2d, ejes_receta_ui
presentacion/           Pipeline maqueta/ (M5) · agua/ · vfx/ (vfx_3d partido, elementos/, estado, kit, formas_3d) · entorno/ (luz, zonas, posproceso, tilt-shift, ocluso) · personajes/ (material, sombra) · piezas/
  juego/                Juego    sensacion_3d, apuntado_3d, logros_3d, prevision_reaccion_3d  (presentación que decide el Juego; la única excepción, y escrita)
audio/                  Pipeline sonidos + sfx.gd, sonidos.gd, sfx_3d.gd (fuera de nucleo/)
laboratorios/juego/     Juego    · laboratorios/pipeline/  Pipeline   (y los Prueba*.tscn que son laboratorios)
pruebas/                Juego    base/ (escenario_base, base_prueba, base_captura) · unidad/ (115) · escena/ (83: escenarios y pruebas con maqueta)
capturas/               los dos  captura_* (111), dueño por cabecera, igual que hoy
herramientas/           los dos  arte/ (Pipeline: generador_piezas, generar_*, rig/…) · medidas/ (medir_, medidas_, diag_, banco_)
```

**Regla de dependencias que acompaña** (para el trinquete del paso 1): `nucleo` → nada · `mundo` → `nucleo` ·
`objetos` → `mundo`, `nucleo` · `magia`/`jugador`/`enemigos`/`personajes` → `objetos`, `mundo`, `nucleo` (y entre sí, sin
ciclos) · `niveles` → todo lo anterior · `interfaz`, `presentacion` → todo lo anterior · `presentacion/juego` es la única
capa de presentación que el juego puede llamar directamente, y solo hasta que existan las señales.
`pruebas`, `capturas`, `laboratorios` y `herramientas` → todo, y nadie depende de ellos.

**El sufijo `_3d`: no renombrar.** Son 136 `class_name` y cada uno aparece en docs, diario y pruebas. El coste es alto, el
beneficio es solo estético y el riesgo de chocar con el otro contexto es seguro. Propuesta: **los archivos nuevos van sin
`_3d`** y los viejos lo conservan. Con el idioma, igual: `spellbook` y `rune_data` se quedan como están.

### 4.3 Mapa de mudanza

El mapa completo, archivo por archivo, está en `mudanza.csv` (scratchpad): 577 archivos, de los que **517 cambian de carpeta**
y 60 se quedan. Por destino:

| Destino | Archivos | Origen | Riesgo de rutas |
|---|---|---|---|
| `pruebas/unidad/` · `pruebas/escena/` · `pruebas/base/` | 115 · 83 · 1 | `herramientas/` | **alto**: 92 `extends "res://herramientas/escenario_base.gd"`, `tools/pruebas.cmd`, `prueba_una.cmd`, `resumen_prueba.ps1` (l. 96-97: `Get-ChildItem 'herramientas' -Filter 'prueba_*.gd'`), `grafo.py` (raíces `herramientas/prueba_`) |
| `capturas/` | 111 | `herramientas/` | medio: `extends` entre capturas y escenarios |
| `herramientas/medidas/` · `herramientas/arte/` | 22 · 12 | `herramientas/` | bajo; `generador_piezas` lo usa `nivel_pruebas.gd:52` por `class_name` |
| `interfaz/{libro,hud,menus,tema}/` | 18 | `presentacion/ui/`, `grimorio/`, `nucleo/aviso_objeto` | **bajo**: 3 `load` en `lanzador_3d.gd:601,610,622` y 9 rutas a `spellbook.gd` desde pruebas |
| `presentacion/juego/` | 4 | `presentacion/` | nulo: solo `class_name` |
| `niveles/reglas/` · `niveles/puzle/` | 6 · 1 | `escenas/` | medio: los `.tscn` montan estos scripts por ruta, pero el `uid` lo resuelve si se mueve con el editor |
| `personajes/` | 12 | `jugador/` | bajo: `marcador_3d.gd:239` carga `pj_3d.gd` por ruta |
| `nucleo/{hechizo,gestos,partida}/` | 29 | `nucleo/` | bajo (todo es `class_name`); **los 7 `*_rune.tres` y `gesture_library.tres` tienen `preload` desde muchos sitios** |
| `audio/` | 3 | `nucleo/` | nulo (`class_name`) |
| `presentacion/{agua,vfx,entorno,maqueta,personajes,piezas}/` | 59 | `presentacion/`, `magia/formas_3d`, `mundo/vista_suelo_editor`, `objetos/vfx_calidad` | medio: **la maqueta tiene `uid` y la cargan 6 escenas y `marcador_3d.gd:238` por ruta**; se mueve la última |
| `laboratorios/{juego,pipeline}/` | 22 | `laboratorios/`, `escenas/prueba_titan`, `presentacion/prueba_limo` | bajo |
| `_a_eliminar/` | 1 | `magia/spellcaster.gd` | tras 01 §3.1 |

**Lo que hace barata la mudanza:** el juego usa casi siempre `class_name` (293 aristas) y casi nunca rutas a `.gd` (31 en
todo el código de juego). Las rutas que pesan son a **escenas** (`.tscn`: 210 desde pruebas y capturas) y a **recursos**
(`arte/`, `.tres`). Por eso: **no se mueven `escenas/*.tscn` ni `mundo/datos_nivel/`** hasta tener §5. Y de los 1 107 literales `res://`
en `.gd`, la mayoría apunta a `arte/`, que no se mueve.

### 4.4 Cómo mover sin romper nada (procedimiento)

1. **Godot cerrado** (PROPIETARIOS §5.6). Se mueve **en lotes de una carpeta**, nunca todo a la vez.
2. Un guion `tools/mover.py <origen> <destino>` (Juego), que: mueve el `.gd` **y su `.uid`**; reescribe `"res://<origen>"` →
   `"res://<destino>"` en todos los `.gd`, `.tscn`, `.tres`, `.cfg`, `.ps1`, `.cmd` y `.py` del repo; y deja un registro.
   Godot 4 resuelve las escenas por `uid://` (hay 244 en `.tscn`), pero **los literales de los scripts no los cambia nadie**.
3. Comprobación estática: `tools/rutas_vivas.py`. Cada `res://…` de código y escenas debe existir en disco. Si sale algo, hay que corregirlo.
4. Abrir Godot una vez con `--headless --editor --quit` para que reimporte y regenere la caché de `class_name`.
   Después, la batería corta (§6) y una partida con F5 del `main_scene`.
5. Diario: una entrada por lote con la tabla «antes → después». El otro contexto hace `git pull` antes de tocar nada.

Orden de lotes (de menos a más riesgo): `presentacion/juego/` y `audio/` (solo `class_name`) → `interfaz/` →
`nucleo/*` → `personajes/`, `niveles/` → `herramientas/` partido en `pruebas/`, `capturas/` y `herramientas/` (con los cuatro
guiones de `tools/`) → `presentacion/*` → la maqueta, la última y ya partida (M5).

---

## 5. Puntos de entrada y datos

### 5.1 Cómo nace un nivel hoy

```
project.godot  run/main_scene = res://escenas/PruebaBosque01_v01.tscn
  └─ PruebaBosque01_v01 (Node3D, script presentacion/prueba_test2.gd = PruebaTest2)
       @export: nivel="Bosque_01_v01", kit="pruebas", zona_luz="bosque", agua_fisica, arqueros, fuego_nuevo… (44 @export en total)
       ├─ Reglas  (escenas/bosque_01_v01_3d.gd)        ← reglas del nivel (Juego), leen privados de la maqueta
       └─ Puzles  (escenas/puzle.gd = Puzle3D)          ← lee las líneas «;» de mapas/<Nivel>.txt
PruebaTest2._ready (l. 1040):
  · _modo_nivel = HorneadorNivel.existe_nivel(nivel)  → mundo/datos_nivel/Nivel_<nivel>.tscn (GridMap + Pieza3D + Marcador3D)
  · si no: HorneadorNivel.leer_mapa(nivel)            → mundo/datos_nivel/mapas/<nivel>.txt (letras)
  · reglas por texto: "jugabilidad" → Jugabilidad3D.new(); "bosque" → load("res://escenas/bosque_3d.gd") (l. 1055-1064)
  · crea Mundo3D, Terreno3D, AguaSim3D, Jugador3D (y con él, Lanzador3D, que monta libro y HUD)
Niveles.ESCENAS (nucleo/niveles.gd:19): nombre → Prueba*.tscn, para viajar entre niveles
```

La maqueta decide qué reglas monta a partir de una cadena **y** también hay un nodo `Reglas` en la escena. Hay dos caminos para lo
mismo (`reglas`/`REGLAS_BOSQUE` frente al hijo de la escena).

### 5.2 «Añadir X» = tocar N archivos (medido buscando un caso real)

| Añadir… | Caso medido | Archivos (tablas) que hay que tocar | N |
|---|---|---|---|
| **una pieza de decorado** | `cueva_pared` | `arte/meshy/*.glb` + `arte/piezas/<id>.tscn` (lo genera `generador_piezas`) · `mundo/pieza_3d.gd` (`MEDIDA`, `MEDIDA_ANCHO`, `PLANAS`, `GIRO_MODELO`, `SUSTITUTAS`, `BIBLIOTECAS`) · `herramientas/generador_piezas.gd` (`COLISION`, `BLOQUEA`, `REACTIVO`, `INFLAMABLE`, `ZONAS`) · `presentacion/prueba_test2.gd` (`SOMBRA_CONTACTO`, `SIN_SOMBRA`, `SOMBRA_REDUCIDA`, `VIENTO_DECORADO`; en cueva, además, `GIRO_CUEVA` y `DECOR_CUEVA` l. 3291) · `mundo/marcador_3d.gd` (`LETRAS`/`DATOS`, si lleva letra) | **4 scripts, hasta 13 tablas, 2 propietarios** |
| **un personaje** | `goblin_asesino` | `jugador/pj_3d.gd` (`MODELO_DE`, `CLIPS_DE` l. 107, `RAIZ_ANULADA` l. 121, `VEL_CLIP_PJ`, `MODELOS_EMPUJABLES` l. 1544, `MODELOS_ATAQUE_DOBLE` l. 1884, `MOMENTOS_CORTE` l. 1887) · `jugador/clips_familia.gd:74` · `jugador/equipo_3d.gd:83` · `enemigos/combate_3d.gd` (velocidades l. 84, `_personaje` l. 359, `begins_with` l. 393) · `presentacion/prueba_test2.gd` (`PJ_ASESINO` l. 82, `ALTO_PJ` l. 84) · `mundo/marcador_3d.gd` (`PJ_DE_LETRA` l. 232, que lee las `PJ_*` de la maqueta **por reflexión**, l. 238) · labs: `lab_humanoide_3d.gd:31`, `catalogo_assets.gd:20` | **6 scripts de juego + 2 labs, unas 13 tablas** |
| **un glifo** | `raido` | `nucleo/sigils.gd` (`GLYPHS` PNG, `NOMBRE_VISIBLE`, `GLIFOS`, `GLIFOS_V2` en desuso) · `nucleo/gesture_library.gd` (3) + `gesture_library.tres` (muestras) · `nucleo/hechizo.gd:150` · `nucleo/tinta.gd:99` · `presentacion/ui/ejes_receta_ui.gd:30,96` · `art/ui/glyphs/<id>.png` | **5 scripts + 1 `.tres` + 1 PNG**. Es el mejor caso: «un glifo nuevo es solo datos aquí» (`sigils.gd`), casi |
| **un elemento** | `viento` | `nucleo/runes.gd` (enum, **siempre al final**, porque los `.tres` guardan el número) · `nucleo/<x>_rune.tres` · `presentacion/vfx_elementos/<x>.gd` · y unas 35 menciones de `"viento"` en código de juego: `vfx_3d` ×14, `vfx_elemento_3d` ×6, `hierba_3d` ×4, `lanzador_3d` ×4, `vfx_estado_3d` ×4, `materia`, `gesture_library`, `nido_3d`, `colmena_3d`, `combate_3d`, `prueba_test2` (`COLOR_ELEMENTO`), `sfx`, `repertoire`, `datos_test2`… | **15–35 archivos** (no todos obligatorios: hay que leerlos para saberlo) |
| **un nivel** | `Bosque_01_v01` | `mundo/datos_nivel/mapas/<X>.txt` · `Nivel_<X>.tscn` (horneado y editado por Pablo) · `escenas/Prueba<X>.tscn` (**copia a mano** de la raíz con ~10 `@export`) · `escenas/<x>_3d.gd` (reglas, opcional) · `nucleo/niveles.gd:19` (`ESCENAS`) · si hay zona nueva, `LuzZona3D.ZONAS`; si hay misión, `nucleo/misiones.gd` · `herramientas/escenario_<x>.gd` | **5 (3 sin reglas)** |

### 5.3 Propuesta: una cosa = una carpeta o un `.tres`

El patrón ya está probado en el proyecto: `*_rune.tres` (elementos), `suelo_tipos.tres` y `Hechizo` (03). Se extiende así:

| Cosa | Recurso propuesto | Qué absorbe | Quién lo lee | Resultado |
|---|---|---|---|---|
| Pieza | `arte/piezas/<id>.tres` (`PiezaDef`: medida, ancho, plana, giro, colisión, bloquea, reactivo, inflamable, sombra, viento, letra) junto al `<id>.tscn` | las 13 tablas de 4 scripts | `generador_piezas` (escribe el `.tscn` a partir del `.tres`), `Pieza3D.def(id)`, decorado de la maqueta, `Marcador3D` | **1 archivo** (más el `.glb`) |
| Personaje | `personajes/datos/<id>.tres` (`PersonajeDef`: glb, alto, familia de clips, sinónimos, raíz anulada, velocidades, equipo, roles, empujable, golpes) | tablas de `pj_3d`, `clips_familia`, `equipo_3d`, `combate_3d`, `PJ_*`/`ALTO_PJ` de la maqueta | `Pj3D.def(id)`; `Marcador3D` deja de leer la maqueta por reflexión | **1** |
| Glifo | `nucleo/hechizo/glifos/<id>.tres` (`GlifoDef`: modificadores, PNG, nombre visible, repertorio, cooldown, tinta) | las 4 entradas de `sigils.gd`, `hechizo.gd:150`, `tinta.gd:99`, `ejes_receta_ui` | `Sigils.GLIFOS` se rellena al arrancar desde la carpeta | **1 + muestras** (las muestras del gesto siguen en `gesture_library.tres`: es inevitable) |
| Nivel | carpeta `niveles/<X>/`: `mapa.txt`, `nivel.tscn` (horneado), `reglas.gd` (opcional), `nivel.tres` (`NivelDef`: kit, zona_luz, agua_fisica, arqueros, misión…) | la escena raíz copiada, `Niveles.ESCENAS`, el `@export nivel` | **una** escena raíz `escenas/Juego.tscn` que carga `niveles/<X>/`; `Niveles` descubre las carpetas | **1 carpeta** |
| Elemento | `nucleo/hechizo/elementos/<x>.tres` (ya existe, ampliado con color, sonido, VFX y propiedades EoW de 02) | `COLOR_ELEMENTO`, ramas `if elemento == "viento"` | VFX y reacciones por tabla | baja de 15–35 a unos 3 archivos (`.tres`, `vfx_elementos/<x>.gd`, y el enum mientras exista) |

Orden: **personaje** primero (es el más repartido, lo usan los dos contextos y tiene una prueba natural en
`LabHumanoide3D`), luego **pieza** (le toca al Pipeline por `generador_piezas`) y **nivel** con M5. Los glifos ya casi están.

---

## 6. Pruebas

### 6.1 Qué hay

| Tipo (prefijo) | N | Base | Cómo corre | Tiempo aproximado |
|---|---|---|---|---|
| `prueba_*` **puras** (no cargan escena ni maqueta) | 115 | `extends SceneTree` suelto | `--headless --script` | 2–8 s cada una, arranque incluido (logs de Godot del 30/10: cuatro pruebas entre 22:01:10 y 22:01:23) |
| `prueba_*` con escena | 48 | 34 sobre `escenario_base.gd` u otra prueba, 14 montan la maqueta a mano | 66 piden `--fixed-fps 30` en cabecera | 20–60 s |
| `escenario_*` | 36 | `escenario_base.gd` (30), otros escenarios (4), sueltos (2) | `--fixed-fps 30`, escena entera | 20–60 s; `escenario_puzles_agua` ~4 min (DIARIO l. 1894) |
| `captura_*` | 111 | 74 sueltas, 30 sobre `escenario_base`, 7 sobre pruebas o escenarios | no entran en la batería | — |
| `medir_`/`medidas_`/`diag_`/`banco_` | 22 | `SceneTree` | a mano | — |
| arte (`generar_`, `hornear_`, `rig/`…) | 12 | `SceneTree`/editor | a mano | — |

`tools/pruebas.cmd` → `resumen_prueba.ps1` lanza **en serie** `prueba_*` + `escenario_*` (199), con un tope de 1 800 s por
prueba, y saca una tabla. **No hay ningún archivo de resultados con el tiempo total** (ni `pruebas_resultado.txt` ni
`salida*.txt` en el worktree ni en `C:\Users\pablo\Documents\magic-symbols`). Estimación: 115 × ~4 s + 48 × ~30 s + 36 ×
~40 s ≈ **8 + 24 + 24 min, unos 40–50 min**. Hay que medirlo (paso 6). Ya existe un subconjunto: `pruebas.cmd solo hechizos`
(18 pruebas, `$suiteHechizos`).

### 6.2 Propuesta

1. **Carpetas por tipo** (§4.2): `pruebas/unidad/`, `pruebas/escena/`, `pruebas/base/`, `capturas/`, `herramientas/medidas/`.
   El tipo se ve en la carpeta y deja de depender del prefijo.
2. **Base común** (01 §3.2 ya la diseñó: `base_prueba.gd`, `base_captura.gd`, y `escenario_base` heredando de
   `base_prueba`). Lo que añade este análisis: `base_prueba.gd` imprime al final `TIEMPO <nombre>: N ms`, para que
   `resumen_prueba.ps1` sume y guarde `pruebas/ultimo_resultado.txt` con fecha, máquina, total, fallos y tiempos (hoy no queda
   nada escrito).
3. **Batería corta (< 2 min):** las 115 de `pruebas/unidad/`, **6 a la vez** (`Start-Process` en paralelo en
   `resumen_prueba.ps1`: 115 × 4 s / 6 ≈ 80 s). Es la que se lanza antes de cada entrega. A medida que se parta la maqueta,
   más pruebas pasan de escena a unidad: `gramatica_puzle`, `cargador_nivel` y `Terreno3D` sin maqueta.
4. **Batería larga:** `pruebas/escena/`, en serie y a 30 fps fijos (lo exigen los tiempos), de noche o antes de
   fusionar. Con `ultimo_resultado.txt` se ve qué escenario se ha vuelto lento.
5. **Prueba de capas** (`pruebas/unidad/prueba_capas.gd` o, mejor, en `tools/grafo.py`, porque no necesita Godot): falla si
   las aristas hacia arriba pasan de la cifra de referencia (674) o si aparece un ciclo nuevo entre carpetas.

---

## 7. Convenciones

### 7.1 Lo que se cumple (y hay que conservar)

| Convención | Medida (juego + labs, sin `herramientas/`) |
|---|---|
| Funciones con tipo de vuelta (`->`) | **5 032 de 5 061 (99,4 %)**. Las 29 que faltan están en `presentacion/` (17), `ui/` (4), `nucleo/` (3), `magia/` (3) y `objetos/` (2) |
| Variables con tipo | 15 367 de 15 371: 84 % con `: T` explícito, 16 % con `:=`, **4 sin tipo** |
| `static` donde no hay estado | 1 325 `static func` (el 26 %), sobre todo en `nucleo/` (323), `presentacion/` (302), `magia/` (148) y `mundo/` (147) |
| Comentarios que cuentan el porqué (fecha, quién, el fallo) | 10–15 % de líneas en los dioses y 29 % en `spellbook` |

### 7.2 Lo que falla

| Problema | Medida | Propuesta |
|---|---|---|
| **`print` sueltos** en código de juego | **81**: `magia/` 46 (casi todos en `spellcaster.gd` 26 y `grimorio.gd` 20), `presentacion/` 21, `ui/` 6, `laboratorios/` 5, `nucleo/` 2, `mundo/` 1. En `herramientas/` hay 948, que es lo esperable | centralizar en `PlayLog.d(canal, texto)`, con canales que se apagan (el plan ya lo pide). Se borran los de `spellcaster.gd` con el archivo (01 §3.1) |
| `push_warning` | 66 en juego (sin labs): `nucleo/partida.gd` 5, `pj_3d.gd` 5, `misiones.gd` 4, `bosque_01_v01_3d.gd` 4, `repertoire`/`flags`/`hornear_nivel`/`puzle` 3 cada uno… No se pudo arrancar Godot para ver cuáles salen al iniciar (los 5 logs que guarda `app_userdata/Magic_Symbols/logs` son de pruebas y no traen avisos) | lo normal en el arranque deberían ser **0 avisos**. Uno real de hoy: `pj_3d.gd:289` todavía cita `poc_25d\COPIAR_MODELOS.cmd`, una carpeta que ya no existe |
| **Señales poco usadas** | 175 `signal` declaradas y 291 `.emit`, frente a 963 `get/call/set("_x")` en todo el repo (240 en juego, y eran 230 el 24/10: **siguen subiendo**) y 156 `has_method("…")` | trinquete también para `get("_`: no se acepta ninguno nuevo entre contextos (ARQUITECTURA_MODULAR §5.2) |
| **Constante de casilla repetida** | `const S/CASILLA/LADO = 2.3` copiada en **13 archivos de juego** (4 de ellos labs: `prueba_test2:18`, `pieza_3d:30`, `objetos_3d:68`, `canal_3d:22`, `hornear_nivel:22`, `puente_reactivo_3d:26`, `limo_visual_3d:28`, `prueba_titan:9`, `prueba_limo:9`…) y en 77 de herramientas. Además, **65 literales `2.3` sueltos** en juego (`prueba_test2` 12, `marcador_3d` 5, `terreno_3d` 5, `hierba_3d` 4…). Junto a eso ya hay 178 usos de la constante central (`Terreno3D.S`/`casilla`, `Lanzador3D.S`): la mitad del camino está hecha | `nucleo/medidas.gd`: `const CASILLA := 2.3`, `ALTO_NIVEL := CASILLA * 0.45` (hay `const ALTO` en 44 archivos, casi todos pruebas y la mayoría `2.3 * 0.45`), `ALTURA_MANO_U := 0.9` (`hechizo.gd:83`, repetido a mano en `vfx_3d.gd:569,576`, `vfx_elementos/tierra.gd:90` y 3 pruebas). `Terreno3D.casilla` reenvía a la constante |
| Constantes de capa física en el lanzador | `Lanzador3D.CAPA_REACTIVO` ×30, `CAPA_SOLIDO` ×2 fuera del lanzador | `nucleo/capas.gd` (paso 3) |
| Grupos como API sin declarar | `"spellcaster"`, `"combate3d"`, `"bloquea"`, `"muneco"`, `"entrada_nivel"`, `"flammable3d"` (este, muerto en el juego): 59 aristas hacia arriba | `nucleo/grupos.gd` con `const` por grupo y quién lo añade; buscar por constante y no por cadena |
| Reflexión sobre constantes ajenas | `marcador_3d.gd:238-271` hace `load(...).get_script_constant_map()` sobre la maqueta, `pj_3d`, `objetos_3d` y `bosque_3d` | desaparece con `PersonajeDef` y `nucleo/medidas.gd` |
| Cabecera «Dueño» | 99 archivos de juego dicen «Juego» o «Pipeline» en sus 8 primeras líneas; 114 no dicen nada | con la propiedad por carpeta (§4.2) no hace falta; mientras tanto, la cabecera manda sobre la carpeta y PROPIETARIOS se pone al día |

---

## 8. Plan ordenado

Ningún paso cambia el comportamiento. Todos se verifican con la batería, con el grafo (`deps.py` o `grafo.py`) y con una partida
corta en el `main_scene`.

| # | Paso | Coste | Riesgo | Qué lo verifica | Quién |
|---|---|---|---|---|---|
| 1 | **Trinquete de capas.** `tools/grafo.py` gana un modo `--capas` (las reglas de `deps.py`) que imprime la matriz y falla si las aristas hacia arriba superan 674, si los `get("_` de juego superan 240 o si aparece un ciclo nuevo entre carpetas. Se apunta en `ARQUITECTURA_MODULAR.md` §5 | S | nulo | el propio guion, que entra en `pruebas.cmd` | Juego (Pablo aprueba las cifras de referencia) |
| 2 | **Mudanzas sin código** (§4.4, primeros lotes): `presentacion/juego/` (4), `interfaz/` (18) con la propiedad por subcarpeta, `audio/` (3), `formas_3d`/`vfx_calidad`/`vista_suelo_editor` a `presentacion/`; `herramientas/` → `pruebas/{unidad,escena,base}`, `capturas/`, `herramientas/{medidas,arte}` con `tools/mover.py` y los 4 guiones de `tools/`; `datos_nivel/`: copias y `.jpg` a `_a_eliminar/`. Se actualiza `PROPIETARIOS.md` | M | bajo (rutas: `tools/rutas_vivas.py`) | `rutas_vivas.py` = 0 · batería completa en `TOTAL DE FALLOS: 0` · F5 · el trinquete baja unas 70 aristas por la reclasificación | Juego (los guiones) · Pipeline (sus carpetas) · **Pablo** (PROPIETARIOS, `datos_nivel/` y el visto bueno con Godot cerrado) |
| 3 | **Terminar M1.** `nucleo/medidas.gd` (`CASILLA`, `ALTO_NIVEL`, `ALTURA_MANO_U`) y `nucleo/capas.gd` (`CAPA_*`). Los callers de los 35 reenvíos de `Lanzador3D` pasan a `Terreno3D` y se borran los reenvíos. `Terreno3D` guarda su propio `_bloqueadas`/`_lado` (los recibe al cargar) y deja de leer la maqueta | S | bajo | `grep "Lanzador3D\.(celda_de|y_pies|en_mapa|bloqueada|LECHO_AGUA|CAPA_)"` = 0 · `terreno_3d.gd` sin `mundo_s.get(` · `prueba_mundo`, `prueba_terreno`, suite `hechizos` · trinquete: `objetos→magia` baja de 46 a menos de 15 | Juego |
| 4 | **Fachada pública de la maqueta** (la mitad de M5 que desbloquea al resto): el Pipeline añade los ~20 getters de 01 §3.4 (`jugador()`, `fx()`, `enemigos()`, `pieza()`, `props()`, `camara()`…) y el Juego cambia los 255 `get("_x")` y 62 `._x` sobre la maqueta, empezando por las reglas de nivel (162 de ellos) | M | medio (un getter mal puesto cambia qué objeto se lee) | `grep 'get\("_' escenas/ objetos/ jugador/ enemigos/ magia/` sobre la maqueta = 0 · batería larga · playtest de Bosque_01_v01 | **Pipeline primero** (define), luego **Juego** (consume), en dos sesiones (PROPIETARIOS §6) |
| 5 | **Sacar la composición de la partida de la magia.** Un nodo `niveles/partida_3d.gd` (o la raíz de M5) monta jugador, lanzador, libro, HUD, menú y pantalla de muerte. `Lanzador3D` y `Jugador3D` reciben las referencias o emiten señales (`vida_cambio`, `muerte`, `pagina_cambio`), y quitan `lanzador_3d.gd:595-622` y `jugador_3d.gd:82,112` | M | medio | trinquete: `magia→ui` y `jugador→ui` = 0 · F5, abrir el libro y morir · `escenario_*` que abren el libro | Juego |
| 6 | **Baterías corta y larga** (§6.2): base común (01 §3.2) con `TIEMPO`, `resumen_prueba.ps1` en paralelo para `pruebas/unidad/` y `pruebas/ultimo_resultado.txt`. Se mide de verdad el tiempo de la larga | M | bajo | la corta tarda menos de 2 min · la larga escribe su tiempo total | Juego |
| 7 | **Sacar las clases internas y partir por familia** los dioses de menos riesgo: `lanzador_3d` (6 clases internas → archivos, luego `modo_lanzar` y `materializar`), `vfx_estado_3d` (`EfectoHechizo`), `agua_render_3d` (shaders a `.gdshader` y ajustes a `.tres`), `vfx_3d` (fachada y 4 familias) | M | bajo a medio | suite `hechizos` · `LabVfx3D` y capturas de VFX comparadas antes y después · `prueba_agua_*` | Juego (lanzador) · Pipeline (VFX y agua) |
| 8 | **Registros por datos** (§5.3): `PersonajeDef` (`.tres` por personaje, `Marcador3D` sin reflexión), después `PiezaDef` con `generador_piezas`, y `NivelDef` con la carpeta `niveles/<X>/` y una sola escena raíz | L | medio | `LabHumanoide3D` y `CatalogoAssets` muestran los mismos modelos y altos · el horneado da el mismo `Nivel_*.tscn` (comparar en disco) · todas las `Prueba*.tscn` arrancan | Juego (`PersonajeDef`, `NivelDef`) · Pipeline (`PiezaDef`) · **Pablo** (la escena raíz única y `main_scene`) |
| 9 | **M5 completo**: la maqueta en 6 archivos (§3.2), `cargador_nivel` en `mundo/`, `colocador_reactivos` en `objetos/` y el resto en `presentacion/maqueta/`. Sobre la misma base: `combate_3d` (IA y elemental), `objetos_3d` (familias), `puzle.gd` (gramática pura en `niveles/puzle/`) | L | alto (es el archivo que más se toca en paralelo) | cada `Prueba*.tscn` arranca · `vista_suelo_editor` funciona · batería larga · trinquete: el componente conexo baja de 127 archivos | Pipeline (dibujo) · Juego (cargador, reactivos, combate, puzle), con el diario para cada contrato |
| 10 | **Convenciones**: `PlayLog.d` en lugar de `print` (81), `nucleo/grupos.gd`, 0 avisos al arrancar (empezando por `pj_3d.gd:289`) y archivos nuevos sin `_3d` | S | nulo | `grep print\( ` en juego = 0 · arranque limpio en la consola de Godot | los dos, cada uno en lo suyo |

**Orden y dependencias:** 1 → 2 → 3 se pueden hacer esta semana y no necesitan coordinación de contratos. 4 abre el
camino a 5 y a 9. 6 conviene antes de 7–9, porque son los pasos que más necesitan una batería rápida. 8 puede ir en paralelo a 7.

**Qué decide Pablo:** (a) la estructura de carpetas de §4.2, sobre todo `interfaz/`, `personajes/`, `niveles/` y
`presentacion/juego/` como única excepción escrita; (b) no renombrar `_3d` ni los nombres en inglés; (c) si `main_scene` pasa a una
escena raíz única cuando exista `NivelDef`; (d) las cifras de referencia del trinquete (674 y 240) y que no puedan subir.
