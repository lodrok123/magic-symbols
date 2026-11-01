# Prueba 3, camino C (Unreal 5.8 con packs de Fab): candidatos de fuego estilizado

Fecha de la búsqueda: 2026-11-01. Sin iniciar sesión en ninguna cuenta, sin descargar ni instalar nada. Todo leído de páginas públicas de Fab (con el navegador integrado y los datos JSON que sirve la propia web), de itch.io y de búsquedas web.

**Referencia de estilo usada para puntuar:** `docs/capturas/comparativa_vfx/referencia_toy/eow_hierba.jpg` y su LEEME (llama blanda, degradado blanco-amarillo a naranja, resplandor, formas redondas y gordas, sin humo negro, sin contorno duro).

**Cómo he puntuado «Estilo» (1–5):** a ojo, solo con las imágenes de la galería de cada ficha (no he visto los vídeos ni abierto los packs). 5 = casi igual a la referencia, 1 = nada que ver (realista o píxel).

**Cosas que conviene saber antes de leer las tablas**
- Los precios de Fab que muestra la web van con IVA (21 %). Donde pone «Personal», es la licencia estándar de Fab para un creador o equipo pequeño que no supere 100 000 $ de ingresos o financiación en 12 meses; **permite uso comercial** dentro de ese límite. La «Profesional» es para estudios mayores y es de pago. Para Pablo vale la Personal.
- Las versiones de motor son las que declara el vendedor en Fab. «5.8» solo cuenta si lo dice la ficha; si el máximo es 5.6 o 5.7 no significa que falle en 5.8, pero Fab no lo garantiza (ver «Riesgo de versión» al final).
- Fab no deja leer sus fichas con WebFetch (error 403); por eso el contenido de cada pack sale de la descripción del vendedor y de la galería, no de abrirlo.

## Tabla 1. Gratuitos (ordenados por ajuste al estilo)

Cobertura: ✔ cubre bien, ~ cubre a medias (hay que montarlo o reusar), ✘ no lo trae. Efectos: **Bola** estática / **Proy** bola proyectil con impacto / **Muro** 6,9 × 1,5 m / **Pilar** 4 m / **Barr** barrera esférica r 1,5 m.

