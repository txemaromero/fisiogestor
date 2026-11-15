# Decisiones de implementación

Decisiones tomadas en los puntos que la especificación deja abiertos o ambiguos, con su justificación.
Se ordenan por la fase en la que se tomaron.

## Resumen: lo que más se aparta de la especificación o la completa

- **Bootstrap con la gema `bootstrap` + `dartsass-rails`** en lugar de `cssbundling-rails`, que no
  funciona en Windows; no hace falta Node (D3). El CSS compilado se versiona (D10).
- **Devise reducido** a login, registro y validaciones: sin "recordarme" ni editar/borrar la cuenta
  (D14, D21). La recuperación de la clave por email (D76), el segundo factor obligatorio (D84) y la
  confirmación del email al registrarse (D103) se añadieron después.
- **Borrar un paciente borra también sus visitas** (si no, el borrado fallaría por la clave foránea) (D16).
- **Asistente de visita:** las sesiones y técnicas viajan como JSON en un campo oculto (D30); la visita
  se guarda con la fecha del día (D32); una enfermedad creada con "Otra…" toma como descripción la del
  diagnóstico (D33); las sesiones son opcionales (D35).
- **`Diagnosis.filtrar` encadena los criterios en lugar de usar `merge`**, porque `merge` perdía la edad
  mínima al combinarla con la máxima (D40).
- **Añadidos pequeños de interfaz:** nombre del osteópata conectado en la navbar (D23), lista de
  visitas y botón "Crear visita" en la ficha del paciente (D37), sexo y edad del paciente y número de
  técnicas en los resultados del filtro (D42).
- **Seeds ampliadas** con más pacientes y técnicas, y escalas de dolor variadas (D19, D48).
- **Ajustes para Windows** que no cambian nada en Linux/macOS: scripts de `bin/` (D7), preparación de la
  base de datos de test (D20), tests sin paralelismo (D25) y `db:setup` repetible (D49).
- **Seguimiento del tratamiento** (mejora posterior a la especificación): las visitas guardadas se
  pueden editar, borrar y completar con diagnósticos y sesiones (D69), cada diagnóstico muestra su
  progreso (D70) y la ficha, una gráfica de la evolución del dolor (D71).
- **Pruebas complementarias con su fichero** (mejora posterior): PDF, JPG o PNG en Active Storage, sin
  enlaces públicos y descargables solo por el osteópata de la visita (D72); ficheros de ejemplo en las
  seeds (D73).
- **Gestión diaria** (mejora posterior): buscador y paginación de pacientes (D74), agenda de sesiones
  (D75), recuperación de la clave por email (D76) e informe de la visita para imprimir o guardar como
  PDF (D77).
- **Informes y catálogo** (mejora posterior): filtros por fechas y por pacientes propios (D78), gráfica de
  barras y aviso de las medias con pocas sesiones (D79), descarga en CSV (D80) y un rol de
  administrador (D81) que fusiona los duplicados del catálogo (D82).
- **Datos de salud y RGPD** (mejora posterior): consentimiento del paciente para compartir sus datos
  (D83), segundo factor de autenticación obligatorio para todos (D84), registro de quién abre las fichas
  de otros osteópatas (D85), y exportación y borrado de todos los datos de un paciente (D86).
- **Red de osteópatas** (mejora posterior): perfil profesional (D87), verificación de cada osteópata por
  un administrador (D88), casos clínicos anonimizados (D89) con comentarios y técnicas sugeridas (D90), y
  denuncias que modera un administrador (D91).
- **Auditoría de seguridad tras los bloques 5 y 6:** códigos del segundo factor limitados por cuenta,
  límite de login por cuenta, claves de 10 caracteres, cambio de dispositivo con un código del actual y
  logs sin claves ni códigos (D92); avisos por correo de los cambios en el acceso a la cuenta (D93); lo de
  otros osteópatas, solo para verificados (D94); número de colegiado único y quién verifica (D95); más
  anonimato en los casos clínicos (D96) y denuncias que se conservan aunque se borre lo denunciado (D97);
  producción con caché compartida, Puma solo en la máquina, proxies y SSL de la base de datos (D98), y
  sesiones que se revocan al cerrar sesión (D99); reglas del agente de IA reforzadas en la copia local
  (D100); huellas de las gemas en `Gemfile.lock` y versiones acotadas (D101); comprobaciones de seguridad
  en `bin/ci` y en GitHub Actions en cada push (D102).
- **Confirmación del email al registrarse** (mejora posterior): no se puede entrar hasta confirmarlo con el
  enlace del correo, que caduca en 3 días (D103).
- **Tercera auditoría de seguridad** (14 de noviembre de 2026): el enlace del correo pide la clave para
  confirmar el email, el login tarda lo mismo tenga o no la cuenta el segundo factor, el correo de
  producción va siempre cifrado, la comprobación del SSL de la base de datos mira también `DATABASE_URL`, y
  cada límite de intentos tiene su contador (D104).

## Fase 0 — Setup

### D1. Versiones: Ruby 3.4.11 y Rails 8.1.4
Son las últimas estables disponibles (Rails 8.1.4 exige Ruby ≥ 3.2). Devise 5.0 es compatible con Rails 8.1.

### D2. `rails new` ligero
Se omiten los componentes que la aplicación no usa: Docker, Kamal, Thruster, Solid Cache/Queue/Cable,
Action Mailbox, Action Text, Active Storage, jbuilder, RuboCop, Brakeman, bundler-audit y CI de GitHub.
Se mantienen importmap, Turbo y Stimulus (vienen con Rails y cubren el JavaScript de cliente que pide la
especificación), Action Mailer (lo usa Devise) y Minitest + Capybara + Selenium.

### D3. Bootstrap con la gema `bootstrap` + `dartsass-rails` (no `cssbundling-rails`)
La especificación permite la gema `bootstrap` o `cssbundling-rails`. Se probó `cssbundling-rails`, pero
detecta npm/yarn con `command -v`, que no existe en `cmd.exe`: en Windows la tarea `css:build` falla y,
como está enganchada a `test:prepare`, también falla `bin/rails test`.
La gema `bootstrap` (5.3.8) aporta el SCSS y el JS de Bootstrap; `dartsass-rails` lo compila con Dart Sass
(binario incluido en la gema `sass-embedded`). Así **no hace falta Node** y funciona igual en Windows,
Linux y macOS. `dartsass:build` se ejecuta automáticamente antes de los tests y en `assets:precompile`.
Los avisos de obsolescencia de `@import` de Bootstrap 5.3 se silencian en `config/initializers/dartsass.rb`.

### D4. JavaScript de Bootstrap vía importmap
Se sirven `bootstrap.min.js` y `popper.js` desde las gemas `bootstrap` y `popper_js` (Propshaft los
encuentra en las rutas de assets que registran las gemas). Son ficheros UMD: al importarlos quedan
disponibles como `window.bootstrap` y `window.Popper`; los atributos `data-bs-*` (dropdown, modales)
funcionan sin código adicional.

### D5. Estilo: modo oscuro de Bootstrap
`<html data-bs-theme="dark">` y `$body-bg-dark: #343a40` (gris oscuro, `$gray-800`) para el fondo; la
navbar es `bg-success`. Las tablas usan `table-dark` y los botones `btn-success`.

### D6. Español e internacionalización
`config.i18n.default_locale = :es` y zona horaria `Madrid`. Se añaden `rails-i18n` (mensajes de
validación, fechas y meses en español) y `devise-i18n` (mensajes de Devise en español) en lugar de
mantener a mano esos ficheros YAML.

### D7. Scripts de `bin/` multiplataforma
- Rails escribe los shebangs como `ruby.exe` cuando la app se genera en Windows; se cambian a `ruby`
  para que `bin/rails` funcione también en Linux/macOS.
- `bin/dev` es un script Ruby (en lugar de foreman, que no funciona bien en Windows) que lanza
  `rails server` y `dartsass:watch`.
- `bin/setup` invoca `bin/rails` a través de Ruby (en Windows no se pueden ejecutar directamente
  scripts sin extensión) y compila el CSS.

### D8. PostgreSQL en producción
`config/database.yml` define producción con el adaptador `postgresql` y `DATABASE_URL`. La gema `pg`
está comentada en el `Gemfile` para que `bundle install` funcione en cualquier máquina sin tener
instaladas las librerías cliente de PostgreSQL; basta con descomentarla al desplegar.

### D9. Raíz
`/` redirige a `/patients` con un 302 (no 301, que los navegadores memorizan de forma permanente).

### D10. El CSS compilado se versiona
`app/assets/builds/application.css` (Bootstrap compilado, ~230 KB) se incluye en git, aunque Rails lo
excluye por defecto. Así la secuencia `bundle install && bin/rails db:setup && bin/rails s` funciona sin
pasos adicionales. Los tests, `bin/dev` y `bin/setup` lo recompilan automáticamente, de modo que un
cambio en el SCSS aparece en `git status` y se commitea junto con él.

## Fase 1 — Modelos y migraciones

### D11. Nombres de las clases
Los nombres del diagrama con guion bajo se pasan a CamelCase de Ruby: `FamilyMedicalBackground`,
`PersonalMedicalBackground` y `SupplementaryTest` (tablas `family_medical_backgrounds`,
`personal_medical_backgrounds` y `supplementary_tests`). Rails pluraliza `Diagnosis` como `diagnoses`.

### D12. El modelo `Session` conserva su nombre
No ha habido conflictos: la app no usa `ActiveRecord::SessionStore` (las sesiones HTTP van en cookies) y
el propio Rails 8 usa un modelo `Session` en su generador de autenticación. El único riesgo es el helper
`session` (sesión HTTP) de controladores y vistas, así que las variables de este modelo se llaman `sesion`.

### D13. Enumeraciones con columnas `string`
`sexo`, `tipo` y `tipo_prueba` son columnas `string` con `enum` validado: la base de datos es legible
(`"hombre"`, `"digestivos"`) y no depende del orden de los valores; un valor fuera de la enumeración da
un error de validación en lugar de una excepción (y uno vacío, "no puede estar en blanco"; ver D52). Los valores están en constantes con el
nombre del diagrama: `Patient::SEX_TYPE`, `SupplementaryTest::TEST_TYPE` y
`MedicalBackground::BACKGROUND_TYPE` (un *concern* compartido por los dos tipos de antecedentes). Las
etiquetas en español están en `config/locales/es.yml` (`enums.*`).

### D14. Devise sin recuperación de contraseña ni "recordarme"
`Osteopath` usa solo `database_authenticatable`, `registerable` y `validatable`. La especificación no pide
recuperar la contraseña (necesitaría correo) ni la casilla "recordarme", así que se quitan esos módulos y
sus columnas de la migración. *(Después, en el bloque 3 de mejoras, se añadió la recuperación de la
clave: ver D76.)*

### D15. Restricciones en la base de datos
Además de las validaciones, los campos obligatorios son `NOT NULL` y todas las relaciones tienen clave
foránea. `examinations.visit_id` es único (`has_one`) y `sessions_treatments` tiene un índice único
`(session_id, treatment_id)`: una técnica no se repite dentro de la misma sesión.

