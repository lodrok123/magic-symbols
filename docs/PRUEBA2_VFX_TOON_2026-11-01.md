# Prueba 2 de VFX: fuego toon con referencia, método libre, Godot y Unreal (1/11/2026)

Segunda ronda de `COMPARATIVA_VFX_GODOT_UNREAL_2026-11-01.md`. La primera demostró que con el mismo método y sin referencia los dos motores llegan al mismo «se ve fuego». Pablo pide ahora **el método que haga falta para el mejor resultado posible**, con una **referencia válida** y el mismo objetivo en los dos motores. Esta es la tarea, para validar antes de arrancar.

---

## 0. La referencia: B con E

Elegida por Pablo entre cinco opciones: **fuego estilo Zelda Breath of the Wild** (B) con **animación a pocos fotogramas y bordes duros** (E).

Fuentes para mirar (vídeo y desglose, no capturas sueltas):
- Recreación de los efectos de Zelda en Unity, con la técnica de erosión y distorsión por datos de partícula: https://www.gamedeveloper.com/art/recreating-the-zelda-vfx-in-unity
- Otra recreación, con las cinco fases de una explosión: https://80.lv/articles/making-zelda-like-vfx-with-unity
- Fuego procedimental con tiempo cuantizado: https://80.lv/articles/check-out-this-fully-procedural-stylized-fire-vfx-made-with-shaders/

**Tres fotogramas de referencia** en `docs/capturas/comparativa_vfx/referencia/` (`ref_muro.png`, `ref_hoguera.png`, `ref_impacto.png`): un muro o línea de fuego en el suelo, una hoguera o columna, y un golpe de fuego. Se guardan antes de empezar y son contra lo que Pablo puntúa. Están pendientes de su visto bueno para descargarlos (son capturas del juego; uso interno de referencia).

### 0.1 Lo que define el estilo, en términos que se pueden comprobar

| Rasgo | Valor objetivo | Cómo se comprueba |
|---|---|---|
| Paleta | Tres tonos planos: núcleo amarillo claro (≈ `#FFF3B0`), cuerpo naranja (≈ `#FF8A1F`), borde rojo (≈ `#C8321E`). Humo en dos grises azulados. Chispas amarillas. | Rampa en escalones, no degradado: cuenta de colores distintos en una captura a 2 m ≤ 8 en la llama |
| Silueta | Lenguas redondeadas, como gotas invertidas, que se separan por arriba y desaparecen de golpe | Erosión con umbral duro: `suavidad` ≤ 0,03 |
| Animación | **12 fotogramas por segundo** cuantizados, en todo: desplazamiento del ruido, flipbook, titileo de la luz, humo | Vídeo o dos capturas separadas 1/24 s iguales |
| Iluminación de la llama | Ninguna (`unshaded`); la llama no recibe sombra ni luz | Captura con el sol apagado: la llama no cambia |
| Luz emitida | Una luz cálida en el suelo con titileo cuantizado | Presupuesto ≤ 1 luz por efecto (antes eran 2) |
| Humo | Bolas redondas, dos tonos, que nacen en la punta de la llama, crecen y se van de golpe | Captura a 2 m: el humo no sale del suelo |
| Contorno | Opcional, una línea oscura fina en el borde de la llama (segundo umbral) | Mando `contorno` 0–1 |
| Distancia | Se lee a 10 m con la cámara del juego (ortográfica, 30°) | `juego_muro.png` |

### 0.2 Los efectos y el orden

1. **Muro** (6,9 × 1,5 m) primero, hasta acercarlo a `ref_muro.png`. Es la única obligación de las dos jornadas.
2. **Columna** (1 × 4 m) y **bola** (r 0,4 m, impacto) solo si el muro convence a Pablo. Reutilizan lo del muro.

---

## 1. Reglas comunes

| | |
|---|---|
| Presupuesto por motor | **2 jornadas de agente** (16 h), cronometradas por paso en un `NOTAS.md` como el de la prueba B. Más **1 hora de Pablo** por motor, al final, moviendo mandos en el editor. |
| Método | Libre. Vale todo lo que dé mejor resultado: mallas, sprites, flipbook, procedimental, desplazamiento de vértices, contenido gratuito donde la licencia lo permita. Se apunta qué se usó. |
| Contenido ajeno | Godot: solo CC0 o propio. Unreal: lo que haya en el motor y lo gratuito de Fab (la licencia lo permite dentro de Unreal). Se apunta el porcentaje de lo que se ve que es ajeno. |
| Mandos | Los diez que más cambian el aspecto, con nombre en castellano y rango, accesibles sin abrir código: inspector en Godot, User Parameters y Material Instance en Unreal. |
| Capturas | Mismos nombres que la prueba 1, en `docs/capturas/comparativa_vfx/godot_toon/` y `unreal_toon/`: `muro_cerca`, `muro_lejos`, `juego_muro`, `diez_muros` (con fps legible), y si llegan, `columna_*` y `bola_*`. Más un vídeo o GIF de 3 s del muro a 2 m, porque el estilo E es de movimiento. |
| Presupuesto de render | ≤ 1 luz y ≤ 300 partículas por efecto; diez muros ≥ 60 fps a 1080p. |
| Pruebas | Godot: `prueba_vfx_toon.gd` sin ventana (presupuesto, escalado, vida, shaders cargan, paleta ≤ 8 colores en una captura). Unreal: un script Python con las mismas aserciones que se pueda lanzar, y un intento documentado de ejecutarlo **sin interfaz** (`-run=pythonscript`). |
| Las cinco modificaciones de Pablo | Sustituyen a las de §0 de la comparativa para esta prueba: (1) paleta de fuego a fuego azul de tres tonos; (2) de 12 a 6 fotogramas por segundo; (3) lenguas un 50 % más altas; (4) quitar el humo y poner el doble de chispas; (5) muro al doble de largo con la misma densidad. Solo, sin pedir código, cronometrado. |

