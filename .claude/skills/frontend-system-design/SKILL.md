---
name: frontend-system-design
description: Checklist de diseño de sistemas frontend (Frontend System Design Guide) para decidir la arquitectura de una aplicación web: requisitos, plataforma, SPA/MPA/SSR, estado, APIs, rendimiento, seguridad, accesibilidad, i18n, QA y MVP. Úsalo al planificar o revisar la arquitectura de un frontend.
argument-hint: "[aplicación o decisión de arquitectura a analizar]"
---

# Frontend System Design

Solicitud: $ARGUMENTS

Guía genérica (sin sesgo de framework) para arquitectura frontend. Recorre el checklist en este orden y quédate solo con lo que aplique; no conviertas el resultado en un cuestionario largo, declara supuestos.

1. **Ingeniería**: tamaño de equipo, base de usuarios, conocimiento disponible, cumplimiento, expectativas, código abierto vs propietario, documentación/PRD, roadmap.
2. **Alto nivel**: plataforma (escritorio/móvil/tablet), SPA vs MPA, SSR/SSG/CSR, PWA, stack, SEO, CI/CD, UX, A/B testing, MVP, arquitectura de servidor, seguridad, estado, i18n, E2E, autenticación/autorización, roles, QA.
3. **Bajo nivel**: estructura de código/carpetas, mobile-first vs desktop-first, componentes, formularios, almacenamiento, diseño de API, instrumentación, design system, rutas, CSS, lazy loading, accesibilidad, imágenes, paginación/debounce/throttle, rendimiento (FCP, LCP, TTI, CLS), versionado, pruebas unitarias.
4. Define el **MVP** (problema → solución → MVP → clientes) y los casos límite y de fallo.

Detalle completo del checklist: [references/checklist.md](references/checklist.md). Manual en PDF: `references/FE_SE_Handbook.pdf`.

En miniapps BLAST/PRO del skill `constructor`, usa esta guía para justificar la arquitectura elegida.

Origen: devkodeio/frontend-system-design (MIT).
