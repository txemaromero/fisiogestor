class FamilyMedicalBackground < ApplicationRecord
  belongs_to :patient

  validates :familiar, presence: true, length: { maximum: 100 }

  # Tipo y descripción (después de familiar para que los errores salgan en el orden de la tabla).
  include MedicalBackground
end
