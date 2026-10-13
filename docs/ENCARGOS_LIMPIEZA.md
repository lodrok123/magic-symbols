# Encargos de la limpieza de primavera (13/10/2026)

Tres destinatarios. Cada bloque se pega tal cual en su chat. Referencias: `docs/LIMPIEZA.md` y
`docs/ARQUITECTURA_MODULAR.md` (Pablo los deja en `docs/` antes de nada; también están en el proyecto de Claude).

---

## Pablo (orden exacto)

1. En el desktop, con el repo al día: `git pull` y `git status` limpio.
2. Los documentos ya están en `docs/` y el script en `tools/` (los puso el Juego el 13/10). Añadir a `PROPIETARIOS.md`:
   `docs/LIMPIEZA.md` y `docs/ARQUITECTURA_MODULAR.md` → Juego escribe, Pipeline lee; `tools/limpieza_mover.ps1` → Juego.
   Y, de paso, lo pendiente desde el 12/10: los archivos del agua (`agua_*.gd`, `flotador_3d.gd`, `costra_hielo_3d.gd`,
   `surtidor_3d.gd`, `canal_3d.gd`…) con su propietario.
3. `powershell -ExecutionPolicy Bypass -File tools\limpieza_mover.ps1 -Fase 1 -Simular` → leer la lista. Si las tres
   escenas comentadas del Bosque (`PruebaJugabilidadBosque.tscn`, `PruebaNivelBosque.tscn`, `_1`) y `niveles/jugabilidad.tscn`,
   `niveles/test2.tscn` tampoco se usan, quitar el `#` de esas líneas. Volver a ejecutar sin `-Simular`.
4. `project.godot`: `run/main_scene="res://poc_25d/PruebaBosque.tscn"` (hoy apunta a `Mundo.tscn`, que se acaba de mover).
5. Abrir Godot; si avisa de uid duplicados, cerrar y borrar `.godot/`. Arrancar `PruebaBosque.tscn`. Ejecutar las pruebas
   sin ventana (`godot --headless --path . --script res://poc_25d/herramientas/prueba_agua_sim.gd`, y las demás `prueba_*.gd`).
6. Commit «limpieza L1». (La entrada del diario ya está pegada; abajo queda como referencia.)
7. Dar los encargos al Juego (L2.1, L2.2, M1) y al Pipeline. Cuando el Juego termine L2: `-Fase 2`. Cuando el Pipeline
   confirme: `-Fase 3`.
8. Leer `ARQUITECTURA_MODULAR.md` §6 y contestar las cuatro decisiones (nombres, unidades de `AccionElemental`,
   nodo o RefCounted, orden M3/M4) antes de que el Juego empiece M2.

**Entrada para el diario (pegar al final de `docs/DIARIO.md`):**

