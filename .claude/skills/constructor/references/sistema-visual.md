# Sistema visual premium y reglas de implementación

## Principios (mobile-first, legible, coherente)
- Propósito visible en ~5 segundos; una acción principal por vista.
- Jerarquía: título → ayuda breve → acción → resultado.
- Espaciado: 4, 8, 12, 16, 24, 32 px. Áreas táctiles ≥44 px. Texto base ~16 px.
- Esquinas y sombras coherentes; contraste suficiente; foco visible; etiquetas accesibles; navegación por teclado.
- Respetar movimiento reducido; no depender solo del color para estados.
- Adaptación 360–1440 px; evitar desbordamientos y scroll horizontal.

## Seis familias estéticas
1. **Pastel editorial y agenda** — lila suave, tipografía oscura, banner principal, tarjetas de color, calendario en píldoras, navegación inferior. Uso: agendas, rutinas, planificadores.
2. **SaaS violeta comercial** — violeta, rosa y blanco, tarjetas de servicios, CTAs claros, gráficos sencillos. Uso: servicios, catálogos, herramientas de negocio.
3. **Wellness minimalista** — fondo claro, verde lima suave, registro diario, barras de progreso. Uso: hábitos, trackers, dashboards personales.
4. **Fitness dark** — fondos oscuros, acento verde lima, fotografía, paneles compactos. Uso: rutinas y planes de entrenamiento.
5. **Dashboard de alta densidad** — contraste alto, tarjetas KPI, calendario/timeline, estados de proceso. Uso: administración y operaciones.
6. **Gamificación violeta** — violeta intenso, retos, rachas, puntos, medallas, recompensas. Uso: educación, motivación, fidelización.

## Elegir y aplicar el estilo
- Una familia principal según usuario y tarea; permitir un matiz complementario, sin mezclar todas.
- Referencias = inspiración, no diseños obligatorios. No copiar logos, marcas, textos ni activos protegidos.
- Si el alumno necesita reproducir detalles de una captura, pedir que la adjunte; ante una captura, identificar jerarquía, composición, densidad y paleta.
- No dibujar un marco falso de iPhone.
- Priorizar contenido real sobre decoración; imágenes solo si mejoran la comprensión.
- Ninguna fuente/imagen externa debe ser imprescindible para una función central si hay alternativa.

## Componentes reutilizables
Header contextual · indicador de progreso · tarjeta KPI · campo con etiqueta y ayuda · CTA · pestañas · selector de fecha · resultado principal · estados vacío/carga/error/éxito · modal accesible · gráfica con explicación textual · notificación no intrusiva.

## Antipatrones
Pantallas bonitas pero estáticas · botones sin acción · números ficticios presentados como reales · degradados excesivos · texto minúsculo · contraste insuficiente · gráficos sin explicación · navegación ficticia · animaciones excesivas · imágenes rotas · enlaces que no llevan a ningún sitio.

## Código
Nombres comprensibles; estructura clara; comentarios solo si ayudan; sin dependencias innecesarias; rutas relativas; prevenir desbordamientos; no inventar endpoints, claves ni integraciones; archivo autocontenido solo si simplifica, separar si facilita mantenimiento.

## Formularios
Etiquetas visibles y accesibles; ayuda contextual; errores claros; validación; manejo de datos ausentes y tipos incorrectos; captura mínima; controles táctiles cómodos; estados de carga solo con operaciones asíncronas reales.

## Cálculos
Declarar unidades; validar extremos; comprobar denominadores y entradas no numéricas; redondeo consistente; explicar resultados; probar valores normales, límite e inválidos; no presentar estimaciones como garantías.

## Privacidad y persistencia
Explicar dónde se guardan los datos; no prometer sincronización inexistente; no guardar información sensible innecesaria; `localStorage` no es base de datos segura; no prometer privacidad absoluta; en usos sensibles limitar alcance y requerir revisión humana.
