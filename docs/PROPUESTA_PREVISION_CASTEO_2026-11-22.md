# Previsión durante el casteo

22 de noviembre de 2026. Propuesta e implementación inicial solicitadas por Pablo.

## Criterio

La preparación insinúa la función del hechizo con su propia silueta, sin texto explicativo ni otra demostración. Las propiedades de `Hechizo` determinan el resultado; no se escriben recetas especiales por parejas de glifos.

Los contornos de preparación son abiertos, tenues, sin colisiones, sin luces y sin efectos de juego. Desaparecen al emitirse el disparo: solo la manifestación real protege, daña o modifica el mundo. La previsión actual de trayectorias, casillas, rebotes y reacciones permanece como referencia de alcance y resultado.

Para evitar duplicación visual, la protección local sustituye el fantasma esférico relleno por el contorno abierto. En un volumen móvil solo se omite ese fantasma en la casilla de Mid; los destinos posteriores se conservan. Se filtra una copia para dibujo, sin modificar los datos de la simulación.

## Funciones y formas

Se respeta la prioridad de ejecución: suelo/plataforma, órbita, haz, volumen móvil, proyectil, colocación y protección/área local.

| Propiedades finales | Preparación propuesta |
|---|---|
| Barrera local, sin desplazamiento ni colocación | Cúpula tenue y abierta alrededor de Mid; no parece una defensa ya activa. |
| Barrera con Flecha: volumen móvil | Silueta geométrica pequeña en la mano y dirección de salida. No deja una falsa protección alrededor de Mid. |
| Flecha: proyectil | Forma en la mano orientada hacia el objetivo; el recorrido real existente permite apuntar. |
| Línea que produce haz | Dos trazos cortos desde la mano insinúan emisión dirigida; el indicador actual limita el recorrido. |
| Suelo, plataforma o colocación | Contorno abierto en el origen de construcción calculado por el lanzador; el fantasma existente muestra ocupación y viabilidad. |
| Retorno y copias sin desplazamiento: órbita | Aro interrumpido y marcas de orbes alrededor de Mid, con el radio derivado de la misma regla de ejecución. |
| Volumen local sin barrera | Silueta abierta en su origen, sin presentarla como protección. |

La silueta conserva las proporciones X/Y/Z. La figura sostenida en la mano es una miniatura; los indicadores del mundo conservan el tamaño y recorrido reales.

## Glifos y modificadores disponibles

- **Línea X/Z y Altura:** modifican las proporciones de la silueta. No fuerzan una burbuja esférica para todas las formas.
- **Flecha:** comunica salida dirigida; con Barrera anuncia un volumen móvil.
- **Barrera:** comunica protección personal únicamente si el resultado es local.
- **Repetición:** marcas laterales para copias simultáneas; marcas longitudinales para la ráfaga ya definida por la receta. El recorrido existente sigue mostrando los proyectiles reales.
- **Retorno:** conserva el recorrido existente; con copias y sin Flecha se anuncia la órbita.
- **Rebote, Buscar y Perforar:** conservan la previsión de recorrido y reacciones. No añaden iconos que puedan tapar los avisos enemigos.
- **Crecer y Permanencia:** conservan el tamaño y las propiedades de la receta. Esta primera versión no simula visualmente toda su duración futura.
- **Pulso:** conserva la previsión de efectos existente. No se confunde el contorno de preparación con un pulso activo.
- **Carga:** la silueta permanece durante el retardo del casteo; el tiempo real de activación no cambia.
- **Suelo y Posición:** la preparación aparece en el origen de colocación, no en una burbuja personal.
- **Hijos:** se representa el padre actual. La simulación completa de hijos sigue siendo una mejora independiente; no se inventan destinos ni consecuencias que la previsión actual aún no calcula.

## Integración

Un nodo visual en `magia/prevision_casteo_3d.gd`, creado por el lanzador, reutiliza una malla. Se actualiza al apuntar y se conserva durante el conjuro. Se retira al cancelar, morir, interrumpirse el conjuro, disparar o abandonar el árbol.

No cambia controles, animaciones, coste, recarga, daño, protección ni el momento del cast point. Usa la dirección y el objetivo que ya calcula el lanzador. Los VFX oficiales de fuego y agua se conservan; el contorno funcional complementa su carga.

Puede apagarse mediante `Lanzador3D.PREVISION_CASTEO_ACTIVA` para comparar con el comportamiento anterior.

## Verificación

- Clasificar cada pareja de glifos actual con los seis elementos, sin mutar los hechizos.
- Comprobar las prioridades de Barrera+Flecha, Suelo+Flecha, haz y órbita.
- Verificar ausencia de colisiones y efectos, reutilización de malla y limpieza de conexiones.
- Verificar cancelación, muerte, disparo e interrupción.
- Ejecutar regresiones de previsión y cast points.
- Renderizar una matriz de las funciones principales y comprobar legibilidad y distinción frente a un efecto activo.

## Resultado de la implementación

Implementado en `E:\magic-symbols`:

- `magia/prevision_casteo_3d.gd`: clasificación, contornos, seguimiento del cast point y limpieza.
- `magia/lanzador_3d.gd`: integración al apuntar y conjurar; filtro exclusivamente visual de los fantasmas del origen.
- `herramientas/prueba_prevision_casteo.gd`: 1.536 recetas de parejas de glifos con seis elementos y 1.560 comprobaciones; 0 fallos.
- `herramientas/escenario_prevision_casteo.gd`: preparación, ausencia de gasto/defensa, cancelación, funciones, casteo real y desactivación; 0 fallos.
- `herramientas/prueba_apuntado.gd`: actualizadas las expectativas de protección local; 56 comprobaciones, 0 fallos. Se conservan las expectativas antiguas con la función desactivada.
- Regresiones: `prueba_prevision_hechizo` (166 comprobaciones) y `prueba_cast_points`, ambas con 0 fallos.

Se han renderizado y revisado capturas de protección personal, Flecha, barrera móvil, haz, Suelo, órbita, muro y casteo real, usando el renderizador Compatibility para la captura. La capa visual no incorpora físicas, luces ni cambios de balance.

Los escenarios completos imprimen avisos de recursos al cerrar. La regresión de simulación también imprime avisos de materiales nulos y de una metainformación de congelación ausente. Se han reproducido con la previsión nueva desactivada; no se han modificado esos sistemas ajenos a este encargo.

La simulación completa de hijos, las nuevas distribuciones de copias y una representación temporal completa de Crecer/Permanencia siguen fuera de esta primera versión.
