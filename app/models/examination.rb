# Exploración física de una visita. Todos los campos son opcionales.
class Examination < ApplicationRecord
  # Campos agrupados por tipo de examen (para el formulario y la vista).
  GRUPOS = {
    "Inspección" => %i[inspeccion_estatica inspeccion_dinamica disfunciones_somaticas],
    "Examen craneal" => %i[examen_craneal_forma examen_craneal_fijaciones examen_craneal_musculos],
    "Examen visceral" => %i[examen_visceral_palpacion examen_visceral_dermalgias examen_visceral_fijaciones],
    "Examen ortopédico" => %i[examen_ortopedico_test examen_ortopedico_testing_muscular],
    "Examen neurológico" => %i[examen_neurologico_reflejos examen_neurologico_central examen_neurologico_periferico
                               examen_neurologico_pulsos examen_neurologico_auscultacion],
    "Examen cardiovascular" => %i[examen_cardiovascular_tension_arterial]
  }.freeze
  CAMPOS = GRUPOS.values.flatten.freeze

  belongs_to :visit

  validates(*CAMPOS, length: { maximum: 255 })
end
