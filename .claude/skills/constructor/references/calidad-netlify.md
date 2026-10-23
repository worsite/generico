# Netlify y control de calidad

## Publicación BLAST
1. Confirmar que `index.html` está en la raíz de la carpeta publicable.
2. Probar localmente.
3. Revisar rutas relativas y recursos.
4. Subir la carpeta o un ZIP compatible por el método manual de Netlify.
5. Abrir el enlace HTTPS generado.
6. Repetir las pruebas esenciales.
7. Si es SPA con rutas de cliente, configurar fallback a `index.html`.

## Publicación PRO
1. Preferir conexión con Git cuando haya build y funciones.
2. Configurar comando de build.
3. Configurar directorio publicable.
4. Configurar funciones de servidor.
5. Añadir variables de entorno.
6. Crear y configurar servicios externos.
7. Aplicar migraciones y políticas RLS.
8. Probar permisos con usuarios diferentes.
9. Revisar errores de red, autorización y datos ausentes.
10. Confirmar que no se filtran secretos al navegador.

## Checklist obligatorio
- [ ] La función principal produce el resultado esperado en los escenarios ejecutados.
- [ ] Todos los botones y enlaces hacen lo anunciado.
- [ ] Los cálculos son reproducibles.
- [ ] Las entradas inválidas generan mensajes claros.
- [ ] Estados vacíos y errores contemplados.
- [ ] Vista móvil revisada.
- [ ] Accesibilidad básica revisada.
- [ ] Sin scroll horizontal accidental.
- [ ] No se exponen secretos.
- [ ] README incluido.
- [ ] Se diferencian pruebas ejecutadas de pendientes.
- [ ] Rutas y recursos revisados.
- [ ] Configuraciones externas pendientes identificadas.
- [ ] No se afirma una publicación que no se ha realizado.

Si no puedes ejecutar el código o usar Netlify, decláralo como pendiente de verificar.

## Matriz de pruebas mínima
| Caso | Resultado esperado |
|---|---|
| Entrada válida | Resultado correcto |
| Campo vacío | Mensaje o valor predeterminado documentado |
| Entrada inválida | Error comprensible |
| Valor mínimo y máximo | Resultado coherente o rechazo explícito |
| Reinicio | Estado realmente restablecido |
| Navegación por teclado | Controles operables |
| Pantalla estrecha | Sin desbordamiento |
| Sin conexión externa | Función offline disponible si se prometió |
| Usuario sin permisos | Acceso denegado en servidor |
| Usuario A y usuario B | Cada uno accede solo a datos autorizados |

En este entorno hay Chromium y Playwright preinstalados: úsalos para probar la app y revisar a 360 px cuando sea posible.
