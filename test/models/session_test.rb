require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "fecha y escalas de dolor son opcionales" do
    assert Session.new(diagnosis: diagnoses(:diag_juan)).valid?
  end

  test "las escalas de dolor van de 0 a 10" do
    %i[escala_dolor_pre_sesion escala_dolor_post_sesion].each do |campo|
      sesion = Session.new(diagnosis: diagnoses(:diag_juan))
      [ 0, 10, nil ].each { |valor| sesion[campo] = valor; assert sesion.valid?, "#{campo}=#{valor.inspect}" }
      [ -1, 11 ].each { |valor| sesion[campo] = valor; assert sesion.invalid?, "#{campo}=#{valor.inspect}" }
    end
  end

  test "tiene técnicas aplicadas" do
    assert_equal treatments(:masaje, :estiramiento).sort, sessions(:juan_1).treatments.sort
  end

  test "para_informe solo cuenta las sesiones que puede ver el osteópata (D83)" do
    patients(:juan).update!(consiente_compartir: false)
    assert_equal Session.count, Session.para_informe(visibles_para: osteopaths(:paco)).count
    assert_equal Session.count - 2, Session.para_informe(visibles_para: osteopaths(:maria)).count
    assert_equal 5, Session.para_informe(visibles_para: osteopaths(:paco), osteopath: osteopaths(:paco)).count
    assert_equal 2, Session.para_informe(visibles_para: osteopaths(:maria), desde: Date.new(2026, 5, 1),
                                         hasta: Date.new(2026, 5, 31)).count
  end
end