| # | Pack (autor) | Enlace | Precio / licencia | Motor | Qué trae | Cobertura | Estilo | Qué habría que ajustar |
|---|---|---|---|---|---|---|---|---|
| 1 | **Stylized Fire VFX** (Vefects) | https://www.fab.com/listings/d2855faa-e4df-4acd-8f08-07dd5933d276 | Personal 0 € (Profesional 37,84 €). Licencia estándar de Fab | 4.27 y 5.0–5.8 (**sí 5.8**), v1.0.11, actualizado 9-ago-2026 | Material + instancias de material, variantes de color y de forma, presets de Niagara con parámetros expuestos. «9 llamas elementales con variaciones», incluye «Radial Flames» (aros de llama alrededor de una esfera). Texto del vendedor: «Free Stylized Anime Fire» | Bola ✔, Barr ✔ (las llamas radiales), Proy ~ (la bola con estela), Muro ~ y Pilar ~ (apilar o escalar llamas), sin impacto propio | **3** | Las llamas son finas y con borde marcado (anime), no blandas y gordas. Suavizar la opacidad en el material, empujar el color a blanco-amarillo en el centro y naranja en el borde, añadir bloom y luz puntual. Impacto: reusar un burst de otro pack |
| 2 | **Stylish Fire VFX (Free asset)** (VfxSTOCK) | https://www.fab.com/listings/01e8534c-5877-4ce2-8948-9a696100de11 | Personal 0 € (Profesional 21,62 €). Licencia estándar | 5.0–5.6 (**no declara 5.7 ni 5.8**), publicado 18-sep-2025 | «Más de 4 efectos» en Niagara: llama alta de aspecto pintado, orbe de fuego en espiral, más de la familia «Basic Pack» (energía, escudo de color). Color y brillo por capa cambiables «en 2 clics». Etiquetas Toon, Anime, Cartoon, Glow | Bola ✔, Pilar ✔ (llama alta), Muro ~ (varias llamas en fila), Barr ~ (orbe/escudo del Basic Pack, hay que tintarlo), Proy ~ | **3** (la llama es la más blanda de las gratuitas, pero sale roja) | Quitar el rojo (la mezcla va de rojo oscuro a naranja) y subir el núcleo a blanco-amarillo; con eso se acerca mucho al fuego de la referencia. Hay un mensaje en el foro de que el parámetro «Color» no cambia el color de la llama: tocar el color en cada capa del sistema |
| 3 | **Candle VFX** (Vefects) | https://www.fab.com/listings/98e82577-7a94-4a30-b5b4-b5a2d6073061 | Personal 0 € (Profesional 16,21 €). Licencia estándar | 4.27–5.8 (**sí 5.8**) | Sistema de velas con llamas que titilan, varios estilos de vela, tamaño y color parametrizables | Bola ✔ (llama pequeña, redonda y brillante, como las antorchas de Link's Awakening), el resto ✘ | **4** (solo como bola/llama de juguete) | Escalar la llama; es la mejor forma blanda y redonda de todas, pero no trae muro, pilar ni barrera. Sirve de «pieza» para repetir en muro/pilar |
| 4 | **Perfect Fire VFX** (Vefects) | https://www.fab.com/listings/d2136c01-8d35-403f-a637-146e8173bdb3 | Personal 0 € (Profesional 32,44 €). Licencia estándar. Misma versión en itch.io «Free Fire VFX» a «paga lo que quieras», sin licencia escrita: https://vefects.itch.io/free-fire-vfx-unreal-engine | 4.27–5.8 (**sí 5.8**) | 15 sistemas Niagara de fuego (tamaños Big, Medium, Small, Floor 01, Floor 02; cada uno con variante Normal, Simple y con humo), 6 emisores, 2 materiales, 10 instancias, 17 texturas, 1 Blueprint, sonido de fuego en bucle. Emisores CPU | Bola ✔ (Small), Muro ✔ (Floor en fila), Pilar ✔ (Big), Proy ~, Barr ~ (suelo en anillo) | **2–3** (fuego pintado pero más bien realista; en itch.io lo etiquetan «photorealistic») | Usar las variantes «Simple» (sin humo), quitar el humo oscuro, bajar el detalle de la textura y aumentar bloom/suavizado. Es la mejor opción por cobertura, no por estilo |
| 5 | **Free Flame Vfx Pack** (Fateloom) | https://www.fab.com/listings/30953ced-726e-4a2d-a432-1662886b66e5 | Personal 0 € (Profesional 81,13 €). Licencia estándar | 5.4–5.8 (**sí 5.8**) | 2 efectos: llama de antorcha y «Flame Fx». Color, duración y tamaño editables en Niagara. Forma parte de un bundle de pago de Fateloom | Bola ~, Pilar ~, el resto ✘ | **2** (híbrido realista/estilizado, llama tipo hoguera) | Pocas piezas y estilo más naturalista; solo como base de llama extra |
| 6 | **M5 VFX Vol.2 Fire and Flames (Niagara)** (M5VFX) | https://www.fab.com/listings/c5b0270a-a295-4644-a4be-42cb1e56a197 | 0 € en las dos licencias (colección permanente patrocinada por Epic), 4,8 de 5 en 233 reseñas | 4.15–4.27 y 5.0–5.7 (5.8 no declarado) | Velas, hogueras, fuego, llamas y explosiones; presets por Blueprint, escala global del efecto | Bola ~, Muro ~, Pilar ~, impacto (explosión) ✔; Barr ✘ | **2** (realista) | Solo útil como explosión de impacto de reserva; hay que tintarlo y suavizarlo mucho |
| 7 | **Niagara Examples Pack** (Epic Games) | https://www.fab.com/listings/0e188eca-4e54-4fb2-a9ed-d8b8a565e600 | 0 € en las dos licencias. Licencia estándar de Fab | **Solo 5.7** (carpeta «NiagaraExamplesPack») | Más de 50 sistemas: explosiones, impactos de bala, trails, chispas, fuego, humo, buffs y debuffs de jugador, relámpagos, mapa de galería con la lógica de juego (proyectiles, impactos, canales de datos) | Proy ~ (la lógica de proyectil + impacto sí), Barr ~ (buff alrededor del jugador); estilo del fuego ✘ | **1–2** | Es el mejor ejemplo para *cómo* montar proyectil, impacto y aura con buenas prácticas, no para el aspecto. Hay que migrarlo a 5.8 (ver riesgo de versión) |
| 8 | **Stoneage: VFX** (wizardhatstudio / ka1gar, itch.io) | https://wizardhatstudio.itch.io/stoneage-vfx | «Paga lo que quieras» (gratis). Uso personal, educativo y comercial; se puede editar y teñir; **prohíbe revender o subir el pack a otros mercados** | «Solo Unreal Engine», archivos UE5 sin versión concreta | Niagara de estilo low-poly: Campfire Small, Campfire Big, Torchfire, humo, hojas, luciérnagas (9 MB) | Bola ~ (torchfire), el resto ✘ | **1** (low poly cúbico) | No encaja con la referencia (llama facetada); solo se lista porque es gratis y con licencia comercial clara |

