# Todos los datos de un paciente en un JSON (D86), para entregárselos si ejerce su derecho de acceso o de
# portabilidad (RGPD, arts. 15 y 20): ficha, consentimiento, antecedentes, visitas con su exploración,
# pruebas complementarias (con el fichero escaneado en base64), diagnósticos, sesiones y técnicas, los
# casos clínicos publicados con sus comentarios (D89) y el registro de los osteópatas que han abierto su
# ficha. Las fechas van en ISO 8601.
class ExportacionPaciente
  VERSION = 1

  def initialize(patient)
    @patient = patient
  end

  def nombre_fichero
    nombre = I18n.transliterate(@patient.nombre_completo, locale: :es).downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    "datos-#{nombre}-#{Date.current.iso8601}.json"
  end

  def generar
    JSON.pretty_generate(datos)
  end

  def datos
    {
      formato: { aplicacion: "RedSocialFisios", version: VERSION, exportado_at: Time.current.iso8601 },
      paciente: paciente,
      osteopata: { nombre: @patient.osteopath.nombre_completo, email: @patient.osteopath.email },
      antecedentes_familiares: @patient.family_medical_backgrounds.map do |antecedente|
        { familiar: antecedente.familiar, tipo: etiqueta(:background_type, antecedente.tipo), descripcion: antecedente.descripcion }
      end,
      antecedentes_personales: @patient.personal_medical_backgrounds.map do |antecedente|
        { tipo: etiqueta(:background_type, antecedente.tipo), descripcion: antecedente.descripcion }
      end,
      visitas: visitas.map { |visita| visita_exportada(visita) },
      casos_clinicos: casos.map { |caso| caso_exportado(caso) },
      accesos_de_otros_osteopatas: @patient.accesos_fichas.includes(:osteopath).map do |acceso|
        { fecha: acceso.created_at.iso8601, osteopata: acceso.osteopath.nombre_completo, pagina: acceso.nombre_pagina }
      end
    }
  end

  private

  def paciente
    {
      nombre: @patient.nombre,
      apellidos: @patient.apellidos,
      anyo_nacimiento: @patient.anyo_nacimiento,
      sexo: etiqueta(:sex_type, @patient.sexo),
      alta: @patient.created_at.iso8601,
      consentimiento_compartir: {
        consiente: @patient.consiente_compartir?,
        actualizado_at: @patient.consentimiento_actualizado_at&.iso8601
      }
    }
  end

  def visitas
    @patient.visits
            .includes(:examination, supplementary_tests: { archivo_attachment: :blob },
                                    diagnoses: [ :disease, { sessions: :treatments } ])
            .order(:fecha, :id)
  end

  def visita_exportada(visita)
    {
      fecha: visita.fecha&.iso8601,
      motivo: visita.motivo,
      anamnesis: visita.anamnesis,
      escala_dolor: visita.escala_dolor,
      exploracion: visita.examination&.slice(*Examination::CAMPOS)&.compact_blank,
      pruebas_complementarias: visita.supplementary_tests.sort_by(&:id).map { |prueba| prueba_exportada(prueba) },
      diagnosticos: visita.diagnoses.sort_by(&:id).map do |diagnostico|
        {
          enfermedad: diagnostico.disease.nombre,
          descripcion: diagnostico.descripcion,
          sesiones_recomendadas: diagnostico.sesiones_recomendadas,
          sesiones: diagnostico.sessions.map do |sesion|
            {
              fecha: sesion.fecha&.iso8601,
              dolor_antes: sesion.escala_dolor_pre_sesion,
              dolor_despues: sesion.escala_dolor_post_sesion,
              tecnicas: sesion.treatments.map(&:nombre).sort
            }
          end
        }
      end
    }
  end

  # Casos clínicos publicados con sus diagnósticos (D89), con los comentarios de otros osteópatas.
  def casos
    Caso.joins(diagnosis: :visit).where(visits: { patient_id: @patient.id })
        .includes(diagnosis: :disease, comentarios: %i[osteopath treatments]).order(:created_at, :id)
  end

  def caso_exportado(caso)
    {
      titulo: caso.titulo,
      resumen: caso.resumen,
      enfermedad: caso.enfermedad.nombre,
      publicado_at: caso.created_at.iso8601,
      oculto_por_la_moderacion: caso.oculto?,
      comentarios: caso.comentarios.map do |comentario|
        { fecha: comentario.created_at.iso8601, osteopata: comentario.osteopath.nombre_completo,
          texto: comentario.texto, tecnicas_sugeridas: comentario.treatments.map(&:nombre),
          oculto_por_la_moderacion: comentario.oculto? }
      end
    }
  end

  def prueba_exportada(prueba)
    datos = { tipo: etiqueta(:test_type, prueba.tipo_prueba), resumen: prueba.resumen, escaneado: prueba.escaneado }
    if prueba.archivo.attached?
      blob = prueba.archivo.blob
      datos[:archivo] = { nombre: blob.filename.to_s, tipo: blob.content_type, bytes: blob.byte_size,
                          base64: Base64.strict_encode64(blob.download) }
    end
    datos
  end

  def etiqueta(enum, valor)
    I18n.t("enums.#{enum}.#{valor}", locale: :es, default: valor.to_s) if valor.present?
  end
end
