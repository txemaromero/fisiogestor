require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "etiqueta_enum traduce los valores de las enumeraciones" do
    assert_equal "Mujer", etiqueta_enum(:sex_type, "mujer")
    assert_equal "Músculo-esqueléticos", etiqueta_enum(:background_type, "musculo_esqueleticos")
    assert_equal "IRM", etiqueta_enum(:test_type, "irm")
    assert_equal "", etiqueta_enum(:sex_type, nil)
  end

  test "opciones_enum genera pares [etiqueta, valor] para un select" do
    assert_equal [ [ "Hombre", "hombre" ], [ "Mujer", "mujer" ] ], opciones_enum(:sex_type, Patient.sexos.keys)
  end

  test "opciones_escala_dolor va de vacío a 10" do
    opciones = opciones_escala_dolor
    assert_equal [ "—", "" ], opciones.first
    assert_equal [ "10", 10 ], opciones.last
    assert_equal 12, opciones.size
  end

  test "formatos de fecha, reducción del dolor y valores vacíos" do
    assert_equal "4/3/2026", fecha_o_guion(Date.new(2026, 3, 4))
    assert_equal "—", fecha_o_guion(nil)
    assert_equal "2,67", reduccion_dolor(2.6667)
    assert_equal "—", reduccion_dolor(nil)
    assert_equal "—", valor_o_guion("")
    assert_equal "Lumbago", valor_o_guion("Lumbago")
  end

  test "clase_campo marca los campos con errores" do
    paciente = Patient.new
    paciente.valid?
    assert_equal "form-control is-invalid", clase_campo(paciente, :nombre)
    assert_equal "form-select", clase_campo(paciente, :osteopath_id, "form-select")
  end
end
