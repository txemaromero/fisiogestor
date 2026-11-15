class PersonalMedicalBackground < ApplicationRecord
  include MedicalBackground

  belongs_to :patient
end
