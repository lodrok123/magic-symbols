# Comparativa de VFX: Godot (a la manera de Unreal) frente a una POC en Unreal

**Fecha**: 1/11/2026 · **Dirección** · Decide: Pablo
**Pregunta que responde**: ¿el problema de los VFX de Magic Symbols es el motor o el método? Y si es el motor, ¿compensa el coste de cambiarlo?

Dos pruebas con el **mismo presupuesto de tiempo** y los **mismos tres efectos**: bola de fuego, muro de fuego y columna de fuego. Al final se rellena la tabla de §4 y se aplica la regla de §5. Nada más: ni mapa propio, ni enemigos, ni otros elementos.

---

## 0. Reglas comunes (para que la comparación no haga trampa)

| Regla | Valor |
|---|---|
| Presupuesto por prueba | 2 jornadas (16 h) de trabajo efectivo, cronometradas. Se anota en qué se va cada hora. |
| Mapa | Un plano de 20×20 m, cuatro cubos como obstáculos, un personaje que anda. Nada de arte propio. |
| Efectos | **Bola**: proyectil de 0,4 m, 8 m/s, estela, impacto en el suelo con llamarada de 1 s. **Muro**: 2,3 × 3 casillas (6,9 m de largo, 1,5 m de alto), nace desde el suelo en 0,3 s, vive 4 s, se apaga en 0,5 s. **Columna**: 1 m de diámetro, 4 m de alto, nace en 0,3 s, vive 4 s, se apaga en 0,5 s. Los tres con luz propia y distorsión de calor. |
| Referencia visual | La misma para las dos: tres imágenes o vídeos que Pablo elige ANTES de empezar y guarda en `docs/capturas/comparativa_vfx/referencia/`. Sin referencia no se puede puntuar «aspecto». |
| Qué se graba | Por prueba: vídeo de 20 s con los tres efectos (1080p, 60 fps), capturas fijas de cada uno a 2 m y a 10 m, y el fps con 10 muros a la vez. |
| Las 5 modificaciones | Al acabar cada prueba, Pablo intenta hacer **solo, sin pedir código**, estas cinco cosas y cronometra: (1) fuego → hielo (azul y más lento); (2) muro al doble de largo; (3) columna que vive 10 s en vez de 4; (4) la mitad de partículas en todo; (5) que la bola gire sobre sí misma. Se anota cuántas consigue y en cuánto tiempo. |
| Prohibido | Copiar contenido de Unreal (Starter Content, Fab) a Godot: la licencia de Epic solo permite usarlo dentro de Unreal. Lo que se use en Godot tiene que ser CC0 o hecho por nosotros. |

Orden sugerido: **primero Unreal** (es la que tiene instalación y curva), después Godot. Así la de Godot se hace sabiendo exactamente qué técnica usa Unreal en cada efecto.

---

## 1. Prueba A: Godot, los tres efectos hechos como los haría Unreal

### 1.1 Qué cambia respecto a lo que hay

Hoy `presentacion/vfx_3d.gd` (2 217 líneas), `vfx_elemento_3d.gd`, `vfx_estado_3d.gd` y `vfx_kit_3d.gd` montan cada efecto **en código**: crean `GPUParticles3D`, mallas y tweens a mano, con parámetros numéricos repartidos por el script. Cada retoque es un cambio de código y una prueba headless. Eso es lo que hace lento iterar, y es independiente del motor.

Lo que Unreal hace bien no es el código: es que **cada efecto es un asset** que se abre, se ve y se retoca con sliders, y que el aspecto sale de **texturas y materiales** (flipbooks de fuego, erosión con ruido, rampas de color, distorsión) más que de la cantidad de partículas. Las dos cosas se pueden hacer en Godot 4.7:

- Un efecto = una escena `.tscn` que se edita en el editor de Godot (partículas, mallas, luz, `AnimationPlayer` con nacer/vivir/morir). Se previsualiza en el editor sin lanzar el juego.
- El aspecto = materiales con flipbook, erosión y rampa (shaders `.gdshader` cortos y reutilizables), no cientos de partículas lisas.

No se toca `vfx_3d.gd` ni el kit. La prueba se hace en limpio, al lado, y si gana se migra elemento a elemento.

### 1.2 Materiales (el 80 % del resultado)

