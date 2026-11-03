# Portafolio Más Trámites Cuba

Portafolio de servicios en un solo archivo: `index.html` (sin dependencias salvo las fuentes de Google).

- Estilo oscuro con 5 puertas de colores (una por categoría). Al tocar una puerta se abre la sala con los servicios de esa categoría.
- Cada servicio se muestra como una tarjeta con su ilustración, descripción y botón "Cotizar este servicio".
- El panel de cotización (nombre, celular, ciudad, dato opcional, urgencia y resumen del caso) abre WhatsApp (573216081381) con la solicitud ya redactada. No se guarda ni se envía nada a un servidor.
- El botón "atrás" del celular cierra la sala o el panel.
- Sin precios y sin panel de administración.

## Probar
Abrir `index.html` en el navegador (requiere internet solo para las fuentes).

## Publicar en Netlify
Entrar a app.netlify.com/drop y arrastrar esta carpeta (o solo `index.html`).

## Editar servicios
Los servicios están en el arreglo `CATS` dentro del `<script>` de `index.html`; los colores de las puertas, en `META`.
