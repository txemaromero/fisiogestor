# Parte común de los antecedentes médicos de un paciente (familiares y personales):
# el tipo de antecedente (enumeración background_type) y su descripción.
module MedicalBackground
  extend ActiveSupport::Concern

  BACKGROUND_TYPE = {
    musculo_esqueleticos: "musculo_esqueleticos",
    cardio_respiratorios: "cardio_respiratorios",
    digestivos: "digestivos",
    genito_urinarios: "genito_urinarios",
    endocrinos: "endocrinos",
    neurologicos: "neurologicos"
  }.freeze

  included do
    # El enum valida los valores no vacíos; el vacío lo valida presence.
    enum :tipo, BACKGROUND_TYPE, validate: { allow_nil: true }

    validates :tipo, :descripcion, presence: true
    validates :descripcion, length: { maximum: 1000 }
  end
end