Cuatro shaders, en `presentacion/vfx/shaders/`, cada uno de 30–60 líneas, con parámetros `uniform` para que Pablo los mueva desde el inspector:

| Shader | Para qué | Parámetros |
|---|---|---|
| `flipbook_erosion.gdshader` | Billboards de llama. Lee un atlas N×M (`particles_anim`), le resta un ruido (`erosion`) con un umbral que crece con la vida de la partícula (la llama «se come» por los bordes al morir) y colorea con una rampa (`GradientTexture1D`). Aditivo o mezcla normal según `uniform`. | atlas, columnas, filas, ruido, rampa, erosión_min/max, brillo |
| `scroll_erosion.gdshader` | Mallas: cilindro de la columna y plano del muro. Dos capas de ruido que suben (`TIME × velocidad`) y se restan a un gradiente vertical (más llama abajo, más humo arriba), con la misma rampa. | ruido_a, ruido_b, velocidad_a/b, rampa, altura_llama, aditivo |
| `calor.gdshader` | Distorsión de calor: `hint_screen_texture` + un normal map de ruido que sube. Un plano billboard o un cilindro envolvente. | fuerza, velocidad, normal_map |
| `nucleo_fresnel.gdshader` | Núcleo de la bola: esfera con fresnel blanco-amarillo que satura al centro y flipbook por encima. | color_nucleo, color_borde, potencia |

Texturas (todas CC0 o nuestras, en `presentacion/vfx/atlas/`):
- **Atlas de fuego 8×8** renderizado con Blender 5.2 (Mantaflow, 64 fotogramas, 1024×1024). Hay script a medio camino en `herramientas/rig/` para Blender por lotes; el de este atlas es nuevo, `herramientas/vfx/render_atlas_fuego.py`, y queda en el repo para regenerar con otro color o densidad.
- **Humo 8×8** del mismo render (pase de densidad sin emisión).
- **Ruidos**: `NoiseTexture2D` de Godot (Perlin y celular), generados en el editor, no hace falta archivo.
- **Rampas**: `GradientTexture1D` por elemento (fuego: negro → rojo → naranja → amarillo → blanco). El hielo de la modificación 1 es otra rampa.
- Si el render de Blender se atasca: el *Particle Pack* de Kenney (CC0) trae llamas y humo sueltos que valen para empezar.

### 1.3 Las tres escenas

Cada una en `presentacion/vfx/efectos/`, con un script mínimo (`efecto_vfx_3d.gd`, común) que expone **una sola función**: `preparar(volumen: Dictionary, dir: Vector3, elemento: String)`. Lo que hace cada escena por dentro está en el editor, no en código.

**`BolaFuego.tscn`** (va colgada del proyectil, viaja con él)
- `MeshInstance3D` esfera r=0,4 con `nucleo_fresnel`.
- `GPUParticles3D` llamas: 24 billboards con `flipbook_erosion`, emiten hacia atrás (`direction` = −dir, `spread` 15°), vida 0,5 s, escala 0,6 → 0.
- `GPUParticles3D` chispas: 30, aditivas, gravedad −3, vida 0,8 s.
- `GPUParticles3D` humo: 8, `flipbook_erosion` no aditivo, vida 1,2 s.
- `OmniLight3D` naranja, energía 2, rango 4, con `AnimationPlayer` parpadeando ±15 %.
- Plano `calor` billboard de 1 m.
- Al impactar: `Impacto.tscn` (una llamarada de 1 s: 40 llamas en cono hacia arriba, anillo de calor que se expande, decal de quemado 3 s).

**`MuroFuego.tscn`** (nace quieto)
- Un plano vertical de 6,9 × 1,5 m con `scroll_erosion` (dos caras), más un segundo plano cruzado a 90° más bajo (0,8 m) para que tenga cuerpo desde cualquier ángulo.
- `GPUParticles3D` llamas: 60 billboards en caja de emisión de 6,9 × 0,2 × 0,3, suben 1,2 m/s, vida 0,7 s.
- Brasas 40, humo 12, dos `OmniLight3D` (una cada tercio), cilindro envolvente `calor`.
- `AnimationPlayer`: «nacer» 0,3 s (escala Y 0 → 1, luz 0 → 2), «morir» 0,5 s (erosión a tope, `amount_ratio` → 0, luz → 0).

