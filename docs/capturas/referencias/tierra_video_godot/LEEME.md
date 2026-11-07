# Referencia de tierra: «Godot 3D VFX — Stunning Earth Effects Tutorial (Step by Step)»

Vídeo que pasó Pablo el 7/11/2026: <https://www.youtube.com/watch?v=fe1bjORXeBg> (46:16, VFX For Games).
Revisado por fotogramas clave desde el reproductor, capítulo a capítulo. **No hay vídeo ni fotogramas guardados aquí**: esta ficha es el índice, con el minuto de cada cosa para que puedas ir al sitio.

Es nuestro mismo efecto, hecho por otro camino: una línea de PÚAS que brotan en secuencia, con marcas en el suelo, cascotes y polvo. Las cuatro piezas del `TierraToy` de la entrada 423, una por una.

## Los capítulos

| Min | Capítulo | Qué enseña |
|---|---|---|
| 0:00 | Intro | el resultado final |
| 1:39 | The plan | la receta en tres láminas: 1 púas · 2 + marcas de suelo · 3 + cascotes |
| 2:39 | Spikes | las púas: malla, material y la animación en secuencia (19 min, el grueso) |
| 21:25 | Floor Marks | las grietas del suelo: un **Decal** más mallas de grieta |
| 31:06 | Debris | los cascotes: modelado en Blender y partículas con curva de velocidad |
| 43:22 | Dust Smoke | el polvo: partículas con flipbook de humo |
| 45:25 | End Result | el conjunto |

## Lo que hace, pieza por pieza

**Las púas (2:39).** No son conos de primitiva: salen de un pack gratuito de rocas estilizadas de Sketchfab, «Stylized Rocks - Stones» de lala_vfx (3:55 lo enseña; el autor dice que lo hizo para el tutorial y que es libre). Cada púa es una roca del pack estirada y girada, y en la escena hay diecisiete (`stone01`…`stone17`) colgando de un `AnimationPlayer`.
La secuencia es **una sola animación con una pista `position` por púa**, con los grupos de claves desplazados en la línea de tiempo: eso es lo que las hace brotar una detrás de otra (18:20 enseña la pista por púa, 20:55 el resultado). Cada clave tiene su **easing** a mano en el inspector, no una curva global.
El material de la púa es un shader propio con, entre otros, `Scale`, `Albedo Mix`, `Emission Energy`, `Modulate` y un **fundido vertical** (`Enable Y Fade`, `Fade Start` / `Fade End` / `Fade Power`): la púa se desvanece cerca del suelo en vez de cortarse a ras (27:00).

**Las marcas de suelo (21:25).** Dos capas. Una es un nodo **`Decal`** con una textura de grieta (`T_Groundmark_1.png`) proyectada sobre el suelo, con `Albedo Mix`, `Emission Energy`, `Modulate`, fundido vertical y fundido por distancia (22:40): al ser proyección se adapta al terreno irregular, que es justo lo que a nosotros nos cuesta. La otra son mallas de grieta alrededor de la base de cada púa, animadas con su propia pista y desplazadas igual que las púas (30:30).

**Los cascotes (31:06).** Se modelan en Blender (32:40) y se tiran con un `GPUParticles3D` de malla: el inspector enseña `Spawn`, `Angle`, `Velocity`, velocidad angular, direccional, orbital y radial, y sobre todo una **curva de velocidad** (`CurveTexture`) que cae deprisa al principio y se aplana (37:35, el minuto que marcaste). A 41:20 ya hay cascotes por toda la línea.

**El polvo (43:22).** Otro `GPUParticles3D` con `ParticleProcessMaterial` y una textura de **flipbook de humo** (`T_VFX_flipbookSmoke72.png`), con curva de escala, curvas de color, variación de tono y turbulencia.

## Qué nos vale y qué no

**Nos vale:**
- La **secuencia por pista con easing por clave** es lo mismo que ya hacemos con `PASO_PUA_S` y `SUBE_PUA_S`, así que confirma el camino; lo que podemos robarle es el **sobrepaso y el easing distinto por púa** en vez de uno igual para todas.
- El **fundido vertical del material** (`Y Fade`) para que la púa no corte a ras de suelo. Hoy la nuestra sí corta.
- El **Decal para las grietas**: resolvería que nuestras grietas sean un quad plano que no se pega al terreno irregular.
- **Púas hechas de rocas de verdad, estiradas**, en vez de conos: es exactamente lo que ya hicimos en la entrada 421 con la piedra del mundo, y explica por qué las nuestras parecen láminas (son conos de pocos lados, no rocas).

**No nos vale tal cual:**
- Todo lo de cascotes y polvo va con `GPUParticles3D`, que está descartado en este proyecto por la GPU integrada: lo nuestro son MultiMesh por CPU. La **forma** (curva de velocidad que cae deprisa y se aplana, turbulencia, variación de tono) sí se puede copiar a mano.
- El estilo es semirrealista, con textura de roca fotográfica. Lo nuestro es toon con color plano, como decidiste el 6/11.
- El pack de Sketchfab no hace falta: ya usamos la piedra del mundo, que además nos ata a la paleta del nivel.

## Lo que propongo cambiar en `TierraToy`

1. **Engordar la púa** (ya estaba pendiente): menos lámina y más roca, por el camino de la entrada 421.
2. **Fundido vertical en `tierra_roca.gdshader`** para la base de la púa.
3. **Easing y sobrepaso distintos por púa**, no el mismo para las catorce.
4. **Grietas como decal** en vez de quad, si el coste lo permite.
5. **Subir el color de la púa**: en el juego salen casi negras contra la hierba del Bosque (visto en `toys_nuevos/tierra_linea_procedural_*`).