Descartados tras mirarlos: *Free Torch Fire* (CodePhase, 5.1–5.8, antorcha realista), *Basic Fire VFX* (Narr, 5.6–5.7, realista), *Mayu's Basic VFX Pack* (5.7, mezcla de efectos básicos sin fuego propio claro y licencia sin leer), *VFX Low Poly Fire Particles* (5.5–5.7, llamas de cubos), *RPG Cinematic Flame Attack [FREE]* (VRhinoFX, 5.7–5.8, lanzallamas cinemático realista), *Free Pack Fire Effects* (PolyOne, hecho para Unity URP, no vale para Unreal). En itch.io y GitHub no apareció ningún pack de fuego toon gratuito con licencia abierta (CC0, CC-BY o MIT) para Unreal; lo más parecido son los de Vefects y Stoneage ya listados.

## Tabla 2. De pago baratos (menos de 30 €, solo alternativa)

Precios con IVA según la página (Personal; la Profesional es más cara).

| # | Pack (autor) | Enlace | Precio Personal | Motor | Qué trae | Cobertura | Estilo | Nota |
|---|---|---|---|---|---|---|---|---|
| A | **Niagara Stylized Fire Vol. 1** (Gabriel Aguiar Prod.) | https://www.fab.com/listings/257ddb76-5e55-43c3-9a6e-c47a5b5288f1 | 10,80 € (Profesional 21,62 €) | 4.27–5.7 | 13 fuegos estilizados en Niagara con parámetros expuestos, cambio de color, textura y velocidad; forman parte del «Niagara Mega Pack Vol. 2» | Bola ✔, Pilar ~, Muro ~, Barr ~ | **3** (bolas de fuego pequeñas de colores, blandas) | La mejor relación calidad/precio para fuegos de forma redonda; sin reseñas aún |
| B | **Stylized Fires VFX** (Fire Forest) | https://www.fab.com/listings/405be863-0ba2-43de-9253-c536c73afd19 | 5,40 € (Profesional 10,80 €) | 5.5 | 4 fuegos estilizados con color propio, aspecto de llama pequeña brillante | Bola ✔ | **3** | Solo 4 efectos, de un tamaño |
| C | **VFX Fireball** (Fire Forest) | https://www.fab.com/listings/8305ad85-6f5c-43f9-b3f6-896118f4e785 | 6,47 € (Profesional 10,80 €) | 5.5–5.7 | Bola de fuego y proyectiles con estela sobre fondo oscuro | Proy ✔ (sin impacto declarado) | **3** | Valdría para el proyectil; el impacto lo tendría que dar otro pack |
| D | **Stylized VFX Environment (Fire/Smoke)** (Splatchy Labs) | https://www.fab.com/listings/1819224e-2e3a-4608-b66f-533246b92af5 | 16,21 € (Profesional 22,69 €) | 5.0–5.6 | 3 fuegos (llamas, chispas, bolas de fuego), 4 humos, 4 escenas montadas (hoguera, energía oscura); estilo «casual» caricaturesco | Bola ✔, Proy ~ | **2–3** | Trae humo (en la referencia no hay), sin reseñas |