**`ColumnaFuego.tscn`** (nace quieto)
- Cilindro r=0,5, h=4 con `scroll_erosion`, dos capas (interior aditiva brillante, exterior normal con humo), ambas girando lento en sentidos opuestos.
- `GPUParticles3D` llamas 50 en disco r=0,45, velocidad 3 m/s vertical, vida 1 s. Chispas 30 que suben y se dispersan. Humo 10 que sale por arriba.
- `OmniLight3D` a 1 m de altura, energía 3, rango 6. Cilindro `calor`.
- `AnimationPlayer` «nacer»/«morir» como el muro.

### 1.4 Dónde se prueba

`laboratorios/LabVfxComparativa3D.tscn` (F6): plano, cuatro cubos, la jugadora montada como el juego, y teclas **1** bola, **2** muro, **3** columna, **0** diez muros a la vez (medida de fps), **X** limpia, **C** cámara (juego → cerca 2 m → lejos 10 m), flechas para andar. Las escenas se instancian directamente, sin pasar por el sistema de hechizos, para que el tiempo se vaya en el aspecto y no en la integración. (`LabVfx3D` no valía: es la matriz F4 de `LabHechizos3D`, no una escena suelta.)

Captura: `herramientas/captura_vfx_comparativa.gd` (ventana, no headless) deja en `docs/capturas/comparativa_vfx/godot/` las capturas a 2 m y 10 m de cada efecto, la vista del juego y la escena con diez muros con el fps en pantalla.

### 1.4 bis · Estado el 1/11 (primera versión, hecha por un agente en una tarde)

Hecho y en el repo: el atlas de Mantaflow (`herramientas/vfx/render_atlas_fuego.py`, 96 divisiones, 64 fotogramas en bucle de llama estable, alfa = max(densidad, luminancia) suavizado), los cuatro shaders, las cuatro escenas escritas por `herramientas/vfx/montar_efectos_fuego.gd` (la primera versión; a partir de aquí se retocan en el editor y **no** se vuelve a correr el montador, que las pisaría), el lab, la captura y `herramientas/prueba_vfx_comparativa.gd` (presupuesto, escalado, vida, shaders) a 0 fallos.

Lo que se ve en las capturas y dónde se toca:
- **Muro**: las llamas de arriba leen bien a 2 m y en la vista del juego; la base aún es una franja amarilla demasiado sólida (las tres capas se suman por encima del umbral). Se toca en `MuroFuego.tscn` → PlanoA/B/C → `material_override`: `ruido_base` (0,35: más bajo = base más rota), `brillo`, `rampa_tope`.
- **Columna**: con la silueta apagada (`silueta`) dejó de ser un tubo de cristal; ahora la llevan las partículas y los cilindros apenas se ven. Para que vuelvan a verse: `ColumnaFuego.tscn` → CilindroInt → `brillo` 0,5 → 0,8 y `umbral` 0,4 → 0,3.
- **Bola**: núcleo translúcido con las llamas pegadas (van en coordenadas locales) y chispas y humo que se quedan atrás. El impacto es el efecto que mejor sale.
- **Calor**: funciona en los tres; está muy bajo (`fuerza` 0,008–0,012) porque alto convertía el muro en una banda ondulada en el cielo.
- **fps**: con diez muros a lo lejos, 60 (tope de vsync). Con un solo efecto a 2 m, entre 33 y 53 a 1600×1000 en una RTX 3070: el coste es de relleno (quads grandes cerca de la cámara, tres capas aditivas) y de la lectura de pantalla del calor; está sin optimizar y es un dato de la tabla, no un veredicto.
- **Atlas**: el humo sale negro de Blender (sin luz de volumen útil); el shader lo colorea por densidad (`color_por_alfa` = 1), así que sirve. Para otro color o altura de llama se cambia `TEMPERATURA_K`, `FUEGO_COMBUSTION` o `ENCUADRE` y se vuelve a correr el script (unos 3 min; borra su caché al acabar).

### 1.5 Traslado al sistema de hechizos (si gana Godot, o para enseñar el camino)

El sistema ya está preparado para colgar dibujos sin tocar la lógica. Tres puntos de entrada en `magia/lanzador_3d.gd`:

