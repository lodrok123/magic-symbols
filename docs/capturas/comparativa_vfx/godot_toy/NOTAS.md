# Prueba 3 de VFX en Godot: cinco efectos de fuego «toy» (1/11/2026)

Rama `claude/prueba3-godot-toy` (worktree `E:\tmp\wt_prueba3_godot`), sin push. Diseño: `docs/PRUEBA3_VFX_TOY_2026-11-01.md`. Referencia: `docs/capturas/comparativa_vfx/referencia_toy/` (`eow_hierba.jpg` es el juez de la llama, `la_pilar.jpg` el pilar, `la_antorchas.jpg` la bola).

## Nota propia frente a la referencia (1–5) y lo que falta

| Efecto | Nota | Rondas | Lo que falta |
|---|---|---|---|
| Bola estática (`bola_cerca`, `bola_juego`) | **3,5** | 3 | Es una bola gorda y redonda con un borde claro y una puntita, bien parecida a las antorchas de `la_antorchas.jpg`, pero la punta no ondula tanto como una llama de `eow_hierba.jpg` (se ve un poco «farolillo»); dentro se adivinan los círculos concéntricos de las tres capas. |
| Muro (`muro_cerca`, `muro_juego`) | **3,5** | 3 | Lenguas gordas, blandas y con las puntas torcidas, translúcidas, con filo crema y base clara; se parece a las llamas de la hierba. Falta: son 17 lenguas de la misma familia (se nota la repetición en la fila de delante), el color tira a amarillo claro donde la referencia es más naranja ámbar, y no hay el brillo de la hierba quemada debajo. |
| Pilar (`pilar_cerca`, `pilar_juego`) | **3,5** | 2 | Columna de bultos gordos que suben (lo que pide `la_pilar.jpg`), con núcleo claro, anillo en el suelo y chispas. Falta: el borde es más liso que el de la referencia (que tiene los lóbulos separados, como nubes de fuego) y la parte alta se afina demasiado pronto. |
| Bola en movimiento + impacto (`bola_vuelo`, `bola_impacto`) | **3** | 2 | La estela corta se ve poco (es una nube difusa, no una cola con forma de lengua) y el impacto es un estallido de siete pétalos con un anillo en el suelo, correcto pero sin la silueta clara de la referencia; el resplandor de la luz sobre el suelo del lab lava el color en la cámara cerca. **No pasa de 3 en dos rondas: apuntado, no se tocó más.** |
| Barrera (`barrera_cerca`, `barrera_juego`) | **3** | 2 | Cáscara translúcida con borde luminoso y ocho lenguas que suben girando, se ve a la jugadora dentro. Falta: las lenguas son «hojas» de bordes afilados, no las puntas redondas y gordas de la bola o el muro; el fresnel de la cáscara es un velo amarillo claro que se parece más a una burbuja que a un fuego. **No pasa de 3 en dos rondas: apuntado.** |

Media de las cinco: **3,3**. Es la nota de quien lo ha hecho; la que vale es la de Pablo.

## Qué hay

| Cosa | Dónde |
|---|---|
| Escenas con `EfectoVfx3D` (`preparar` / `lanzar` / `morir` / `impactar`) | `presentacion/vfx/toy/`: `BolaFuegoToy.tscn` (estática; con `proyectil` activo suelta estela; al `impactar` instancia `ImpactoBolaToy.tscn`), `MuroFuegoToy.tscn`, `PilarFuegoToy.tscn`, `BarreraFuegoToy.tscn` |
| Shader de la llama (plano con billboard en Y o completo; dos ruidos que suben, gradiente vertical, `smoothstep` ancho, rampa continua) | `llama_toy.gdshader` |
| Resplandor aditivo (halo, charco en el suelo, anillo) | `halo_toy.gdshader` |
| Cáscara de la barrera (esfera, dos pasadas: cara de atrás y de delante) | `barrera_toy.gdshader`, `barrera_toy_trasera.gdshader`, `barrera_toy.gdshaderinc` |
| Script del raíz con los diez mandos | `efecto_toy.gd` (`class_name EfectoToy extends EfectoVfx3D`) |
| Montaje de un solo uso (después se edita en el editor) | `herramientas/vfx/montar_efectos_toy.gd` |
| Lab: F1 bola estática · F2 muro · F3 pilar · F4 bola en vuelo con impacto · F5 barrera · F6 diez muros; RePág/AvPág eligen mando, + / − lo mueven, Retroceso lo repone; el panel enseña los diez con su valor | `laboratorios/lab_vfx_comparativa_3d.gd` |
| Captura con ventana, GIF y fps | `herramientas/captura_vfx_toy.gd`, `herramientas/gif_desde_secuencia.py` |
| Prueba sin ventana | `herramientas/prueba_vfx_toy.gd` (0 fallos) |
| Capturas (los 11 PNG del diseño) y GIF de 3 s (`bola`, `bola_vuelo`, `muro`, `pilar`, `barrera`) | esta carpeta |

## Los diez mandos (raíz de cada escena, inspector, grupo «Los diez mandos», con rango)

`altura` (0,3–3) · `ancho` (0,3–2) · `blandura` (0,05–1) · `ondulacion` (0–1,5) · `velocidad` (0,1–4) · `brillo` (0,3–3) · `halo` (0–3) · `tono` (0 fuego, 1 azul) · `chispas` (0–1, proporción) · `luz` (0–4, energía de la luz).
Cada instancia duplica sus materiales al nacer, así que mover un mando en una no cambia las demás. Fuera de los diez: `vida` (segundos que dura al lanzar), `proyectil` (bola), `titileo`, `aparicion` (la anima el AnimationPlayer).

## Método

