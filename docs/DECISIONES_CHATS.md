# Decisiones que solo estaban en los chats

Recogidas el 21/10/2026 de la exportación de claude.ai: los chats Juego, Pipeline, Análisis del proyecto, QA de arte y Zelda (EoW).
Aquí está **solo lo que no figuraba en ningún otro documento del repo**. Lo que ya está en ARQUITECTURA, DISENO_FUTURO, PLAN_ARREGLOS o DIARIO no se repite.
Cuando una decisión se pase a su documento natural, se borra de aquí.

## 1. Gramática visual de los hechizos (Pipeline, 29/09) — regla madre

> El sello controla la macroforma y el comportamiento; el elemento controla la microanimación y el material.

| lo decide el ELEMENTO | lo decide el SELLO/GLIFO |
|---|---|
| color, textura, partículas, luz, microanimación | silueta, dimensiones, orientación, trayectoria, persistencia, distribución |

- La barrera es **una superficie continua** cuyo contorno coincide con el círculo dibujado: «Barrera debe parecer una cosa, no seis cosas».
- Flecha + fuego y flecha + rayo son el mismo proyectil, girado 90° respecto al resto.
- **Por qué:** así un elemento nuevo funciona con todos los glifos sin hacer un VFX por combinación. Es la misma idea de «comportamiento son datos» que sigue el código.

## 2. El paso de 2D a 3D (Pipeline y QA de arte, 2–5/10)

**Hasta el 3/10.** El flujo era Meshy → autorig → Blender, que renderizaba 8 direcciones → atlas → AnimatedSprite2D.

**Por qué se abandonó:**
- «el acabado de los personajes no se acerca al terreno».
- «se siente el tono plastificado del 3D».
- Pablo, el 3/10: «el bloqueo de arte viene de que renderizo 3d con escenario».
- Las animaciones en sprites eran inviables de mantener.

**4/10, prueba de concepto 2,5D:**
- Personajes chibi y paleta pastel.
- Referencia: Link's Awakening.
- Cámara inclinada.
- Kenney descartado por «muy low poly».

**5/10.** Arte validado; el canon es la elfa chibi (ver `RETIRADA_ARTE_ANTERIOR.md`).

**La vuelta a 2D que se planeó no se hizo:** el juego se quedó en 3D (Jolt, `.glb`, piezas `.tscn`).

> **Deuda de documentación:** `ARQUITECTURA.md` (Animación, Vista isométrica, Arte) y la cabecera y §3–§8 de `ARTE.md` todavía describen la era 2D.

## 3. Diseño de juego

- **Penalizar los hechizos poderosos lanzados sin preparación** (playtest del 29/09): «cualquiera podría parar el juego, convocar un meteorito y seguir». La tinta y la recarga lo cubren en parte, pero el principio no está escrito como regla.
- **Ideas aparcadas sobre acumular glifos iguales:** 2 flechas = chorro continuo, 6 flechas = rayo largo, varias barreras = barreras de distinto radio. La regla vigente (18/10) es otra: el 1.er glifo activa y los siguientes suman alcance o persistencia. Esto queda como posible evolución.
- **Elementos compuestos al estilo Magicka** (fuego + tierra = meteorito): solo aparece «magma, por definir» en DISENO_FUTURO.

## 4. Estilo y arte

**Referencias, por orden de aparición:**
- Little Goody Two Shoes (luz y saturación)
- Genshin
- Link's Awakening (estética general y fuego)
- Tears of the Kingdom (marco del inventario)
- Echoes of Wisdom (diorama, DOF, agua)

**Árboles**
- Sin rojo («se ve de pegote»).
- Verdes y amarillos en degradado; se admiten variantes otoñales.

**Goblins**
- Piel verde oscuro.
- Todos con la altura del warrior.

**Escala**
- El tamaño de referencia es el del personaje **corriendo**, no en idle.

**Contornos y bordes (3D)**
- Sin contorno por bloque.
- Sin biseles a 45°.

**Presupuesto de polígonos**
- Equipo: 15k como máximo.
- El resto está en `arte/meshy/PRESUPUESTO.md`.

**Postura final de chibi_elf (QA)**

| hueso | ángulo |
|---|---|
| cabeza | -4° |
| cuello | 8° |
| columna | 6° |
| brazos | 24° |
| rodillas | 12° |
| pies | 0° |
| pelvis | -14° |

## 5. Herramientas y entorno

- **Motor:** se evaluaron Unreal 5 (dos veces) y Terrain3D. Se sigue con Godot 4.7.
- **Máquinas:**
  - Sobremesa: `C:\Users\pablo\Documents\magic-symbols`.
  - Portátil / PC del trabajo: `C:\Users\paranda\Documents\GitHub\magic-symbols`.
  - Antes de escribir hay que comprobar cuál está enlazada.
- **Sincronización:** GitHub (`SUBIR_A_GITHUB.cmd` / `BAJAR_DE_GITHUB.cmd`). OneDrive se probó el 5/10 y se descartó ese mismo día. `SUBIR_A_ONEDRIVE.cmd`, `BAJAR_DE_ONEDRIVE.cmd` y `ORDENAR_DOCS.cmd` siguen en la raíz, pero ya no se usan.
- **Organización de los chats en claude.ai:**
  - JUEGO (código de juego).
  - PIPELINE (arte, VFX, audio).
  - «Análisis del proyecto»: dirección. Planifica, reparte y redacta los prompts; no programa.
  - QA de arte.
  - Las reglas están en `PROPIETARIOS.md`. Los avisos van al final de `DIARIO.md` (solo se añade, nunca se reescribe).

## 6. Estudio de Echoes of Wisdom (21/10)

- **Objetivo:** «Al saber como se ha hecho antes no se parte a ciegas». Se estudia cómo resolvió los problemas técnicos, **sin copiar assets**.
- **Síntesis:** `docs/ANALISIS_EOW.md`. Anexos en `docs/estudios/eow/`.
- **Plan:** `docs/PLAN_EOW.md`. Pendiente pasarlo a `PLAN_ARREGLOS.md` como Fase 15.
