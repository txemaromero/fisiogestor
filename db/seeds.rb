# Datos de ejemplo de RedSocialFisios.
# Son idempotentes: `bin/rails db:seed` se puede ejecutar varias veces sin duplicar registros.
# Usuarios: paco@example.com y maria_campos@example.com, ambos con clave demo-123456. No tienen segundo factor:
# lo dan de alta al entrar por primera vez (D84), con una app de autenticación en el móvil.

# Crean cuentas con una clave conocida y pacientes ficticios: nunca deben cargarse en producción.
abort "Las seeds de ejemplo no se cargan en producción." if Rails.env.production?

# --- Osteópatas ---------------------------------------------------------------------------------

def crear_osteopata(email:, nombre:, apellidos:)
  Osteopath.find_or_create_by!(email: email) do |osteopata|
    osteopata.nombre = nombre
    osteopata.apellidos = apellidos
    osteopata.password = osteopata.password_confirmation = "demo-123456"
    osteopata.skip_confirmation! # con el email ya confirmado (D103), y sin enviar el correo
  end
end

paco  = crear_osteopata(email: "paco@example.com", nombre: "Paco", apellidos: "Martínez")
maria = crear_osteopata(email: "maria_campos@example.com", nombre: "Maria", apellidos: "Campos Gil")
# Paco administra el catálogo de técnicas y enfermedades (D81); Maria no.
paco.update!(admin: true) unless paco.admin?

# --- Catálogo de enfermedades -------------------------------------------------------------------

ENFERMEDADES = {
  "Bronquitis" => "Inflamación de los bronquios que provoca tos y dificultad para respirar.",
  "Ciática" => "Dolor que recorre el trayecto del nervio ciático, desde la zona lumbar hasta la pierna.",
  "Condromalacia rotuliana" => "Reblandecimiento y desgaste del cartílago de la cara posterior de la rótula.",
  "Hernia discal" => "Desplazamiento del núcleo del disco intervertebral que puede comprimir las raíces nerviosas.",
  "Lumbago" => "Dolor agudo en la zona lumbar, normalmente de origen muscular.",
  "Miopía" => "Defecto visual que dificulta ver con nitidez los objetos lejanos.",
  "Intestino permeable" => "Aumento de la permeabilidad de la mucosa intestinal que se asocia a molestias digestivas."
}.freeze

enfermedades = ENFERMEDADES.to_h do |nombre, descripcion|
  [ nombre, Disease.find_or_create_by!(nombre: nombre) { |enfermedad| enfermedad.descripcion = descripcion } ]
end

# --- Catálogo de técnicas -----------------------------------------------------------------------

TECNICAS = {
  "Masaje espalda" => "Masaje de la musculatura paravertebral para relajar la espalda.",
  "Descompresión columna" => "Tracción suave de la columna para reducir la presión sobre los discos intervertebrales.",
  "Estiramiento cuadrado lumbar" => "Estiramiento pasivo del cuadrado lumbar en decúbito lateral.",
  "Manipulación lumbar" => "Manipulación de alta velocidad y baja amplitud sobre las vértebras lumbares.",
  "Manipulación en lumbar roll" => "Manipulación lumbar en decúbito lateral con rotación del tronco.",
  "Estiramiento columna" => "Se estiran los erectores espinales.",
  "Stretching cuadrado lumbar" => "Estiramiento activo del cuadrado lumbar realizado por el propio paciente.",
  "Hipopresivos" => "Ejercicios respiratorios que reducen la presión abdominal y tonifican la faja abdominal.",
  "Movilización rotuliana" => "Movilización pasiva de la rótula en sentido craneal, caudal y lateral.",
  "Fisioterapia respiratoria" => "Técnicas de drenaje y respiración para movilizar las secreciones bronquiales.",
  "Masaje visceral abdominal" => "Movilización suave de las vísceras abdominales para mejorar el tránsito intestinal."
}.freeze

tecnicas = TECNICAS.to_h do |nombre, descripcion|
  [ nombre, Treatment.find_or_create_by!(nombre: nombre) { |tecnica| tecnica.descripcion = descripcion } ]
end

# --- Pacientes, antecedentes y visitas ----------------------------------------------------------
# Cada sesión es [fecha, dolor antes, dolor después, técnicas aplicadas]. Las próximas (para la agenda)
# son [días a partir de hoy, técnicas previstas].

