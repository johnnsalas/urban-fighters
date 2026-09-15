# Urban Fighters — prototipo móvil

Juego de lucha 2D arcade original, ambientado en barrios urbanos de España. El proyecto está preparado para Godot 4.3 o superior y usa gráficos procedurales, por lo que se puede ejecutar sin descargar recursos adicionales.

## Contenido de esta versión

- Cuatro luchadores: Kael, Luna, Dani y Naira.
- Tres escenarios: azoteas de Barcelona, Metro de Madrid y puerto de València.
- Selección de personaje y rival controlado por CPU.
- Combates al mejor de tres rounds, cronómetro, vida y energía.
- Puño, patada, ataque especial, bloqueo, salto y movimiento.
- Controles táctiles para móvil y controles de teclado para pruebas.
- Resolución base 1280×720 adaptable a pantalla horizontal.

## Cómo probarlo

1. Instala Godot 4.3 o posterior.
2. Abre Godot y pulsa **Importar**.
3. Selecciona `project.godot`.
4. Pulsa **Ejecutar proyecto**.

Controles de teclado: A/D para desplazarse, W o espacio para saltar, S para agacharse, J para puño, K para patada, L para especial e I para bloquear.

## Exportación móvil

El proyecto ya contiene un preset llamado **Android APK**, configurado para generar `build/UrbanFighters.apk`, con soporte ARM de 32 y 64 bits y modo de pantalla completa. Instala las plantillas de exportación de Godot y configura el SDK/JDK. Después abre **Proyecto → Exportar**, selecciona **Android APK** y pulsa **Exportar proyecto**. Para iOS, crea un preset iOS y completa la exportación final desde Xcode en macOS. La orientación prevista es horizontal.

## Próxima fase recomendada

Sustituir las figuras generadas por sprites pixel art animados, añadir sonido y música originales, ajustar hitboxes, implementar dificultad y completar el modo arcade con presentación e historia de cada luchador.