### D16. Borrados en cascada
La especificación pone `dependent: :destroy` en los antecedentes del paciente y en lo que cuelga de la
visita. Se añade también en `Patient has_many :visits` (sin él, borrar desde "Mostrar pacientes" un paciente
con visitas fallaría por la clave foránea) y en `Osteopath has_many :patients, :visits`. Al borrar una
sesión, Rails elimina sus filas de `sessions_treatments`; el catálogo de técnicas no se toca.

### D17. Catálogos sin duplicados por mayúsculas
`Disease` y `Treatment` validan la unicidad del nombre sin distinguir mayúsculas y normalizan los espacios
(`normalizes`), para que el catálogo compartido no acumule variantes como "Masaje espalda" y
"masaje  espalda".

### D18. Sesiones recomendadas
`Diagnosis#sesiones_recomendadas` debe ser un entero mayor que 0.

### D19. Seeds
Además de los datos pedidos, se añaden tres técnicas (Movilización rotuliana, Fisioterapia respiratoria y
Masaje visceral abdominal) y cuatro pacientes más, para que los diagnósticos que no son de espalda
(condromalacia, bronquitis, intestino permeable) tengan técnicas coherentes. Miopía no tiene diagnósticos
(sirve para ver un filtro sin resultados), una sesión no tiene escala postsesión (los informes de
efectividad la ignoran) y la visita de Pepe Campos tiene exploración y dos pruebas complementarias.

### D20. Base de datos de test en Windows
Rails actualiza la base de datos de test lanzando `system("bin/rails db:test:prepare")`, que en Windows
falla. `lib/tasks/test_prepare.rake` hace que `test:prepare` (que se ejecuta antes de `bin/rails test`)
prepare la base de datos en el mismo proceso. En Linux/macOS no cambia nada.

## Fase 2 — Autenticación

### D21. Registro limitado al alta
`devise_for :osteopaths, skip: :registrations` más una ruta propia con solo `new` y `create`
(`/osteopaths/sign_up` y `POST /osteopaths`). Las páginas de Devise para editar o borrar la cuenta no
están en la especificación, así que no se exponen.

### D22. Comportamiento del login y el logout
- Login obligatorio en todas las páginas salvo las de Devise
  (`before_action :authenticate_osteopath!, unless: :devise_controller?`).
- Tras registrarse o iniciar sesión se va a `/` (que redirige a `/patients`).
- Tras cerrar sesión se va directamente al login, para no encadenar redirecciones y mostrar el aviso
  "Sesión finalizada".
- El logout es un botón (`button_to` con `DELETE`), no un enlace, para que funcione también sin JavaScript.

### D23. Navbar según la sesión
Sin sesión, la navbar solo muestra el título. Con sesión muestra el menú, el nombre del osteópata
conectado (para saber con qué cuenta se está trabajando) y el botón **Logout**.

### D24. Errores de formulario
Los formularios muestran un resumen de errores (`shared/_errores`) y marcan en rojo los campos
erróneos con la clase `is-invalid` de Bootstrap. Se desactiva el `<div class="field_with_errors">`
que Rails añade por defecto, porque rompe la maquetación de Bootstrap.

### D25. Tests en paralelo
En Linux/macOS los tests se ejecutan en paralelo por procesos (la opción por defecto de Rails). En
Windows no hay `fork()` y la alternativa con hilos falla con SQLite (los hilos comparten la conexión
de los fixtures transaccionales), así que allí se ejecutan en un solo proceso.

## Fase 3 — Pacientes

### D26. Tablas de antecedentes editables
La especificación deja elegir entre `accepts_nested_attributes_for` y campos ocultos generados por JS.
Se usa `accepts_nested_attributes_for` (con `allow_destroy` y `reject_if: :all_blank`) y un controlador
Stimulus (`filas_anidadas_controller.js`):
- El botón **+** de la cabecera añade una fila editable (Familiar | Tipo | Descripción) copiada de un
  `<template>`; **Borrar** la quita (si es nueva) o la oculta y marca con `_destroy` (si ya estaba
  guardada).
- La "estructura JS" donde se acumulan las filas es la propia tabla del formulario: no hay un array
  aparte que sincronizar, todo se envía con el formulario al pulsar **Crear** y, si hay errores de
  validación, las filas reaparecen tal como estaban.
- Las filas que se dejan completamente vacías se ignoran; las incompletas dan error.
- Los antecedentes se muestran en el orden en que se crearon.

### D27. Autorización y privacidad de pacientes
- Editar, actualizar y borrar buscan el paciente entre los del osteópata conectado
  (`current_osteopath.patients.find`): un paciente ajeno responde 404, sin revelar si existe.
- `/patients/:id` y `/patients/:id/medical_background` están abiertos a cualquier osteópata (se llega
  desde el filtro de tratamientos); la vista usa `@patient.pertenece_a?(current_osteopath)` para ocultar
  nombre y apellidos y el botón Editar. En la ficha de un paciente ajeno se añade una nota que explica
  por qué no aparece el nombre.
- `osteopath_id` no se acepta desde el formulario: el paciente siempre es del osteópata conectado.

### D28. Listado y formulario
- "Mostrar pacientes" se ordena por apellidos y nombre.
- **Borrar** pide confirmación al navegador y avisa de que se borrarán también antecedentes y visitas.
- El botón del formulario es **Crear** al dar de alta y **Guardar** al editar; **Cancelar** vuelve atrás.
- El año de nacimiento se elige en un select del año actual a 1900.

## Fase 4 — Visitas

