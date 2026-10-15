# Propietarios — quién toca qué

El proyecto lo desarrollan **dos contextos en paralelo** (dos proyectos de
Claude, a veces en máquinas distintas): el de **Juego** (jugabilidad, runas,
niveles, mundo) y el de **Pipeline** (arte, modelos, dibujo del mundo, VFX,
HUD). Este archivo dice qué carpetas posee cada uno y dónde se encuentran.

> **Regla de oro: un archivo tiene UN propietario.** Si una tarea pide tocar
> un archivo que no es tuyo, **no lo edites**: para, di qué cambio hace falta
> y en qué archivo, y Pablo se lo pasa al otro contexto o lo hace él.

Esto existe porque ya pasó, dos veces: un contexto reescribió
`test_jugabilidad.gd` entero desde una copia vieja (5/10), y el 13/10 una
herramienta de escritura puso en disco una copia de `prueba_test2.gd` de dos
días antes (17 KB menos) sin que nadie lo pidiera. Por eso la sección 5 pide
**verificar en disco** después de escribir.

**Desde el 13/10 el repo está ordenado por capas** (`docs/ARQUITECTURA_MODULAR.md`
§2) y `poc_25d/` ya no existe. La propiedad va **por carpeta**, con las
excepciones que se indican.

---

## 1. Juego (proyecto "Magic_Runes")

**Posee**

| Carpeta | Qué hay |
|---|---|
| `nucleo/` | datos puros sin nodo: `runes.gd`, `rune_data.gd`, `sigils.gd`, `spell_recipe.gd`, `estado.gd`, `objetos.gd`, `repertoire.gd`, `playlog.gd`, `playlog_3d.gd`, gestos (`gesture_*`), `*_rune.tres` (**`sfx.gd` y `sonidos.gd` son del Pipeline**, ver sección 2) |
| `magia/` | `lanzador_3d.gd` (Lanzador3D, GeometriaHechizo, Receta3D), `spellcaster.gd` (base 2D hasta M4), `formas_3d.gd` |
| `mundo/` | `terreno_3d.gd`, `mundo_3d.gd`, `estados_suelo_3d.gd`, `agua_sim_3d.gd`, `hornear_nivel.gd`, `marcador_3d.gd`, `pieza_3d.gd`, `vista_suelo_editor.gd`, `datos_nivel/datos_test2.gd` |
| `objetos/` | `objetos_3d.gd` (Reactivo3D), `surtidor_3d.gd`, `emisor_rayo_3d.gd`, `puente_reactivo_3d.gd`, `enredadera_3d.gd`, `flotador_3d.gd` |
| `enemigos/` | `combate_3d.gd` e IA |
| `jugador/` | `jugador_3d.gd`, `pj_3d.gd`, `equipo_3d.gd`, `proporcion_chibi.gd` |
| `escenas/` | reglas por nivel (`bosque_3d.gd`, `jugabilidad_3d.gd`, `nivel_pruebas.gd`) y las escenas `Prueba*.tscn` que se juegan |
| `herramientas/` | las pruebas sin ventana `prueba_*.gd` (**`generador_piezas*.gd` es del Pipeline**) |
| `presentacion/ui/` (solo estos cuatro) | `spellbook.gd`, `page_hud.gd`, `rune_palette.gd`, `bolsa_ui.gd`: son lógica del grimorio y la mochila, viven con la UI pero las escribe el Juego |
| `laboratorios/` (parte) | `lab_agua_3d.gd`, `LabAgua3D.tscn` |
| `tools/` (parte) | `podar_gestos.py`, `grafo.py`, `pruebas.cmd`, `limpieza_mover.ps1`, `reorganizar.ps1` |
| `docs/` (parte) | `NUEVOS_SISTEMAS.md`, `TEST2_CONCLUSIONES.md`, `QA_ARTE.md`, `ESTADOS_SUELO.md`, `LIMPIEZA.md`, `ARQUITECTURA_MODULAR.md`, `ENCARGOS_LIMPIEZA.md` |

**No toca**: nada de la sección 2. Si necesita un dato de la maqueta, lo pide
como método de la fachada (`Mundo3D` / `Terreno3D`) en el diario; **nunca**
`get("_algo")` ni `call("_algo")` sobre nodos del Pipeline.

---

## 2. Pipeline (proyecto "pipeline sprite isométricos")

**Posee**