PACIENTES = [
  {
    osteopata: paco, nombre: "Juan", apellidos: "Martínez Campos", anyo_nacimiento: 1980, sexo: "hombre",
    familiares: [ [ "Padre", "digestivos", "Problemas de intestino permeable" ],
                  [ "Madre", "cardio_respiratorios", "Arritmia" ] ],
    personales: [ [ "musculo_esqueleticos", "Condromalacia rotuliana" ],
                  [ "endocrinos", "Hipotiroidismo" ] ],
    visitas: [
      { fecha: "2026-01-12", motivo: "Dolor lumbar", escala_dolor: 8,
        anamnesis: "Dolor lumbar agudo tras cargar cajas en una mudanza. No irradia a las piernas.",
        enfermedad: "Lumbago", sesiones_recomendadas: 3,
        descripcion: "Contractura de la musculatura lumbar.",
        sesiones: [ [ "2026-01-14", 8, 6, [ "Masaje espalda", "Estiramiento cuadrado lumbar" ] ],
                    [ "2026-01-21", 6, 2, [ "Manipulación lumbar", "Masaje espalda" ] ],
                    [ "2026-01-28", 3, 1, [ "Estiramiento columna", "Hipopresivos" ] ] ] }
    ]
  },
  {
    osteopata: paco, nombre: "María", apellidos: "Torres Gutiérrez", anyo_nacimiento: 1992, sexo: "mujer",
    familiares: [ [ "Madre", "musculo_esqueleticos", "Artrosis de rodilla" ] ],
    personales: [ [ "musculo_esqueleticos", "Esguince de tobillo derecho en 2019" ] ],
    visitas: [
      { fecha: "2026-02-03", motivo: "Dolor de rodilla al subir escaleras", escala_dolor: 6,
        anamnesis: "Dolor en la cara anterior de la rodilla derecha que empeora al subir escaleras y tras correr.",
        enfermedad: "Condromalacia rotuliana", sesiones_recomendadas: 3,
        descripcion: "Condromalacia rotuliana de grado II en la rodilla derecha.",
        sesiones: [ [ "2026-02-05", 6, 5, [ "Movilización rotuliana" ] ],
                    [ "2026-02-12", 5, 3, [ "Movilización rotuliana", "Hipopresivos" ] ] ],
        proximas: [ [ 0, [ "Movilización rotuliana" ] ] ] }
    ]
  },
  {
    osteopata: paco, nombre: "Pepe", apellidos: "Campos Giménez", anyo_nacimiento: 1958, sexo: "hombre",
    familiares: [ [ "Hermano", "cardio_respiratorios", "Hipertensión" ] ],
    personales: [ [ "cardio_respiratorios", "Hipertensión arterial controlada" ],
                  [ "genito_urinarios", "Hiperplasia benigna de próstata" ] ],
    visitas: [
      { fecha: "2026-03-02", motivo: "Dolor lumbar irradiado a la pierna izquierda", escala_dolor: 9,
        anamnesis: "Dolor lumbar de tres semanas que baja por la pierna izquierda con hormigueo en el pie.",
        enfermedad: "Hernia discal", sesiones_recomendadas: 4,
        descripcion: "Hernia discal L4-L5 con irradiación ciática izquierda.",
        sesiones: [ [ "2026-03-04", 9, 6, [ "Descompresión columna", "Masaje espalda" ] ],
                    [ "2026-03-11", 7, 4, [ "Descompresión columna", "Manipulación en lumbar roll" ] ],
                    [ "2026-03-18", 5, 4, [ "Descompresión columna", "Estiramiento columna" ] ] ],
        proximas: [ [ 7, [ "Descompresión columna" ] ] ],
        exploracion: {
          inspeccion_estatica: "Hiperlordosis lumbar y báscula pélvica izquierda",
          inspeccion_dinamica: "Flexión anterior limitada y dolorosa",
          disfunciones_somaticas: "L4-L5 en extensión",
          examen_ortopedico_test: "Lasègue positivo a 45º en la pierna izquierda",
          examen_neurologico_reflejos: "Reflejo aquíleo izquierdo disminuido",
          examen_cardiovascular_tension_arterial: "135/85"
        },
        pruebas: [ { tipo_prueba: "irm", resumen: "Protrusión discal L4-L5 con leve compromiso de la raíz L5 izquierda.",
                     escaneado: "irm_lumbar_pepe_campos.pdf" },
                   { tipo_prueba: "rx", resumen: "Rectificación de la lordosis lumbar.",
                     escaneado: "rx_lumbar_pepe_campos.jpg" } ] }
    ]
  },
  {
    osteopata: paco, nombre: "Lucía", apellidos: "Fernández Ruiz", anyo_nacimiento: 2004, sexo: "mujer",
    familiares: [ [ "Padre", "cardio_respiratorios", "Asma" ] ],
    personales: [ [ "cardio_respiratorios", "Asma leve" ] ],
    visitas: [
      { fecha: "2026-02-16", motivo: "Tos persistente y opresión en el pecho", escala_dolor: 4,
        anamnesis: "Tos productiva desde hace dos semanas tras un resfriado.",
        enfermedad: "Bronquitis", sesiones_recomendadas: 2,
        descripcion: "Bronquitis aguda con acumulación de secreciones.",
        sesiones: [ [ "2026-02-18", 4, 2, [ "Fisioterapia respiratoria" ] ],
                    [ "2026-02-25", 3, 1, [ "Fisioterapia respiratoria", "Hipopresivos" ] ] ] }
    ]
  },
  {
    osteopata: maria, nombre: "María", apellidos: "Pérez Gil", anyo_nacimiento: 1975, sexo: "mujer",
    familiares: [ [ "Madre", "endocrinos", "Diabetes tipo 2" ] ],
    personales: [ [ "endocrinos", "Hipotiroidismo" ],
                  [ "digestivos", "Colon irritable" ] ],
    visitas: [
      { fecha: "2026-01-20", motivo: "Dolor en el glúteo que baja por la pierna derecha", escala_dolor: 8,
        anamnesis: "Dolor en el glúteo derecho que se irradia por la cara posterior del muslo al estar sentada.",
        enfermedad: "Ciática", sesiones_recomendadas: 3,
        descripcion: "Ciática derecha por síndrome del piramidal.",
        sesiones: [ [ "2026-01-22", 8, 4, [ "Estiramiento cuadrado lumbar", "Manipulación lumbar" ] ],
                    [ "2026-01-29", 6, 4, [ "Manipulación en lumbar roll", "Stretching cuadrado lumbar" ] ],
                    [ "2026-02-05", 5, 2, [ "Estiramiento cuadrado lumbar", "Masaje espalda" ] ] ] }
    ]
  },
  {
    osteopata: maria, nombre: "Antonio", apellidos: "López Sanz", anyo_nacimiento: 1950, sexo: "hombre",
    familiares: [ [ "Padre", "neurologicos", "Párkinson" ] ],
    personales: [ [ "musculo_esqueleticos", "Artrosis lumbar" ] ],
    visitas: [
      { fecha: "2026-04-06", motivo: "Dolor lumbar crónico", escala_dolor: 7,
        anamnesis: "Dolor lumbar de años de evolución que empeora por la mañana y mejora al caminar.",
        enfermedad: "Lumbago", sesiones_recomendadas: 2,
        descripcion: "Lumbalgia mecánica sobre artrosis lumbar.",
        sesiones: [ [ "2026-04-08", 7, 5, [ "Masaje espalda", "Manipulación lumbar" ] ],
                    [ "2026-04-15", 6, 6, [ "Masaje espalda" ] ] ],
        proximas: [ [ 2, [ "Manipulación lumbar" ] ] ] }
    ]
  },
  {
    osteopata: maria, nombre: "Carmen", apellidos: "Navarro Díaz", anyo_nacimiento: 1966, sexo: "mujer",
    familiares: [ [ "Hermana", "genito_urinarios", "Cálculos renales" ] ],
    personales: [ [ "musculo_esqueleticos", "Hernia cervical C5-C6" ] ],
    visitas: [
      { fecha: "2026-03-09", motivo: "Dolor lumbar al estar de pie", escala_dolor: 8,
        anamnesis: "Dolor lumbar que aparece tras estar de pie mucho tiempo en el trabajo.",
        enfermedad: "Hernia discal", sesiones_recomendadas: 3,
        descripcion: "Hernia discal L5-S1 sin afectación neurológica.",
        sesiones: [ [ "2026-03-11", 8, 6, [ "Descompresión columna" ] ],
                    [ "2026-03-18", 7, 4, [ "Descompresión columna", "Hipopresivos" ] ],
                    [ "2026-03-25", 5, 4, [ "Estiramiento columna" ] ] ] }
    ]
  },
  {
    # No consiente compartir sus datos (D83): solo Maria lo ve en el filtro y en los informes.
    osteopata: maria, nombre: "Javier", apellidos: "Romero Ortega", anyo_nacimiento: 1999, sexo: "hombre", consiente: false,
    familiares: [ [ "Madre", "digestivos", "Enfermedad celíaca" ] ],
    personales: [ [ "digestivos", "Intolerancia a la lactosa" ] ],
    visitas: [
      { fecha: "2026-05-04", motivo: "Hinchazón abdominal y digestiones pesadas", escala_dolor: 5,
        anamnesis: "Hinchazón abdominal después de las comidas desde hace meses.",
        enfermedad: "Intestino permeable", sesiones_recomendadas: 3,
        descripcion: "Disfunción visceral asociada a intestino permeable.",
        # La última sesión no tiene escala postsesión: no cuenta en los informes de efectividad.
        sesiones: [ [ "2026-05-06", 5, 4, [ "Masaje visceral abdominal", "Hipopresivos" ] ],
                    [ "2026-05-13", 4, 3, [ "Masaje visceral abdominal" ] ],
                    [ "2026-05-20", 3, nil, [ "Hipopresivos" ] ] ] }
    ]
  }
].freeze