---

## 2. Plan en Godot (`presentacion/vfx/toon/`)

Se parte de lo que hay (atlas, shaders, `EfectoVfx3D`, `LabVfxComparativa3D`) pero el aspecto se hace nuevo.

1. **Shader `fuego_toon.gdshader`** (procedimental, para mallas): dos ruidos que suben con el tiempo **cuantizado** (`t = floor(TIME * fps) / fps`), gradiente vertical, umbral duro con `suavidad` ≤ 0,03, **rampa en escalones** de tres tonos (`GradientTexture1D` con interpolación constante), banda de contorno por segundo umbral, y **desplazamiento de vértices** por el mismo ruido para que la silueta de la malla ondule. Mandos: `fps`, `umbral`, `altura_llama`, `desplazamiento`, `contorno`, `rampa`, `velocidad`, `escala_ruido`, `brillo`, `erosion`.
2. **Lenguas sueltas**: quads con billboard bloqueado en Y (siempre de frente, sin tumbarse) con el mismo shader, distribuidos a lo largo del muro; son las «gotas invertidas» que se separan por arriba. Alternativa si el procedimental no da la silueta: **flipbook posterizado** renderizado en Blender con `render_atlas_fuego.py` y una rampa dura en la composición (ya está el camino hecho).
3. **Humo toon**: `GPUParticles3D` con quad y shader de bola redonda en dos tonos, emisión en la punta (altura de la llama), crecimiento lineal y muerte de golpe, tiempo cuantizado.
4. **Chispas**: puntos amarillos con estela corta, cuantizados.
5. **Luz**: una `OmniLight3D` con titileo por curva en escalones.
6. **Escena `MuroFuegoToon.tscn`** con `EfectoVfx3D` (mismo contrato `preparar` / `lanzar` / `morir`), montada por un script de un solo uso y luego editable.
7. **Lab**: tecla 5 en `LabVfxComparativa3D` para el muro toon, panel con los diez mandos y teclas para subirlos y bajarlos; captura y vídeo por `captura_vfx_comparativa.gd`.
8. **Prueba sin ventana** y `NOTAS.md` con horas por paso.

## 3. Plan en Unreal (`E:\UnrealProjects\MS_POC_VFX`, carpeta `Content/POC2`)

Se reutiliza la cola de scripts y `poc_niagara.py` de la prueba B; lo nuevo es el material y la forma.

1. **Material `M_FuegoToon` creado por script** con `MaterialEditingLibrary` (`create_material_expression`, `connect_material_expressions`): dos `TextureSample` de ruido (los del motor), `Panner` con tiempo cuantizado (`Floor(Time × fps) / fps`), máscara vertical, umbral con `Step`, rampa de tres tonos con `If` o `LinearColor` por escalón, contorno por segundo umbral, `WorldPositionOffset` por ruido para el desplazamiento, `Unlit`, `Masked`. Los mandos como parámetros escalares y de color, expuestos en una **Material Instance**. Si el grafo no se deja hacer por script, se apunta y queda para la hora de Pablo.
2. **Forma**: emisor de **malla** (plano o cilindro) con `M_FuegoToon` para el cuerpo del muro, y emisor de sprites alineados en Y para las lenguas sueltas; humo en sprites con material de bola en dos tonos; chispas; un `LightRenderer` con curva en escalones.
3. **Contenido de Fab**: se busca una textura o material de fuego toon gratuito; si se usa, se apunta como ajeno. No se usa `NetworkPredictionExtras`.
4. **Blueprint `BP_MuroFuegoToon`** y tecla 5 en el personaje, como en la prueba B.
5. **Capturas y vídeo** con `08_capturas.py` adaptado; `stat fps` con diez muros.
6. **Intento sin interfaz**: `UnrealEditor-Cmd.exe <proyecto> -run=pythonscript -script=<prueba.py>` con las aserciones; se apunta si funciona o en qué se cae.
7. `NOTAS.md` con horas por paso y porcentaje de contenido ajeno.

---

## 4. Tabla de resultados

| Criterio | Peso | Godot | Unreal | Notas |
|---|---|---|---|---|
| Aspecto frente a los tres fotogramas (Pablo, 1–5) | 3 | | | muro; columna y bola si llegan |
| Horas de agente hasta el muro que Pablo da por bueno | 2 | | | de las 16 |
| Las cinco modificaciones de §1: cuántas solo, tiempo | 3 | | | |
| Fps con diez muros a 1080p | 1 | | | mínimo 60 |
| Flujo que sobrevive (sin ventana, pruebas, texto, capturas) | 3 | | | 0–5 |
| Parte de lo que se ve que es contenido ajeno | 1 | | | % |
| Coste de llegar al juego entero | 3 | 0 | 50–80 jornadas (`MIGRACION_UNREAL_COSTE_2026-11-01.md`) | |

La regla de decisión de §5 de la comparativa sigue valiendo: el traslado solo se abre con Godot por debajo del 80 % del aspecto de Unreal y Pablo haciendo solo ≥ 4 de 5 modificaciones allí y ≤ 2 aquí.

## 5. Calendario

| Paso | Quién |
|---|---|
| Validar este diseño y los tres fotogramas | Pablo |
| Prueba 2 en Godot y en Unreal, en paralelo, una sesión cada una, con esta tarea como brief | Agentes |
| Una hora por motor con los mandos, nota de aspecto, cinco modificaciones | Pablo |
| Tabla de §4 rellena, diario, decisión al día siguiente | Juntos |