| Carpeta | Qué hay |
|---|---|
| `presentacion/` | la maqueta (`prueba_test2.gd`), `vfx_3d.gd`, `vfx_kit_3d.gd`, `vfx_elementos/`, `vfx/`, el dibujo del agua (`agua_render_3d.gd`, `agua_ondas_3d.gd`, `agua_metaballs_3d.gd`, `costra_hielo_3d.gd`, `canal_3d.gd`), `hierba_3d.gd`, `ocluso_3d.gd`, `hilo_luz_3d.gd`, `grimorio/`, `ui/laminas/` (**salvo los cuatro `.gd` de `ui/` listados en la sección 1**) |
| `arte/` | `modelos/` (los `.glb` y texturas), `piezas/`, `meshy/`, `suelo_meshy/`, `equipo/`, `COPIAR_MODELOS.cmd` |
| **Audio, entero** (14/10, Pablo): `audio/` (los sonidos y su `LICENCIAS.md`), `nucleo/sfx.gd` y `nucleo/sonidos.gd` (qué suena, cuándo y cómo: posicional en 3D) | sonidos y música. El Juego solo **llama** a `Sfx.play` / `Sonidos.play` con un nombre; si falta un sonido, lo pide por el diario |
| `art/ui/`, `art/fx/` | iconos del grimorio y de elemento |
| `laboratorios/` (parte) | `lab_vfx_3d.gd`, `lab_gato_3d.gd`, `lab_grandmaster_3d.gd`, `lab_humanoide_3d.gd`, sus `.tscn`, `catalogo_assets.gd`, `CatalogoAssets.tscn` |
| `herramientas/` (parte) | `generador_piezas.gd`, `generar_piezas_cli.gd`, `generar_piezas_editor.gd` |
| `mundo/datos_nivel/suelo_tipos.tres` | la paleta del GridMap |
| `docs/` (parte) | `ARTE.md`, `ANIMACION.md`, `PERSONAJE.md`, `ASSETS_PENDIENTES.md`, `maqueta_3d/LEEME.md`, `docs/*.png` (referencias) |

**No toca**: ningún archivo de la sección 1. En particular, la maqueta **no
llama a estáticos nuevos de `Lanzador3D`** ni expone campos privados para el
Juego: lo que el Juego necesite se pide por el diario y se pone en la fachada.

---

## 3. Archivos de Pablo (nadie los edita sin que lo pida)

| Archivo | Por qué |
|---|---|
| `project.godot`, `.gitignore`, `.gitattributes`, los `.cmd` de la raíz | Configuración de todo el proyecto |
| `README.md`, `ARQUITECTURA.md`, `docs/CONTEXTO.md`, `docs/DISENO_FUTURO.md`, `docs/PLAN_ARREGLOS.md`, `docs/Estructura del codigo/`, este archivo | Son la fuente de verdad para los dos contextos |
| `mundo/datos_nivel/` (los `Nivel_*.tscn` horneados, `mapas/*.txt`, `luz_juego.tscn`) | Los niveles los edita Pablo en Godot; el Juego solo `datos_test2.gd`, el Pipeline solo `suelo_tipos.tres` |
| `.godot/`, `*.import`, `*.uid` | Los genera Godot; se tocan abriendo el editor, no a mano |
| `_a_eliminar/` | Lo que está pendiente de borrar; nadie lee ni escribe ahí |

Si un contexto cree que uno de estos debe cambiar (p. ej. `main_scene`),
**lo propone** con el cambio exacto y Pablo lo aplica.

---

## 4. La frontera: contratos, no ganchos

Los dos contextos solo se encuentran a través de **contratos escritos**, nunca
editando el mismo archivo. Los vigentes:

| Contrato | Lo escribe | Lo lee | Dónde |
|---|---|---|---|
| Objetos reactivos: `on_spell_hit(rune, dir)`, `spell_reacts(rune)`, `carried_element()`, `nivel_altura()`, `punto_activacion()` | Juego (`Reactivo3D`) | Pipeline (maqueta, al colocar piezas) | `objetos/objetos_3d.gd` cabecera; diario 6/10 y 12/10 |
| Consultas de mundo: `Terreno3D.*` (`celda_de`, `y_pies`, `es_agua`, `bloquear_celda`…), `Mundo3D` (`terreno`, `agua`, `estados`, señales `casilla_cambio`, `impacto`) | Juego | Pipeline | `docs/ARQUITECTURA_MODULAR.md` §3; diario 13/10 |
| Agua: `AguaSim3D.textura()` (RGBAF: R superficie, G profundidad, B/A corriente), `textura_hielo()`, `textura_mojado()`, `imagen_hielo()` | Juego | Pipeline (`AguaRender3D`) | `mundo/agua_sim_3d.gd` cabecera |
| Maqueta → Juego: `poner_agua`, `marcar_estado`, `chorro_agua`, `salpicadura_agua`, `hielo_desde`, `kit`, `agua_fisica`, `_es_canal`/`_abre_hacia` (hasta M2) | Pipeline | Juego | `docs/maqueta_3d/LEEME.md`; diario 10–13/10 |
| Marcadores de nivel (letras y `Marcador3D`) | Pipeline define, Pablo coloca | Juego | `mundo/marcador_3d.gd` |
| Colores de elemento | Pipeline | Juego | `docs/ARTE.md` §1 |
| Nombres de sonido (`Sfx.play(nodo, "golpe")`, `Sonidos.play(nodo, "bolsa", …)`): la lista de nombres vigentes y su archivo | Pipeline | Juego | cabecera de `nucleo/sfx.gd` y `nucleo/sonidos.gd` |

