---
name: diseno
description: Atajo /diseno (escrito "/diseño"). Activa la suite UI/UX Pro Max para diseñar, construir, revisar o corregir interfaces (estilos, paletas, tipografía, accesibilidad, layout responsive, componentes, design systems). Úsalo cuando el usuario escriba /diseno o /diseño, o pida decisiones de diseño visual o UX.
argument-hint: "[qué diseñar, revisar o mejorar]"
---

# /diseño — UI/UX Pro Max

Solicitud: $ARGUMENTS

1. Invoca la skill `ui-ux-pro-max` con la herramienta Skill, pasándole la solicitud anterior. Es el núcleo: reglas por prioridad (accesibilidad, táctil, rendimiento, estilo, layout, tipografía/color, animación, formularios, navegación) y un buscador local de datos.
2. Genera primero un design system con el buscador antes de escribir UI:
   `python .claude/skills/ui-ux-pro-max/scripts/search.py "<tipo de producto> <sector> <palabras clave>" --design-system -p "Nombre"`
   (otros usos: `--domain ux|style|color|typography|chart`, `--stack <stack>`).
3. Si la tarea encaja, apóyate también en las skills hermanas de la suite:
   - `design-system` — tokens, especificaciones de componentes y presentaciones.
   - `ui-styling` — shadcn/ui + Tailwind.
   - `brand` — voz, identidad visual y guías de marca.
   - `banner-design` — banners y piezas gráficas.
   - `slides` — presentaciones HTML con Chart.js.
   - `design` — router general de diseño (logos, CIP, iconos, social).
4. Si se está construyendo una miniapp con `/constructor`, esta skill decide la parte visual y `/constructor` conserva las reglas de arquitectura, honestidad y entrega.

Requiere Python 3 para el buscador. Origen: nextlevelbuilder/ui-ux-pro-max-skill (MIT).
