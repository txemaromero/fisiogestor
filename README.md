# RedSocialFisios

Plataforma web para fisioterapeutas y osteópatas (en la aplicación, **osteópatas**). Cada osteópata:

- gestiona sus pacientes, con sus antecedentes médicos personales y familiares, y los encuentra con un
  buscador;
- registra visitas y, dentro de cada visita, uno o varios diagnósticos, las sesiones de fisioterapia y
  las técnicas aplicadas en cada sesión, con la escala de dolor antes y después;
- sigue el tratamiento: completa y corrige las visitas guardadas a medida que llegan las sesiones, ve el
  progreso de cada diagnóstico frente a las sesiones recomendadas y la evolución del dolor del paciente
  en una gráfica;
- organiza su día con una agenda de las sesiones programadas;
- entrega al paciente un informe de la visita, para imprimir o guardar como PDF;
- guarda la exploración y las pruebas complementarias de cada visita, con su fichero escaneado (PDF o
  imagen), que solo él puede abrir;
- consulta los tratamientos aplicados por **cualquier** osteópata de la plataforma, filtrando por perfil
  de paciente (sexo, edad y dolencias), una vez verificado;
- genera informes de efectividad de las técnicas, de sus pacientes o (una vez verificado) de toda la
  plataforma, y entre fechas, con gráficas, aviso de las medias con pocas sesiones y descarga en CSV;
- exporta todos los datos de un paciente en un fichero, o los borra, si el paciente lo pide;
- publica **casos clínicos** anonimizados para que los demás osteópatas los comenten y le sugieran
  técnicas, y tiene un perfil profesional.

Los osteópatas administradores mantienen el catálogo de técnicas y enfermedades, que es compartido
(corrigen nombres y descripciones y fusionan las entradas duplicadas), verifican el número de colegiado
de cada osteópata y moderan los casos clínicos y sus comentarios.

Son datos de salud, así que:
- el nombre y los apellidos de un paciente solo los ve el osteópata al que pertenece, y el resto de sus
  datos clínicos solo se comparten si **el paciente consiente**, y solo con **osteópatas verificados**: un
  administrador comprueba el número de colegiado de cada uno (el registro está abierto a cualquiera);
- cada vez que otro osteópata abre su ficha queda registrado, y su osteópata lo ve;
- los casos clínicos van sin nombre ni fechas, con la edad en tramos de 5 años, y no admiten fechas,
  teléfonos ni otros datos que identifiquen; si el paciente retira el consentimiento, se retiran;
- al registrarse, cada osteópata **confirma su email** con el enlace que le llega y su clave: hasta entonces
  no puede entrar;
- para entrar hace falta la clave (de al menos 10 caracteres) y un código de una app de autenticación en
  el móvil: el **segundo factor es obligatorio** para todos. Los códigos incorrectos bloquean la cuenta un
  tiempo, y cada cambio en el acceso (o un intento de forzarlo) se avisa por correo. Si un osteópata olvida
  su clave, puede elegir una nueva con un enlace que recibe por email.

Hecho con Ruby on Rails 8.1, SQLite, Devise, Bootstrap 5, Turbo y Stimulus. Toda la interfaz está en español.

## Demostración

![Recorrido guiado por RedSocialFisios: registro con confirmación del email y segundo factor, administración, pacientes, visitas, informes y casos clínicos](demo.webp)

Recorrido guiado por toda la aplicación, grabado el 14 de noviembre de 2026 (19 min 22 s, 1920×1080, con
subtítulos), con los cambios de la tercera auditoría de seguridad (D104). `demo.webp` no tiene sonido,
porque el WebP animado no admite audio. La versión con la voz narrada (Ximena, de edge-tts, en español de
España) es `demo.mp4`, que no está en el repositorio por su tamaño (54 MB).

El vídeo muestra, por este orden:
- **Registro:**
  - una osteópata nueva se registra (se rechaza una clave demasiado corta);
  - no puede entrar hasta confirmar su email: abre el enlace del correo, que le pide su clave, y lo
    confirma;
  - da de alta el segundo factor con el QR y recibe sus códigos de recuperación;
  - ve lo que queda cerrado sin verificar y completa su perfil profesional.
- **Administración:**
  - el login de un administrador con el código de la app;
  - la verificación de la osteópata;
  - el catálogo, con el aviso de un duplicado y su fusión.
- **El día a día:**
  - el buscador y la ficha del paciente, con la gráfica del dolor, el registro de accesos y los
    antecedentes;
  - la visita, con su exploración y sus pruebas, y una sesión nueva;
  - el informe para el paciente y la agenda.
- **La red:**
  - el filtro de tratamientos y la ficha de un paciente de otra osteópata, sin su nombre;
  - los informes y su CSV;
  - los casos clínicos, un comentario con técnicas sugeridas y el perfil de un osteópata.
- **El trabajo de la osteópata nueva:**
  - una paciente con sus antecedentes y su consentimiento;
  - el asistente de visita, la exploración y una prueba con su PDF;
  - la publicación de su caso clínico (primero rechazado por llevar un año en el texto).
- **El final:**
  - una denuncia y la moderación, y la vista en el móvil;
  - la entrada con un código de recuperación;
  - la exportación de los datos de la paciente, la retirada de su consentimiento y su borrado;
  - la recuperación de la clave por correo.

## Requisitos

