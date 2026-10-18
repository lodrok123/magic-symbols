# Clips de lanzar a UNA mano para el héroe (17 de octubre de 2026)

Encargo T-CP4 de `claude/LAB_CASTPOINT.md` (§4): tres clips para `woodland_wanderer` (esqueleto `mixamorig`, el GLB que usa el juego es `woodland_wanderer_suave.glb`) con la
**mano derecha lanzando y la izquierda sujetando un libro cerrado al pecho**: (1) lanzar al frente, (2) invocar hacia arriba, (3) señalar o golpear el suelo delante.
Cada uno corresponde a un origen del punto de conjuración (`mano_libre`, `manos_alto`, `suelo_delante`).

## Qué se ha hecho y por qué no con Mixamo ni Meshy
**Los tres clips ya existen**, generados por Pipeline sobre el propio esqueleto (cinemática inversa de los dos brazos y las piernas, columna girada en ejes del mundo; sin Blender
porque en la sandbox no hay). Motivo: ningún clip de Mixamo/Meshy trae **la mano izquierda quieta sujetando un libro** — todos balancean los dos brazos —, y recolocar
un brazo de un clip ajeno hace el mismo trabajo que generarlo. Esta ruta (Mixamo/Meshy) queda aquí **como alternativa** si Pablo prefiere movimiento capturado.

| clip | rol propuesto | origen | duración | qué hace |
|---|---|---|---|---|
| `CastOneHandFront` | `cast_mano_frente` | `mano_libre` | 1,10 s | la mano derecha se arma junto al hombro con el torso girado hacia atrás y se lanza al frente (palma hacia abajo-delante) |
| `CastOneHandUp` | `cast_mano_alto` | `manos_alto` | 1,30 s | recoge la mano a la altura de la cadera y la sube arriba y hacia un lado (la cabeza es enorme: pasa por fuera), el torso se arquea, palma hacia arriba |
| `CastOneHandGround` | `cast_mano_suelo` | `suelo_delante` | 1,20 s | puño alzado, se agacha y apunta/clava hacia el suelo de delante con el torso inclinado |

## Medidas (sandbox, leyendo el GLB ya escrito; 1 «altura» = la y de la cadera: 0,735 m en el primer fotograma, 0,797 en reposo)
| clip | cadera en el suelo (cuenta de `Pj3D._desplazamiento`) | cadera en 3D (en reposo / cadera→cabeza) | máxima extensión de la mano que lanza | mano del libro (recorrido máx.) |
|---|---|---|---|---|
| `CastOneHandFront` | 0,07 | 0,09 / 0,20 | t = 0,70 s (fotograma 21 a 30 fps, 64 % del clip) | 0,04 / 0,10 alturas |
| `CastOneHandUp` | 0,03 | 0,07 / 0,15 | t = 0,95 s (fotograma 28, 73 %) | 0,04 / 0,08 |
| `CastOneHandGround` | 0,06 | 0,10 / 0,23 | t = 0,75 s (fotograma 22, 62 %) | 0,06 / 0,14 |

«Máxima extensión» = el fotograma en que la mano llega más lejos de la cadera **en la dirección del lanzamiento** (adelante / arriba / adelante-abajo). La distancia a la cadera a secas no sirve en
el golpe al suelo: el puño alzado de la preparación queda más lejos que el golpe. Los tres cumplen cadera < 0,3 y libro < 0,2 también con la unidad más estricta (cadera→cabeza = 0,358 m).

Todos empiezan en la misma postura de «listo» (libro al pecho, mano derecha delante) y **se quedan en la pose de extensión máxima hasta el final**: `Pj3D.lanzar()` reproduce el clip
sin bucle y lo mantiene hasta `soltar_lanzar()`.

## Si se hacen con Mixamo
1. Sube el GLB/FBX del héroe a Mixamo (auto-rig) o usa `woodland_wanderer_suave.glb` ya con esqueleto. Los nombres `mixamorig:*` coinciden.
2. Busca clips de lanzar de **una mano** (palabras: «1H magic attack», «1H cast spell», «magic heal», «point», «ground punch»/«kneeling punch»). Los nombres exactos **no los he podido comprobar** (sin acceso a Mixamo desde aquí); elige por la vista previa.
3. Descarga **sin piel** (*Without skin*), 30 fps, con **«In Place» marcado** (sin avance de la cadera).
4. Importa a Godot, y **sustituye las pistas del brazo izquierdo** (Shoulder/Arm/ForeArm/Hand izquierdos) por las del libro al pecho: se puede pedir a Pipeline (hace el mismo IK que los clips actuales sobre el clip descargado).
5. Nombres: `CastOneHandFront` / `CastOneHandUp` / `CastOneHandGround` (los mismos de arriba) para que los SINONIMOS no cambien.

## Si se hacen con Meshy (animación por texto, si el plan lo ofrece)
Pegar en el campo de descripción de la animación, en inglés, **un clip por generación**; el personaje es el rig `mixamorig` del héroe:

**Front**
```
A small chibi mage stands in place with the left hand holding a closed book against the chest, the left arm almost still. The right arm cocks back beside the shoulder, the torso twists slightly back,
then the right hand thrusts forward at shoulder height in one quick one-handed spell cast, open palm facing down and forward. Hold the extended pose. No walking, no root motion, feet planted, 1.1 seconds.
```
**Up**
```
A small chibi mage stands in place, left hand holding a closed book against the chest, left arm almost still. The right hand gathers low beside the hip, then sweeps up and slightly outward
above the head, open palm facing up, while the torso arches back and the head looks up, a one-handed summoning gesture. Hold the raised pose. Feet planted, no root motion, 1.3 seconds.
```
**Ground**
```
A small chibi mage stands in place, left hand holding a closed book against the chest, left arm almost still. The right fist is raised beside the head, then the character crouches slightly,
leans the torso forward and points or strikes the ground in front with the right hand, arm fully extended down and forward. Hold the final pose. Feet planted, no root motion, 1.2 seconds.
```

## Criterios de aceptación (los mismos que se han medido en los clips generados)
Con la herramienta del lab (`LabHumanoide3D`, sección «Casts a una mano») o en el sandbox:
1. **Cadera**: se aleja del primer fotograma **< 0,3 alturas** (la altura de la cadera en reposo; se da también en cadera→cabeza, más estricta).
2. **Mano que lanza**: anotar el **fotograma de máxima extensión** (distancia hombro→mano máxima) para que el Juego dispare el conjuro ahí.
3. **Mano del libro**: recorrido máximo **< 0,2 alturas** en todo el clip.
4. Empiezan en la postura de listo y terminan sosteniendo la pose de máxima extensión.
