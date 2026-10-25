---
name: accion
description: Atajo /accion. Carga y aplica juntas todas las skills de ingeniería instaladas: superpowers (flujo completo), frontend-system-design, fabricjs y diseno (UI/UX Pro Max). Úsalo cuando el usuario escriba /accion para ejecutar una tarea de desarrollo con el máximo rigor.
argument-hint: "[tarea a ejecutar]"
---

# /accion — todas las skills

Tarea: $ARGUMENTS

Si no hay tarea, pregunta cuál en una sola frase. Con la tarea definida, invoca con la herramienta Skill, en este orden y sin omitir ninguna que aplique:

1. `using-superpowers` — reglas base de cómo usar las skills.
2. `brainstorming` — aclarar el objetivo y el diseño antes de tocar código.
3. `frontend-system-design` — decisiones de arquitectura frontend (si hay interfaz o app web).
4. `diseno` — decisiones visuales y de UX con UI/UX Pro Max (si hay interfaz).
5. `fabricjs` — solo si hay lienzo/canvas interactivo.
6. `writing-plans` → `executing-plans` (o `subagent-driven-development` / `dispatching-parallel-agents` si hay trabajo independiente).
7. Durante la implementación: `test-driven-development`, `systematic-debugging` ante fallos, `using-git-worktrees` si conviene aislar.
8. Al cerrar: `requesting-code-review`, `receiving-code-review`, `verification-before-completion` y `finishing-a-development-branch`.

Reglas: si una skill no aplica a la tarea, di en una línea cuál omitiste y por qué; no afirmes haber verificado nada sin evidencia; si la tarea es una miniapp para publicar en Netlify, complementa con `/constructor`.