Un poco por encima de 30 €: *Fire Flipbook VFX* (3D Chest, 32,44 €, 5.0–5.7, flipbook pintado a mano con **contorno rojo duro**, estilo 2, https://www.fab.com/listings/28f79d82-e51d-426e-8a0e-2e141fc916bc) y *Stylized VFX - Fire* (VRhinoFX, 32,44 €, 5.5–5.8, 70 fuegos con sub-UV, https://www.fab.com/listings/6d737c6a-cf43-4805-afae-d6e73ab62d6f). En el antiguo Marketplace, *Stylized Fire Effects* de VFXmania (25 efectos) no se migró a Fab, solo está en la Vault del Launcher y llega a 5.3, así que no sirve para 5.8.

## Recomendación: instalar de 1 a 3

1. **Stylized Fire VFX (Vefects)**: gratis, declara 5.8 y es el que cubre más efectos del encargo con parámetros y variantes de color (bola, barrera con las llamas radiales, algo de proyectil).
2. **Stylish Fire VFX (VfxSTOCK)**: gratis y con la llama alta más blanda de las gratuitas; da el pilar y el muro. Compensa su problema (rojo, hasta 5.6) con retoque de color.
3. **Candle VFX (Vefects)**: gratis, declara 5.8, mismo autor y misma instalación que el 1; da la llama redonda y brillante «de juguete» para la bola estática.

No he metido en la recomendación el *Niagara Examples Pack* (solo 5.7, estilo realista), aunque sirve de guía para montar proyectil con impacto. Si Pablo quiere reforzar el estilo redondo con un gasto mínimo, la alternativa es **Niagara Stylized Fire Vol. 1** (10,80 €).

Ninguna de las tres trae por sí sola los cinco efectos con el aspecto de la referencia: hay que contar con retoque de materiales (suavizar bordes, degradado blanco-amarillo a naranja, bloom, luz cálida). Es lo que mide la prueba.

## Pasos exactos para que Pablo los añada a `E:\UnrealProjects\MS_POC_VFX`

Hace falta su cuenta de Epic (yo no he iniciado sesión en ninguna). Hacerlo para los tres packs.

**A. Añadir a la biblioteca (en fab.com)**
1. Abrir en el navegador cada enlace de la recomendación (arriba) e iniciar sesión con la cuenta de Epic.
2. En la ficha, abrir el desplegable **Licencia** y elegir **Personal** (precio 0 €). No elegir Profesional.
3. Pulsar **Añadir a mi biblioteca** (en inglés «Add to My Library»). Debe aparecer el aviso de que ya está en la biblioteca.

**B. Meterlo en el proyecto, vía A: Epic Games Launcher**
1. Cerrar el editor de Unreal si está abierto con MS_POC_VFX.
2. Abrir el Epic Games Launcher → **Unreal Engine** → **Biblioteca** → sección **Biblioteca de Fab**.
3. Buscar el pack por nombre y pulsar **Añadir al proyecto** (en inglés «Add to Project»).
4. En la ventana, elegir la versión de motor **5.8** (si el pack no ofrece 5.8, ver el riesgo de versión) y elegir el proyecto **MS_POC_VFX** (si no aparece en la lista, abrirlo una vez desde el Launcher o usar la vía C).
5. Confirmar con **Añadir al proyecto**; el Launcher copia el contenido al `Content` del proyecto.

**C. Meterlo en el proyecto, vía B: plugin de Fab dentro del editor**
1. Abrir `MS_POC_VFX` en el editor de Unreal 5.8.
2. Menú **Ventana → Fab** (aparece como pestaña). Iniciar sesión con la cuenta de Epic si lo pide.
3. Ir a **Mi biblioteca**, buscar el pack y pulsar **Añadir al proyecto** (o **Importar**), y confirmar.

**D. Comprobar**
1. En el Content Browser buscar `NS_` (sistemas de Niagara) y la carpeta con el nombre del pack. Si no salen, Edit → Plugins → comprobar que **Niagara** está activo y reiniciar.
2. Abrir el mapa de demostración que trae cada pack, si lo hay, para ver los efectos antes de montar los cinco de la prueba.

## Riesgo de versión (5.8)

- *Stylized Fire VFX* y *Candle VFX* declaran 5.8, no hay riesgo.
- *Stylish Fire VFX* declara hasta 5.6 y el *Niagara Examples Pack* solo 5.7: el Launcher puede no dejar elegir 5.8. Camino de reserva: descargarlo a la Vault (Biblioteca de Fab → Descargar), abrirlo en un proyecto vacío de la versión que ofrece (5.6 o 5.7) y usar **Migrate** hacia `E:\UnrealProjects\MS_POC_VFX\Content`, o copiar la carpeta de contenido a mano. Los sistemas de Niagara suelen subir de versión sin problema, pero hay que abrirlos y guardar para comprobarlo (y apuntarlo en la tabla de la prueba).

## Qué no he podido comprobar

- No he visto ningún vídeo ni abierto ningún pack: las puntuaciones de estilo salen de capturas de la galería de Fab.
- La licencia exacta de «Mayu's Basic VFX Pack» y de «Free Fire VFX» (itch.io) no está escrita en sus páginas; por eso no los recomiendo.
- Los precios y versiones pueden cambiar; los valores son los que mostraba Fab el 2026-11-01.
