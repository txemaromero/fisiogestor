require "test_helper"

class FamilyMedicalBackgroundTest < ActiveSupport::TestCase
  test "familiar, tipo y descripción son obligatorios" do
    antecedente = FamilyMedicalBackground.new(patient: patients(:juan))
    assert_not antecedente.valid?
    assert antecedente.errors.added?(:familiar, :blank)
    assert antecedente.errors.added?(:descripcion, :blank)
    assert antecedente.errors.key?(:tipo)
  end

  test "es válido con todos los datos" do
    antecedente = FamilyMedicalBackground.new(patient: patients(:juan), familiar: "Hermano",
                                              tipo: "neurologicos", descripcion: "Migrañas")
    assert antecedente.valid?
  end

  test "el tipo es la enumeración background_type" do
    assert_equal %w[musculo_esqueleticos cardio_respiratorios digestivos genito_urinarios endocrinos neurologicos],
                 FamilyMedicalBackground.tipos.keys
    assert family_medical_backgrounds(:juan_padre).digestivos?
    assert_not FamilyMedicalBackground.new(tipo: "otro").valid?
  end
end
