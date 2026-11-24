# Impactos de Effekseer traducidos a nuestras piezas (25/11/2026)

Pablo: «ejecuta toda la lista y implementa una comparación con lo que ya hay para ver qué merece la pena y qué no».
Se tradujeron los cinco impactos elegidos de la demo oficial de EffekseerForGodot4 (probada aparte en `E:\pruebas_effekseer\demo`, fuera del repo). **No entra en el juego nada de Effekseer:**
ni el plugin, ni sus texturas, ni sus materiales. Se copia solo la coreografía (capas, tiempos, tamaños y fundidos) y se dibuja con nuestros shaders y la paleta de cada elemento.

## Qué hay

| Pieza | Archivo |
|---|---|
| Lector de recetas `.efkefc` (XML del editor sin instalar Effekseer) | `herramientas/effekseer_receta.py` |
| Reproductor genérico de capas (sprite, halo, chispas, gotas, piedras, humo, grieta, onda, luz) | `presentacion/vfx/toy/impacto_capas_toy.gd` |
| Las cinco recetas traducidas, con lo que se dejó fuera y por qué | `presentacion/vfx/toy/recetas_effekseer.gd` |
| Comparativa en el lab (Ctrl+4..7) | `laboratorios/lab_impactos_effekseer.gd` (enganchada en `LabVfxComparativa3D`) |
| Prueba | `herramientas/prueba_impactos_effekseer.gd` (67 comprobaciones) |
| Capturas y hojas | `herramientas/captura_impactos_effekseer.gd`, `herramientas/hoja_impactos_effekseer.gd` |

Hojas (fila de arriba: Effekseer original · en medio: lo de ahora · abajo: lo traducido; columnas: 50, 100, 200, 350, 600 y 1000 ms):
`docs/capturas/impactos_effekseer/hoja_*.png`.

## Veredicto por impacto

| # | Impacto | Se compara con | ¿Merece la pena? | Qué cogería |
|---|---|---|---|---|
| 1 | Golpe hit01 | ImpactoFuegoToy GOLPE (estilo C) | **Una parte** | La **estrella grande de rayos 0,1 s** al principio (T_VFX_Flare_666, más grande que nuestro hit22) para dar más «punch». El resto (aro blando, distorsión) no mejora lo que hay: el nuestro tiene chispas y el de Effekseer no. |
| 2 | Golpe toon | ImpactoFuegoToy GOLPE | **No, tal cual** | Su gracia son **arcos concéntricos nítidos** y rayas que salen con 0,2 s de retraso. Con nuestro halo-anillo (blando) queda una rosquilla luminosa. Haría falta una textura de aro/arco nítido. |
| 3 | Explosión fire02 | ExplosionFuegoToy (barril) | **No** | El original es amarillo-blanco (justo lo que no queremos) y nuestra explosión del barril ya tiene más: onda en el suelo, llamas verticales, brasas que quedan y humo. Traducida suma bolas de fuego sueltas, menos compacta. |
| 4 | Salpicadura toon | ImpactoAguaToy GOLPE | **Una parte** | **Dos o tres ondas escalonadas** (cada 0,07 s) en vez de una: se lee mejor el golpe en el suelo. La corona de láminas, que es lo mejor del original, no se puede hacer con gotas; haría falta una pieza nueva (lámina de corona). |
| 5 | Golpe de tierra (fire03 + ice01) | ImpactoTierraToy GOLPE | **Una parte** | **Más fragmentos pequeños y rápidos** (debris) que salen más lejos. El nuestro ya gana en la marca de grietas (decal) y las púas. Ojo: fire03 es una explosión de fuego con rocas, no de tierra. |

**Resumen:** lo que aportan los efectos de Effekseer es **ritmo** (destello enorme muy corto, retrasos escalonados, ondas repetidas), no piezas nuevas: en 3 de 5 nuestro impacto ya está igual o mejor.
Lo que de verdad falta para acercarse a los toon son **texturas**, no código: un aro nítido, arcos y láminas de corona.

## Cómo verlo

`LabVfxComparativa3D` → **Ctrl+4** pone la comparativa (izquierda lo de ahora, derecha lo traducido, se repite solo) · **Ctrl+5** par siguiente (Mayús: anterior) · **Ctrl+6** vista juego / cerca / solo traducido · **Ctrl+7** cámara lenta ×0,25 · **Ctrl+4** sale.

## Regenerar

```
python herramientas/effekseer_receta.py <efecto>.efkefc --salida output/effekseer_impactos_2026-11-25/recetas
godot --headless --path . --script res://herramientas/prueba_impactos_effekseer.gd
godot --fixed-fps 60 --path . --script res://herramientas/captura_impactos_effekseer.gd -- output/effekseer_impactos_2026-11-25/capturas
godot --fixed-fps 60 --path E:\pruebas_effekseer\demo --script res://captura_original.gd -- E:\magic-symbols\output\effekseer_impactos_2026-11-25\originales
godot --path . --script res://herramientas/hoja_impactos_effekseer.gd -- output/effekseer_impactos_2026-11-25
```

Licencias: el plugin es MIT. La demo no indica la licencia de sus efectos (solo la de los modelos, CC-BY GDQuest), por eso no se ha copiado ninguna textura ni material al repo.