PACIENTES.each do |datos|
  paciente = Patient.find_or_create_by!(osteopath: datos[:osteopata], nombre: datos[:nombre],
                                        apellidos: datos[:apellidos]) do |nuevo|
    nuevo.anyo_nacimiento = datos[:anyo_nacimiento]
    nuevo.sexo = datos[:sexo]
    nuevo.consiente_compartir = datos.fetch(:consiente, true)
  end

  datos[:familiares].each do |familiar, tipo, descripcion|
    paciente.family_medical_backgrounds.find_or_create_by!(familiar: familiar, tipo: tipo, descripcion: descripcion)
  end
  datos[:personales].each do |tipo, descripcion|
    paciente.personal_medical_backgrounds.find_or_create_by!(tipo: tipo, descripcion: descripcion)
  end

  datos[:visitas].each do |datos_visita|
    visita = Visit.find_or_create_by!(patient: paciente, osteopath: paciente.osteopath,
                                      fecha: Date.parse(datos_visita[:fecha])) do |nueva|
      nueva.motivo = datos_visita[:motivo]
      nueva.anamnesis = datos_visita[:anamnesis]
      nueva.escala_dolor = datos_visita[:escala_dolor]
    end

    diagnostico = visita.diagnoses.find_or_create_by!(disease: enfermedades.fetch(datos_visita[:enfermedad])) do |nuevo|
      nuevo.sesiones_recomendadas = datos_visita[:sesiones_recomendadas]
      nuevo.descripcion = datos_visita[:descripcion]
    end

    datos_visita[:sesiones].each do |fecha, dolor_pre, dolor_post, nombres_tecnicas|
      sesion = diagnostico.sessions.find_or_create_by!(fecha: Date.parse(fecha)) do |nueva|
        nueva.escala_dolor_pre_sesion = dolor_pre
        nueva.escala_dolor_post_sesion = dolor_post
      end
      sesion.treatments = nombres_tecnicas.map { |nombre| tecnicas.fetch(nombre) }
    end

    # Sesiones programadas a partir de hoy (salen en la agenda). Solo se crean si el diagnóstico no tiene
    # ya alguna futura, para que repetir las seeds otro día no las duplique.
    unless diagnostico.sessions.exists?(fecha: Date.current..)
      datos_visita.fetch(:proximas, []).each do |dias, nombres_tecnicas|
        sesion = diagnostico.sessions.create!(fecha: Date.current + dias)
        sesion.treatments = nombres_tecnicas.map { |nombre| tecnicas.fetch(nombre) }
      end
    end

    if datos_visita[:exploracion]
      (visita.examination || visita.build_examination).update!(datos_visita[:exploracion])
    end
    # Las pruebas llevan su fichero escaneado de ejemplo (db/seeds/, con el mismo nombre), si existe.
    datos_visita.fetch(:pruebas, []).each do |datos_prueba|
      prueba = visita.supplementary_tests.find_or_create_by!(datos_prueba)
      fichero = Rails.root.join("db/seeds", prueba.escaneado)
      next if prueba.archivo.attached? || !fichero.exist?

      prueba.archivo.attach(io: File.open(fichero, "rb"), filename: prueba.escaneado)
    end
  end
