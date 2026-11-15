class Patient < ApplicationRecord
  SEX_TYPE = { hombre: "hombre", mujer: "mujer" }.freeze

  # Osteópata que dio de alta al paciente: "mis pacientes" son los que tienen mi osteopath_id.
  belongs_to :osteopath
  has_many :visits, dependent: :destroy
  has_many :family_medical_backgrounds, -> { order(:id) }, dependent: :destroy
  has_many :personal_medical_backgrounds, -> { order(:id) }, dependent: :destroy
  # Quién ha abierto la ficha siendo de otro osteópata (D85). Se borra con el paciente.
  has_many :accesos_fichas, -> { order(created_at: :desc, id: :desc) }, class_name: "AccesoFicha", dependent: :delete_all

  # Los antecedentes se crean, editan y borran desde el propio formulario del paciente.
  # Las filas que se dejan completamente vacías se ignoran.
  accepts_nested_attributes_for :family_medical_backgrounds, :personal_medical_backgrounds,
                                allow_destroy: true, reject_if: :all_blank

  # El enum valida los valores no vacíos; el vacío lo valida presence (mensaje "no puede estar en blanco").
  enum :sexo, SEX_TYPE, validate: { allow_nil: true }

  validates :nombre, :apellidos, :anyo_nacimiento, :sexo, presence: true
  validates :nombre, :apellidos, length: { maximum: 100 }
  validates :anyo_nacimiento, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1900,
    less_than_or_equal_to: ->(_patient) { Date.current.year },
    allow_nil: true
  }

  before_save :preparar_texto_busqueda
  before_save :anotar_cambio_de_consentimiento, if: :consiente_compartir_changed?
  # Al retirar el consentimiento, sus casos clínicos se retiran de la red y no vuelven solos (D96).
  after_update :retirar_casos, if: -> { saved_change_to_consiente_compartir?(from: true, to: false) }

  def nombre_completo
    "#{nombre} #{apellidos}"
  end

  # --- Buscador de la lista de pacientes ------------------------------------------------------------
  # texto_busqueda guarda el nombre y los apellidos sin tildes y en minúsculas: así la búsqueda no
  # distingue tildes ni mayúsculas en SQLite ni en PostgreSQL.

  MAX_PALABRAS_BUSQUEDA = 5

  def self.normalizar_busqueda(texto)
    I18n.transliterate(texto.to_s, locale: :es).downcase.squish
  end

  # Pacientes cuyo nombre y apellidos contienen todas las palabras buscadas, en cualquier orden.
  # Sin texto, todos. Los comodines de LIKE (% y _) se buscan como caracteres normales.
  def self.buscar(texto)
    palabras = normalizar_busqueda(texto).split.first(MAX_PALABRAS_BUSQUEDA)
    palabras.reduce(all) do |pacientes, palabra|
      pacientes.where("patients.texto_busqueda LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(palabra)}%")
    end
  end

  # Solo se guarda el año de nacimiento, así que la edad es la que cumple este año.
  def edad
    Date.current.year - anyo_nacimiento
  end

  def pertenece_a?(osteopath)
    osteopath.present? && osteopath_id == osteopath.id
  end

  # --- Consentimiento para compartir (D83) -----------------------------------------------------------
  # Los datos clínicos de un paciente (sin nombre ni apellidos) solo los ven otros osteópatas, en el filtro
  # de tratamientos y en los informes de la plataforma, si el paciente consiente y si ellos están
  # verificados (D94). Su osteópata los ve siempre.

  def self.visibles_para(osteopath)
    return where(osteopath_id: osteopath.id) unless osteopath.acceso_a_la_red?

    where(consiente_compartir: true).or(where(osteopath_id: osteopath.id))
  end

  def visible_para?(osteopath)
    pertenece_a?(osteopath) || (consiente_compartir? && osteopath&.acceso_a_la_red?) || false
  end

  # --- Fichas de pacientes de otros osteópatas -----------------------------------------------------
  # Un osteópata verificado puede ver la ficha de un paciente ajeno que consiente (llegando desde el filtro
  # de tratamientos), pero con un identificador firmado en la URL en lugar del id: no se puede adivinar, así
  # que las fichas ajenas no se pueden recorrer cambiando el número de la URL. El identificador caduca en un
  # día (D94), así que un enlace copiado o guardado deja de valer. El osteópata del paciente usa el id. Si
  # el paciente retira el consentimiento, sus enlaces firmados dejan de funcionar (404).

  PROPOSITO_FICHA = :ficha_compartida
  CADUCIDAD_FICHA = 1.day

  # Identificador de la ficha en las URLs que verá ese osteópata.
  def id_ficha_para(osteopath)
    pertenece_a?(osteopath) ? id : signed_id(purpose: PROPOSITO_FICHA, expires_in: CADUCIDAD_FICHA)
  end

  # Paciente de una URL de ficha: uno propio por su id, o uno ajeno que consiente por su identificador firmado.
  def self.ficha(identificador, osteopath)
    propio = osteopath.patients.find_by(id: identificador) if identificador.to_s.match?(/\A\d+\z/)
    return propio if propio

    ajeno = find_signed(identificador, purpose: PROPOSITO_FICHA)
    ajeno&.visible_para?(osteopath) ? ajeno : raise(ActiveRecord::RecordNotFound)
  end

  private

  def anotar_cambio_de_consentimiento
    self.consentimiento_actualizado_at = Time.current
  end

  def retirar_casos
    Caso.where(retirado_at: nil, diagnosis_id: Diagnosis.joins(:visit).where(visits: { patient_id: id }).select(:id))
        .update_all(retirado_at: Time.current, updated_at: Time.current)
  end

  def preparar_texto_busqueda
    self.texto_busqueda = self.class.normalizar_busqueda(nombre_completo)
  end
end
