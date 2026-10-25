# Arquitectura técnica

## Nivel 1 — BLAST
Arquitectura mínima para miniapps que funcionan en el navegador sin servidor propio, cuentas ni secretos.

**Casos:** calculadoras, presupuestadores, quizzes offline, generadores de texto, trackers locales, planificadores personales, herramientas informativas sencillas.

**Estructura** (proyecto pequeño):
```
mi-miniapp/
├── index.html
└── README.md
```
Cuando separar facilite el mantenimiento:
```
mi-miniapp/
├── index.html
├── styles.css
├── app.js
├── README.md
└── assets/
```

**Persistencia local (`localStorage`)**: solo preferencias e información no sensible. Explicar siempre que: los datos permanecen en el navegador/dispositivo; no hay sincronización entre dispositivos; no se crean cuentas; no sustituye una base de datos compartida; no es lugar para secretos o datos sensibles.

**Calidad BLAST:** controles funcionales; respuesta clara a acciones; validación de entradas; errores comprensibles; diseño adaptable desde 360 px; accesibilidad por teclado; reinicio funcional; exportación/compartición del resultado cuando corresponda; README con instrucciones, límites y pruebas.

## Nivel 2 — PRO
Se usa cuando se requieren capacidades que no deben resolverse con HTML estático.

**Cuándo:** cuentas y autenticación; datos compartidos; sincronización entre dispositivos; permisos y roles; APIs privadas; webhooks; automatizaciones; pagos; validación de servidor.

**Arquitectura orientativa (no obligatoria; justificar):** frontend estático o SPA en Netlify + Netlify Functions para lógica de servidor + Supabase Auth y Postgres si encaja.

**Seguridad PRO**
1. Nunca incluir secretos de servidor en HTML o JS del navegador.
2. Nunca exponer la clave `service_role` de Supabase al cliente.
3. Secretos en variables de entorno del servidor.
4. Aplicar y comprobar políticas RLS.
5. Validar entradas en cliente y servidor.
6. No confiar en roles declarados solo por el cliente.
7. No almacenar contraseñas manualmente.
8. No simular que las integraciones están configuradas.
9. Verificar pagos y webhooks en servidor.
10. No conceder beneficios de pago por un clic en el frontend.

**Entregables PRO:** árbol de carpetas; `package.json` si hay build; migraciones SQL; nombres de variables de entorno (sin secretos reales); guía de configuración; comandos de desarrollo/build/pruebas; configuración de Netlify; pruebas con usuarios distintos y sesiones anónimas; comprobaciones de permisos, errores de red y datos ausentes.

**Límite importante:** Netlify aloja el frontend y ejecuta funciones, pero no incluye una base Postgres integrada. Publicar el frontend no configura automáticamente Supabase, autenticación, pagos ni APIs.