```
## 13/10 — Juego (con Pablo): limpieza de primavera, catálogo y arquitectura modular
Medido sobre el grafo de dependencias de todo el código (`tools/grafo.py`, adjunto en `docs/`): de los 104 archivos de código 2D de la raíz, 26 no los carga ninguna escena, 41 viven solo porque `prueba_test2.gd` hace `preload("res://test_2.gd")` (que `extends nivel_base.gd`), 37 los usa el 3D y de esos 11 están arrastrados por referencias de nombre (`SpellFactory` en `spell_recipe.gd`, `Botin`/`BlockFx`/`Sonidos` en `combate_comun.gd`). Catálogo completo y estructura objetivo: `docs/LIMPIEZA.md`. Los movimientos los hace `tools/limpieza_mover.ps1` (git mv a `_a_eliminar/` con `.gdignore`), por fases; Pablo ejecuta la 1 hoy.
**Diagnóstico de la modularidad** (`docs/ARQUITECTURA_MODULAR.md`): `Lanzador3D` tiene 61 estáticos y siete archivos consultan el mundo a través de él (`celda_de`, `y_pies`, `es_agua`, `pisable`, `agua_sim`…): por eso el agua (34 referencias a `agua_sim` en `lanzador_3d.gd`) obligó a tocar los hechizos. El Juego entra en la maqueta por 25 campos privados (`_helada` ×8, `_fx` ×7, `_lado` ×6…). Hay tres fuentes de verdad para «hay agua» (letra `~`, `AguaSim3D`, `Canal3D`). Plan en cinco pasos estranguladores: M1 `Terreno3D` (mover los estáticos de mundo fuera del Lanzador con reenvíos), M2 `Mundo3D` con `casilla_cambio`/`impacto`, M3 `AccionElemental` (el mundo recibe acciones, no hechizos), M4 cortar la herencia del 2D (`spellcaster.gd`, `combate_comun.gd`), M5 partir la maqueta en cargador + dibujo.
**Contrato nuevo (desde M1):** las consultas de mundo se hacen a `Mundo3D.terreno` / `Mundo3D.agua`; `Lanzador3D.xxx` queda como reenvío marcado `## REENVÍO M1` hasta que nadie lo llame. Pipeline: no usar `Lanzador3D.` nuevo en la maqueta; lo que necesite del mundo, pedirlo a la fachada.
**Pendiente:** Pablo decide §6 del documento; Pipeline decide `art/` (menos `ui/`), `Sprites/`, `pipeline/`, `Render Studio/`, `tests/`, `tools/gen_*.py`, `actor_animator`/`ms_*` (Fase 3 del script). — Juego
```

---

## Juego — L2.1, L2.2 y M1 (pegar)

```
Lee docs/PROPIETARIOS.md, docs/LIMPIEZA.md, docs/ARQUITECTURA_MODULAR.md y las últimas entradas de docs/DIARIO.md. Tres tareas, en este orden, cada una con sus pruebas en FALLOS 0 antes de pasar a la siguiente. Cambios parciales, leer del disco antes de editar, sin commit.

L2.1 — Cortar test_2.gd. Crea poc_25d/niveles/datos_test2.gd (class_name DatosTest2, extends RefCounted) con las cinco constantes que prueba_test2.gd lee de TEST2: MAPA_TEST2, GUARDADOS_T2, SUELO_T2, ROTULOS, COLOR_PRUEBA (cópialas de test_2.gd tal cual). No edites prueba_test2.gd (es del Pipeline): dile en el diario que cambie `const TEST2 = preload("res://test_2.gd")` por `preload("res://poc_25d/niveles/datos_test2.gd")` (prerender_test2d.gd ya está en _a_eliminar). Comprueba en headless que DatosTest2.MAPA_TEST2 tiene 40 filas de 40.

L2.2 — Cortar los arrastrados. (a) spell_recipe.gd: quitar la función que llama a SpellFactory.cast (l. 421): es el lanzamiento 2D; Lanzador3D no pasa por ahí. Comprueba con grep que nada del 3D la llama. (b) rune_data.gd l. 61: el comentario que cita SpellBeam. (c) combate_3d.gd: copiar la tabla de debilidades/efectos que usa de CombateComun (l. 252 en adelante: multiplicador, efectos) a una clase sin nodo TablaCombate (poc_25d/tabla_combate.gd) y dejar de heredar de CombateComun. (d) sfx.gd: comentarios que citan Glow y BlockFx. Al acabar: grep -l "SpellFactory\|SpellBeam\|BlockFx\|Botin\b\|Glow\b\|IsoGrid" sobre los archivos que el 3D usa debe dar vacío (sonidos.gd se queda: lo usa bolsa_ui). Avisa a Pablo: ya puede ejecutar limpieza_mover.ps1 -Fase 2.

