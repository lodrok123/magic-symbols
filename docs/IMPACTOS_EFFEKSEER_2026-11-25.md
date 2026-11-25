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

## Aplicado al juego (25/11/2026, decisión de Pablo)

Pablo: «de la explosión del barril sí tomaba lo suyo, porque en nuestro caso hay una explosión ascendente cuando debería tener un foco y expandirse uniformemente desde el foco en todos los ángulos. El resto (humo, halo y suelo) es mejor lo nuestro. Golpe hit: añadía el halo a lo que ya tenemos. Del resto de apreciaciones estoy de acuerdo».

| Impacto | Qué cambia | Archivo |
|---|---|---|
| Explosión del barril | **Fuera** las lenguas que subían y las chispas en cono hacia arriba. **Nuevo núcleo** (`NUCLEO`): 14 bocanadas del flipbook que salen de un foco a ~1 m y se abren en esfera, repartidas por igual (espiral de Fibonacci), y 22 trazos de chispa en todas direcciones. Se quedan la bola, la onda del suelo, las brasas y el humo. | `explosion_fuego_toy.gd`, `impacto_capas_toy.gd` (`expande`) |
| Golpe de fuego (estilo C) | Suma el halo blando, la estrella grande de rayos (0,1 s) y el aro de luz (0,17 s) de hit01 (`halo_hit01`, activo por defecto). | `impacto_fuego_toy.gd` |
| Golpe de agua en el suelo | Dos anillos más (sin charco) cada 0,07 s detrás del primero. | `impacto_agua_toy.gd` |
| Golpe de tierra | 14 fragmentos pequeños y rápidos (debris), más rasantes y que llegan más lejos. | `impacto_tierra_toy.gd` |

Hojas con el resultado (la fila «AHORA» ya lleva los cambios): `docs/capturas/impactos_effekseer/aplicado/hoja_*.png`.

## Aro nítido y distorsión (25/11/2026, segunda ronda, Pablo: «aro nítido + distorsión»)

Las dos piezas que faltaban, sin texturas nuevas:

- **Aro de choque nítido** (`presentacion/vfx/toy/aro_choque.gdshader`). Anillo de borde duro con anti-alias de un píxel, en dos tonos toon de la rampa (cuerpo y filo exterior), entero o partido en arcos afilados (medias lunas). Mezcla normal, no aditiva: sumado sobre el suelo claro, el naranja se lavaba a crema. Es la pieza `aro` de ImpactoCapasToy: crece, adelgaza y se apaga.
- **Distorsión del aire**. Es el `calor.gdshader` de siempre con una máscara nueva (`mascara = 2`, anillo) que empuja la imagen hacia fuera. Lo que ya lo usaba no cambia. Es la pieza `distorsion`.

Dónde se usan:

| Impacto | Qué lleva |
|---|---|
| Golpe de fuego (estilo C) | El aro de choque de hit01 y su distorsión, además del halo y la estrella. |
| Explosión del barril | Un aro de choque TUMBADO en el suelo (Pablo: «tumbarla en el suelo»; de pie, el suelo lo cortaba en cúpula), que llega al radio en 0,28 s, por delante de la onda blanda (0,38 s), y el aire que se deforma desde el foco. |
| ToonHit (receta del lab) | HitBase, HitSub y Ring ya son arcos y aros nítidos tumbados en la pared: ahora sí se parece al original. |

Hojas: `docs/capturas/impactos_effekseer/aro_distorsion/`. Ojo: la distorsión solo se nota sobre fondo con dibujo. En el suelo liso del lab casi no se ve; en el borde de la pared, sí.

## Bolas en vuelo: estela que se queda en el mundo (25/11/2026, tercera ronda)

Pablo: «revisa cómo hace el repositorio una bola de fuego y demás elementos… es un elemento mejorable en todos los elementos». Para la prueba eligió fuego, agua y tierra.

En la demo de Effekseer solo hay un proyectil de verdad, `ef_fire01_projectile`. La bola **no arrastra su cola**: cada instante suelta una bocanada que **se queda donde nació**. La bocanada vive 0,13–0,4 s, encoge y se enfría. La cola sale sola, larga, irregular y más fina hacia atrás, y deja leer el recorrido. El resto de efectos (hielo, rayo, viento, sagrado) son de área o impactos.

Cómo estaban nuestras bolas con la cámara del juego (`docs/capturas/estela_mundo/hoja_proyectiles_todos_antes.png`):

