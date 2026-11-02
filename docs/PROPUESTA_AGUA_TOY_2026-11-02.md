# Propuesta: agua «toy» (02/11/2026)

Pablo pide agua con sus referencias (`docs/capturas/comparativa_vfx/referencia_agua/ref_agua_*.png`): bola, ola (muro), pilar/géiser (explosión hacia arriba), haz de agua, explosión de área y salpicadura, casteo en la mano y partículas sutiles. «No esperes input mío: propón y empezamos desde ahí.» «No crees otro lab: básate en los que ya hay.»

## Rasgos del agua (de las referencias y de PLAN_VFX_ELEMENTOS §1.2/§2.2)

- Translúcida de **tres tonos** por umbral: azul medio, celeste, cresta casi blanca. **No brilla**: blend_mix, sin emisión, sin luz propia.
- Borde claro por fresnel. Interior con cáusticas que se mueven.
- Todo lo que sube **cae**: gravedad en gotas, coronas y olas. La espuma está en las crestas y en la base.
- Animación fluida (igual que FuegoToy). Misma escala y ejes que FuegoToy, para que un hechizo cambie de elemento sin cambiar de tamaño.

## Estructura

- **`AguaToy extends EfectoToy`** en `presentacion/vfx/toy/agua_toy.gd`, clase **hermana** de FuegoToy. Tiene las mismas figuras: BOLA, MURO (= ola), PILAR (= géiser), BARRERA (= cúpula de agua) y HAZ. Se construye desde los ejes x/y/z con `definir` / `describir(h)` / `desde_hechizo(h)`, y tiene la misma API de carga e impacto (`empezar_carga`, `soltar`, `impactar_en`, `rebotar`, `terminar_sin_choque`, `finalizar`).
- **No se refactoriza FuegoToy ahora.** Está aprobado, se sigue iterando y se cubre con dos pruebas. Por eso AguaToy copia la máquina de carga e impacto en vez de subirla a una base común. La unificación (`FiguraToy`) queda para cuando los dos elementos estén aprobados.
- Se reutiliza tal cual `FuegoToyMallas` (geometría pura) y `EfectoToy` (mandos, materiales por instancia, nacer/vivir/morir).
- Shader común nuevo `agua_toy.gdshaderinc`: mix, 3 tonos por umbral, fresnel, flujo de ruido, espuma por umbral, fundido de canto y de profundidad (como FuegoToy). Usa la rampa de `VfxAgua.rampa()`, ya validada.
- `ImpactoAguaToy` (salpicadura) y la carga de agua van en archivos propios.

## Recursos

- **LeLu** (ya en `assets/vfx/lelu_noise/`, uso libre):
  - `T_Noise_Wf4` (cáusticas), `T_Noise_W5i` / `T_Noise_Wo14` (flujo), `T_LiquidVertical_Wave` (cortina de ola y pilar).
  - `T_wavesKI96` (picos de la corona), `T_Wave43` / `T_Wave66` (frente de ola y chorro).
  - `T_VFX_Ex1d` / `T_VFX_SparklesF21` (salpicadura), `T_VFX_Spiral07` (remolino de bola y casteo), `T_VFX_CircleFit1` (charco), `T_VFX_RoundSmoke71` (vaho).
- **Kenney smoke particles** (CC0): `whitePuff*` teñido para espuma y rocío. Se copian a `assets/vfx/kenney_puff/` solo los que se usen.
- **Gotas y burbujas**: generadas por código (SDF / GradientTexture), como `_textura_blanda()` de FuegoToy. Las pegatinas antiguas del proyecto son de otro estilo.
- **Vefects (Shockwaves, Trails, Stylized Fire «Water»)**: **solo como referencia** de valores y aspecto. Su EULA prohíbe subirlos a repositorios públicos y el proyecto está en GitHub. Además, son ports de Unity con rutas fijas. No se copian a `res://`.

## Figuras

| Figura | Cómo |
|---|---|
| Bola | Billboard/esfera con cáusticas y fresnel; 2–3 cintas en espiral alrededor (banda con `T_Wave43`); en vuelo estela de cinta y gotas que caen; cabeza mayor que la estela. |
| Ola (muro) | Banda `perfil_muro` con `T_LiquidVertical_Wave` subiendo y cresta `T_Wave66` con espuma; láminas Y-billboard en profundidad (lo aprendido con el muro de fuego); al morir **cae** y deja charco. |
| Pilar / géiser | Cilindro con cortina que sube + corona de picos `T_wavesKI96` (láminas Y-billboard) + anillo de onda en la base + gotas que suben y caen. |
| Barrera | Cúpula de agua translúcida: fresnel fuerte, cáusticas que fluyen, aro en el suelo (mismo esquema que la barrera de fuego de la referencia). |
| Haz | Cono `haz_cono` que nace de un punto (lo aprendido con el haz de fuego), flujo `T_Noise_W5i`, núcleo claro, cintas enrolladas, gotas sueltas, abanico de salpicadura al final. |
| Explosión de área / impacto | Corona de lenguas que suben y caen + charco/anillo ondulado que se expande y se desvanece + gotas en corona con gravedad (MultiMesh por CPU, mix) + vaho. Pequeña para impacto de proyectil, grande para área. Si cae en agua real, `AguaOndas3D.impulso`. |
| Casteo | Gotas pequeñas que convergen hacia la mano y forman la esfera, remolino pequeño, anillo de ondas en el suelo bajo los pies. Sin brillo. |

## Lab

En `laboratorios/LabVfxComparativa3D.tscn` (sin lab nuevo):
- La tecla **Z** alterna el elemento **fuego / agua**.
- **G / B / N / M / R** (carga, impactos, fin y rebote), **F7** (figuras), los ejes **U–L** y **F9** (hechizos) valen para el elemento activo.
- Las funciones del lab que hoy hacen `FuegoToy.new()` pasan a crear según el elemento.

## Verificación

- Prueba nueva `herramientas/prueba_agua_toy.gd`: figuras, carga, impacto y presupuesto (0 luces del agua, ≤300 partículas, 0 materiales aditivos en el cuerpo). Las pruebas de FuegoToy siguen en 0.
- Capturas con ventana junto a las referencias, cámara del juego, cercana y horizontal, y secuencias de animación.

## Orden

1. Bola + casteo + salpicadura (el ciclo de un proyectil).
2. Haz.
3. Pilar/géiser + explosión de área.
4. Ola.
5. Barrera.
