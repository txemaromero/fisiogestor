require "test_helper"

class PersonalMedicalBackgroundTest < ActiveSupport::TestCase
  test "tipo y descripción son obligatorios" do
    antecedente = PersonalMedicalBackground.new(patient: patients(:juan))
    assert_not antecedente.valid?
    assert antecedente.errors.added?(:descripcion, :blank)
    assert antecedente.errors.key?(:tipo)
  end

  test "el tipo es la enumeración background_type" do
    assert_equal FamilyMedicalBackground.tipos, PersonalMedicalBackground.tipos
    assert personal_medical_backgrounds(:juan_rodilla).musculo_esqueleticos?
    assert_not PersonalMedicalBackground.new(patient: patients(:juan), tipo: "otro", descripcion: "x").valid?
  end
end
