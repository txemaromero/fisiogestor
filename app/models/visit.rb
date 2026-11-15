class Visit < ApplicationRecord
  belongs_to :patient
  belongs_to :osteopath
  has_one :examination, dependent: :destroy
  has_many :supplementary_tests, dependent: :destroy
  has_many :diagnoses, dependent: :destroy

  validates :escala_dolor, numericality: { only_integer: true, in: 0..10 }, allow_nil: true
  validates :anamnesis, length: { maximum: 5000 }
  validates :motivo, length: { maximum: 255 }
end
