# Pack «Stylescape: Ruins» (Fab) — estilo «ruinas»

Pack de Unreal comprado en Fab (licencia estándar: se puede usar en Godot, pero **no se sube suelto a un repo público**). Por eso
en git solo viaja este LEEME; todo lo demás de `arte/stylescape/` se regenera en cada máquina.

## Qué lo usa

- **Estilo «ruinas» de la maqueta** (`estilo = "ruinas"` en la escena; en el generador de mapas, «Estilo: Ruinas (muros del pack)»):
  el bosque de siempre, pero los `#` que tocan suelo son **muros finos** del pack (0,29 u de grueso) por el eje de la casilla
  (`presentacion/paredes_stylescape.gd`). La pared sur de cada sala va baja para no tapar el interior. Los `#` de más adentro
  siguen siendo árboles. Si el pack no está generado, el nivel sale como un bosque normal.
- **LabStylescape** (`laboratorios/LabStylescape.tscn`): las pruebas de material y las salas sobre la rejilla.

## Cómo regenerarlo (desde la raíz del repo)

1. Tener Unreal 5.8 y el zip del pack (`StylescapeRuins.zip`) extraído en `E:\ue_proyectos\StylescapeRuins`. Al `.uproject` hay
   que activarle los plugins `PythonScriptPlugin` y `EditorScriptingUtilities`.
2. Exportar desde Unreal sin abrir el editor (unos 30 s; deja todo en `E:\ue_proyectos\StylescapeRuins_export`):

       "E:\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "E:\ue_proyectos\StylescapeRuins\StylescapeRuins501.uproject" -run=pythonscript -script="E:\magic-symbols\tools\ue_exportar_stylescape.py" -unattended -nop4 -nosplash -NullRHI

3. Pasarlo al repo (mallas FBX, texturas a 1K con las normales convertidas a OpenGL):

       python tools\preparar_stylescape.py "E:/ue_proyectos/StylescapeRuins_export"

4. Importar en Godot: `tools\Godot_v4.7.2-stable_win64.exe --headless --path . --import`. Después, en los `.import` de
   `arte/stylescape/texturas/`, poner `compress/mode=2` y `mipmaps/generate=true` (y `compress/normal_map=1` en las `_N`) y volver a importar.
5. Crear las piezas del juego (`arte/stylescape/piezas/ss_*.tscn`, con el beige de nuestros muros ya horneado):

       tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/generar_piezas_stylescape.gd

6. Comprobarlo: `tools\Godot_v4.7.2-stable_win64.exe --path . --script res://herramientas/captura_ruinas_generado.gd`
   (genera y carga el mapa RuinasGen, cuenta los muros y deja fotos en `docs/capturas/stylescape/generado/`).

## Qué hay aquí (todo fuera de git)

- `mallas/` FBX exportados · `texturas/` PNG a 1K · `informe*.json` las recetas de material de Unreal
- `materiales/`, `mallas_res/`, `piezas/` lo que crea `generar_piezas_stylescape.gd`