| Señal | Cuándo sale | Quién la escucha hoy |
|---|---|---|
| `hechizo_v2(estado, elemento, volumen, origen, dir, props)` | Una vez por hechizo que **no viaja** como proyectil, justo antes de materializarlo (`HechizoVivo._materializar`). `volumen` trae `x, y, z` (semiejes en casillas), `celdas`, `niveles`, `persiste`, `suelo`, `eventos`, `vida_total`, `permanencia`, `viaja`, `velocidad`… | `VfxElemento3D` (por elemento) y `VfxEstado3D` (por estado, apagado) |
| `child_entered_tree` del lanzador | Cada `HechizoVivo` con `velocidad > 0` es un proyectil: no emite `hechizo_v2`. Se le cuelga un nodo que viaja con él y se suelta al morir. | `VfxElemento3D._en_nodo` |
| `vfx_hechizo(nombre, posicion, elemento)` | La `estela`, el `efecto_impacto` y la acción `vfx` de un hechizo piden un efecto por nombre. | `VfxEstado3D` (ráfaga genérica) |

El traslado es **un escuchador nuevo**, `presentacion/vfx_biblioteca_3d.gd` (`VfxBiblioteca3D`), de unas 150 líneas, que no dibuja nada: solo elige una escena y la escala.

1. **Tabla, no código.** `const EFECTOS := {"fuego": {"proyectil": BolaFuego, "muro": MuroFuego, "columna": ColumnaFuego, "esfera": ..., "impacto": Impacto}}`. Un elemento sin tabla cae en `VfxElemento3D` como hasta ahora: se migra elemento a elemento sin romper los demás.
2. **Silueta a partir del volumen**, con dos constantes: `proyectil` si `viaja` y `velocidad > 0`; `columna` si `y ≥ RATIO_COLUMNA × max(x, z)` (2,0); `muro` si `max(x, z) ≥ RATIO_MURO × min(x, z)` (2,5) y `y ≤ 1,5`; `esfera` en el resto. Con los glifos de hoy: **bola** = fuego + `flecha`; **muro** = fuego + `linea_x` (o `linea_z`) repetido; **columna** = fuego + `altura` repetido. Es exactamente lo que ya resuelve `Sigils.semieje_horizontal_v2` y `GLIFOS_ALTURA_CUATRO_NIVELES_V2`.
3. **Escalado por `preparar(volumen, dir, elemento)`**: cada escena se diseña a un tamaño de referencia (el de §0) y `preparar` escala el nodo raíz a `(x·casilla / ref_x, y·casilla / ref_y, z·casilla / ref_z)`, orienta el muro según `dir`, ajusta `amount` de las partículas en proporción al área (para que diez muros largos no cuesten diez veces más), y pone `vida_total` al `AnimationPlayer` (nacer + vivir + morir = `vida_total`). Los `eventos` (copias, rebotes) se resuelven como hoy: una instancia por evento.
4. **Vida**: el efecto cuelga del `HechizoVivo` (igual que `VfxElemento3D`: es el último hijo del lanzador cuando sale la señal). Si el `HechizoVivo` muere antes, el efecto se suelta y toca «morir» (0,5 s). `MAX_VIVOS` y el presupuesto de luces se heredan tal cual.
5. **Pruebas**: `herramientas/prueba_vfx_biblioteca.gd` headless: para las tres recetas comprueba que se instancia la escena correcta, que la escala del raíz coincide con el volumen (±2 %), que las luces ≤ 2 y las partículas ≤ 400 por volumen (los mismos límites que `VfxEstado3D`), y que al liberar el `HechizoVivo` el efecto desaparece en ≤ 0,6 s. Más una línea en `prueba_vfx_v2` para que `VfxElemento3D` siga atendiendo los elementos sin tabla.
6. **Migración**: fuego primero (es el que se está probando), después hielo (misma geometría, rampa y velocidad distintas: la modificación 1 de §0 se convierte en la receta de hielo), luego el resto en el orden de `VfxKit3D.VALIDADOS`. Cuando todos tengan tabla, `vfx_elemento_3d.gd` y la mitad de `vfx_3d.gd` sobran.

Lo que **no** cambia: `Hechizo`, `HechizoVivo`, `Sigils`, las señales y las 198 pruebas. El traslado es solo del lado de `presentacion/`.

### 1.6 Riesgos propios de Godot

