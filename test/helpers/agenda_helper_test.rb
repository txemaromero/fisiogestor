require "test_helper"

class AgendaHelperTest < ActionView::TestCase
  test "dia_agenda dice hoy y mañana, y el año solo si no es el actual" do
    hoy = Date.new(2026, 10, 19) # lunes
    assert_equal "Hoy, lunes 19 de octubre", dia_agenda(hoy, hoy)
    assert_equal "Mañana, martes 20 de octubre", dia_agenda(hoy + 1, hoy)
    assert_equal "Jueves 22 de octubre", dia_agenda(hoy + 3, hoy)
    assert_equal "Viernes 1 de enero de 2027", dia_agenda(Date.new(2027, 1, 1), hoy)
  end
end