### D29. Guardado del asistente en una transacción (`RegistroVisita`)
La lógica del POST de `/crear_visita` está en un objeto de formulario (`app/models/registro_visita.rb`,
ActiveModel) y no en el controlador. Dentro de `ActiveRecord::Base.transaction` crea, en orden, la
visita, el diagnóstico (y la enfermedad si es nueva), las sesiones y las técnicas con `create!`: si
cualquiera no es válido se deshace todo. El error se muestra con su contexto ("Sesión 2: Escala de
dolor presesión…") y el asistente se abre directamente en el panel donde está.

### D30. Cómo viajan los datos del asistente
Los campos de los paneles Visita y Diagnóstico son campos normales del formulario. Las sesiones con sus
técnicas (una estructura anidada de tamaño variable) se guardan en JS y se envían como JSON en un campo
oculto (`visita[sesiones_json]`). Es la forma más sencilla de enviarlas y de recuperarlas: si el servidor
devuelve errores, la página vuelve con el mismo JSON y el asistente lo pinta de nuevo. El servidor solo
lee las claves conocidas (`fecha`, `escala_dolor_pre_sesion`, `escala_dolor_post_sesion`, `tecnicas`).

### D31. Validación en el navegador
Al pulsar **Siguiente** se comprueban los campos obligatorios del panel (paciente; enfermedad, nombre
de la enfermedad nueva y sesiones recomendadas ≥ 1) y no se avanza si falta alguno. El servidor vuelve a
validarlo todo. Pulsar Enter en un panel intermedio avanza en lugar de guardar. Los modales están fuera
del formulario de la visita, para que Enter dentro de ellos cree la sesión o la técnica y no envíe la visita.

### D32. Campos de la visita que no están en el asistente
El panel Visita no pide fecha ni motivo. La visita se guarda con la **fecha del día** (la lista de
visitas y el resumen la necesitan); el motivo queda vacío.

### D33. Enfermedad "Otra…"
Muestra un campo para escribir el nombre. Si ya existe una enfermedad con ese nombre (sin distinguir
mayúsculas) se reutiliza; si no, se crea. Como `Disease.descripcion` es obligatoria, se usa la descripción
del diagnóstico o, si está vacía, "Enfermedad añadida al registrar una visita.".

### D34. Técnicas
- `Treatment.buscar_o_crear!` es el `find_or_create_by(nombre:)` de la especificación, sin distinguir
  mayúsculas (coherente con la validación de unicidad, D17). La descripción del modal solo se usa si la
  técnica se crea nueva.
- El campo "Nombre técnica" sugiere las técnicas del catálogo (`<datalist>`) para favorecer que se
  reutilicen en lugar de crear variantes.
- Una técnica no se puede añadir dos veces a la misma sesión.

### D35. Sesiones opcionales
Una visita se puede guardar sin sesiones (el diagnóstico puede registrarse antes de tratar). En el modal
de nueva sesión la fecha se propone con el día actual y las escalas de dolor son opcionales.

### D36. Resumen de la visita, exploración y pruebas complementarias
- `/visits/:id`, `/visits/:id/examination` y `/visits/:id/supplementary_tests` solo son accesibles para
  el osteópata de la visita (404 en otro caso).
- Exploración: ver, crear, editar y borrar (una por visita). Pruebas: listar, crear, editar y borrar.
- `escaneado` guarda solo el nombre del fichero (no se usa Active Storage).

### D37. Visitas en la ficha del paciente
`/patients/:id` lista las visitas del paciente (solo a su osteópata) con enlace a `/visits/:id` y un
botón **Crear visita** que abre el asistente con el paciente ya seleccionado (`/crear_visita?patient_id=`).

### D38. Pestañas no clicables
Las pestañas del asistente son `<span>` (no enlaces), con las inactivas atenuadas, y se actualizan al
moverse con Anterior/Siguiente.

## Fase 5 — Filtrado de tratamientos y técnicas aplicadas

### D39. Criterios de filtrado como métodos de clase de `Diagnosis`
`por_sexo`, `por_edad_minima`, `por_edad_maxima` y `por_dolencias` son métodos de clase (con
`return all` cuando el valor significa "no filtrar", lo que se lee mejor que un `scope` con condicional).
Valores que no filtran: sexo vacío o `"ambos"`; edad vacía o no numérica; ninguna dolencia elegida.
- Edad mínima `m`: `anyo_nacimiento <= año actual − m`; máxima `M`: `anyo_nacimiento >= año actual − M`.
  Así ambos límites son inclusivos (edad mínima 40 incluye a quien tiene 40).
- Varias dolencias: `disease_id IN (…)`, es decir, OR entre ellas.

### D40. `Diagnosis.filtrar` encadena los criterios en lugar de usar `merge`
La especificación sugiere `merge` o intersección de resultados. Se probó `merge` y **no sirve**: desde
Rails 7, `merge` sustituye las condiciones sobre la misma columna, y la edad mínima y la máxima filtran
las dos por `patients.anyo_nacimiento`, así que la mínima se perdía. Encadenar los métodos de clase
(`por_sexo(...).por_edad_minima(...)...`) produce un AND de todas las condiciones con un solo JOIN, y
añadir un criterio nuevo es añadir un eslabón. Hay un test específico para este caso.

### D41. Resultados sin recargar la página
El formulario de `/filtrar_tratamientos` es un GET que carga la tabla en un Turbo Frame (sin JS propio):
la tabla no existe hasta pulsar **Mostrar tratamientos**, se rellena sin recargar la página y la URL se
actualiza con el filtro, de modo que "Atrás" desde las técnicas o el paciente vuelve a los mismos resultados.

### D42. Tabla de resultados
Un diagnóstico por fila (de todos los osteópatas), ordenados por enfermedad. Además de los enlaces
"Mostrar técnicas" y "Mostrar paciente" se indican el número de técnicas y el sexo y la edad del paciente
(datos que cualquier osteópata puede ver), para entender por qué cumple el filtro sin tener que abrirlo.
Si un diagnóstico no tiene técnicas se indica "Sin técnicas" en lugar del enlace.

### D43. `/tecnicas_aplicadas`
Muestra Nombre | Descripción de las técnicas cuyos ids llegan en `ids[]`, ordenadas por nombre; el
botón **Volver** regresa a la página anterior (los resultados del filtro).

## Fase 6 — Informes

### D44. Cálculo en métodos de clase de `Treatment`, en una sola consulta SQL
`Treatment.con_estadisticas` une técnicas y sesiones y calcula por técnica, con `GROUP BY`,
`num_sesiones` (`COUNT`) y `reduccion_media` (`AVG(pre − post)`). Los cuatro informes son métodos de
clase que parten de ahí: `mas_frecuentes`, `mas_efectivas`, `menos_efectivas` y `para_cuadro_clinico`.
La consulta es SQL estándar (funciona igual en SQLite y PostgreSQL).

### D45. Qué cuenta en cada informe
- **Frecuencia:** número de sesiones en las que se aplicó la técnica (todas).
- **Más/menos efectivas:** solo las sesiones con las dos escalas; el "nº de sesiones" es el de esas
  sesiones, es decir, en cuántas se basa la media.
- **Menos efectivas** es literalmente el ranking anterior invertido (`reverse_order`), desempates incluidos.
- Las técnicas que nunca se han aplicado no aparecen.
- Empates: primero la que tiene más sesiones y después por nombre.
- La mejora de una sesión se atribuye a todas las técnicas aplicadas en ella: con los datos registrados
  no se puede separar el efecto de cada una. Es una limitación del modelo de datos, no del cálculo.

### D46. Técnicas posibles para un cuadro clínico
Enfermedad obligatoria; sexo y rango de edad opcionales, aplicados con `Diagnosis.filtrar` (los mismos
criterios y semántica que el filtro de tratamientos). Se listan todas las técnicas aplicadas en esos
diagnósticos, ordenadas por reducción media; las que no tienen ninguna sesión con ambas escalas van al
final con "—". Aquí "nº de sesiones" son todas las sesiones en las que se aplicó.

### D47. Interfaz de `/informes`
Un select **Tipo de informe** y el botón **Generar** (GET, la URL refleja el informe). Los controles del
cuadro clínico solo se muestran (y solo se envían) con ese tipo, gracias a un pequeño controlador
Stimulus; desde el servidor también se pintan ocultos y desactivados para que el formulario funcione
antes de que cargue el JS. Resultados en `table-dark`, con posición, y la reducción con dos decimales
(coma decimal).

### D48. Seeds con efectividades variadas
Se ajustaron las escalas de dolor de algunas sesiones de las seeds (completa D19) para que los informes
de efectividad tengan un orden claro en lugar de muchos empates. El dolor sigue bajando o manteniéndose
en todas las sesiones.

### D49. `db:setup` repetible
Cargar el esquema recrea las tablas, y con SQLite y claves foráneas falla si la base de datos ya tiene
datos (por ejemplo, la de test después de ejecutar los tests, que `db:setup` también carga).
`lib/tasks/schema_load.rake` vacía la base de datos (`db:purge`) antes de `db:schema:load` en
desarrollo y test. Así `bin/rails db:setup` funciona siempre, también en Windows, donde `db:reset` falla.

## Fase 7 — Estilo

### D50. Ajustes de contraste sobre el tema oscuro
- Los botones de contorno verde y rojo (`btn-outline-success`, `btn-outline-danger`) usan en modo
  oscuro los tonos claros de Bootstrap (`$green-300`, `$red-300`): con los colores por defecto, el texto
  apenas se leía sobre el fondo oscuro. Al pasar el ratón se rellenan con el verde/rojo normal.
- Los enlaces de la navbar verde usan blanco al 85 % (Bootstrap usa un gris translúcido de poco
  contraste sobre el verde) y la sección actual se marca en negrita (`aria-current="page"`).

### D51. Pantallas estrechas
La app se usa con normalidad en móvil: la navbar se pliega en un botón de menú y las tablas se
desplazan en horizontal (`table-responsive`). En las tablas editables de antecedentes los campos no
se encogen (ancho mínimo) y la columna de los botones **+**/**Borrar** se queda fija a la derecha.

### D52. Mensajes de validación
Los enums validan solo valores no vacíos y el vacío lo valida `presence`, de modo que un sexo, tipo de
antecedente o tipo de prueba sin elegir da "no puede estar en blanco" (y no "no está incluido en la
lista"). Los errores aparecen en el mismo orden que los campos del formulario.

## Fase 8 — Tests, verificación desde cero y documentación

### D53. Foco al abrir los modales del asistente
Al terminar la animación de apertura (~300 ms), Bootstrap mueve el foco al propio modal y el asistente
lo pasa al primer campo. Si en ese momento el usuario ya estaba escribiendo en otro campo del modal
(por ejemplo, la descripción de la técnica), el resto del texto acababa en el nombre. Lo detectó un
system test intermitente (1 de cada ~10 ejecuciones guardaba la técnica "Punción secabar"). Ahora se
recuerda el campo en el que estaba el usuario durante la animación y se le devuelve el foco; además, el
test espera a que el modal termine de abrirse antes de escribir y compara los textos de forma exacta.

### D54. El CSS compilado se trata como binario en Git
`.gitattributes` marca `app/assets/builds/application.css` como `binary`: con `core.autocrlf` (Windows)
Git convertía sus finales de línea al clonar y, al recompilarlo, aparecía como modificado sin
cambios reales.

### D55. Verificación desde cero
Se clonó el repositorio en una carpeta limpia y se siguieron los pasos del README (`bundle install`,
`bin/rails db:setup`, `bin/rails server`): registro con login automático, logout, login, filtro, privacidad
de pacientes ajenos e informes funcionan con las seeds, y pasan `bin/rails test` y `bin/rails test:system`.
Con la gema `pg` descomentada, `RAILS_ENV=production bin/rails assets:precompile` y la carga completa de
la aplicación en producción funcionan; el despliegue real contra PostgreSQL no se ha probado (no había un
servidor PostgreSQL disponible).

### D56. Los system tests pulsan los botones con `click_button`
`click_on` busca enlaces y botones. Si el primer clic falla mientras la página se desplaza (Bootstrap
activa el desplazamiento suave), Capybara lo reintenta y puede acabar pulsando un enlace con un texto
parecido: en el recorrido completo, `click_on "Crear"` (botón del formulario de paciente) pulsó el
enlace "Crear visita" de la barra de navegación 6 de 6 veces en la misma secuencia. Con `click_button`,
que solo busca botones, el clic llega siempre al botón correcto. Los tests usan `click_button` para los
botones y `click_on` solo para los enlaces. No afecta a los usuarios: es un problema de cómo el test
localiza el elemento.

## Corrección de la auditoría de seguridad

Una auditoría con 8 agentes (entorno del agente, secretos, código, dependencias, inyecciones,
autenticación, infraestructura y *prompt injection*) no encontró hallazgos críticos ni altos. Estas
decisiones corrigen los medios y los bajos que afectan a la aplicación.

### D57. Límite de intentos de login y de registro
`Osteopaths::SessionsController` y `Osteopaths::RegistrationsController` heredan de los de Devise solo
para añadir `rate_limit` (Rails 8): 10 intentos de login cada 3 minutos y 5 registros por hora, por IP.
Al superarlo se vuelve al formulario con un aviso. Se declara en controladores propios (y no en un
initializer sobre los de Devise) para que no se duplique en cada recarga del código en desarrollo. Los
contadores se guardan en la caché de Rails; en test es una caché en memoria que se vacía antes de cada
test. No se usa `:lockable`: bloquear cuentas permitiría a cualquiera bloquear las de otros. (D92 añade
después un límite por cuenta de 15 minutos, para los ataques repartidos entre muchas IP.)

### D58. Caducidad de la sesión
`:timeoutable` de Devise cierra la sesión tras 30 minutos sin actividad (`config.timeout_in`). Al
volver, se pide el login con el aviso "Tu sesión expiró".

### D59. Datos personales y de salud fuera de los logs
`filter_parameters` incluye nombre, apellidos, año de nacimiento, sexo, antecedentes (familiar, tipo,
descripción), anamnesis, motivo, escala de dolor, resumen y fichero de las pruebas, el JSON de sesiones
y todos los campos de la exploración: en los logs aparecen como `[FILTERED]`.

### D60. Validación de las entradas
- Los filtros y los informes solo aceptan textos en sus parámetros GET (`texto_param`, `lista_param`
  y `sexo_param` en `ApplicationController`); el sexo debe ser uno de los valores válidos o se trata como
  "ambos". Un parámetro con otra forma (`?sexo[a]=b`), que antes provocaba un error 500, se ignora.
- `/tecnicas_aplicadas` atiende como máximo 100 ids.
- El JSON de sesiones del asistente se valida antes de guardar: como mucho 100 KB, 50 sesiones y 30
  técnicas por sesión, y solo textos o números en sus campos. Si no cumple, no se guarda nada y se avisa
  ("Los datos de las sesiones no son válidos."). Antes, un JSON mal formado se trataba como "sin
  sesiones" y con tipos inesperados se podían crear técnicas basura como `{"a" => 1}`.
- Longitudes máximas en los campos de texto (nombres 100, descripciones 1000–2000, anamnesis 5000,
  exploración 255…).
- `escaneado` debe ser solo un nombre de fichero (sin `/`, `\`, `:` ni empezar por punto), por si algún
  día se usa para abrir el fichero.

### D61. Enlace «Volver» de las técnicas aplicadas
Solo usa la página anterior (`Referer`) si es de la propia aplicación (`url_from`); si no, vuelve al
filtro de tratamientos.

### D62. Seeds bloqueadas en producción
`db/seeds.rb` se detiene si `Rails.env.production?`: crean cuentas con una clave conocida.

### D63. Unicidad de los catálogos en la base de datos
Índices únicos sobre `LOWER(nombre)` en `diseases` y `treatments` (antes eran sobre `nombre`, que sí
distingue mayúsculas). Si dos peticiones crean a la vez la misma técnica o enfermedad, la segunda
inserción choca con el índice y `buscar_o_crear!` devuelve la que ya existe (dentro de un savepoint,
para no invalidar la transacción del asistente en PostgreSQL).

### D64. Fichas de pacientes ajenos con identificador firmado
La especificación exige que cualquier osteópata pueda ver la ficha y los antecedentes de un paciente de
otro (sin nombre ni apellidos) llegando desde el filtro de tratamientos. Con el id numérico en la URL,
cualquiera que se registrara podía recorrerlos todos (`/patients/1`, `/patients/2`…). Ahora:
- El osteópata del paciente sigue usando el id (`/patients/12`).
- Para los demás, los enlaces del filtro llevan un identificador firmado
  (`patient.signed_id(purpose: :ficha_compartida)`), que no se puede adivinar ni fabricar sin la clave
  secreta de la aplicación. `Patient.ficha` resuelve ambos casos y el id numérico de un paciente ajeno
  responde 404.
- No se ocultan las descripciones de los antecedentes a otros osteópatas (la sección 6.5 pide
  mostrarlos): con esta medida solo se llega a ellos desde un resultado del filtro.

### D65. Política de seguridad de contenidos (CSP)
Se activa una CSP estricta: scripts, estilos, imágenes, fuentes y conexiones solo de la propia
aplicación (`'self'`, más `data:` para las imágenes SVG de Bootstrap), sin plugins (`object-src
'none'`), sin incrustarse en otras webs (`frame-ancestors 'none'`) y formularios solo hacia la propia
aplicación. El importmap y los estilos que inserta Turbo llevan un nonce.
- Los anchos de columna que estaban en atributos `style="..."` pasan a clases CSS (la CSP bloquea los
  estilos inline); un test comprueba que ninguna página tiene atributos `style`.
- El nonce es un valor aleatorio guardado en la sesión, y no el id de sesión como propone la plantilla
  de Rails: en la primera visita la sesión aún no tiene id, el nonce quedaba vacío (`'nonce-'`) y el
  navegador bloqueaba el JavaScript de la página de login. Al estar en la sesión, se mantiene entre
  navegaciones de Turbo y al iniciar sesión (Devise renueva el id de sesión pero conserva sus datos).
- Verificado con el recorrido completo en Chrome registrando la consola: ninguna violación de la CSP.

### D66. Configuración de producción
- `APP_HOST` (uno o varios dominios separados por comas) activa `config.hosts`, que rechaza peticiones
  con otra cabecera `Host`; `/up` queda excluida para las comprobaciones de salud, también de la
  redirección a HTTPS. Si no se define no hay restricción, para poder compilar los assets sin él.
- El host de los enlaces de los correos sale de `APP_HOST` (antes era `example.com`).
- PostgreSQL exige SSL (`sslmode: require`, cambiable con `PGSSLMODE`). Desde D98, sin cifrar no arranca.
- Action Cable usa el adaptador `async`: la aplicación no tiene canales; antes apuntaba a un Redis en
  `localhost` sin contraseña y sin la gema `redis` instalada.
- `robots.txt` pide no indexar nada (aplicación privada con datos de salud).
- El README explica cómo desplegar: sin gemas de desarrollo, Puma solo detrás del proxy HTTPS y una
  caché compartida si hay varios procesos (para que el límite de intentos sea común). D98 lo deja ya
  configurado: Solid Cache, Puma en 127.0.0.1 y `TRUSTED_PROXIES`.

### D67. Comprobaciones automáticas de seguridad (bundler-audit y brakeman)
Se ejecutaron `bundle-audit` 0.9.3 (con la base de avisos de ruby-advisory-db del 10/10/2026) y
`brakeman` 8.1.0: ninguna vulnerabilidad conocida en las gemas y ningún aviso en el código. No se añaden
al `Gemfile` (se omitieron en `rails new`, D2, y la especificación pide no añadir gemas innecesarias; en
D102 sí se añaden, para comprobarlo en cada `bin/ci` y en GitHub Actions);
el README explica cómo instalarlas y ejecutarlas. Para asegurarse de que `bundle-audit` funcionaba, se
probó antes con un lockfile con versiones antiguas de nokogiri y rack: en Windows, con la ruta de su
base de datos escrita con barras invertidas, no carga ningún aviso y siempre responde "No
vulnerabilities found" (con barras normales detecta 76). `bundle outdated` solo señala `marcel`, una
dependencia indirecta que Rails 8.1 fija en la serie 1.x.

### D68. Ajustes tras la segunda revisión de seguridad y riesgos aceptados
Una segunda pasada de los agentes (código, autenticación, inyecciones e infraestructura) confirmó
corregidos o aceptados todos los hallazgos anteriores, sin nada nuevo de nivel medio o superior. Se
aplicaron los ajustes bajos en los que coincidían:
- `APP_HOST` es obligatoria en producción: sin ella la aplicación no arranca (salvo al compilar los
  assets con `SECRET_KEY_BASE_DUMMY`), para no perder la protección de `config.hosts` por un olvido.
- `escaneado` rechaza también caracteres de control (saltos de línea, NUL…).
- El filtro acepta como máximo 100 dolencias.
- El README explica `PGSSLMODE=verify-full` y la configuración de proxies para el límite de intentos.

Riesgos residuales que se aceptan (bajos, documentados):
- El límite de intentos es por IP y no por cuenta: un límite por cuenta permitiría bloquear el login
  de otro a propósito (mismo motivo que para no usar `:lockable`, D57). Cambiado en D92.
- Los identificadores firmados de las fichas no caducan: solo dan acceso a lo que la especificación ya
  muestra a cualquier osteópata, y que caducaran rompería los enlaces guardados. Cambiado en D94: caducan
  en un día.
- El nonce de la CSP es por sesión y no por petición (necesario con Turbo, D65).
- Las sesiones van en cookies: cerrar sesión no invalida una copia robada de la cookie antes de que
  caduque por inactividad (30 minutos).
- Con el registro abierto que exige la especificación, cualquiera que se registre puede consultar, desde
  el filtro, los antecedentes (sin nombre) de los pacientes con diagnósticos.

## Bloque 1 de mejoras — Seguimiento del tratamiento

Hasta ahora una visita solo se podía crear (con el asistente) y consultar. En la práctica las sesiones
llegan semanas después de la visita, así que este bloque permite completarla y corregirla después.

### D69. Editar y borrar visitas, diagnósticos y sesiones ya guardados
- **Rutas** anidadas en la visita, con `shallow` para no repetir identificadores:
  `/visits/:id/edit`, `/visits/:visit_id/diagnoses/new`, `/diagnoses/:id/edit`,
  `/diagnoses/:diagnosis_id/sesiones/new` y `/sesiones/:id/edit`, con sus `update` y `destroy`.
- **Las sesiones se llaman `sesiones` en rutas y controlador** (`SesionesController`, con una regla de
  inflexión `sesion`/`sesiones`). Con `sessions`, el helper `session_path` chocaría con el de Devise que
  usa el formulario de login.
- **Autorización como en el resto:** se buscan solo entre los del osteópata conectado
  (`current_osteopath.visits`, `.diagnoses` y `.sesiones`, asociaciones `through`); lo ajeno responde 404.
- **Editar la visita** cambia fecha, motivo, anamnesis y escala de dolor; el paciente no se cambia.
  `motivo` estaba en el modelo pero el asistente no lo pedía: ahora se puede rellenar aquí.
- **Diagnósticos:** se puede añadir otro a la visita (el modelo ya lo permitía y el resumen ya los
  listaba). La enfermedad se elige igual que en el asistente, con «Otra…»; la lógica está ahora en
  `Disease.elegida` y la usan los dos. La enfermedad nueva y el diagnóstico se guardan en una
  transacción: si el diagnóstico no es válido, la enfermedad no se queda en el catálogo. Se puede borrar
  el último diagnóstico de una visita (queda la visita con su anamnesis, exploración y pruebas).
- **Sesiones:** formulario propio con las técnicas en filas que se añaden y quitan sin recargar
  (`filas_anidadas_controller.js`, el mismo de los antecedentes) y el catálogo como sugerencias
  (`datalist`). Las técnicas se buscan por nombre sin distinguir mayúsculas y las nuevas se crean
  (`Treatment.buscar_o_crear!`); la descripción solo se usa entonces. Al guardar, la sesión queda con
  exactamente las técnicas enviadas; quitar una de la sesión no la borra del catálogo. Las filas vacías
  se ignoran, y se mantiene el máximo de 30 técnicas por sesión del asistente (D60).
- **Borrar** pide confirmación y borra en cascada: la visita, sus diagnósticos, sesiones, exploración y
  pruebas; el diagnóstico, sus sesiones. Las técnicas del catálogo nunca se borran.
- Los controladores nuevos leen los parámetros con `params.expect` (Rails 8): unos parámetros con forma
  inesperada responden 400 en lugar de dar un error 500.

### D70. Progreso del tratamiento
Cada diagnóstico muestra sus sesiones registradas frente a las recomendadas ("2 de 3 sesiones
recomendadas") con una barra de progreso, y la etiqueta «✓ Completado» al llegar (con icono, para no
depender solo del color). *(Cambiado en D75: desde que hay agenda, las sesiones de fecha futura cuentan
como programadas y no como realizadas.)* Cuentan todas las sesiones registradas, también las de fecha futura: la
aplicación no distingue sesiones previstas de realizadas. La barra es un `<progress>` nativo porque la
de Bootstrap necesita un `width` inline que la CSP no permite. En la ficha, la lista de visitas muestra
el mismo dato sumando los diagnósticos de cada visita ("2 de 3").

### D71. Gráfica de evolución del dolor en la ficha
- **Solo para el osteópata del paciente**, como las visitas (la ficha ajena no la muestra).
- **Forma:** una columna por sesión de todas las visitas del paciente, por fecha (las que no tienen
  fecha, al final): el dolor antes y después de cada sesión unidos por un tramo vertical (gráfico de
  pesas, la forma habitual para «antes → después»), sobre una única escala de 0 a 10. Las sesiones sin
  ninguna escala no se dibujan.
- **Color:** un solo tono azul en dos pasos (antes `#3987e5`, después `#9ec5f4`), validados con el
  script de la guía de visualización como rampa ordinal sobre el fondo de la tarjeta (`#212529`):
  contraste 4,2:1 del más oscuro y separación suficiente incluso con daltonismo. Leyenda siempre visible.
- **Rótulos:** solo la cifra con la que empieza el tratamiento y la última; el resto está en el tooltip
  y en una tabla desplegable con los mismos datos, para no depender del ratón ni del color.
- **Interacción:** cada columna es una zona de hover y de foco del teclado (`tabindex`, con su
  `aria-label`); el tooltip (`grafica_dolor_controller.js`) muestra antes, después, fecha y enfermedad, y
  se coloca al lado de la columna para no tapar sus puntos. Los textos se insertan con `textContent`.
- **Sin librerías:** el SVG se genera en el servidor (`GraficaDolor` calcula la geometría y la vista
  `patients/_grafica_dolor` lo dibuja). No hace falta ninguna gema ni paquete JavaScript, y es
  compatible con la CSP: el SVG no lleva estilos inline (los colores están en `application.scss`) y el
  tooltip se coloca con `element.style`, que la CSP permite.
- Con muchas sesiones solo se rotulan como máximo 12 fechas en el eje; todas están en el tooltip y la tabla.

## Bloque 2 de mejoras — Pruebas complementarias con su fichero

Hasta ahora de cada prueba complementaria solo se guardaba el nombre del fichero escaneado
(`escaneado`). Ahora se sube el fichero.

### D72. Ficheros escaneados con Active Storage, privados
- **Active Storage**, que venía desactivado del `rails new` ligero (D2), se activa: no añade gemas
  (forma parte de Rails). Los ficheros van a disco: `storage/` en desarrollo y producción (o la carpeta
  de `STORAGE_PATH`) y `tmp/storage` en los tests, que se vacía al terminar.
- **Sin enlaces públicos.** Las rutas propias de Active Storage (`/rails/active_storage/...`) dan el
  fichero a cualquiera que tenga el enlace, y el identificador firmado del fichero no caduca: con datos
  de salud no sirven. Se desactivan (`draw_routes = false`) y el fichero solo se sirve en
  `/visits/:visit_id/supplementary_tests/:id/archivo`, que comprueba que la visita es del osteópata
  conectado (lo ajeno responde 404), con `Cache-Control: private, no-store` y `nosniff`.
- **«Ver» abre el fichero en otra pestaña** (en el visor del navegador) y **«Descargar»** lo descarga;
  los dos enlaces van sin Turbo, porque no son páginas.
- **CSP propia para los ficheros:** los visores de imagen y PDF del navegador necesitan estilos inline,
  que la CSP de las páginas bloquea (la imagen salía sin centrar). Las respuestas con el fichero llevan
  `default-src 'none'; img-src 'self'; style-src 'unsafe-inline'`, sin formularios ni marcos, y sin
  nonce (con un nonce, el navegador ignora `'unsafe-inline'`). Las páginas conservan su CSP (D65).
- **Tipos y tamaño:** PDF, JPG o PNG de hasta 10 MB. El tipo lo decide el contenido (Active Storage lo
  identifica por los primeros bytes), y además se comprueba que el contenido empieza como corresponde a
  su tipo: un texto que el navegador declare como PDF se rechaza. Un fichero no válido no se llega a
  guardar en el almacenamiento.
- **Sin procesar los ficheros:** ni análisis, ni miniaturas, ni variantes (`analyzers` y `previewers`
  vacíos, `variant_processor = :disabled`): los ficheros que suben los usuarios no pasan por librerías
  de imagen, que son una fuente habitual de vulnerabilidades.
- **El fichero se borra con la prueba**, en el momento (`dependent: :purge`) y no en segundo plano,
  también cuando se borra en cascada con la visita o el paciente.
- **`escaneado` se toma del fichero subido** (saneado por Active Storage, sin caracteres de control ni
  punto inicial) y ya no se escribe a mano. Las pruebas antiguas, que solo tienen el nombre, siguen
  siendo válidas y se les puede subir el fichero al editarlas. Al editar sin elegir otro fichero se
  conserva el que había.
- El nombre del parámetro del fichero (`archivo`) se filtra en los logs, como el resto de datos (D59).

### D73. Ficheros de ejemplo en las seeds y en los tests
Las dos pruebas de las seeds (la resonancia y la radiografía de Pepe) llevan un fichero de ejemplo en
`db/seeds/`, con el mismo nombre que su `escaneado`; las seeds lo adjuntan solo si la prueba aún no
tiene fichero, así que se pueden repetir. Los ficheros son sintéticos: el PDF se generó con un script
de Ruby (texto «Documento de ejemplo: no contiene datos reales»); la radiografía es un dibujo de una
columna lumbar de perfil, hecho con un script de Python (Pillow), con la lordosis rectificada que dice su
resumen y el rótulo «Imagen de ejemplo · Sin datos reales». Al principio era un rectángulo gris hecho con
ffmpeg, que en el vídeo de demostración parecía un trozo en blanco. Los tests
usan ficheros igual de pequeños en `test/fixtures/files/`, más un `falso.pdf` (HTML con extensión
`.pdf`). En Windows hay que abrirlos en binario (`fixture_file_upload(..., true)`, `open("rb")`): en
modo texto el byte `\x1A` de la cabecera PNG se toma como fin de fichero y la subida se corta.

## Bloque 3 de mejoras — Gestión diaria

### D74. Buscador y paginación de la lista de pacientes
- **Buscador** por nombre y apellidos (`?busqueda=`), sin distinguir tildes ni mayúsculas: «maria»
  encuentra a «María». Como SQLite no sabe quitar tildes, cada paciente guarda su nombre completo ya
  normalizado en `texto_busqueda` (una columna nueva que rellena `Patient` al guardar y que la migración
  calculó para los pacientes existentes). Se exigen todas las palabras, en cualquier orden («campos
  juan»), hasta 5; los comodines de `LIKE` (`%` y `_`) se buscan como caracteres normales. Solo busca
  entre los pacientes propios.
- **Paginación** de 20 en 20 (`?pagina=`) con una clase propia (`Paginacion`) y un parcial con los
  enlaces de Bootstrap, en lugar de una gema (pagy o kaminari), que habría necesitado red para
  instalarla. Una página fuera de rango o que no es un número lleva a la más cercana. Los enlaces
  conservan la búsqueda.
- Lo que se escribe en el buscador (nombres) se filtra en los logs, como el resto de datos (D59).

### D75. Agenda y sesiones programadas
- **`/agenda`** (enlace en la barra de navegación) lista las sesiones del osteópata a partir de hoy,
  agrupadas por día («Hoy, lunes 19 de octubre», «Mañana, …»), con el paciente, el diagnóstico y su
  progreso, las técnicas previstas y enlaces a la visita y a la sesión. Como máximo 200 sesiones.
- **No hay un modelo de citas nuevo:** una sesión con fecha futura es una sesión programada, y se crea
  igual que las demás («Añadir sesión» en la visita, D69). Así una cita, cuando llega el día, se
  completa con el dolor y las técnicas en el mismo registro.
- **Cambia el progreso (D70):** las sesiones de fecha futura ya no cuentan como realizadas, sino como
  programadas: «3 de 4 sesiones recomendadas · 1 programada». «Completado» solo aparece cuando las
  realizadas llegan a las recomendadas. Las de hoy cuentan como realizadas.
- Las seeds crean tres sesiones programadas (hoy, dentro de 2 días y dentro de 7, relativas a la
  fecha en que se cargan), solo si el diagnóstico no tiene ya alguna futura, para que repetir las seeds
  otro día no las duplique.

### D76. Recuperación de la clave por email
- Se añade el módulo `:recoverable` de Devise (D14 lo había dejado fuera porque la especificación no lo
  pedía), con sus dos columnas. Enlace «¿Has olvidado tu clave?» en el login.
- **El enlace caduca en una hora** (Devise usa 6 por defecto) y solo sirve una vez; Devise guarda el
  token cifrado.
- **Modo paranoico:** pedir el enlace responde siempre lo mismo, exista o no el email, para no revelar
  quién tiene cuenta. (El registro abierto sí lo revela al decir que el email ya está en uso; es un
  riesgo aceptado, D68.)
- **Límite de intentos por IP**, como el login (D57): 5 peticiones de enlace y 10 cambios de clave cada
  15 minutos.
- **Textos propios** en la página, el correo y los avisos: los de devise-i18n dicen «contraseña» y
  mezclan «usted» y «tú», y la aplicación usa «clave» y «tú». El correo tiene versión HTML y de texto.
- **Envío:** en desarrollo los correos no se envían, se guardan en `tmp/mails/` para poder abrir el
  enlace. En producción se envían por SMTP con las variables `SMTP_ADDRESS`, `SMTP_PORT`,
  `SMTP_USER_NAME` y `SMTP_PASSWORD`, con el remitente de `MAIL_FROM` y enlaces `https` al dominio de
  `APP_HOST`.

### D77. Informe de la visita para imprimir o guardar como PDF
- Se eligió una **página imprimible** en lugar de generar el PDF en el servidor: no añade gemas (Prawn
  habría necesitado red y nuevas dependencias) y el navegador produce el PDF con «Guardar como PDF».
- `/visits/:id/informe`, solo para el osteópata de la visita, con un layout propio de **tema claro** y
  sin barra de navegación, y un botón «Imprimir o guardar como PDF» que abre el diálogo de impresión.
  Se abre en otra pestaña y sin Turbo, porque Turbo no cambiaría el tema del `<html>`.
- **Contenido pensado para el paciente:** sus datos, la consulta, cada diagnóstico con su progreso y sus
  sesiones, la gráfica de evolución del dolor de esa visita, qué es cada técnica aplicada (con la
  descripción del catálogo), la exploración (solo los campos rellenos) y las pruebas complementarias.
  Pie con la fecha y el aviso de que es confidencial.
- **Impresión:** márgenes de página, sin la barra de botones, sin cortar secciones ni filas entre
  páginas, y la leyenda de la gráfica con sus colores (los navegadores no imprimen fondos salvo que se
  pida). Se comprobó generando el PDF con el motor de impresión de Chrome.
- **Gráfica en papel:** sobre blanco, el paso más destacado es el oscuro, así que «después» pasa a ser el
  azul oscuro (#184f95) y «antes» el claro (#5598e7, contraste 3:1); validados como rampa ordinal sobre
  blanco con el script de la guía de visualización.

## Bloque 4 de mejoras — Informes y catálogo

### D78. Informes por fechas y de «mis pacientes»
- Todos los informes admiten dos filtros comunes: **las fechas de las sesiones** (desde y hasta, ambas
  opcionales e incluidas) y **«Pacientes»: toda la plataforma o solo los propios**. Se combinan con los
  del cuadro clínico (enfermedad, sexo y edad).
- Los cálculos de `Treatment` reciben las sesiones que cuentan (`Session.para_informe`) y las filtran
  con una subconsulta (`sessions.id IN (...)`), así los rankings no cambian de forma. Con fechas, las
  sesiones sin fecha no cuentan.
- Una fecha mal escrita se ignora; si «desde» es posterior a «hasta», se avisa y no se genera el
  informe. Encima de los resultados se resume qué filtros se aplicaron.

### D79. Gráfica de los informes y técnicas con pocas sesiones
- **Pocas sesiones:** una media basada en menos de 5 sesiones (`Treatment::MIN_SESIONES_FIABLE`) es poco
  fiable. En los informes de efectividad, esas técnicas llevan la marca «⚠ Pocas sesiones» (icono y
  texto, no solo color) en una columna «Fiabilidad», con una nota que lo explica. No se ocultan: con
  pocos datos en la plataforma, ocultarlas dejaría los informes casi vacíos.
- **Gráfica de barras horizontales** encima de la tabla, en el orden del ranking y con el valor en el
  extremo de cada barra (sesiones en el de frecuencia; reducción media en los de efectividad), como
  máximo 15 barras. SVG generado en el servidor (`GraficaBarras`), sin librerías y sin estilos inline.
  La tabla de debajo es su vista accesible; cada barra tiene su texto emergente (`<title>`).
- **Color y forma:** azul para los valores positivos y rojo para una reducción media negativa (el dolor
  aumentó, que sale a la izquierda del cero), validados como par categórico sobre el fondo de la
  tarjeta. Para las técnicas con pocas sesiones se probó un gris de «menos énfasis», pero el validador lo
  rechazó: con protanopía se confundía con el rojo. Por eso van **huecas** (contorno y un velo del 12 %):
  la forma las distingue sin depender del color, y la leyenda lo explica.
- La gráfica se limita a 50rem de ancho: a todo el ancho de la página el SVG se escalaba casi al doble.

### D80. Descarga de los informes en CSV
- Botón «Descargar CSV» con los mismos filtros (`/informes.csv?...`), sin Turbo.
- Formato pensado para Excel o LibreOffice en español: separador «;», coma decimal y UTF-8 con BOM (sin
  él, Excel no reconoce las tildes). Una fila de cabecera y una por técnica; en los de efectividad,
  también la columna «Pocas sesiones».
- Se escribe sin la gema `csv` (desde Ruby 3.4 ya no es parte de la biblioteca estándar y habría que
  añadirla al Gemfile), siguiendo RFC 4180: los textos entre comillas y sus comillas duplicadas.
- **Inyección de CSV:** el nombre de una técnica lo escribe cualquier osteópata; si empieza por `=`,
  `+`, `-`, `@`, tabulador o retorno, una hoja de cálculo lo tomaría como fórmula. Se le antepone un
  apóstrofo. Los números (también los negativos) no llevan esa protección, para que sigan siendo números.

### D81. Administradores del catálogo
- El catálogo de técnicas y enfermedades es compartido: cambiarlo afecta a las visitas e informes de
  todos. Por eso solo lo gestionan los **administradores**, una marca nueva en los osteópatas (`admin`,
  falsa por defecto).
- **El permiso no se consigue desde la aplicación:** no es un parámetro permitido en el registro, y se da
  o se quita desde el servidor (`bin/rails administradores:dar EMAIL=...`, `quitar` y `listar`). En las
  seeds, Paco es administrador y Maria no.
- Las páginas del catálogo responden 404 a quien no es administrador (como si no existieran), y el
  enlace «Catálogo» de la barra de navegación solo lo ven los administradores.

### D82. Edición, fusión y borrado en el catálogo
- `/catalogo` lista las técnicas y enfermedades con sus usos (sesiones o diagnósticos) y marca los
  **posibles duplicados**: nombres que coinciden sin tildes, mayúsculas, signos ni palabras vacías
  («Masaje espalda» y «Masaje de espalda»). Es solo un aviso; fusionar lo decide el administrador.
- **Editar** el nombre y la descripción (siguen siendo únicos sin distinguir mayúsculas).
- **Fusionar** una entrada con otra: todos sus usos pasan a la elegida y la de origen se borra, en una
  transacción. En las técnicas, las sesiones que ya tenían las dos solo pierden la de origen (el par
  sesión-técnica es único). Si la elegida no tiene descripción, se queda con la de la otra. Pide
  confirmación y no se puede deshacer.
- **Registro de fusiones:** cada fusión se guarda (qué con qué, cuántos usos movió, quién y cuándo) y
  las últimas se ven en el catálogo. Se guardan los nombres porque la entrada de origen deja de existir.
- **Borrar** solo las entradas que no se usan; las que se usan se fusionan.

## Bloque 5 de mejoras — Datos de salud y RGPD

### D83. Consentimiento del paciente para compartir sus datos
- Los datos clínicos de un paciente (sin nombre ni apellidos: edad, sexo, antecedentes, diagnósticos,
  sesiones y técnicas) solo los ven otros osteópatas si el paciente **consiente**. Es una casilla del
  formulario del paciente (`consiente_compartir`), y se anota la fecha en que se marcó o se retiró.
- **Sin consentimiento, dejan de compartirse:** el paciente no sale a los demás en el filtro de
  tratamientos, sus sesiones no cuentan en sus informes de toda la plataforma, y su ficha y sus
  antecedentes responden 404 aunque se tenga un enlace firmado de antes. **Su osteópata lo sigue viendo
  todo** y sus sesiones siguen contando en sus propios informes (también en los de toda la plataforma).
- Se aplica en un solo sitio por consulta: `Patient.visibles_para`, `Diagnosis.visibles_para` (filtro),
  `Session.para_informe(visibles_para:)` (informes; el argumento es obligatorio para que no se olvide) y
  `Patient.ficha` (fichas ajenas).
- **Los pacientes nuevos empiezan sin consentimiento** (hay que marcarlo). Los que ya existían se marcaron
  como que consienten al migrar, para que el filtro y los informes siguieran igual; no tienen fecha de
  consentimiento. En las seeds todos consienten salvo Javier, para que se vea el efecto.

### D84. Segundo factor de autenticación obligatorio
- **Obligatorio para todos:** después de la clave se pide el código de 6 cifras de una app de
  autenticación (TOTP, RFC 6238: Google Authenticator, Microsoft Authenticator, 1Password…). Quien no lo
  tiene activado (las cuentas nuevas, las de las seeds o alguien a quien se le ha restablecido) entra con
  la clave, pero **solo puede llegar al alta o salir**: cualquier otra página le lleva al alta, y la
  barra de navegación no muestra el menú.
- **Gemas `rotp` 6.3.0 y `rqrcode` 3.2.0**, con versión exacta. No se usa `devise-two-factor`: el flujo
  propio son dos controladores pequeños y así se controla cada paso.
- **Login en dos pasos:** si la clave es correcta, todavía no hay sesión; se guarda en la sesión (cookie
  cifrada) quién es y se pide el código. Hay 5 minutos; si no, se vuelve al login. Además, 10 códigos cada
  5 minutos por IP, como el límite del login (D57), y los incorrectos se cuentan por cuenta (D92).
- **Códigos:** se aceptan los de 30 segundos antes o después (por el desfase del reloj del móvil). Cada
  código **solo vale una vez**: se guarda el último paso de tiempo usado y se actualiza de forma atómica,
  así dos peticiones a la vez con el mismo código no entran las dos.
- **Alta:** QR (PNG en un `data:`, que la CSP ya permitía) y la clave en grupos de 4 para escribirla a
  mano. El secreto nuevo espera en la sesión hasta que se confirma con un código válido, así recargar la
  página no lo cambia. **Cambiar de dispositivo** (en «Mi cuenta», el nombre de la barra de navegación)
  pide además la clave actual y un código del móvil actual (D92); hasta confirmarlo sigue valiendo el
  móvil anterior.
- **10 códigos de recuperación** de un solo uso (`xxxxx-xxxxx`, sin letras ni números que se confundan),
  para entrar sin el móvil. Se enseñan **una sola vez**, en la respuesta del formulario (sin redirigir,
  sin Turbo y con `Cache-Control: no-store`), y se guarda solo su HMAC-SHA256. En «Mi cuenta» se ve
  cuántos quedan y se pueden generar otros con un código de la app (los anteriores dejan de valer).
- **El secreto se guarda cifrado** con Active Record Encryption. Sus claves se derivan de
  `secret_key_base` (no hay credenciales nuevas que gestionar); si `secret_key_base` cambia, hay que
  restablecer el segundo factor de todos.
- **Cambiar la clave con el enlace del correo ya no inicia sesión** (Devise lo hacía, D76): saltaría el
  segundo factor. Ahora lleva al login.
- **Desde el servidor:** `bin/rails dos_factores:estado`, `dos_factores:restablecer EMAIL=...` (si
  alguien pierde el móvil y los códigos de recuperación) y, solo en desarrollo y test,
  `dos_factores:codigo EMAIL=...`, que muestra el código actual para probar sin móvil.

### D85. Registro de accesos a las fichas de otros osteópatas
- Cada vez que un osteópata abre la **ficha o los antecedentes** de un paciente de otro osteópata, se
  anota quién, cuándo y qué página (`AccesoFicha`). Los accesos a los pacientes propios no se anotan, y
  un acceso rechazado (sin consentimiento) tampoco, porque no ve nada.
- El osteópata del paciente ve en la ficha los **20 más recientes** («Accesos de otros osteópatas»); la
  exportación (D86) los incluye todos.
- El filtro de tratamientos y los informes no se anotan: muestran datos sin abrir la ficha de nadie.

### D86. Exportar y borrar todos los datos de un paciente
- **«Exportar datos»** en la ficha (solo para su osteópata) descarga un JSON con todo lo que hay del
  paciente: ficha y consentimiento, antecedentes, visitas con su exploración, pruebas complementarias
  (con el fichero escaneado en base64), diagnósticos, sesiones y técnicas, y el registro de accesos. Es
  lo que se le entrega si ejerce su derecho de acceso o de portabilidad (RGPD, arts. 15 y 20). Fechas en
  ISO 8601, enumeraciones con su nombre en español y `Cache-Control: private, no-store`.
- **Borrar** (en la lista y ahora también en la ficha) borra todos sus datos, incluidos los ficheros
  (D72) y el registro de accesos, y la confirmación lo dice. Ojo: la ley obliga a conservar la historia
  clínica un mínimo de años (en España, 5 desde el alta según la Ley 41/2002, y más en algunas
  comunidades), así que el derecho de supresión no siempre se puede atender; decide el osteópata.

## Bloque 6 de mejoras — Red de osteópatas

### D87. Perfil profesional
- Cada osteópata tiene un perfil opcional: **número de colegiado**, especialidad, ciudad y una
  presentación. Se edita desde «Mi cuenta» (`/cuenta/perfil`).
- Los demás lo ven en `/osteopatas/:id`, con sus casos publicados, enlazado desde los casos y los
  comentarios. Solo existe para quienes entran en los casos (D88), y solo se ven los perfiles de los
  verificados (el propio, siempre).

### D88. Verificación de los profesionales
- El registro está abierto a cualquiera, así que **solo los osteópatas verificados entran en los casos
  clínicos** (y los administradores, para moderarlos). Hasta entonces, `/casos` explica cómo conseguirlo.
- Verificar es comprobar el número de colegiado en el registro del colegio profesional: lo hace un
  administrador en `/verificaciones` (pendientes y verificados) o desde la consola
  (`bin/rails verificacion:listar`, `dar EMAIL=...` y `quitar EMAIL=...`). Sin número no se puede verificar.
- **Cambiar el número de colegiado quita la verificación**: lo verificado es ese número.
- El filtro de tratamientos y los informes no cambian: siguen abiertos a todos los registrados con los
  datos de los pacientes que consienten (D83). Cambiado en D94: también son solo para verificados.

### D89. Casos clínicos anonimizados
- Un osteópata publica como caso un **diagnóstico propio de un paciente que consiente** (D83), desde la
  visita («Publicar como caso clínico»). Un diagnóstico se publica una sola vez.
- **Qué se publica:** un título y un resumen que escribe el osteópata para el caso, el sexo, la **edad en
  tramos de 5 años**, la enfermedad y las sesiones realizadas con su dolor y sus técnicas, **en días desde
  la primera sesión** («Día 7») y sin fechas, también en la gráfica de evolución del dolor (que tiene un
  modo anónimo). No se publican el nombre, los antecedentes, la anamnesis, la descripción del
  diagnóstico, la exploración ni las pruebas: esos textos libres pueden identificar al paciente.
- Al publicar y cada vez que se edita, el osteópata **confirma que el título y el resumen no identifican
  al paciente**; el formulario le enseña antes lo que se va a publicar.
- Los datos clínicos se leen del diagnóstico, no se copian: el caso se actualiza al añadir sesiones; si el
  paciente retira el consentimiento, el caso deja de verse (solo lo ve su autor, con un aviso; desde D96, se
  retira y no vuelve solo aunque vuelva a consentir); y se borra
  con el diagnóstico, la visita o el paciente. La exportación del paciente (D86) incluye sus casos y sus
  comentarios.
- Ver un caso no queda en el registro de accesos (D85): no se abre la ficha del paciente.
- Lista en `/casos`, la más reciente primero, con filtro por enfermedad y de 20 en 20. Solo el autor
  edita o borra su caso.

### D90. Comentarios y técnicas sugeridas
- En un caso compartido, cualquier osteópata con acceso escribe un comentario y **sugiere técnicas del
  catálogo** (hasta 10), o las dos cosas. El caso muestra las técnicas sugeridas de la más sugerida a la
  menos. Cada uno borra solo sus comentarios.
- Sin votos ni avisos por ahora (se dejaron para más adelante).
- **Catálogo:** al fusionar técnicas (D82), las sugerencias pasan también a la de destino (sin
  repetirla en un comentario); los usos que se cuentan siguen siendo las sesiones. Al borrar una técnica
  sin usos, se quita de los comentarios que la sugerían.
- Límites por IP: 20 comentarios cada 10 minutos y 10 casos por hora.

### D91. Denuncias y moderación
- Cualquiera con acceso puede **denunciar** un caso o un comentario que no sea suyo, una vez y con un
  motivo (10 denuncias por hora). El formulario está plegado (`<details>`), sin JavaScript.
- Los administradores lo ven en `/moderacion` y en un contador en el menú «Administración» (que agrupa
  ahora el catálogo, los profesionales y la moderación). Pueden **ocultar** el contenido o **descartar**
  las denuncias; se guarda quién las resolvió, cuándo y cómo, y lo oculto se puede volver a mostrar.
- **Oculto:** un caso solo lo ven su autor y los administradores, y no admite comentarios; un comentario
  se sustituye por «Comentario oculto por la moderación» y sus técnicas dejan de contar.
- Desde D97, las denuncias se conservan aunque su autor borre lo denunciado.

## Auditoría de seguridad tras los bloques 5 y 6

Una nueva auditoría con 8 revisiones (entorno del agente, secretos, código, dependencias, inyección,
autenticación, infraestructura e inyección de instrucciones), después de los bloques 5 y 6, no encontró
nada crítico y sí dos hallazgos altos. Se corrigen por bloques (S1 a S6), empezando por esos dos.

### D92. Segundo factor y login más difíciles de forzar (bloque S1)
- **Códigos incorrectos contados por cuenta, en la base de datos.** Antes se contaban en la sesión, que es
  una cookie: volviendo a enviar la cookie de antes, el límite de 5 fallos no se aplicaba nunca y solo
  quedaba el límite por IP. Ahora cada 5 códigos incorrectos seguidos (de la app o de recuperación, en el
  login, al cambiar de dispositivo o al generar códigos) la cuenta no acepta ningún código, ni siquiera el
  correcto, durante 15 minutos, y el tiempo se dobla cada vez (30 min, 1 h…) hasta 24 h. Un código
  correcto pone la cuenta a cero. Mientras está bloqueada, la clave correcta tampoco llega a pedir el
  código. `dos_factores:estado` muestra las cuentas bloqueadas y `restablecer` quita el bloqueo.
- **Límite de login también por cuenta:** 20 intentos cada 15 minutos por email, además de los 10 cada 3
  minutos por IP. **Cambia lo decidido en D57 y D68**, que lo descartaban para que nadie pudiera bloquear
  el login de otro: con datos de salud y un segundo factor que se puede forzar desde muchas IP, pesa más
  frenar esos ataques. El bloqueo dura solo 15 minutos y no afecta a las demás cuentas.
- **Cambiar de dispositivo pide también un código del móvil actual** (o uno de recuperación, si se ha
  perdido), además de la clave: con una sesión robada y la clave no basta. El código de la app nueva se
  comprueba antes, para no gastar el del móvil actual si el nuevo está mal escrito.
- **Clave de al menos 10 caracteres** (antes 6). Las claves más cortas que ya existían siguen valiendo
  hasta que se cambien. La clave de los usuarios de prueba pasa a ser `demo-123456` (una base de datos de
  desarrollo creada antes conserva `123456` hasta repetir `bin/rails db:setup`).
- **Logs:** se filtran la clave actual y los códigos de los formularios del segundo factor (`clave`,
  `codigo`, `codigo_actual`), que no coincidían con ningún filtro y salían en claro, y los textos de los
  casos y comentarios (`titulo`, `texto`).

### D93. Avisos por correo de los cambios en el acceso a la cuenta
- Se avisa al osteópata cuando se activa el segundo factor, cuando se cambia de dispositivo, cuando se
  generan códigos de recuperación nuevos, cuando alguien entra con un código de recuperación y cuando la
  cuenta se bloquea por códigos incorrectos (señal de que alguien conoce su clave).
- El correo dice qué ha pasado y cuándo, y qué hacer si no ha sido él (cambiar la clave con el enlace y
  avisar a un administrador). Nunca lleva códigos ni claves.
- Se envía en el momento, como el de recuperar la clave. Si el envío falla en producción, se anota en el
  log y la acción sigue: un problema del correo no debe impedir entrar.

### D94. Lo de otros osteópatas, solo para verificados (bloque S2)
- **Hallazgo alto de la auditoría:** el registro está abierto, y una cuenta nueva, con el segundo factor
  activado pero sin verificar, veía en el filtro de tratamientos y en las fichas ajenas la edad exacta, el
  sexo y los antecedentes en texto libre de los pacientes de otros osteópatas que consienten: más datos que
  los casos clínicos, que sí exigían verificación.
- **Una sola regla:** lo de otros osteópatas es solo para los verificados (y los administradores). Sin
  verificar, la aplicación funciona igual con los pacientes propios, pero el filtro de tratamientos explica
  cómo conseguir la verificación (como `/casos`), las fichas y antecedentes ajenos responden 404 aunque se
  tenga el enlace, y los informes solo son de «Mis pacientes» (el de toda la plataforma no se ofrece, ni se
  acepta desde la URL). Se aplica en `Patient.visibles_para` y `visible_para?`, de los que dependen el
  filtro, los informes y las fichas.
- `acceso_a_casos?` pasa a llamarse `acceso_a_la_red?` (y el módulo, `AccesoALaRed`): ya no protege solo
  los casos.
- **Los enlaces firmados de las fichas ajenas caducan en un día** (cambia D68): un enlace copiado o
  guardado deja de valer. Se generan de nuevo cada vez que se abre el filtro.

### D95. Identidad de los colegiados
- **Un número de colegiado solo puede estar en una cuenta.** Se compara sin espacios, puntos, guiones,
  barras ni mayúsculas («28-01234» y «28 / 01234» son el mismo), con una columna normalizada y un índice
  único. Si alguien escribe uno que ya está en otra cuenta, se le pide que avise a un administrador.
- Se guarda **qué administrador verificó** a cada osteópata (o que fue desde la consola), y se ve en
  «Profesionales». Se borra con la verificación.
- La página de verificación recuerda comprobar también el nombre y los apellidos en el registro del colegio
  y, si hay dudas, contactar con el profesional por el medio que dé el colegio, no por el email de la cuenta.

### D96. Más anonimato en los casos clínicos
- **Solo el mes de publicación** («octubre de 2026»), no el día: junto con los días de las sesiones,
  ayudaría a situar al paciente.
- **El título y el resumen no pueden llevar** fechas, años, teléfonos, DNI o NIE ni emails: al publicar o
  editar se rechazan con un mensaje que dice qué se ha encontrado. Los patrones evitan los falsos positivos
  de los textos clínicos («L4-L5», «de 8 a 4», «sesión 1/3»). No sustituye a la confirmación de anonimato.
- **Casos retirados:** si el paciente retira el consentimiento, sus casos se retiran de la red
  (`retirado_at`) y no vuelven solos aunque vuelva a consentir. Su autor los ve con un aviso y, si el
  paciente ha vuelto a consentir, puede volver a publicarlos.
- **Moderación:** de un caso retirado o de un paciente que ya no consiente no se enseñan el título, el
  resumen ni los comentarios, tampoco a los administradores; la denuncia se puede resolver igual.

### D97. Denuncias que se conservan
- Si el autor borra un caso o un comentario denunciado, las denuncias **no se borran**: se cierran como
  «Contenido borrado» y quedan en las últimas resueltas con quién era el autor. Así, borrar no sirve para
  esquivar la moderación. Se guarda el autor del contenido al denunciar, porque luego puede no existir.
- No se copia el contenido denunciado: si se borra por el derecho de supresión del paciente (D86), no debe
  quedar en otro sitio.
- **Doble envío:** si dos peticiones publican a la vez el mismo diagnóstico, el índice único deja pasar una
  y la otra lleva al caso ya publicado, en lugar de un error.

### D98. Producción lista para varios procesos y detrás de un proxy (bloque S3)
- **Caché compartida: Solid Cache** (gema `solid_cache` 1.0.10, versión exacta), en una tabla
  (`solid_cache_entries`) de la misma base de datos PostgreSQL: sin servicios externos. Guarda los
  contadores de los límites de intentos, que así son comunes a todos los procesos y servidores y no se
  pierden al desplegar (antes, sin configurar, cada proceso contaba por su cuenta en ficheros). El
  instalador de la gema crea otra base de datos para la caché; aquí se usa la principal (sin `database:` en
  `config/cache.yml`) y la tabla se crea con una migración. Entradas de como mucho una semana y 256 MB. En
  desarrollo y test sigue la caché en memoria.
- **Gema `pg` activada** (1.7.0, versión exacta) en el grupo de producción: desplegar ya no necesita editar
  el Gemfile.
- **Puma solo en la propia máquina** (`127.0.0.1`) en producción: la aplicación da por hecho que la conexión
  es HTTPS porque va detrás de un proxy (`assume_ssl`), así que no debe ser accesible directamente.
  `BINDING` lo cambia (por ejemplo, dentro de un contenedor). En desarrollo, como antes.
- **`TRUSTED_PROXIES`:** las direcciones o redes de los proxies que no sean privadas, separadas por comas,
  para que Rails tome la IP real del cliente (los límites de intentos van por IP).
- **Base de datos sin cifrar, no:** con `PGSSLMODE` `disable`, `allow` o `prefer` (los que pueden conectar
  sin cifrar) la aplicación no arranca, salvo con `PERMITIR_BD_SIN_SSL=1` para pruebas locales.
  `verify-full` sigue siendo lo recomendable.
- **Permisos de `storage/`:** al arrancar en producción se avisa en el log si la carpeta de los ficheros
  escaneados la pueden leer otros usuarios del servidor (deberían ser 700). Solo avisa: los permisos son
  cosa de quien administra el servidor.

### D99. Sesiones que se revocan al cerrar sesión
- La sesión es una cookie (cifrada): copiada, seguía valiendo después de cerrar sesión hasta caducar. Ahora
  cada osteópata tiene un token de sesión que forma parte de lo que Devise guarda en la cookie y compara en
  cada petición (`authenticatable_salt`). Al **cerrar sesión** el token cambia y deja de valer cualquier
  cookie anterior, también una copiada. Sin gemas ni sesiones en la base de datos.
- Cerrar sesión cierra también las sesiones abiertas en otros dispositivos. Que una sesión caduque por
  inactividad no cambia el token: las de otros dispositivos siguen abiertas. Cambiar la clave ya las cerraba
  (Devise usa la clave en lo mismo).
- Las sesiones abiertas antes de existir el token siguen valiendo hasta el primer cierre de sesión.

### D100. Reglas del agente de IA reforzadas (bloque S5)
- La auditoría vio que las reglas de `.claude/settings.json` (lo que el agente que ayuda a programar puede
  hacer sin preguntar) se podían esquivar: prohibían leer `.env` o `~/.ssh` con la herramienta de leer
  ficheros, pero no con `cat` o `Get-Content`; solo cubrían `rm -rf` literal; y no frenaban otras vías de
  red ni los comandos que leen la base de datos.
- Se amplían (de 30 a 148 reglas): **prohibido** leer credenciales también desde Bash y PowerShell, leer
  `storage/` (bases de datos SQLite y ficheros escaneados), y las variantes de borrado recursivo,
  `git clean`, `git reset --hard` y `git push --force`; **se pregunta** antes de cualquier `git push` o
  `git remote`, de herramientas de red (`nc`, `rsync`, `iwr`…), de intérpretes en línea (`ruby -e`,
  `rails runner`, `rails console`…), de las tareas que borran la base de datos (`db:drop`, `db:setup`…), de
  instalar gemas y de cambiar la configuración del agente o `.github/`. Los tres subagentes de seguridad
  que no usan los escáneres ya no tienen Bash.
- No es una barrera completa (un script en un fichero puede usar la red); para eso estaría el sandbox de
  Claude Code. Las reglas de intérpretes hacen que el agente pregunte más a menudo.
- **Siguen fuera de Git**, por decisión: `.claude/`, `CLAUDE.md` y `scripts/security/` están en
  `.gitignore`, así que estas reglas solo protegen la copia local; un clon nuevo no las trae.

### D101. Dependencias con huella y versiones acotadas (bloque S4)
- **Huella de cada gema:** `Gemfile.lock` lleva la sección `CHECKSUMS` (`bundle lock --add-checksums`), con
  la SHA-256 de las 124 gemas en todas las plataformas. Bundler rechaza una gema descargada que no coincida
  (por ejemplo, republicada o manipulada).
- **Versiones acotadas:** las 13 gemas que no tenían restricción, o solo un mínimo (puma `>= 5.0`, sqlite3
  `>= 2.1`…), pasan a `~>` desde la versión que ya estaba en `Gemfile.lock`: misma versión mayor y, en las
  0.x, solo correcciones. Así un `bundle update` no salta a una versión mayor sin revisarla. No cambia
  ninguna versión instalada. Las gemas añadidas en las mejoras siguen con versión exacta. `tzinfo-data` se
  deja libre a propósito: son los datos de las zonas horarias, que conviene tener al día.
- **Avisos de seguridad:** la base de datos de `bundle-audit` se actualiza (17 de octubre de 2026) y sigue
  sin avisos. `chunky_png` 1.4.0 (la usa `rqrcode` para el PNG del QR) lleva años sin versiones nuevas,
  pero no tiene avisos y solo procesa el QR que genera la propia aplicación; se vigila.

### D102. Comprobaciones de seguridad automáticas (bloque S6)
- **`bin/ci`** pasa, además de los tests y las seeds, las tres comprobaciones de seguridad: vulnerabilidades
  conocidas de las gemas (bundler-audit, que antes actualiza la base de avisos), de los paquetes JavaScript
  del importmap y el análisis estático de Brakeman, que falla con cualquier aviso. Los system tests se
  lanzan aparte (necesitan Chrome).
- **Las herramientas pasan al Gemfile** (grupo de desarrollo y test, versión exacta: brakeman 8.1.0 y
  bundler-audit 0.9.3), como en una aplicación nueva de Rails 8.1, con `bin/brakeman` y `bin/bundler-audit`.
  Antes se instalaban aparte (D67). `bin/brakeman` no lleva `--ensure-latest` (fallaría con cada versión
  nueva aunque la del Gemfile esté fijada a propósito) y `bin/bundler-audit` guarda la base de avisos en
  `tmp/ruby-advisory-db`, dentro del proyecto. `config/bundler-audit.yml` no acepta ningún aviso.
- **`bin/ci` funciona en Windows:** cada paso se lanza con el Ruby actual y sin shell, como `bin/setup`
  (D7), y `RAILS_ENV=test` va en el entorno del paso de las seeds, que vacía la base de datos antes de
  cargarlas (así nunca puede ser la de desarrollo).
- **GitHub Actions** (`.github/workflows/ci.yml`): en cada push y pull request a `main`, un trabajo de
  seguridad (las tres comprobaciones) y otro de tests (los de `bin/rails test` y las seeds), en Ubuntu.
  Solo con permiso de lectura del repositorio y sin secretos; las acciones van fijadas por el commit exacto
  (checkout v7.0.1 y setup-ruby v1.327.0, versiones de hace más de dos semanas que ya conocen Ruby 3.4.11).
- **Los scripts de `bin/` se marcan como ejecutables en Git:** se habían subido desde Windows sin ese
  permiso, y en Linux (también en GitHub Actions) `bin/rails` no se podía lanzar directamente.

## Después de la auditoría

### D103. Confirmación del email al registrarse
- **Por qué:** el registro está abierto a cualquiera, y Devise solo comprobaba el formato del email y que
  no estuviera repetido. Sin confirmarlo, alguien podía:
  - registrarse con el email de otro y ocuparlo: el verdadero dueño no podría registrarse y, aunque
    recuperase la clave (el enlace le llega a él), no podría entrar sin el segundo factor del otro;
  - hacer que la aplicación enviara correos a terceros (el aviso de que se ha activado el segundo factor);
  - equivocarse al escribirlo y quedarse sin recuperación de la clave ni avisos de seguridad.

  La confirmación no demuestra quién es la persona (eso lo hace la verificación del número de colegiado,
  D88): demuestra que el email existe y es de quien se registra.
- **Cómo:** Devise `:confirmable`. Al registrarse no se inicia sesión: se vuelve al login con un aviso, y
  llega un correo con un enlace de un solo uso que caduca a los 3 días (`confirm_within`). No hay margen
  para entrar sin confirmar (`allow_unconfirmed_access_for = 0`). Después se entra con la clave y se da de
  alta el segundo factor, como antes (D84). Con la clave correcta, el login dice que falta confirmar el
  email; con una incorrecta, el error de siempre, exista la cuenta o no.
- **Pedir otro enlace:** en `/osteopaths/confirmation/new` («¿No te ha llegado el correo para confirmar tu
  email?», en el login). Como la recuperación de la clave (D76):
  - va en modo paranoico: el mismo mensaje exista o no la cuenta, o esté ya confirmada, y en esos casos no
    se envía nada;
  - tiene límite de intentos por IP: 5 peticiones y 10 intentos de confirmar cada 15 minutos.

  El enlace lleva el token en la URL, que no queda en los logs (`token` está en `filter_parameters`).
- **Sin reconfirmación:** la aplicación no deja cambiar el email (D14, D21), así que no hace falta la
  columna `unconfirmed_email` y `reconfirmable` está desactivado.
- **Cuentas que ya existían:** la migración las da por confirmadas, para no dejar fuera a nadie. Las seeds
  crean a los usuarios ya confirmados (y sin enviar el correo), y los fixtures lo están.
- **Desde la consola:** `confirmacion:listar` y `confirmacion:dar EMAIL=...`. Sirven para quien no recibe
  el correo (después de comprobar por otro medio que el email es suyo) y para el primer administrador, si el
  correo de producción aún no funciona.
- **Mensajes en español con «tú» y «clave»,** como los de la recuperación de la clave. También el error
  genérico del login, que venía de devise-i18n («Email o contraseña inválidos.») y ahora es «Email o clave
  incorrectos.».
- **En producción, registrarse depende del correo (SMTP),** como ya lo hacía recuperar la clave.

## Tercera auditoría de seguridad

### D104. Confirmación con la clave, login sin pistas de tiempo y conexiones cifradas
Una tercera auditoría con las mismas 8 revisiones, el 14 de noviembre de 2026, no encontró nada crítico ni
alto. Estos son sus cuatro hallazgos de riesgo medio en la aplicación, y un fallo que apareció al corregirlos:

- **Confirmar el email pide la clave de la cuenta.** Antes, abrir el enlace del correo confirmaba la cuenta.
  Alguien podía registrarse con el email de otra persona y una clave suya: si esa persona abría el enlace (o
  lo abría el antivirus del correo, que comprueba los enlaces), la cuenta quedaba confirmada con la clave del
  intruso, que entraba y daba de alta su propio segundo factor. Ahora:
  - el enlace abre una página con el nombre y el email de la cuenta, y el email se confirma al enviar su clave
    (PATCH); abrirlo no cambia nada;
  - quien no se registró no sabe la clave, y la página le dice que no haga nada. Si quiere recuperar su
    email, cambia la clave con «¿Has olvidado tu clave?» (el enlace le llega a ella) y confirma con la nueva:
    la del intruso deja de valer;
  - los errores (enlace inventado, ya usado o caducado) son los de Devise, que al confirmar vuelve a
    comprobar que no ha caducado. Abrir el enlace y confirmar comparten el límite de 10 intentos cada 15
    minutos por IP.
- **El login tarda lo mismo tenga o no la cuenta el segundo factor.** Con el segundo factor activado y una
  clave incorrecta, la clave se calculaba (bcrypt, lo que más tarda) una vez en el controlador y otra en
  Devise; con un email sin cuenta, una sola. La diferencia, de unos 250 ms en producción, decía qué emails
  tienen cuenta. Ahora se calcula una vez: con una clave incorrecta se da el error de siempre sin pasar por
  Devise, y sin que Devise la vuelva a comprobar al pintar otra vez el formulario. Un test cuenta los
  cálculos de cada caso.
- **Correo siempre cifrado.** Con `enable_starttls_auto` solo se cifraba si el servidor lo ofrecía, y alguien
  en medio de la red podía quitar la oferta para leer la clave del SMTP y los enlaces de confirmación y de
  recuperación. Ahora STARTTLS es obligatorio (o TLS desde el principio en el puerto 465) y se comprueba el
  certificado: si no se puede cifrar, el correo no se envía. Los ajustes están en `config/correo_smtp.rb`
  para poder probarlos.
- **El SSL de la base de datos también se comprueba en `DATABASE_URL`.** La comprobación de arranque (D98)
  solo miraba `PGSSLMODE`, pero un `?sslmode=disable` en `DATABASE_URL` manda sobre `database.yml`, y la
  aplicación arrancaba sin cifrar. Ahora se mira el modo con el que de verdad se conecta (la configuración
  que monta Rails). Si no hay modo en ningún sitio, cuenta como «prefer», que tampoco vale.
- **Cada límite de intentos, con su contador.** Rails guarda en el mismo contador los límites de un
  controlador que no llevan nombre. En la confirmación del email y en la recuperación de la clave, abrir
  enlaces gastaba el límite de pedir otro correo, y al revés. Ahora cada límite tiene su nombre.

Los hallazgos de riesgo bajo, y los de la configuración local del agente de IA (fuera de Git, D100), se
tratan aparte.
