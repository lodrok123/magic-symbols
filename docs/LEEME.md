# docs/ — cómo está organizado

**Empieza por aquí (2/11/2026):**

- [`GDD.md`](GDD.md): qué juego es, pilares, bucle, qué está decidido y qué no (dos páginas).
- [`DIRECCION_2026-11-02.md`](DIRECCION_2026-11-02.md): dónde está el proyecto y por dónde seguir.
- [`CONTEXTO.md`](CONTEXTO.md) y [`PROPIETARIOS.md`](PROPIETARIOS.md): cómo se trabaja y quién toca qué.

Los documentos nuevos van fechados `NOMBRE_AAAA-MM-DD.md` y se enlazan desde este archivo.

> Aviso: la tabla de carpetas de abajo (`proyecto/`, `arte/`, `sistemas/`) es de la reorganización del 5/10 y **no refleja la disposición actual**: hoy los documentos están sueltos en `docs/`, con `qa/`, `Playtests/`, `capturas/` y `maqueta_3d/` como subcarpetas. Sin reescribir por no estar en el encargo; las rutas de abajo (`proyecto/PROPIETARIOS.md`, `poc_25d/LEEME.md`) ya no existen.

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