Todo procedimental, sin texturas de llama ni flipbook. Cada lengua es un plano (`QuadMesh`) con `llama_toy.gdshader`: en metros dentro del plano, la silueta es una gota (semiancho que baja desde el radio hasta cero en la punta con una potencia `afilado`, base redondeada, o un círculo si es bola) más dos ruidos de senos que suben a distinta velocidad (el segundo se resta al primero) que muerden el borde y mecen la punta; el borde se pasa por `smoothstep` ancho (`blandura`), nunca `discard`. Color por rampa continua (naranja → amarillo → blanco crema) según lo hondo que esté el píxel dentro de la lengua, un filo más claro y translúcido en el borde y el corazón más claro en la base. El tiempo no se cuantiza. Capas: exterior grande y tenue, cuerpo, núcleo claro y un halo aditivo (otro plano con caída suave) además de la luz (una `OmniLight3D` con titileo suave en `efecto_toy.gd`) y de 8 a 16 chispas pequeñas aditivas. No hay humo. Muro: 9 lenguas atrás (más altas y tenues) y 8 delante (más bajas y brillantes) más un charco de luz alargado en el suelo. Pilar: tres capas altas con un mando interno `bultos` (anchura que sube y baja en ondas: las bolas apiladas). Barrera: shader en coordenadas del objeto, `lenguas` con torsión y giro, franja de base continua y fresnel para el borde de la cáscara.

Dos cosas que dieron guerra y quedan apuntadas:

- El ruido de valor con `hash` (el de siempre) dejaba **parches rectangulares** en la llama (cada celda del ruido se veía como un bloque con borde duro); se cambió por un ruido liso de senos con dominio deformado y los parches desaparecieron. Tiempo perdido: ≈ 8 min.
- `smoothstep` con los bordes al revés (`smoothstep(1.0, 0.9, x)`) es indefinido en GLSL y dejaba cortes en el borde del plano. Se escribió como `1 - smoothstep(0.9, 1.0, x)`.

## Horas por paso (reloj del PC; salida de la sesión)

| Paso | Marcas | Tiempo |
|---|---|---|
| Leer el diseño, las referencias, la prueba 2 y el lab; traer la infraestructura de la prueba 2 (merge de `claude/prueba2-godot-toon`, solo chocó el diario) | antes de 16:58 | ≈ 10 min |
| Shaders (llama, halo), `EfectoToy`, script de montaje, teclas F1–F6 y diez mandos del lab, script de captura | 16:58 – 17:02 | ≈ 4 min |
| Bola: cuatro rondas de captura (azulada y blanca demasiado, corte de plano, luz que lava) | 17:02 – 17:07 | ≈ 5 min |
| Muro, pilar y barrera: shaders, primera captura, ronda 2 (anillo, cámara por efecto, bultos) | 17:07 – 17:12 | ≈ 5 min |
| Parches rectangulares: diagnóstico (aislar capas, quitar ondulación, cambiar hash) y ruido nuevo | 17:12 – 17:14 | ≈ 8 min (con las rondas de muro) |
| Impacto con pétalos y barrera más naranja (ronda 2 de ambos) | 17:17 – 17:19 | ≈ 3 min |
| Capturas finales, `diez_muros` sin vsync (primero salió 59 fps: era el vsync), 5 secuencias con Movie Maker y GIF | 17:19 – 17:20 | ≈ 3 min |
| `prueba_vfx_toy.gd`, NOTAS, diario | 17:20 – | ver el diario |

Total de reloj de agente ≈ **40 min** de las 16 h de presupuesto. Hora de Pablo con los mandos: pendiente.

## Resultados medidos

- **`diez_muros`** (diez `MuroFuegoToy`, 1920 × 1080, RTX 3070, vsync apagado, media de 60 fotogramas): **717 fps** (`diez_muros_fps.txt`; con vsync da 59 y no dice nada). 10 luces y 140 partículas en total; por efecto, 1 luz y 14 partículas.
- **Presupuesto por efecto** (`prueba_vfx_toy.gd`): bola 1 luz y 26 partículas (8 chispas + 18 de la estela, que solo emite en modo proyectil), muro 1 y 14, pilar 1 y 16, barrera 1 y 14, impacto 1 y 14; todos ≤ 1 luz y ≤ 300 partículas.
- **Prueba sin ventana: 0 fallos** (escenas cargan, contrato, presupuesto, los diez mandos con rango y el mismo en el lab, que los mandos llegan solo a su instancia, `preparar` y `lanzar(vida)`, estilo por el código de los shaders —sin cuantizar, sin contorno, sin umbral duro, rampa continua, ningún rojo oscuro, azul solo por el mando `tono`—, capturas y GIF existen).
- **Las cinco modificaciones de Pablo con un mando o un parámetro** (comprobado con la prueba): (1) fuego azul = `tono` 1; (2) llama el doble de alta = `altura` 2; (3) mitad de chispas = `chispas` 0,5; (4) barrera el doble de grande = escala 2 del raíz (o `preparar` con el volumen doble); (5) pilar que dura 1 s y se apaga = `lanzar(1.0)` (se libera a los 0,87 s). Cronometrado con Pablo: pendiente.

## Lo que no está

- Humo claro escaso: no se puso (el diseño dice «como mucho»).
- La estela de la bola es una nube difusa, no una cola de lengua; la barrera se queda en 3; el impacto, en 3.
- Que los shaders **compilen** se ve porque salen en las capturas (ventana real, Vulkan); la prueba sin ventana solo comprueba que cargan.
- El lab usa el bloom (`glow`) del entorno; no se ha probado el efecto en el entorno del juego, que puede no tenerlo (los halos aditivos están para que no dependa de él, pero el aspecto cambiaría).
- Sin comparar a ojo con la referencia lado a lado en una pantalla de Pablo; los GIF son 640 px de ancho, 24 fps, 192 colores.