- La distorsión de calor con `hint_screen_texture` solo funciona en Forward+ y Mobile (el proyecto va en Forward+: bien) y no se ve en el editor con la previsualización de partículas: hay que verla en el lab.
- `GPUParticles3D` con sub-emisores y colisiones es más tosco que Niagara; para estos tres efectos no hacen falta.
- No hay vista de «curva de vida» de un efecto como en Niagara: la escala y el color con la edad se hacen con `CurveTexture` y `GradientTexture1D` en el `ParticleProcessMaterial`, que se editan en el inspector pero no se ven animados hasta reproducir.

---

## 2. Prueba B: POC en Unreal

### 2.1 Instalación (no cuenta en las 16 h)

- Epic Games Launcher → Unreal Engine **5.6 o posterior**. Unos 60 GB en disco; conviene SSD. Visual Studio **no** hace falta si todo se hace en Blueprints (es lo previsto).
- Plantilla **Third Person**, con **Starter Content** marcado, proyecto Blueprint, nombre `MS_POC_VFX`, fuera del repo de Magic Symbols (no se versiona aquí; si acaso, un zip del proyecto en `docs/capturas/comparativa_vfx/unreal/`).
- Plugins: **Niagara** (ya activo) y **Niagara Fluids** (activar en Edit → Plugins; trae fuego simulado en 3D con plantillas listas).
- Descargar de Fab (gratis): el proyecto **Content Examples** de Epic (mapa «Niagara» con decenas de efectos abiertos para copiar) y uno o dos packs de fuego con filtro «free». Se anota cuáles.

### 2.2 Mapa

Nivel nuevo vacío: un `Plane` escalado a 20×20 m, cuatro `Cube`, `DirectionalLight` + `SkyLight` + `SkyAtmosphere` + `ExponentialHeightFog` ligero (en un nivel vacío Unreal se ve negro sin esto), `PlayerStart`. El personaje de la plantilla.

### 2.3 Los tres efectos (Niagara)

**Bola**: Blueprint `BP_BolaFuego` (Actor) con `ProjectileMovement` (8 m/s, sin gravedad), `SphereCollision` r=20 cm y un `NiagaraComponent` con `NS_BolaFuego`: emisor de malla esfera (material con fresnel), emisor de llamas en sprite con flipbook (el de Starter Content `T_Fire_SubUV` o el del pack), emisor de chispas, emisor de humo, `Ribbon` como estela, y una `PointLight` con `LightRenderer` del propio Niagara. `OnHit` → spawnea `NS_Impacto` y se destruye. Input: acción `Lanzar1` (tecla 1, Enhanced Input) en el personaje.

**Muro**: `BP_MuroFuego` con `NS_MuroFuego`: emisor sprite con *Box Location* 690×20×30 cm, velocidad hacia arriba, flipbook + erosión en el material (el material de fuego del Starter Content ya la trae), emisor de brasas, emisor de humo, dos `LightRenderer`, y un emisor de malla plano con material de **refracción** para el calor. **User Parameter** `Longitud` que escala la caja y el `SpawnRate` en proporción. `Timeline` en el Blueprint: nacer 0,3 s, vida 4 s, morir 0,5 s (bajando `SpawnRate` y la luz).

**Columna**: `BP_ColumnaFuego` con `NS_ColumnaFuego`. Dos opciones, y se prueban **las dos** porque es el punto donde Unreal más se diferencia: (a) sprites + malla cilindro con *panner* y erosión, igual que en Godot; (b) **Niagara Fluids** «Grid 3D Gas Fire» con la fuente en el suelo: fuego simulado de verdad. Se anota el coste de cada una. User Parameter `Altura`.

### 2.4 Qué medir además del aspecto

- Cuánto del resultado viene del **contenido** (Starter Content, Fab) y cuánto de lo que se ha hecho. Es la clave para saber qué parte sería trasladable: el método y los materiales sí; el contenido, por licencia, no.
- Las cinco modificaciones de §0: en Unreal se hacen en el editor de Niagara y en los User Parameters. Se cronometra igual.
- **Flujo con agentes**: una tarde, no más, probando si Claude puede hacer algo útil en el proyecto: los Blueprints y los sistemas Niagara son **binarios** (`.uasset`); un agente no los lee ni los edita como edita un `.gd`. Las vías son *Python Editor Scripting* (puede crear actores y leer propiedades, pero no cablear Blueprints) y C++ (compilaciones de minutos, y Visual Studio). Se anota, con honestidad, qué parte del flujo actual (pruebas headless, commit por tarea, capturas automáticas, agentes que corrigen solos) sobreviviría.
- Tamaño del proyecto y del ejecutable empaquetado (Windows, Shipping).

