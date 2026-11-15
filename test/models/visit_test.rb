require "test_helper"

class VisitTest < ActiveSupport::TestCase
  test "solo paciente y osteópata son obligatorios" do
    visita = Visit.new
    assert_not visita.valid?
    assert_equal %i[osteopath patient], visita.errors.attribute_names.sort
    assert Visit.new(patient: patients(:juan), osteopath: osteopaths(:paco)).valid?
  end

  test "la escala de dolor va de 0 a 10" do
    visita = visits(:visita_juan)
    [ 0, 10, nil ].each { |valor| visita.escala_dolor = valor; assert visita.valid?, valor.inspect }
    [ -1, 11 ].each { |valor| visita.escala_dolor = valor; assert visita.invalid?, valor.inspect }
  end

  test "tiene exploración, pruebas complementarias y diagnósticos" do
    visita = visits(:visita_pepe)
    assert_equal examinations(:exploracion_pepe), visita.examination
    assert_equal [ supplementary_tests(:irm_pepe) ], visita.supplementary_tests
    assert_equal [ diagnoses(:diag_pepe) ], visita.diagnoses
  end

  test "al borrar la visita se borra todo lo que cuelga de ella" do
    assert_difference -> { Examination.count } => -1,
                      -> { SupplementaryTest.count } => -1,
                      -> { Diagnosis.count } => -1,
                      -> { Session.count } => -2 do
      visits(:visita_pepe).destroy
    end
  end
end