**Cambiar un contrato es un cambio de los dos lados**: quien lo necesite lo
propone en el diario, Pablo lo aprueba, y cada contexto adapta lo suyo.
Las firmas **no cambian sin entrada en el diario**.

---

## 5. Reglas de edición (para los dos)

1. **Leer del disco antes de editar.** El archivo puede haber cambiado desde
   la última vez que lo viste (otro contexto, otra máquina, Godot).
2. **Cambios parciales, nunca reescribir el archivo entero** desde una copia
   que tengas en memoria o en la conversación.
3. **Verificar después de escribir.** Cada escritura usa un **nombre de
   archivo preparado nuevo** (reutilizar uno anterior ha subido copias viejas
   dos veces) y, tras escribir, se **vuelve a leer del disco** y se comprueba
   tamaño y contenido antes de darlo por hecho.
4. **Comprobar la ruta antes de escribir.** El repo vive en
   `C:\Users\pablo\Documents\magic-symbols` (desktop) y en
   `C:\Users\paranda\Documents\magic-symbols` (botiquinmadrid-pc). Si la
   carpeta conectada es otra, decirlo y no escribir. Si el repo no está al
   día (`git pull`), avisar.
5. **No commitear ni hacer push.** Lo hace Pablo.
6. **Godot cerrado cuando un script mueva o renombre archivos.** El editor
   guarda lo que recuerda de sus pestañas y pisa lo movido (13/10:
   `PruebaJugabilidad3D.tscn` acabó con el contenido de `LabVfx3D`).
7. **Diario.** Al terminar una sesión que haya tocado un contrato o algo que
   el otro contexto necesite saber, añadir una entrada **al final** de
   `docs/DIARIO.md`, leído del disco en ese momento, sin reescribir lo que
   hay. Al empezar una sesión, leer las últimas entradas.
8. **Cada módulo nuevo nace con su prueba** en `herramientas/prueba_<modulo>.gd`
   y se comprueba con `tools\pruebas.cmd` en `TOTAL DE FALLOS: 0`.

---

## 6. Qué hacer cuando no está claro

- Un archivo que no aparece en ninguna carpeta de arriba → **preguntar**.
- Un archivo de **código o escena** nuevo → va en la carpeta de su capa y lo
  posee el dueño de esa carpeta; si es de la otra capa, se pide.
- Un **documento** nuevo en `docs/` → **no se crea sin proponerlo** (ver 7).
- Una tarea que de verdad necesita tocar los dos lados → se parte en dos
  (primero quien define el contrato, luego quien lo consume). Nunca una sola
  sesión haciendo las dos cosas.

---

## 7. Documentos: uno de cada, no uno por sesión

**Los documentos vivos son estos, y solo estos:**

| documento | para qué | dueño |
|---|---|---|
| `ARQUITECTURA.md` | lo que el código hace hoy | Pablo |
| `docs/ARQUITECTURA_MODULAR.md` | capas, contratos y plan M1–M5 | Juego escribe, Pipeline lee |
| `docs/DISENO_FUTURO.md` | lo que se quiere, con prioridad P0–P3 | Pablo |
| `docs/PLAN_ARREGLOS.md` | **el único plan**: tareas, responsable, casilla | Pablo |
| `docs/LIMPIEZA.md`, `docs/ENCARGOS_LIMPIEZA.md` | catálogo y encargos de la limpieza del 13/10 (se integran en el plan y se retiran cuando acabe) | Juego |
| `docs/DIARIO.md` | lo que un contexto le dice al otro | los dos escriben |
| `docs/CONTEXTO.md`, `docs/Estructura del codigo/`, este archivo | reglas y diseño | Pablo |
| `docs/NUEVOS_SISTEMAS.md`, `docs/TEST2_CONCLUSIONES.md`, `docs/QA_ARTE.md` | referencia del Juego | Juego |
| `docs/ASSETS_PENDIENTES.md`, `docs/ARTE.md` | referencia del Pipeline | Pipeline |
| `docs/ESTADOS_SUELO.md` | contrato de reglas del suelo | Juego escribe, Pipeline lee |
| `docs/maqueta_3d/LEEME.md` | estado de la maqueta 3D y reparto para M5 | Pipeline |
| `docs/Playtests/` | un archivo por sesión de juego, solo conclusiones | Pablo |

**Regla.** Un contexto **no crea** un documento nuevo en `docs/`. Si cree que
hace falta, lo propone en el diario y lo crea Pablo o quien él diga. Los
documentos que no están en la tabla son **borradores** pendientes de
integrar y borrar.

**Firmas del diario.** Solo hay dos contextos: `Juego` y `Pipeline`.
