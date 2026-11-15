require "test_helper"

class VisitsHelperTest < ActionView::TestCase
  test "texto_progreso en plural y en singular" do
    assert_equal "2 de 3 sesiones recomendadas", texto_progreso(diagnoses(:diag_juan))

    diagnostico = diagnoses(:diag_maria_torres)
    diagnostico.sesiones_recomendadas = 1
    assert_equal "1 de 1 sesión recomendada", texto_progreso(diagnostico)
  end

  test "progreso_sesiones solo marca «Completado» al llegar a las sesiones recomendadas" do
    assert_no_match "Completado", progreso_sesiones(diagnoses(:diag_juan))

    diagnostico = diagnoses(:diag_maria_torres)
    diagnostico.sesiones_recomendadas = 1
    html = progreso_sesiones(diagnostico)
    assert_match "✓ Completado", html
    assert_match '<progress value="1" max="1"', html
  end

  test "texto_progreso añade las sesiones programadas" do
    diagnostico = diagnoses(:diag_juan)
    diagnostico.sessions.create!(fecha: Date.current + 3)
    assert_equal "2 de 3 sesiones recomendadas · 1 programada", texto_progreso(diagnostico.reload)
    diagnostico.sessions.create!(fecha: Date.current + 10)
    assert_equal "2 de 3 sesiones recomendadas · 2 programadas", texto_progreso(diagnostico.reload)
    assert_match '<progress value="2" max="3"', progreso_sesiones(diagnostico)
  end

  test "progreso_visita suma las sesiones de los diagnósticos de la visita" do
    assert_equal "2 de 3", progreso_visita(visits(:visita_juan))
    assert_equal "—", progreso_visita(Visit.new)
  end
end