M1 — Terreno3D. Crea poc_25d/terreno_3d.gd (class_name Terreno3D, extends RefCounted; sin nodos). Mueve ahí, función por función y sin cambiar su cuerpo, los estáticos de mundo de lanzador_3d.gd (l. 226–720: bloqueada, bloquear_celda, liberar_celda, celda_de, centro_de, en_mapa, letra_de, es_agua, es_cauce_seco, altura_en, fijar_altura, y_pies, celda_solida, calcular_huellas, es_parcial, choca_huella, pisable, linea_libre, y las constantes casilla, alto_suelo, alto_agua, ALTO_NIVEL, LECHO_AGUA) y montar_agua_sim con la variable agua_sim. En Lanzador3D deja cada una como reenvío de una línea con el comentario `## REENVÍO M1` para que nada se rompa hoy. Después cambia jugador_3d.gd, combate_3d.gd, surtidor_3d.gd, emisor_rayo_3d.gd, flotador_3d.gd y playlog_3d.gd para que llamen a Terreno3D (o a Mundo3D.terreno si ya existe) y no a Lanzador3D. Medida de salida: grep -c "Lanzador3D\." en esos seis archivos = 0 (excepto lo que sea magia de verdad: configurar, aplicar_progresion, ultimo_impacto). prueba_terreno.gd nueva en herramientas: celda_de/centro_de ida y vuelta, y_pies con y sin hielo, pisable con niveles. Todas las pruebas del agua en FALLOS 0.

Al terminar cada tarea, añade tu entrada AL FINAL de docs/DIARIO.md leído del disco en ese momento, sin reescribir lo que hay. Lo que necesite el Pipeline (el preload de L2.1; que la maqueta deje de llamar a Lanzador3D.agua_sim y use Terreno3D.agua_sim), dilo ahí con el cambio exacto.
```

---

## Pipeline (pegar)

```
Lee docs/PROPIETARIOS.md, docs/LIMPIEZA.md (§2.E y §2.D son tuyos), docs/ARQUITECTURA_MODULAR.md (§2 y §3.4: tu capa es presentacion/) y las últimas entradas de docs/DIARIO.md. Cambios parciales, leer del disco antes de editar, sin commit.

1. Decide §2.E de LIMPIEZA.md: art/ (menos art/ui/, que usan sigils.gd y spellbook.gd), Sprites/, pipeline/, export_godot/, Render Studio/ (21,6 MB), tests/, tools/gen_*.py, video_a_fila.py, y actor_animator.gd / ms_actor.gd / ms_atlas.gd (el 3D solo los cita en comentarios). Lo que sobre va a _a_eliminar/2d_pipeline_sprites/ y _a_eliminar/2d_arte/ con tools/limpieza_mover.ps1 -Fase 3 (añade o quita líneas en esa fase); si prefieres conservar el pipeline de sprites, propón un repo aparte. Confirma también si PruebaJugabilidadBosque.tscn, PruebaNivelBosque.tscn y niveles/jugabilidad.tscn / test2.tscn te sirven aún para algo.
2. Cuando el Juego cierre L2.1: en prueba_test2.gd cambia `const TEST2 = preload("res://test_2.gd")` por `preload("res://poc_25d/niveles/datos_test2.gd")`. Nada más cambia.
3. Prepara M5 sin ejecutarlo aún: en poc_25d/LEEME.md, lista las funciones de prueba_test2.gd (183 KB, 151 funciones) en tres grupos: (a) leer el nivel (letras, marcadores, Nivel_<X>.tscn, giros, desvíos) → irá a un cargador del mundo; (b) dibujar (suelo, lotes, hierba, agua, luz, cámara, vitrina) → se queda en la maqueta; (c) estado del mundo que hoy guardas tú (_helada, _bloqueadas, _mapa, _img_estado, marcar_estado, _es_canal, _poner_canal) → pasará a Mundo3D del Juego en M2. Es la lista con la que se reparte el archivo.
4. Regla desde hoy (ARQUITECTURA_MODULAR §5.2): nada nuevo en la maqueta que llame a Lanzador3D.<estático> ni exponga campos privados para el Juego; si el Juego necesita un dato, pídele que lo ponga en la fachada. vfx_3d.gd (111 KB) se parte por elemento cuando lo toques la próxima vez.

Añade tu entrada AL FINAL de docs/DIARIO.md leído del disco en ese momento.
```
