# Caso clínico anonimizado (D89): un diagnóstico que su osteópata publica para que los demás osteópatas
# verificados lo comenten y sugieran técnicas.
#
# Qué se publica: el título y el resumen que escribe el osteópata para el caso (confirmando que no
# identifican al paciente), el sexo, la edad en tramos de 5 años, la enfermedad y las sesiones realizadas
# con su dolor y sus técnicas, contadas en días desde la primera (sin fechas). No se publican el nombre,
# los antecedentes, la anamnesis ni la descripción del diagnóstico. Los datos clínicos se leen del
# diagnóstico (no se copian): si el paciente se borra, el caso se borra con él; si retira el
# consentimiento, el caso se retira de la red y no vuelve aunque vuelva a consentir, salvo que su autor lo
# publique otra vez (D96).
class Caso < ApplicationRecord
  include Denunciable

  TRAMO_EDAD = 5

  # Lo que no debería aparecer en el título ni en el resumen porque ayuda a reconocer al paciente (D96).
  MESES = "enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre".freeze
  DATOS_IDENTIFICATIVOS = {
    "una fecha" => %r{\b\d{1,2}\s*[/.-]\s*\d{1,2}\s*[/.-]\s*\d{2,4}\b|\b\d{1,2}\s+de\s+(#{MESES})\b}i,
    "un año" => /\b(19|20)\d{2}\b/,
    "un teléfono" => /(?<!\d)(\+34\s*)?[6-9](\s*\d){8}(?!\d)/,
    "un DNI o NIE" => /\b([XYZ]\d{7}|\d{8})\s*-?\s*[A-Z]\b/i,
    "un email" => /\b[\w.+-]+@[\w-]+\.[\w.]+/
  }.freeze

  belongs_to :diagnosis
  belongs_to :osteopath # quien lo publica: el osteópata del paciente
  has_many :comentarios, -> { order(:created_at, :id) }, dependent: :destroy

  validates :titulo, presence: true, length: { maximum: 120 }
  validates :resumen, presence: true, length: { maximum: 4000 }
  validates :diagnosis_id, uniqueness: { message: "ya está publicado como caso clínico" }
  # Al publicar y al editar, el osteópata confirma que el título y el resumen no identifican al paciente
  # (contexto :publicacion, el de los formularios; los cambios de moderación no lo piden).
  validates :confirmacion_anonimato, acceptance: { allow_nil: false, message: "es obligatoria" }, on: :publicacion
  validate :sin_datos_identificativos, on: :publicacion
  validate :del_osteopata_del_paciente
  validate :paciente_consiente, if: :new_record?

  scope :recientes, -> { order(created_at: :desc, id: :desc) }

  # Casos que ve un osteópata: ninguno si no está verificado (ni es administrador); si lo está, los suyos
  # siempre y los de los demás si el paciente consiente, no se han retirado y no están ocultos por la
  # moderación (los administradores ven también los ocultos, para moderarlos).
  def self.visibles_para(osteopath)
    return none unless osteopath&.acceso_a_la_red?

    base = joins(diagnosis: { visit: :patient })
    compartidos = base.where(patients: { consiente_compartir: true }, retirado_at: nil)
    compartidos = compartidos.where(oculto_at: nil) unless osteopath.admin?
    compartidos.or(base.where(osteopath_id: osteopath.id))
  end

  def self.de_enfermedad(disease_id)
    disease_id.present? ? joins(:diagnosis).where(diagnoses: { disease_id: disease_id }) : all
  end

  def paciente
    diagnosis.visit.patient
  end

  def enfermedad
    diagnosis.disease
  end

  def sexo
    paciente.sexo
  end

  # «40-44 años»: la edad exacta, junto con el sexo y la enfermedad, ayudaría a reconocer al paciente.
  def tramo_edad
    inicio = paciente.edad / TRAMO_EDAD * TRAMO_EDAD
    "#{inicio}–#{inicio + TRAMO_EDAD - 1} años"
  end

  # Sesiones ya realizadas (no las programadas), por fecha y las que no tienen al final.
  def sesiones
    @sesiones ||= diagnosis.sessions.reject { |sesion| sesion.fecha&.after?(Date.current) }
                           .sort_by { |sesion| [ sesion.fecha ? 0 : 1, sesion.fecha || Date.current, sesion.id ] }
  end

  # Días desde la primera sesión con fecha (nil si la sesión no tiene fecha).
  def dia(sesion)
    @inicio ||= sesiones.filter_map(&:fecha).min
    (sesion.fecha - @inicio).to_i if sesion.fecha && @inicio
  end

  def reload(...)
    @sesiones = @inicio = nil
    super
  end

  def oculto?
    oculto_at.present?
  end

  def retirado?
    retirado_at.present?
  end

  # Si está en la red: el paciente consiente y no se ha retirado (aunque la moderación lo haya ocultado).
  def en_la_red?
    paciente.consiente_compartir? && !retirado?
  end

  # Si los demás osteópatas lo ven (si no, solo su autor y, si está oculto, los administradores).
  def compartido?
    en_la_red? && !oculto?
  end

  # Su autor lo vuelve a publicar después de retirarse, si el paciente ha vuelto a consentir.
  def republicar!
    return false unless retirado? && paciente.consiente_compartir?

    update!(retirado_at: nil)
  end

  def autor?(osteopath)
    osteopath.present? && osteopath_id == osteopath.id
  end

  # Técnicas sugeridas en los comentarios visibles, de la más sugerida a la menos, con «veces».
  def tecnicas_sugeridas
    Treatment.joins(:comentarios).where(comentarios: { caso_id: id, oculto_at: nil })
             .group(:id).select("treatments.*", "COUNT(*) AS veces")
             .order(Arel.sql("veces").desc, :nombre)
  end

  private

  def sin_datos_identificativos
    texto = "#{titulo} #{resumen}"
    encontrados = DATOS_IDENTIFICATIVOS.select { |_nombre, patron| texto.match?(patron) }.keys
    return if encontrados.empty?

    errors.add(:base, "El título o el resumen parecen contener #{encontrados.to_sentence(locale: :es)}: quítalo, " \
                      "para que no se pueda reconocer al paciente")
  end

  def del_osteopata_del_paciente
    return unless diagnosis && osteopath

    errors.add(:base, "Solo el osteópata del paciente puede publicar el caso") unless diagnosis.visit.osteopath_id == osteopath_id
  end

  def paciente_consiente
    return unless diagnosis

    errors.add(:base, "El paciente no consiente compartir sus datos") unless paciente.consiente_compartir?
  end
end
