# docs/ — cómo está organizado

Cuatro carpetas por tema. Un documento vive en una sola; si no sabes dónde
va, es que no hace falta crearlo (regla 7 de `proyecto/PROPIETARIOS.md`).

| carpeta | qué hay | dueño |
|---|---|---|
| `proyecto/` | reglas y estado: `CONTEXTO.md`, `PROPIETARIOS.md`, `PLAN_ARREGLOS.md` (el único plan), `DIARIO.md`, `DISENO_FUTURO.md` | Pablo (el diario lo escriben los dos contextos) |
| `arte/` | dirección de arte y assets: `ARTE.md`, `ASSETS_PENDIENTES.md`, `PERSONAJE.md`, `ANIMACION.md`, las referencias PNG, y los borradores de hoy sobre estilo | Pipeline |
| `sistemas/` | contratos y guías de sistemas de juego: `NUEVOS_SISTEMAS.md`, `ESTADOS_SUELO.md`, `runas.png`, y los borradores de técnicas para la maqueta 3D | Juego (lo que es contrato lo lee el Pipeline) |
| `qa/` | lo medido: `QA_ARTE.md`, `TEST2_CONCLUSIONES.md`, `playtests/` (un archivo por sesión de juego) | Juego; los playtests, Pablo |

Fuera de `docs/`, en la raíz: `ARQUITECTURA.md` (lo que el código hace hoy) y
`README.md`. El contrato del pipeline con Godot está en
`export_godot/CONTRATO_GODOT.md`, y el estado de la maqueta 3D en
`poc_25d/LEEME.md`.

**Borradores.** Los documentos creados el 5/10 que no aparecen en la tabla
de `proyecto/PROPIETARIOS.md` §7 están en su carpeta de tema pero son
borradores: su dueño los integra en los vivos y los borra.
