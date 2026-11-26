# Packs «Pure Nature» de BK (Fab) — piezas `pn_*`

Packs de Unreal comprados en Fab (licencia estándar: se pueden usar en Godot, pero **no se suben sueltos a un repo público**). En git
solo viaja este LEEME; todo lo demás de `arte/pure_nature/` se regenera en cada máquina.

Hay 7 (26/11/2026): Asian Valley, Fantasy Forest, Islands, Jungle, Meadows, Mountains y Savanna → 579 piezas.

## Qué lo usa

- **LabComparativaBosque** (`laboratorios/LabComparativaBosque.tscn`), tecla **3** y **← →**: el muestrario, un pack cada vez.
- Los materiales los traduce `presentacion/fab_ue/materiales_ue.gd` (MaterialesUE), copiados de los grafos de Unreal
  (`docs/fab_ue/grafos/`). Si se cambia algo ahí, se vuelve a generar (paso 5).

## Cómo regenerarlo (desde la raíz del repo)

1. En Fab, «Añadir al proyecto» cada pack en `E:\ue_proyectos\StylescapeRuins` (Unreal 5.8). El exportador encuentra solo las carpetas
   `/Game/PureNature_*`, así que un pack nuevo entra sin tocar nada.
2. Exportar desde Unreal sin abrir el editor (deja `E:\ue_proyectos\PureNature_export`; lo ya exportado no se repite):

       "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_exportar_pure_nature.py" -unattended -nop4 -nosplash -NullRHI

3. Pasarlo al repo (FBX y texturas a 2K con las normales a OpenGL):

       python tools\preparar_pure_nature.py "E:/ue_proyectos/PureNature_export"

4. Importar en Godot, **comprimir las texturas para la GPU** y volver a importar. Sin el paso del medio las texturas ocupan 7,9 GB de
   memoria de vídeo y el laboratorio se queda colgado:

       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --import
       python tools\ajustar_import_texturas.py arte/pure_nature/texturas
       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --import

   (Si la primera importación deja FBX sin importar, repetirla: Godot los importa por tandas.)

5. Crear las piezas (`arte/pure_nature/piezas/pn_<pack>_<malla>.tscn`, escala del juego 0,575 u/m, sin colisión):

       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/generar_piezas_pure_nature.gd

   Tiene que acabar en `sin receta=0`. Si sale un maestro nuevo «sin receta», volcar su grafo con `tools/ue_volcar_grafo_material.py`
   y añadirlo a MaterialesUE.

6. Comprobarlo contra Unreal (opcional): `LabComparativaBosque -- --muestrario` (fotos de Godot y `muestrario.json`),
   `tools/ue_montar_muestrario.py` y `ue_capturar_prueba_bosque.py muestrario` (fotos de Unreal), y `python tools\comparar_muestrario.py`.

7. **Vegetación del juego sustituida por el pack** (decisión de Pablo, 26/11): lo elegido en `docs/fab_ue/candidatos_vegetacion.json`
   (vista de candidatos del laboratorio, tecla 4). Crea `arte/pure_nature/juego/pn_*.tscn` (el modelo del pack con el material del juego,
   que es el que se quema, se moja, se hiela y reacciona) y la tabla `presentacion/fab_ue/tabla_variantes.gd`:

       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/aplicar_candidatos_vegetacion.gd
       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_variantes_vegetacion.gd

   La prueba tiene que acabar en `fallos=0`. **Sin este paso (o sin el pack) el juego usa las piezas originales**: no se rompe nada.
   Para comparar con las originales: la variable de entorno `MS_SIN_VARIANTES=1`.

8. **Decorado por bioma del generador de mapas** (26/11): las piezas `pn_*` que lista `presentacion/tabla_decorado_bioma.gd` (árboles de la masa,
   rocas, hierba corta y flores de los niveles generados) también necesitan su versión del juego. Se crean desde ESA tabla (también las de peso 0,
   por si se sube el peso después); hay que repetirlo al añadir una fila `pn_…`:

       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/generar_decorado_bioma.gd
       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/prueba_tabla_decorado.gd

   Las dos acaban en `fallos=0` / `FALLOS: 0`. Sin este paso (o sin el pack) la tabla se salta las filas `pn_…` y el nivel sale con las piezas del juego.
   Para ver todas las piezas de la tabla a la escala del juego: `herramientas/captura_muestrario_decorado.gd` (fotos en `docs/capturas/…/muestrario/`).

## Qué hay aquí (todo fuera de git)

`mallas/` FBX · `texturas/` PNG · `informe.json` las recetas de material · `materiales/` `.tres` · `mallas_res/` · `piezas/` ·
`indice.json` pieza → pack, categoría (árbol, roca, planta, seta, adorno, suelo, **fondo** = montañas y colinas lejanas), caja.