end

# --- Red de osteópatas: perfiles y casos clínicos (D87-D90) --------------------------------------
# Paco y Maria tienen su perfil profesional y están verificados (números de colegiado ficticios). Cada uno
# ha publicado un caso clínico, que el otro ha comentado sugiriendo técnicas.

{
  paco => { numero_colegiado: "28-01234", especialidad: "Osteopatía estructural", ciudad: "Madrid",
            presentacion: "Osteópata desde 2010. Trabajo sobre todo con dolor lumbar y cervical." },
  maria => { numero_colegiado: "46-05678", especialidad: "Osteopatía visceral", ciudad: "Valencia",
             presentacion: "Me interesan los casos de dolor crónico y su relación con el sistema digestivo." }
}.each do |osteopata, perfil|
  osteopata.update!(perfil) if osteopata.numero_colegiado.blank?
  osteopata.verificar! unless osteopata.verificado?
end

CASOS = [
  {
    osteopata: paco, paciente: [ "Pepe", "Campos Giménez" ], enfermedad: "Hernia discal",
    titulo: "Hernia discal L4-L5 con irradiación: el dolor se estanca en 4",
    resumen: "Hernia discal L4-L5 con dolor que baja por la pierna izquierda. Con descompresión y manipulación, " \
             "el dolor bajó de 9 a 4 en tres sesiones, pero en la última apenas mejoró. ¿Qué añadiríais en las " \
             "próximas sesiones? ¿Habéis probado ejercicios de control motor en casos así?",
    comentarios: [ [ maria, "En casos parecidos me ha ido bien añadir estiramientos del cuadrado lumbar y que haga " \
                            "ejercicios de control motor en casa entre sesiones.",
                     [ "Estiramiento cuadrado lumbar", "Hipopresivos" ] ] ]
  },
  {
    osteopata: maria, paciente: [ "María", "Pérez Gil" ], enfermedad: "Ciática",
    titulo: "Ciática por síndrome del piramidal que empeora al estar sentada",
    resumen: "Ciática derecha por síndrome del piramidal: el dolor aparece sobre todo después de estar sentada " \
             "mucho rato. Ha bajado de 8 a 2 en tres sesiones. Comparto lo que he aplicado por si sirve, y por " \
             "si alguien propone algo para evitar recaídas.",
    comentarios: [ [ paco, "Buen resultado. Para evitar recaídas yo le daría estiramientos para hacer en casa.",
                     [ "Stretching cuadrado lumbar" ] ] ]
  }
].freeze

