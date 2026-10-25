# Catálogo Tramicuba

Catálogo de servicios en un solo archivo: `index.html` (sin dependencias salvo las fuentes de Google).

- 28 servicios en 5 categorías; cada uno es una tarjeta con ilustración y nombre.
- Al tocar una tarjeta se abre un panel con la información del servicio y un formulario de cotización
  (nombre, celular, ciudad, dato opcional según el servicio, urgencia y resumen del caso).
- El formulario abre WhatsApp (573216081381) con la solicitud ya redactada. No guarda ni envía datos a ningún servidor.
- Sin precios y sin panel de administración.

## Probar
Abrir `index.html` en el navegador (requiere internet solo para las fuentes).

## Publicar en Netlify
Entrar a app.netlify.com/drop y arrastrar esta carpeta (o solo `index.html`).

## Editar servicios
Los servicios están en el arreglo `CATS` dentro del `<script>` de `index.html`. Las ilustraciones son SVG propios
(objeto `ICONS`); se pueden reemplazar por fotos más adelante.
