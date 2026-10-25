---
name: fabricjs
description: Guía de uso de Fabric.js, la librería de canvas HTML5 (formas, texto, imágenes, grupos, interacción, serialización JSON/SVG/PNG). Úsalo cuando una app necesite un editor o lienzo interactivo: dibujar, mover/escalar/rotar objetos, exportar imágenes, editores de diseño, firmas, anotaciones.
argument-hint: "[qué construir con canvas]"
---

# Fabric.js

Solicitud: $ARGUMENTS

Librería JavaScript para canvas HTML5 con interacciones listas (mover, escalar, rotar, sesgar, agrupar), formas, controles, animaciones, filtros de imagen, degradados, patrones y pinceles; E/S en JPG, PNG, JSON y SVG. Tipada y modular. Última versión del repositorio fuente al instalar: 7.4.0.

## Uso mínimo (HTML plano, sin build — ideal para BLAST)
```html
<canvas id="canvas" width="300" height="300"></canvas>
<script src="https://cdn.jsdelivr.net/npm/fabric@6.4.3/dist/index.js"></script>
<script>
  const canvas = new fabric.Canvas('canvas');
  canvas.add(new fabric.Rect({ top: 100, left: 100, width: 60, height: 70, fill: 'red' }));
</script>
```
Con bundler: `npm install @fabricjs/browser` e `import { Canvas } from '@fabricjs/browser'` (el paquete `fabric` sigue funcionando por compatibilidad). Node: `@fabricjs/node`. Mantén `fabric` y los `@fabricjs/*` en la misma versión.

## Reglas prácticas
- En React/SPA, crea el `Canvas` en un efecto y llama a `canvas.dispose()` al desmontar.
- Un canvas no es accesible por sí solo: ofrece alternativa de teclado/texto para acciones críticas y no dependas del canvas para información esencial.
- Exportar: `canvas.toDataURL({ format: 'png' })`; guardar/restaurar: `canvas.toJSON()` / `canvas.loadFromJSON(...)`; recuerda que `localStorage` es local y no sensible (reglas de `/constructor`).
- Si fijas versión por CDN, declara cuál (verifica la actual; el ejemplo oficial usa 6.4.3) y no inventes APIs: consulta `references/instalacion-y-paquetes.md` y la documentación oficial (fabricjs.com) antes de usar métodos poco comunes.
- Compatibilidad: navegadores modernos (Chrome 64+, Firefox 58+, Safari 11+); no IE11. Node ≥ 20 con node-canvas.

Detalle de instalación y paquetes: [references/instalacion-y-paquetes.md](references/instalacion-y-paquetes.md). Para abrir PRs al repo de Fabric existe `fabricjs-open-pr`.

Origen: fabricjs/fabric.js (MIT).