CASOS.each do |datos|
  nombre, apellidos = datos[:paciente]
  paciente = datos[:osteopata].patients.find_by!(nombre: nombre, apellidos: apellidos)
  diagnostico = Diagnosis.joins(:visit, :disease)
                         .find_by!(visits: { patient_id: paciente.id }, diseases: { nombre: datos[:enfermedad] })
  caso = Caso.find_or_create_by!(diagnosis: diagnostico) do |nuevo|
    nuevo.osteopath = datos[:osteopata]
    nuevo.titulo = datos[:titulo]
    nuevo.resumen = datos[:resumen]
  end

  datos[:comentarios].each do |autor, texto, nombres_tecnicas|
    next if caso.comentarios.exists?(osteopath: autor, texto: texto)

    caso.comentarios.create!(osteopath: autor, texto: texto, treatments: nombres_tecnicas.map { |nombre_tecnica| tecnicas.fetch(nombre_tecnica) })
  end
end

puts "Seeds cargadas: #{Osteopath.count} osteópatas, #{Patient.count} pacientes, #{Visit.count} visitas, " \
     "#{Diagnosis.count} diagnósticos, #{Session.count} sesiones, #{Disease.count} enfermedades, " \
     "#{Treatment.count} técnicas, #{Caso.count} casos clínicos y #{Comentario.count} comentarios."
