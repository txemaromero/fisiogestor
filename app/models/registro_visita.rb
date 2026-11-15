# Objeto de formulario del asistente /crear_visita.
#
# Recoge los datos de los tres paneles (visita, diagnóstico y sesiones con sus técnicas) y los guarda
# todos juntos en una transacción: si cualquier registro no es válido, no se guarda nada.
# Las sesiones llegan del navegador como JSON (campo oculto sesiones_json):
#   [{ "fecha": "2026-10-17", "escala_dolor_pre_sesion": "7", "escala_dolor_post_sesion": "4",
#      "tecnicas": [{ "nombre": "Masaje espalda", "descripcion": "" }] }]
class RegistroVisita
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Valor de la opción "Otra…" del select de enfermedades.
  OTRA_ENFERMEDAD = Disease::OTRA

  # Panel del asistente (0 Visita, 1 Diagnóstico, 2 Sesiones) en el que está cada tipo de registro.
  PANELES = { Visit => 0, Diagnosis => 1, Disease => 1, Session => 2, Treatment => 2 }.freeze

  # Límites de lo que se acepta en sesiones_json (el asistente nunca se acerca a ellos; protegen frente
  # a peticiones manipuladas que intentaran crear miles de registros).
  MAX_BYTES_SESIONES = 100_000
  MAX_SESIONES = 50
  MAX_TECNICAS_POR_SESION = 30

  # Los valores se pasan tal cual a los modelos, que son los que los validan.
  attribute :patient_id
  attribute :anamnesis
  attribute :escala_dolor
  attribute :disease_id
  attribute :nueva_enfermedad
  attribute :descripcion
  attribute :sesiones_recomendadas
  attribute :sesiones_json, default: "[]"

  attr_accessor :osteopath
  attr_reader :visita

  # Panel que debe mostrarse al volver al asistente tras un error.
  def panel_con_errores
    @panel_con_errores || 0
  end

  def guardar
    return false unless sesiones_validas?

    ActiveRecord::Base.transaction do
      @visita = crear_visita!
      diagnostico = crear_diagnostico!(@visita)
      sesiones.each.with_index(1) do |datos, numero|
        @numero_sesion = numero
        crear_sesion!(diagnostico, datos)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    @visita = nil
    anotar_errores(error.record)
    false
  end

  # Las sesiones enviadas, o nil si el JSON no tiene la forma que genera el asistente.
  def sesiones
    return @sesiones if defined?(@sesiones)

    datos = JSON.parse(sesiones_json.presence || "[]", max_nesting: 4)
    @sesiones = datos.is_a?(Array) && datos.all? { |sesion| sesion_valida?(sesion) } ? datos : nil
  rescue JSON::ParserError
    @sesiones = nil
  end

  private

  def sesiones_validas?
    error = if sesiones_json.to_s.bytesize > MAX_BYTES_SESIONES then "Los datos de las sesiones son demasiado grandes."
    elsif sesiones.nil? then "Los datos de las sesiones no son válidos."
    elsif sesiones.size > MAX_SESIONES then "Una visita admite como máximo #{MAX_SESIONES} sesiones."
    elsif sesiones.any? { |sesion| Array(sesion["tecnicas"]).size > MAX_TECNICAS_POR_SESION }
      "Una sesión admite como máximo #{MAX_TECNICAS_POR_SESION} técnicas."
    end
    return true unless error

    errors.add(:base, error)
    @panel_con_errores = PANELES.fetch(Session)
    false
  end

  # Fecha y escalas: texto o número (o vacías); técnicas: lista de { nombre (texto), descripcion (texto) }.
  def sesion_valida?(sesion)
    sesion.is_a?(Hash) &&
      sesion.values_at("fecha", "escala_dolor_pre_sesion", "escala_dolor_post_sesion").all? { |valor| escalar?(valor) } &&
      (sesion["tecnicas"].nil? || (sesion["tecnicas"].is_a?(Array) && sesion["tecnicas"].all? { |tecnica| tecnica_valida?(tecnica) }))
  end

  def tecnica_valida?(tecnica)
    tecnica.is_a?(Hash) && tecnica["nombre"].is_a?(String) && (tecnica["descripcion"].nil? || tecnica["descripcion"].is_a?(String))
  end

  def escalar?(valor)
    valor.nil? || valor.is_a?(String) || valor.is_a?(Integer)
  end

  # El paciente se busca entre los del osteópata: no se pueden crear visitas de pacientes ajenos.
  def crear_visita!
    osteopath.visits.create!(patient: osteopath.patients.find_by(id: patient_id), fecha: Date.current,
                             anamnesis: anamnesis, escala_dolor: escala_dolor)
  end

  def crear_diagnostico!(visita)
    visita.diagnoses.create!(disease: enfermedad!, descripcion: descripcion,
                             sesiones_recomendadas: sesiones_recomendadas)
  end

  # La enfermedad elegida del catálogo o, con "Otra…", la escrita por el usuario (ver Disease.elegida).
  def enfermedad!
    Disease.elegida(disease_id, nueva_enfermedad, descripcion)
  end

  def crear_sesion!(diagnostico, datos)
    sesion = diagnostico.sessions.create!(datos.slice("fecha", "escala_dolor_pre_sesion", "escala_dolor_post_sesion"))
    sesion.treatments = tecnicas(datos)
  end

  def tecnicas(datos)
    Array(datos["tecnicas"]).map { |tecnica| Treatment.buscar_o_crear!(tecnica["nombre"], tecnica["descripcion"]) }.uniq
  end

  def anotar_errores(registro)
    contexto = case registro
    when Visit then "Visita"
    when Diagnosis then "Diagnóstico"
    when Disease then "Enfermedad nueva"
    when Session then "Sesión #{@numero_sesion}"
    when Treatment then "Técnica de la sesión #{@numero_sesion}"
    end
    registro.errors.full_messages.each { |mensaje| errors.add(:base, "#{contexto}: #{mensaje}") }
    @panel_con_errores = PANELES.fetch(registro.class, 0)
  end
end