- **Ruby 3.4** (probado con 3.4.11). En Windows, [RubyInstaller](https://rubyinstaller.org/) *con
  MSYS2/DevKit*, necesario para compilar algunas gemas (bcrypt, puma…). Con Ruby 3.4 viene Bundler 2.6,
  que comprueba la huella de cada gema que descarga (la sección `CHECKSUMS` de `Gemfile.lock`).
- **Una app de autenticación** para entrar (segundo factor): Google Authenticator, Microsoft
  Authenticator, 1Password, Authy… o cualquier gestor de contraseñas con códigos TOTP.
- **Google Chrome**, solo para los system tests.

No hace falta instalar SQLite (lo incluye la gema `sqlite3`) ni Node.js (el CSS de Bootstrap se compila
con Dart Sass desde Ruby y el JavaScript se sirve con import maps).

## Instalación y arranque

```sh
bundle install
bin/rails db:setup     # crea la base de datos, carga el esquema y las seeds
bin/rails server       # http://localhost:3000
```

En lugar de `bin/rails server` se puede usar `bin/dev`, que además recompila el CSS al modificar
`app/assets/stylesheets/application.scss`. El CSS compilado ya está en el repositorio, así que no hace
falta compilarlo para arrancar.

`bin/rails db:setup` se puede repetir para volver a dejar la base de datos con los datos de ejemplo.

Los ficheros escaneados de las pruebas complementarias se guardan en `storage/` (fuera de Git). Al
repetir `db:setup` no se borran los que hubiera: se pueden eliminar a mano, dejando el `.keep`.

En desarrollo los correos (los de confirmar el email, los de recuperar la clave y los avisos de seguridad)
no se envían: se guardan en `tmp/mails/`, un fichero por destinatario. Se guardan tal cual, codificados en
*quoted-printable*, así que sus enlaces no se pueden copiar sin más:
- salen partidos en dos líneas, y la primera acaba en `=`: hay que unirlas quitando ese `=`;
- el `=` del token aparece como `=3D`: hay que cambiarlo por `=`.

Por ejemplo, `…edit?reset_password_token=3DAbc=` y en la línea siguiente `Def…` se convierten en
`…edit?reset_password_token=AbcDef…`. Con el de confirmar el email (`…confirmation?confirmation_token=…`)
pasa lo mismo; al abrirlo, pide la clave de la cuenta. Para probar sin el correo, una cuenta nueva también
se puede confirmar desde la consola: `bin/rails confirmacion:dar EMAIL=...`.

En desarrollo, los contadores de los límites de intentos (login, registro, recuperación de la clave,
casos, comentarios…) se guardan en la memoria del servidor. Si al probar muchas veces seguidas sale un
«Demasiados…» (por ejemplo, tras 5 registros en una hora desde el mismo ordenador), basta con reiniciar el
servidor. El bloqueo por códigos incorrectos del segundo factor es distinto: está en la base de datos y
se quita con `dos_factores:restablecer` (ver más abajo).

**En Windows (PowerShell)** los scripts de `bin/` se lanzan a través de Ruby (en Linux y macOS se
pueden lanzar directamente, como arriba):

```powershell
bundle install
ruby bin/rails db:setup
ruby bin/rails server     # o: ruby bin/dev
```

## Usuarios de prueba

Las seeds (`db/seeds.rb`) crean dos osteópatas, ambos con la clave `demo-123456` (una base de datos creada
antes de que la clave mínima pasara a 10 caracteres conserva `123456` hasta repetir `bin/rails db:setup`):

| Email | Nombre |
|---|---|
| `paco@example.com` | Paco Martínez |
| `maria_campos@example.com` | Maria Campos Gil |

Los dos tienen el email ya confirmado (D103); las cuentas que se registren después tienen que confirmarlo
antes de entrar.

Cada uno tiene cuatro pacientes (hombres y mujeres de 22 a 76 años) con antecedentes y una visita con
diagnóstico, dos o tres sesiones y varias técnicas por sesión. La visita de Pepe Campos Giménez (de
Paco) tiene además exploración y dos pruebas complementarias con ficheros de ejemplo, sin datos reales
(`db/seeds/`): un PDF y una radiografía dibujada, una columna lumbar de perfil. Las seeds solo adjuntan el
fichero si la prueba aún no lo tiene: en una base de datos creada antes, la radiografía sigue siendo un
rectángulo gris hasta repetir `bin/rails db:setup`.

También hay 7 enfermedades y 11 técnicas en los catálogos. Así el filtro y los informes devuelven
resultados variados, y al entrar con un usuario se pueden ver pacientes del otro (sin nombre) desde el
filtro de tratamientos.

Las seeds programan además tres sesiones a partir del día en que se cargan, para que la agenda no esté
vacía: hoy (María Torres Gutiérrez) y dentro de 7 días (Pepe Campos Giménez) para Paco, y dentro de 2
días (Antonio López Sanz) para Maria.

Todos los pacientes consienten compartir sus datos salvo Javier Romero Ortega (de Maria): Paco no lo ve
en el filtro de tratamientos y sus sesiones no cuentan en los informes de Paco.

Los dos tienen su perfil profesional (con números de colegiado ficticios) y están verificados, así que
ven los casos clínicos. Cada uno ha publicado un caso, que el otro ha comentado sugiriendo técnicas: Paco,
la hernia discal de Pepe Campos Giménez; Maria, la ciática de María Pérez Gil.

Paco es administrador (ve el menú «Administración»: catálogo, profesionales y moderación) y Maria no. El
permiso se da o se quita desde la línea de comandos, nunca desde la aplicación. La verificación de un
osteópata, además de en «Administración → Profesionales», también se puede hacer desde ahí:

```sh
bin/rails administradores:listar
bin/rails administradores:dar EMAIL=maria_campos@example.com
bin/rails administradores:quitar EMAIL=maria_campos@example.com

bin/rails verificacion:listar
bin/rails verificacion:dar EMAIL=maria_campos@example.com      # necesita su número de colegiado
bin/rails verificacion:quitar EMAIL=maria_campos@example.com
```

### Segundo factor de los usuarios de prueba

Los usuarios de las seeds no tienen el segundo factor activado: la primera vez que entran, la aplicación
pide darlo de alta (escanear el QR con la app, o escribir la clave que aparece debajo, y escribir el
código que muestra) y enseña 10 códigos de recuperación, que sirven para entrar sin el móvil. Desde
entonces, el login pide la clave y después el código de la app.

Para probar sin móvil, en desarrollo:

```sh
# Durante el alta: el código de la clave que muestra la página (sin espacios)
bin/rails runner "puts ROTP::TOTP.new('CLAVEDELAPAGINA').now"
# Con el segundo factor ya activado: el código actual de un usuario
bin/rails dos_factores:codigo EMAIL=paco@example.com
# Quién lo tiene activado, y quitárselo a alguien (tendrá que darlo de alta otra vez al entrar)
bin/rails dos_factores:estado
bin/rails dos_factores:restablecer EMAIL=paco@example.com
```

Cada código vale una sola vez: para volver a entrar en los mismos 30 segundos hay que esperar al
siguiente o usar un código de recuperación. `dos_factores:codigo` no existe en producción.

Tras 5 códigos incorrectos seguidos, la cuenta no acepta códigos durante 15 minutos (y el doble cada vez
que se repite, hasta 24 h). `dos_factores:estado` muestra las cuentas bloqueadas y
`dos_factores:restablecer` quita el bloqueo (y el segundo factor). Los avisos por correo de cada cambio se
pueden leer en `tmp/mails/`.

## Mapa de rutas

Todas las páginas exigen haber iniciado sesión, salvo el login (con su paso del código), el registro, la
confirmación del email y la recuperación de la clave. Y con la sesión iniciada, mientras no se activa el
segundo factor, todas llevan a su alta, salvo el logout. Lo de otros osteópatas (el filtro de
tratamientos, sus fichas, los informes de toda la plataforma, los casos clínicos y los perfiles) es solo
para los osteópatas verificados y los administradores: a los demás, el filtro y `/casos` les explican cómo
conseguir la verificación.

| Ruta | Página |
|---|---|
| `/osteopaths/sign_up` | Registro de un osteópata nuevo: no inicia sesión, envía el correo para confirmar el email y vuelve al login |
| `/osteopaths/confirmation`, `/osteopaths/confirmation/new` | Confirmar el email: el enlace del correo (un solo uso, caduca en 3 días) abre una página con el nombre y el email de la cuenta que pide su clave, y el email se confirma al enviarla (`PATCH /osteopaths/confirmation`); abrir el enlace no confirma nada. `/new`: pedir otro enlace. Después se entra con el login y se da de alta el segundo factor |
| `/osteopaths/sign_in` | Login: email y clave (sin el email confirmado, no se entra) |
| `/osteopaths/codigo` | Segundo paso del login: el código de la app o un código de recuperación, en 5 minutos. Tras 5 incorrectos seguidos, la cuenta no acepta códigos durante 15 minutos (el doble cada vez) y se avisa por correo |
| `/osteopaths/password/new`, `/osteopaths/password/edit` | Recuperar la clave: pedir el enlace por email (caduca en una hora) y elegir una clave nueva; después hay que entrar con el login |
| `DELETE /osteopaths/sign_out` | Logout (botón **Logout** de la barra de navegación): cierra la sesión en todos los dispositivos y una copia de la cookie de sesión deja de valer |
| `/cuenta` | Mi cuenta (el nombre en la barra de navegación): el perfil profesional y si está verificado, el segundo factor, cuántos códigos de recuperación quedan y generar otros |
| `/cuenta/perfil` | Editar el perfil profesional: número de colegiado, especialidad, ciudad y presentación (cambiar el número quita la verificación) |
| `/cuenta/segundo_factor` | Alta del segundo factor (QR y clave) o cambio de dispositivo (pide la clave actual y un código del móvil actual o de recuperación); al confirmarlo enseña los códigos de recuperación, una sola vez, y avisa por correo |
| `/` | Redirige a `/patients` |
| `/patients` | Mostrar pacientes: los del osteópata conectado, con Mostrar, Borrar y Editar; buscador por nombre o apellidos (`?busqueda=`) y de 20 en 20 (`?pagina=`) |
| `/patients/new`, `/patients/:id/edit` | Crear / editar paciente, con tablas de antecedentes editables sin recargar y la casilla del consentimiento para compartir sus datos |
| `/patients/:id` | Mostrar paciente: sus datos y si consiente compartirlos, lista de visitas con su progreso ("2 de 3" sesiones), gráfica de la evolución del dolor, accesos de otros osteópatas y botones Exportar datos y Borrar. Los pacientes de otros osteópatas que consienten se abren desde el filtro (solo verificados), con un identificador firmado que caduca en un día en lugar del número, sin nombre ni apellidos y sin visitas ni gráfica, y el acceso queda registrado |
| `/patients/:id/medical_background` | Mostrar antecedentes familiares y personales (si el paciente es de otro osteópata, el acceso queda registrado) |
| `/patients/:id/exportar` | Todos los datos del paciente en un fichero JSON, ficheros escaneados incluidos. Solo para su osteópata |
| `/crear_visita` | Asistente de nueva visita: paneles Visita, Diagnóstico y Sesiones; se guarda todo al final |
| `/visits/:id` | Resumen de una visita: paciente, anamnesis, diagnósticos con su progreso, sesiones y técnicas; botones para editar y borrar la visita, sus diagnósticos y sus sesiones, y para publicar un diagnóstico como caso clínico (si el paciente consiente) |
| `/visits/:id/edit` | Editar fecha, motivo, anamnesis y escala de dolor de la visita |
| `/visits/:id/informe` | Informe de la visita para el paciente, con diseño claro, para imprimir o guardar como PDF |
| `/visits/:visit_id/diagnoses/new`, `/diagnoses/:id/edit` | Añadir otro diagnóstico a la visita / editarlo (enfermedad del catálogo u «Otra…») |
| `/diagnoses/:diagnosis_id/sesiones/new`, `/sesiones/:id/edit` | Añadir una sesión a un diagnóstico / editarla, con sus técnicas |
| `/visits/:id/examination` | Exploración de la visita (ver, crear, editar, borrar) |
| `/visits/:id/supplementary_tests` | Pruebas complementarias de la visita (listar, crear, editar, borrar), con su fichero escaneado: PDF, JPG o PNG de hasta 10 MB |
| `/visits/:visit_id/supplementary_tests/:id/archivo` | El fichero escaneado: se abre en el navegador, o se descarga con `?descargar=1`. Solo para el osteópata de la visita |
| `/filtrar_tratamientos` | Diagnósticos de toda la plataforma (de los pacientes propios y de los de otros osteópatas que consienten) filtrados por género, edad y dolencias. Solo para verificados: a los demás les explica cómo conseguirlo |
| `/tecnicas_aplicadas?ids[]=…` | Nombre y descripción de las técnicas indicadas |
| `/informes` | Informes: técnicas más frecuentes, más efectivas, menos efectivas y para un cuadro clínico; de toda la plataforma (los pacientes propios y los de otros que consienten; solo para verificados) o de los pacientes propios (`?ambito=mios`) y entre fechas (`?desde=` y `?hasta=`), con gráfica de barras y marca de las medias con pocas sesiones |
| `/informes.csv?…` | El mismo informe en CSV (separador «;», coma decimal y UTF-8 con BOM, para Excel en español) |
| `/agenda` | Agenda: las sesiones del osteópata de hoy en adelante, por días |
| `/casos` | Casos clínicos: los más recientes primero, con enfermedad, sexo y tramo de edad del paciente, autor, mes de publicación y número de comentarios; filtro por enfermedad (`?enfermedad=`) y de 20 en 20 |
| `/diagnoses/:diagnosis_id/caso/new` | Publicar un diagnóstico propio como caso clínico: enseña lo que se publica y pide título, resumen y la confirmación de que no identifican al paciente; rechaza fechas, años, teléfonos, DNI y emails |
| `/casos/:id` | El caso: resumen, sesiones y gráfica del dolor en días (sin fechas), técnicas sugeridas, comentarios y el formulario para comentar y sugerir técnicas; botón para denunciar el caso o un comentario |
| `/casos/:id/edit` | Editar el título y el resumen (solo su autor, que también puede borrarlo) |
| `PATCH /casos/:id/republicar` | Su autor vuelve a publicar un caso que se retiró porque el paciente retiró el consentimiento, si ha vuelto a consentir |
| `/osteopatas/:id` | Perfil profesional de un osteópata verificado, con sus casos publicados |
| `/catalogo` | Solo administradores: técnicas y enfermedades con sus usos y posibles duplicados, y las últimas fusiones; desde aquí se borran las que no se usan |
| `/catalogo/tecnicas/:id/edit`, `/catalogo/enfermedades/:id/edit` | Solo administradores: editar el nombre y la descripción |
| `/catalogo/tecnicas/:id/fusion`, `/catalogo/enfermedades/:id/fusion` | Solo administradores: fusionar una entrada duplicada con otra |
| `/verificaciones` | Solo administradores: osteópatas pendientes de verificar (con número de colegiado) y verificados, con quién los verificó; verificar y quitar la verificación |
| `/moderacion` | Solo administradores: denuncias pendientes (ocultar el contenido o descartarlas), contenido oculto (volver a mostrarlo) y últimas denuncias resueltas, también las de contenido que su autor ha borrado. Lo de pacientes que ya no consienten no se muestra |

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Modelo de datos (16 tablas, más las 3 de Active Storage para los ficheros y la de Solid Cache; 3 enumeraciones) | `app/models`, `db/schema.rb` |
| Privacidad del paciente | `Patient#pertenece_a?`, `Patient.ficha` (identificador firmado para los pacientes ajenos) y las vistas `patients/show` y `patients/medical_background` |
| Consentimiento para compartir los datos y verificación | `Patient.visibles_para` y `visible_para?` (consentimiento del paciente y verificación de quien mira), `Diagnosis.visibles_para` (filtro), `Session.para_informe(visibles_para:)` (informes) y `Patient.ficha`; decisiones D83 y D94 |
| Segundo factor | `Osteopath` (códigos TOTP y de recuperación; `comprobar_codigo_de_acceso`, con el límite de incorrectos por cuenta), `Osteopaths::SessionsController` y `Osteopaths::CodigosController` (login en dos pasos), `DosFactoresController` y `CuentaController` (alta, cambio de dispositivo y códigos), `ApplicationController#exigir_segundo_factor`, `config/initializers/active_record_encryption.rb` y `lib/tasks/dos_factores.rake`; decisiones D84 y D92 |
| Avisos de seguridad por correo | `AvisosSeguridadMailer` (un texto por aviso), la plantilla `avisos_seguridad_mailer/aviso` y `Osteopath#avisar`; decisión D93 |
| Registro de accesos | `AccesoFicha` y `PatientsController#show` / `#medical_background`; decisión D85 |
| Exportar los datos de un paciente | `ExportacionPaciente` y `PatientsController#exportar`; decisión D86 |
| Seguridad (límite de intentos, caducidad de sesión, CSP, logs) | `app/controllers/osteopaths/` (cada límite de intentos con su nombre, para que no compartan el contador; en `SessionsController#create`, la clave se calcula una sola vez por intento), `config/initializers/devise.rb`, `content_security_policy.rb` y `filter_parameter_logging.rb`; decisiones D57–D68, D92 y D104 |
| Sesiones revocables | `Osteopath#authenticatable_salt` (con el token de sesión) y `Osteopaths::SessionsController#destroy`; decisión D99 |
| Integración continua | `config/ci.rb` (los pasos de `bin/ci`), `bin/brakeman`, `bin/bundler-audit`, `config/bundler-audit.yml` y `.github/workflows/ci.yml`; decisión D102 |
| Producción (caché, Puma, proxies, correo, comprobaciones al arrancar) | `config/environments/production.rb`, `config/cache.yml` (Solid Cache), `config/puma.rb`, `config/correo_smtp.rb` (SMTP siempre cifrado), `config/database.yml` y `config/initializers/comprobaciones_de_produccion.rb` (SSL de la base de datos, también en `DATABASE_URL`); decisiones D66, D98 y D104 |
| Guardado del asistente de visita en una transacción | `app/models/registro_visita.rb` |
| Filtro de tratamientos | `Diagnosis.por_sexo`, `por_edad_minima`, `por_edad_maxima`, `por_dolencias` y `filtrar` |
| Cálculo de los informes | `Treatment.mas_frecuentes`, `mas_efectivas`, `menos_efectivas` y `para_cuadro_clinico` |
| Seguimiento de visitas guardadas | `VisitsController` (editar, borrar), `DiagnosesController`, `SesionesController` y `Diagnosis#completado?`; decisiones D69–D70 |
| Gráfica de evolución del dolor | `GraficaDolor` (datos y geometría; en los casos clínicos, sin fechas) y la vista `patients/_grafica_dolor` (SVG); decisiones D71 y D89 |
| Ficheros escaneados (privados) | `SupplementaryTest` (tipos, tamaño, nombre), `SupplementaryTestsController#archivo`, `config/storage.yml` y la configuración de Active Storage en `config/application.rb`; decisiones D72–D73 |
| Buscador y paginación de pacientes | `Patient.buscar` (columna `texto_busqueda`), `Paginacion` y el parcial `shared/_paginacion`; decisión D74 |
| Agenda y sesiones programadas | `AgendaController`, `AgendaHelper#dia_agenda` y `Diagnosis#sesiones_realizadas` / `sesiones_programadas`; decisión D75 |
| Recuperación de la clave | `Osteopaths::PasswordsController` (límite de intentos), las vistas `devise/passwords` y `devise/mailer` y `config/initializers/devise.rb`; decisión D76 |
| Confirmación del email | `:confirmable` en `Osteopath` (con `para_confirmar` y `confirmar_con_clave`), `Osteopaths::ConfirmationsController` (el enlace pide la clave; límite de intentos), `Osteopaths::RegistrationsController` (tras registrarse, al login), las vistas `devise/confirmations` (`show`, la página del enlace) y `devise/mailer/confirmation_instructions`, `config/initializers/devise.rb` (caduca en 3 días, sin margen para entrar) y `lib/tasks/confirmacion.rake`; decisiones D103 y D104 |
| Informe de la visita | `VisitsController#informe`, el layout `informe` y la vista `visits/informe` (estilos de impresión en `application.scss`); decisión D77 |
| Filtros, gráfica y CSV de los informes | `Session.para_informe`, `Treatment#pocas_sesiones?`, `GraficaBarras`, `InformeCsv`, `InformesHelper` y la vista `informes/_grafica_barras`; decisiones D78–D80 |
| Administradores y catálogo | La marca `admin` de `Osteopath`, `lib/tasks/administradores.rake`, `SoloAdministradores` (404 para los demás), `app/controllers/catalogo/`, `FusionCatalogo` y `EntradaCatalogo` (posibles duplicados); decisiones D81–D82 |
| Perfil y verificación | `Osteopath#verificado?` / `#acceso_a_la_red?` (número de colegiado único, `clave_colegiado`, y quién verifica), `PerfilesController`, `OsteopatasController`, `VerificacionesController`, `AccesoALaRed` y `lib/tasks/verificacion.rake`; decisiones D87–D88, D94 y D95 |
| Casos clínicos | `Caso` (qué se publica, tramos de edad, días desde la primera sesión, datos identificativos, casos retirados y `visibles_para`), `CasosController` y las vistas `casos/`; decisiones D89 y D96 |
| Comentarios y técnicas sugeridas | `Comentario`, `ComentariosController` y `Caso#tecnicas_sugeridas`; decisión D90 |
| Denuncias y moderación | `Denuncia` (`resolver!`), `Denunciable` (las denuncias se conservan al borrar), `DenunciasController`, `ModeracionController` y `ModeracionHelper`; decisiones D91 y D97 |
| JavaScript (Stimulus) | `app/javascript/controllers`: `asistente_visita`, `filas_anidadas`, `informe`, `enfermedad_nueva`, `grafica_dolor` e `imprimir` |
| Estilos | `app/assets/stylesheets/application.scss` (Bootstrap en modo oscuro + ajustes, las gráficas y la impresión del informe) |
| Textos en español de modelos, atributos y enumeraciones | `config/locales/es.yml` |

## Tests

```sh
bin/rails test          # modelos, helpers, controladores, correos, integración y tareas (511 tests)
bin/rails test:system   # system tests con Chrome headless (24 tests)
bin/ci                  # todo lo que tiene que pasar antes de subir cambios (ver más abajo)
```

- **Modelos:** validaciones, enumeraciones, `Patient#edad`, `Patient#pertenece_a?`, cada criterio de
  filtrado y `Diagnosis.filtrar` (incluidos los casos "no filtrar" y los límites de edad), los rankings
  de los informes, el guardado transaccional de `RegistroVisita`, el progreso de los diagnósticos, la
  geometría de las gráficas (evolución del dolor y barras de los informes), los ficheros escaneados, el
  buscador de pacientes, la paginación, el CSV de los informes, las fusiones y posibles duplicados del
  catálogo, los códigos del segundo factor (margen de 30 segundos, un solo uso, códigos de recuperación,
  bloqueo por incorrectos que se dobla hasta 24 h y se pone a cero con uno correcto), que una cuenta
  recién registrada no puede entrar hasta confirmar su email,
  qué pacientes, diagnósticos y sesiones ve cada osteópata según el consentimiento y su verificación, y de
  la red: la verificación (y que la quita cambiar el número de colegiado), el número de colegiado único y
  quién verifica, qué casos ve cada uno (verificado, autor, administrador, oculto, retirado), los tramos de
  edad y los días sin fechas, los datos identificativos que se rechazan, las técnicas sugeridas, las
  denuncias (una por persona, nunca de lo propio, y que se conservan al borrar) y que la fusión de
  técnicas mueve también las sugeridas.
- **Controladores e integración:** acceso sin login, autorización (no se pueden editar ni borrar pacientes
  ajenos), privacidad de nombre y apellidos, el POST de `/crear_visita` (que no deja nada a medias si
  falla), el filtro con distintas combinaciones, `/tecnicas_aplicadas` y los informes. Del seguimiento:
  editar y borrar visitas, diagnósticos y sesiones (también que lo ajeno responde 404), «Otra…» sin
  dejar enfermedades sueltas si falla, las técnicas de una sesión y la gráfica solo en la ficha propia.
  De los ficheros: tipos admitidos según el contenido, tamaño máximo, nombre saneado, que se sirven solo
  al osteópata de la visita, sin caché y con su propia CSP, que se borran con la prueba y que no hay
  rutas públicas de Active Storage. De la gestión diaria: el buscador (tildes, mayúsculas, varias
  palabras, comodines), la paginación, la agenda (solo sesiones propias de hoy en adelante), el informe
  de la visita y la recuperación de la clave (correo, enlace de un solo uso que caduca, modo paranoico y
  límite de intentos, con su propio contador para pedir el enlace y para cambiar la clave). De los
  informes y el catálogo: los filtros por fechas y por pacientes propios,
  la gráfica (barras huecas y negativas), el umbral de pocas sesiones, el CSV (columnas, formato e
  inyección de fórmulas), que el catálogo responde 404 a quien no es administrador, la edición, las
  fusiones (sin duplicar técnicas en una sesión, en una transacción y registradas), el borrado de las
  entradas sin usos, que nadie se hace administrador al registrarse y las tareas de administradores. De
  la confirmación del email: que registrarse no inicia sesión y envía el correo (en español, con el enlace y
  sin la clave); que sin confirmar no se entra, y con la clave incorrecta el error es el mismo que para
  cualquier cuenta; que abrir el enlace no confirma nada y pide la clave de la cuenta (con otra, sin ella o
  con datos manipulados, no se confirma); que si otro registra tu email no puedes confirmarle la cuenta, y
  la recuperas cambiando la clave; el enlace de un solo uso, que caduca a los 3 días; pedir otro sin revelar
  si la cuenta existe o ya está confirmada; el límite de intentos (abrir el enlace y confirmar, juntos, y
  pedir otro enlace, aparte), y las tareas de confirmación. De
  los datos de salud: el login en dos pasos, el alta obligatoria, el bloqueo por códigos incorrectos aunque
  se use otra sesión u otra IP, el cambio de dispositivo con la clave y un código del actual, los códigos
  de recuperación, los avisos por correo y las tareas del segundo factor; que sin consentimiento el
  paciente no sale a otros en el filtro ni cuenta en sus informes y su ficha responde 404; el registro de
  accesos (solo los ajenos); y
  la exportación (contenido completo, solo del osteópata del paciente) y el borrado de todos sus datos.
  De la red: que sin verificar no se usa el filtro, no se abren fichas ajenas (ni con el enlace), los
  informes son solo de los pacientes propios y no se entra en los casos; que los enlaces a fichas ajenas
  caducan; publicar solo diagnósticos propios de pacientes que consienten, con la confirmación de anonimato
  y sin fechas ni teléfonos en el texto; que el caso no muestra nombre, fechas, edad exacta ni el día de
  publicación; volver a publicar un caso retirado; un doble envío; que solo el autor lo edita o borra; los
  comentarios con técnicas (límites, casos ocultos); las denuncias; la moderación (sin enseñar lo de
  pacientes que ya no consienten, y con las denuncias de contenido borrado) y la verificación solo para
  administradores, con quién verifica; el número de colegiado repetido; el perfil y las tareas de
  verificación.
- **Correos:** los avisos de seguridad (destinatario, remitente, texto y HTML, la fecha y que nunca llevan
  códigos ni la clave).
- **Seguridad:** límite de intentos de login (por IP y por cuenta), del código del segundo factor, de
  registro, de confirmación del email y de recuperación de la clave; que un login fallido calcula la clave
  las mismas veces tenga o no la cuenta el segundo factor y exista o no (el tiempo de respuesta no dice qué
  emails tienen cuenta); caducidad de la sesión y del paso del
  código; secreto del segundo factor cifrado; que cambiar la clave no inicia sesión; la clave mínima de 10
  caracteres; la CSP,
  el identificador firmado de las fichas ajenas, parámetros con forma inesperada, límites de los datos
  del asistente, datos personales y de salud, la clave actual y los códigos filtrados en los logs, y seeds
  que no se cargan en producción. Que al cerrar sesión una copia de la cookie deja de valer (y que caducar
  por inactividad no cierra las demás sesiones). De producción: que Solid Cache cuenta en su tabla como
  necesitan los límites de intentos, Puma solo en la propia máquina, que no arranca con la base de datos
  sin cifrar (tampoco si lo pide `DATABASE_URL`, y leyendo el `config/database.yml` de verdad), que el
  correo va siempre cifrado (STARTTLS obligatorio, o TLS en el puerto 465, y comprobando el certificado)
  y el aviso de permisos de `storage/`.
- **System tests:** registro con la confirmación del email (el enlace del correo y la clave, primero una
  que no es la suya) y el alta del segundo
  factor (QR, clave y códigos de recuperación), y login con un código de recuperación; login con el
  código de la app y «Mi cuenta»; crear un paciente añadiendo antecedentes dinámicamente; el flujo
  completo de crear visita (los tres paneles y los modales de sesión y técnica); filtrar tratamientos y navegar a las técnicas y al paciente; los informes;
  añadir una sesión con técnicas a una visita guardada y verla en el tooltip de la gráfica; editar un
  diagnóstico con «Otra…» y borrarlo; subir el fichero de una prueba complementaria y abrirlo, y rechazar
  uno que no es PDF, JPG ni PNG; buscar un paciente; recuperar la clave con el enlace del correo y entrar
  con la nueva y el código; abrir la agenda; abrir el informe de la visita y su botón de imprimir; generar
  un informe de mis pacientes entre fechas con su gráfica y su CSV; fusionar una técnica duplicada desde
  el catálogo; publicar un caso clínico, comentarlo sugiriendo una técnica, denunciarlo y ocultarlo desde
  la moderación; y completar el perfil y quedar pendiente de verificación.

En Windows los tests se ejecutan en un solo proceso; en Linux y macOS, en paralelo. En Windows, como los
demás scripts de `bin/`, se lanzan con Ruby: `ruby bin/rails test`, `ruby bin/ci`. Lo que solo falla con
los tests en paralelo no se ve en Windows, pero sí en GitHub, que usa Linux (ver «Comprobaciones de
seguridad»).

Última comprobación completa (14 de noviembre de 2026, tras las correcciones de la tercera auditoría de
seguridad, D104; ese mismo día también se hizo tras actualizar Rails a la 8.1.4.1, y antes el 20, el 24 y
el 27 de octubre): `bin/ci` y los system tests sin fallos en Windows, y además un recorrido de principio a
fin en el navegador, contra el servidor de desarrollo, con una osteópata nueva y un administrador, en 24
pasos:
- el registro (rechaza una clave corta), que no deja entrar hasta confirmar el email con el enlace del
  correo y su clave (rechaza una que no es la suya), y el alta del segundo factor;
- lo que no ve sin verificar, el perfil con el número de colegiado y su verificación;
- un paciente con su consentimiento y el asistente de visita;
- la exploración, una prueba con su fichero, una sesión programada en la agenda, el informe de la visita
  y la gráfica del dolor;
- el filtro de tratamientos y el informe de toda la plataforma con su CSV;
- un caso clínico (rechaza un año en el texto y no muestra el nombre de la paciente), un comentario, su
  denuncia y la moderación;
- la exportación de los datos, la retirada del consentimiento y el borrado del paciente;
- la entrada con un código de recuperación.

Todo funcionó, sin errores en el servidor ni en la consola del navegador (tampoco de la CSP). Ese recorrido
se hizo con un script aparte, que no está en el repositorio. Las mismas funciones las cubren, por separado,
los tests de arriba.

## Comprobaciones de seguridad

`bin/ci` prepara el entorno (`bin/setup`) y pasa, por este orden, las comprobaciones de seguridad, los
tests y las seeds (en la base de datos de test); si algo falla, lo dice al final. Tarda unos dos minutos y
necesita red (para la base de avisos y la auditoría del importmap). Los system tests se lanzan aparte. Las
comprobaciones de seguridad también se pueden lanzar sueltas; las herramientas están en el `Gemfile`:

```sh
bin/bundler-audit      # vulnerabilidades conocidas de las gemas de Gemfile.lock (antes actualiza los avisos)
bin/importmap audit    # vulnerabilidades de los paquetes JavaScript del importmap
bin/brakeman           # análisis estático de seguridad del código
```

`bin/bundler-audit` guarda la base de avisos en `tmp/ruby-advisory-db`, dentro del proyecto, y la
actualiza cada vez. Último resultado (15 de noviembre de 2026, con los avisos publicados hasta ese día y
tras actualizar `puma` y `msgpack`): ninguna vulnerabilidad conocida y ningún aviso de Brakeman.

Cuando se publica un aviso para una gema que usa la aplicación, `bin/ci` (y el CI de GitHub) falla aunque
el código no haya cambiado. Se actualizan solo las gemas afectadas, con `bundle update <gemas>
--conservative` (y `--patch` para quedarse en una versión de solo correcciones), y `bin/ci` comprueba que
todo sigue bien. Hasta ahora ha pasado tres veces:
- **24 de octubre:** `crass` 1.0.7 → 1.0.8 (GHSA-pq4g-8rxf-4g29: una URL mal formada dentro de CSS se
  salta el sanitizador de CSS). `crass` llega a través del sanitizador de HTML de Rails. Aquí el riesgo era
  muy bajo: `simple_format` no deja pasar el atributo `style`, y la CSP bloquea los estilos en línea.
- **14 de noviembre:** Rails 8.1.4 → 8.1.4.1, y además rack 3.2.8, nokogiri 1.19.7, loofah 2.25.3,
  rails-html-sanitizer 1.7.2, addressable 2.9.2 y sqlite3 2.10.2, por los avisos publicados desde el 27 de
  octubre:
  - Algunos no afectan a esta aplicación: el análisis de imágenes de Active Storage necesita
    `image_processing`, que la aplicación no usa, y tampoco usa vídeo, Google Cloud ni Action Mailbox.
  - Otros sí la tocan: la suplantación de la IP del cliente (en la que se basan los límites de intentos),
    el sanitizador de HTML y las subidas de ficheros.

  El CI de GitHub falló por ellos el mismo 14 de noviembre.
- **15 de noviembre:** `puma` 8.0.2 → 8.0.3 y `msgpack` 1.8.5 → 1.8.7, por ocho avisos publicados esa
  madrugada. El CI de GitHub falló por ellos en el push de D104 (ejecución #14).
  - El de `msgpack` no afecta a esta aplicación: es del decodificador de JRuby, y aquí `msgpack` solo la usa
    `bootsnap` para su propia caché.
  - De los siete de `puma`, tres son de funciones que no se usan: `pumactl` y el TLS del propio Puma (en
    producción, el TLS lo termina el proxy). Los otros cuatro sí la tocan: son formas de bloquear el
    servidor con clientes lentos (denegación de servicio), que un proxy como nginx mitiga en buena parte.
  - Se eligió la 8.0.3, que solo trae las correcciones, y no la 8.1.0, publicada un día después con
    funciones nuevas (`bundle update puma --patch --conservative`).

  `bin/ci` y los system tests, que arrancan con Puma, pasan con las dos versiones nuevas.

En GitHub, el workflow `.github/workflows/ci.yml` hace lo mismo en cada push y pull request a `main` (sin
los system tests), y el resultado se ve en la pestaña *Actions* del repositorio.

Al principio, el paso de los tests fallaba en GitHub aunque pasaban todos, y por eso no llegaba a cargar las
seeds:
- Al acabar los tests en paralelo, el proceso principal descarta sus conexiones a la base de datos.
- Después, `test/test_helper.rb` cargaba Active Storage para saber en qué carpeta borrar los ficheros que
  suben los tests, y Active Storage, al comprobar esa conexión ya descartada, fallaba.

Ya está corregido: la carpeta se averigua antes de repartir los tests.

Las dependencias están fijadas así (D101): las gemas añadidas para las mejoras, con versión exacta; el
resto, con `~>` (misma versión mayor), salvo `tzinfo-data`; y `Gemfile.lock` lleva la huella SHA-256 de
cada gema, que Bundler comprueba al instalarla.

Además, la aplicación ha pasado tres auditorías de seguridad completas, cada una con ocho revisiones:
configuración del agente de IA, secretos, código, dependencias, inyección, autenticación, infraestructura
e inyección de instrucciones. Lo que se corrigió está en [DECISIONES.md](DECISIONES.md):
- la primera, en D57–D68;
- la segunda, tras los bloques 5 y 6, en D92–D102. Encontró dos fallos altos, ya corregidos: se podía
  forzar el código del segundo factor reenviando la cookie de sesión, y cualquiera que se registrara veía
  datos de pacientes de otros osteópatas sin estar verificado.
- la tercera, el 14 de noviembre de 2026, en D104. No encontró fallos críticos ni altos. Se han corregido
  sus cuatro hallazgos de riesgo medio en la aplicación:
  - quien registraba el email de otra persona podía conseguir que esta le confirmara la cuenta con solo
    abrir el enlace del correo;
  - el tiempo de respuesta del login decía qué emails tienen cuenta;
  - el correo se podía enviar sin cifrar;
  - un `sslmode` dentro de `DATABASE_URL` se saltaba la comprobación del SSL de la base de datos.

  Quedan pendientes sus hallazgos de riesgo bajo y los de la configuración local del agente de IA.

Si se trabaja con un agente de IA (Claude Code), sus reglas de permisos (`.claude/settings.json`), los
subagentes de seguridad, `CLAUDE.md` y los escáneres de `scripts/security/` están fuera del repositorio a
propósito (D100): protegen solo la copia local, y un clon nuevo no los trae.

## Producción con PostgreSQL

`config/database.yml` ya define producción con PostgreSQL, y la gema `pg` está en el grupo de producción
del `Gemfile`:

1. Instalar las gemas sin las de desarrollo y test: `bundle config set --local without "development test"`
   y `bundle install`.
2. Definir las variables de entorno:
   - `DATABASE_URL`, por ejemplo `postgres://usuario:clave@servidor:5432/red_social_fisios`. La conexión
     exige SSL (`PGSSLMODE=require`, que cifra pero no comprueba el certificado del servidor). Si se
     dispone del certificado de la autoridad del servidor de base de datos, es mejor
     `PGSSLMODE=verify-full` (con `PGSSLROOTCERT`). Con un modo que permita conectar sin cifrar (`disable`,
     `allow` o `prefer`) la aplicación no arranca; solo para pruebas locales: `PGSSLMODE=disable` con
     `PERMITIR_BD_SIN_SSL=1`. Un `?sslmode=…` dentro de `DATABASE_URL` manda sobre `PGSSLMODE`, y también
     se comprueba.
   - `RAILS_MASTER_KEY` (o `SECRET_KEY_BASE`). El secreto del segundo factor de cada osteópata se guarda
     cifrado con claves derivadas de `secret_key_base`: si cambia, nadie podrá entrar con su app y habrá
     que restablecer el segundo factor de todos (ver el punto 6).
   - `APP_HOST` (obligatoria): el dominio (o dominios, separados por comas) en el que se publica la
     aplicación. Solo se atienden peticiones a esos dominios; sin esta variable la aplicación no arranca
     (salvo `assets:precompile` con `SECRET_KEY_BASE_DUMMY=1`).
   - Para el correo (confirmar el email al registrarse, recuperar la clave y avisos de seguridad):
     `SMTP_ADDRESS`, `SMTP_PORT` (587 por defecto), `SMTP_USER_NAME`, `SMTP_PASSWORD` y `MAIL_FROM` (el
     remitente). Sin `SMTP_ADDRESS` no se envía ningún correo, y quien se registre no podrá confirmar su
     email ni, por tanto, entrar (salvo que se confirme desde la consola: ver el punto 8). Los enlaces del
     correo usan `https` y el primer dominio de `APP_HOST`. El correo va siempre cifrado: con STARTTLS
     obligatorio (puerto 587) o con TLS desde el principio (puerto 465), y comprobando el certificado del
     servidor de correo. Si el servidor no lo admite, los correos no se envían.
   - Si el proxy está en otra máquina con una dirección que no sea privada: `TRUSTED_PROXIES`, con sus
     direcciones o redes separadas por comas (ver más abajo).
3. `RAILS_ENV=production bin/rails db:prepare assets:precompile` y arrancar con `bin/rails server`.
   `db:prepare` crea también la tabla de la caché (Solid Cache). No hay que ejecutar `db:seed`: las seeds
   se niegan a cargarse en producción.
4. Publicar Puma solo detrás de un proxy que termine HTTPS (la aplicación fuerza HTTPS y supone que
   el proxy lo gestiona). En producción Puma solo escucha en la propia máquina (`127.0.0.1`, puerto
   `PORT` o 3000), así que el proxy tiene que estar en el mismo servidor; si no (o dentro de un
   contenedor), `BINDING` cambia dónde escucha, por ejemplo `tcp://0.0.0.0:3000`, y entonces hay que
   cerrar ese puerto al exterior con el cortafuegos. El proxy debe aceptar peticiones de al menos 11 MB
   para la subida de ficheros (en nginx, `client_max_body_size 11m`; por defecto admite solo 1 MB).
5. Los ficheros escaneados de las pruebas complementarias se guardan en disco, en `storage/` o en la
   carpeta que indique `STORAGE_PATH`. Son datos de salud: esa carpeta debe estar en un volumen
   persistente (no se puede perder al redesplegar), con copias de seguridad junto con las de la base de
   datos, cifrado en disco y solo accesible para el usuario que ejecuta la aplicación (permisos 700: si
   no, la aplicación lo avisa en el log al arrancar). Nunca se sirven directamente: la aplicación los
   entrega solo al osteópata de la visita.
6. Cada osteópata da de alta su segundo factor la primera vez que entra. Si alguien pierde el móvil y
   también los códigos de recuperación, tras comprobar que es él:
   `RAILS_ENV=production bin/rails dos_factores:restablecer EMAIL=su@email` (al entrar con su clave lo dará
   de alta otra vez; también quita el bloqueo por códigos incorrectos). `dos_factores:estado` lista quién
   lo tiene activado y qué cuentas están bloqueadas.
7. El reloj del servidor tiene que estar en hora (sincronizado por NTP): los códigos del segundo factor
   cambian cada 30 segundos y solo se acepta un margen de 30 segundos antes o después.
8. Nadie es administrador al empezar. Cuando el osteópata que vaya a mantener el catálogo, verificar a
   los profesionales y moderar los casos se haya registrado y confirmado su email:
   `RAILS_ENV=production bin/rails administradores:dar EMAIL=su@email`. Si el correo aún no funciona, su
   email se confirma desde la consola con `confirmacion:dar EMAIL=su@email` (`confirmacion:listar` lista
   las cuentas sin confirmar); sirve también para quien no reciba el correo, después de comprobar por otro
   medio que el email es suyo. Desde entonces verifica a los
   demás en «Administración → Profesionales», después de comprobar su número de colegiado y su nombre en
   el registro de su colegio profesional (para verificarse a sí mismo, `verificacion:dar EMAIL=su@email`,
   una vez escrito su número en su perfil). Hasta que estén verificados, los osteópatas solo ven sus
   propios pacientes.
9. «Borrar» un paciente borra todos sus datos y no se puede deshacer. La ley obliga a conservar la
   historia clínica un mínimo de años (en España, 5 desde el alta según la Ley 41/2002, y más en algunas
   comunidades autónomas), así que, antes de borrar por una petición del paciente, conviene comprobar que
   ya no hay que conservarla y entregarle sus datos con «Exportar datos».

El límite de intentos de login, del código del segundo factor, de registro, de confirmación del email y de
recuperación de la clave (y el de casos, comentarios y denuncias) cuenta los intentos por IP (el del
login, también por cuenta) y guarda los contadores en la caché de Rails, uno por límite. Los códigos
incorrectos del segundo factor se cuentan aparte, en la base de datos:
- La caché de producción es **Solid Cache**, en una tabla de la misma base de datos (`config/cache.yml`):
  los contadores son comunes a todos los procesos de Puma y a todos los servidores, y no se pierden al
  desplegar. No hace falta Redis ni Memcached.
- Detrás de un proxy, Rails debe ver la IP real del cliente: el proxy tiene que añadir la cabecera
  `X-Forwarded-For` (sin aceptar la que envíe el cliente) y, si su dirección no es privada, declararla
  en `TRUSTED_PROXIES`. Si no, todos los usuarios compartirían la IP del proxy y un atacante podría
  bloquear el login de todos.

## Problemas conocidos en Windows

- `bin/rails db:drop` y `db:reset` fallan con *Permission denied* porque Rails abre la base de datos
  SQLite antes de borrarla. No hacen falta: para regenerar la base de datos con las seeds basta con
  volver a ejecutar `bin/rails db:setup`, que en desarrollo vacía la base de datos antes de cargar el
  esquema. Si aun así se necesita `db:reset`: `DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:reset`
  (en PowerShell, `$env:DISABLE_DATABASE_ENVIRONMENT_CHECK=1; ruby bin/rails db:reset`).

## Decisiones de diseño

Las decisiones tomadas en los puntos que la especificación dejaba abiertos están en
[DECISIONES.md](DECISIONES.md).

## Nota

Este README está escrito en español debido a los potenciales usuarios que tienen la aplicación.