- **Agua:** una canica casi sin estela. Era la más floja.
- **Fuego:** una llama corta.
- **Tierra:** una roca con piedrecitas.
- **Hielo:** un cristal pálido que se pierde sobre la hierba.
- **Rayo:** bien.
- **Viento:** grande y recargado.

**Nueva pieza:** `presentacion/vfx/toy/estela_mundo_toy.gd`.

- Va suelta en la escena, como hermana de la bola. Sigue a la bola mientras vuela y suelta una bocanada cada pocos centímetros.
- Cuando la bola choca o muere, termina de apagarse y se libera sola.
- La cuelga `EfectoToy` solo en la BOLA de fuego, agua y tierra (`_estela_elemento`).
- Cada elemento usa piezas que ya existían:
  - **Fuego:** bocanadas del flipbook con la parte roja de la rampa, que encogen y se enfrían, más brasas que se desprenden.
  - **Agua:** vaho de espuma (humo toon con los colores del agua) más gotas que caen.
  - **Tierra:** polvo pardo (humo toon de TierraToy) más granitos que caen.
- **Escala:** sigue la raíz del radio, con un mínimo de 0,6. La bola del juego mide 0,12 m de radio y, a escala lineal, la estela quedaba de pocos centímetros.
- **Visibilidad:** las MultiMesh llevan una caja de visibilidad que cubre todo el mapa. Si no, Godot las descartaba lejos del origen.

**Estado:** ENCENDIDA de serie desde el 25/11 (Pablo: «Sí, enciende la estela»; `EstelaMundoToy.activa = true`). Antes la cola se abre y ondula (cada bocanada con deriva lateral y vaivén). OJO: F4 del lab lanzaba la bola VIEJA de la prueba 3 (`BolaFuegoToy.tscn`); ahora lanza la oficial `FuegoToy` a 0,12 m. En `LabVfxComparativa3D`, **Ctrl+8** la enciende, **F4** lanza la bola en vuelo y **Z** cambia de elemento. Prueba: `herramientas/prueba_estela_mundo.gd` (19 comprobaciones). Antes y después en el juego: `docs/capturas/estela_mundo/hoja_estela_antes_despues.png`, que se regenera con `captura_vfx_en_juego.gd -- <carpeta> fuego,agua,tierra proyectil procedural estela`.

**Revisión de la bola de fuego** (Pablo: «no me gusta la bola de fuego»):

- **Disco amarillo pálido encima de la bola en vuelo.** Eran los «trocitos» de FuegoToy: miden 0,2 m fijos, casi el ancho de la bola del juego (0,24 m), y van pegados a ella. Ahora solo salen con la bola quieta y a escala de la bola (`docs/capturas/estela_mundo/bola_fuego_disco_trocitos.png`: arriba en medio, sin los trocitos, ya no está).
- **Estela del fuego.** Las bocanadas eran más grandes que la cabeza, iban separadas como pompones y tenían un naranja plano. Ahora son del ancho de la cabeza o menos, van seguidas (cola continua que se estrecha) y tienen más contraste: se enfrían deprisa hacia el rojo. Las brasas, antes amarillo pálido, son naranja-rojo (`bola_fuego_cerca_revision.png`).

**Bola de fuego oficial** (25/11, Pablo: «integra la bola como la versión oficial»): FuegoToy BOLA del juego (r 0,12) con la estela encendida y sin trocitos en vuelo. En el lab, **F4** = la bola del juego con su ciclo entero (carga → suelta → vuelo con estela → pared), del elemento de **Z**.

**Revisión de agua y tierra** (25/11, Pablo: «mira el resto, agua y piedra»): el agua dejaba nubes blancas de algodón (el agua en el aire no hace espuma) y la tierra una cadena de polvo tan gruesa como la roca, encima de los terrones que ya trae TierraToy. Ahora el agua deja un rocío de gotas que caen en arco con un vaho azulado pequeño junto a la bola, y la tierra un polvo fino y espaciado con más granitos (`agua_cerca_antes/despues.png`, `tierra_cerca_antes/despues.png`; arriba de lado, abajo con la cámara del juego; izquierda sin estela, derecha con ella).

**Flecha de tierra aprobada; bola de agua afinada** (25/11, Pablo: «flecha de tierra aprobada, afina agua»). En vuelo la bola de agua se hace GOTA: cabeza redonda y la mitad de atrás afilada y alargada en cola (uniform `gota` de `agua_esfera` y `agua_esfera_atras`, que movía `AguaToy._forma_vuelo`), tiembla un poco como un líquido y las cintas que la envolvían («balón de playa») bajan a opacidad 0,26. Quieta y en la carga sigue siendo la esfera de siempre (`agua_gota_vuelo.png`).

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