### 2.5 Lo que la POC no mide y hay que tener delante al decidir

Si Unreal gana en VFX, lo que queda detrás no es «cambiar de motor»: es **rehacer el juego**. Para que la cifra esté sobre la mesa:

| Qué | Cuánto hay hoy |
|---|---|
| Scripts GDScript | 577 archivos (`Hechizo`, `HechizoVivo`, `Sigils`, terreno, agua, reacciones, enemigos, interfaz) |
| Pruebas | 198 scripts headless (unas 2 500 comprobaciones), en 40–50 min |
| Escenas y recursos | 209 `.tscn`, 9 `.tres`, niveles en `mundo/datos_nivel` |
| Rigging | `Pj3D`, `ClipsFamilia`, `CapaMuelles3D`, `Ropa3D`, `montar_ropa_glb` (todo propio) |
| Documentos atados al código | ESPEC_HECHIZO, GLIFOS_RECETA, ARQUITECTURA y 290+ entradas del diario |

Un traslado fiel es de **meses** con el equipo actual, y durante ese tiempo no avanza el juego. La alternativa, si gana Unreal solo en el aspecto, es la de §1.5: adoptar el método (assets por efecto, materiales con flipbook y erosión) dentro de Godot.

---

## 3. Calendario

| Día | Qué |
|---|---|
| 0 | Pablo elige las tres referencias visuales y las guarda. Instalación de Unreal en paralelo. |
| 1–2 | Prueba B (Unreal). Vídeo, capturas, cinco modificaciones, tarde de flujo con agentes. |
| 3 | Render del atlas de fuego en Blender y los cuatro shaders (agente). |
| 4–5 | Prueba A (Godot): las tres escenas, el modo del lab, capturas, cinco modificaciones. |
| 6 | Tabla de §4 rellena, decisión por §5, entrada en el diario. |

Pablo pone las horas de «aspecto» y las cinco modificaciones en las dos pruebas (es su ojo el que decide). El montaje de shaders, escenas, lab y capturas en Godot lo hace un agente; en Unreal, lo que Pablo no quiera hacer a mano no lo puede hacer un agente, y eso es ya un dato.

---

## 4. Tabla de resultados (a rellenar)

| Criterio | Peso | Godot (A) | Unreal (B) | Notas |
|---|---|---|---|---|
| Aspecto frente a la referencia (Pablo, 1–5, por efecto y media) | 3 | | | bola / muro / columna |
| Horas hasta la primera versión que Pablo da por buena | 2 | | | de las 16 |
| Cinco modificaciones: cuántas hechas solo, tiempo total | 3 | | | |
| Fps con diez muros a 1080p | 1 | | | mínimo exigido: 60 |
| Flujo actual que sobrevive (pruebas headless, agentes, commit por tarea, capturas) | 3 | | | 0–5 |
| Parte del resultado que es contenido ajeno (no trasladable) | 1 | | | % estimado |
| Coste de llegar al juego entero | 3 | 0 (ya está) | meses | |

Puntuación: cada criterio de 1 a 5, por su peso. Dos columnas, dos totales.

## 5. Regla de decisión (acordada antes de empezar)

- **Godot gana o empata** → se adopta el método de §1 y se hace el traslado de §1.5, fuego primero. Unreal se cierra.
- **Unreal gana en aspecto y modificaciones pero Godot llega al 80 % de su nota de aspecto** → igual que arriba: el problema era el método. Se guardan las técnicas de Unreal como referencia (qué materiales, qué curvas) y se reproducen en Godot.
- **Unreal gana con Godot por debajo del 80 % en aspecto Y Pablo hace solo ≥ 4 de las 5 modificaciones en Unreal y ≤ 2 en Godot** → se abre la decisión de traslado, con la tabla de §2.5 delante y un plan por fases (primero el sistema de hechizos y las pruebas, que es lo que da valor; el resto después). No se decide en el mismo día que se rellena la tabla.

Lo que no vale como argumento: «en Unreal se ve mejor» sin la nota de Godot hecha con el mismo método y el mismo tiempo.
