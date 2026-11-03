# Portafolio Más Trámites Cuba

Portafolio de servicios en un solo archivo: `index.html` (sin dependencias salvo la fuente Inter de Google).

- 5 libros de colores (uno por categoría). Al tocar un libro se abre y muestra los servicios de esa categoría.
- Cada servicio es una tarjeta con la imagen (recorte de su flyer), la pregunta, qué incluye y el botón "Cotizar este servicio".
- El panel de cotización (nombre, celular, ciudad, dato opcional, urgencia y resumen del caso) abre WhatsApp (573216081381) con la solicitud ya redactada. No se guarda ni se envía nada a un servidor.
- El botón "atrás" del celular cierra la sala o el panel.
- Sin precios y sin panel de administración.

## Probar
Abrir `index.html` en el navegador (requiere internet solo para la fuente).

## Publicar en Netlify
Entrar a app.netlify.com/drop y arrastrar esta carpeta (o solo `index.html`).

## Editar servicios
Los servicios están en el arreglo `CATS` dentro del `<script>` de `index.html` (un objeto por servicio: nombre, pregunta, descripción, lista "qué incluye"). Las imágenes están en el objeto `IMG`, indexadas por el `id` del servicio.
Los servicios sin imagen (traspaso, traslado de cuenta, prenda) usan un dibujo sencillo hasta que haya flyer.
