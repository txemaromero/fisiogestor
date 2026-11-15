require "test_helper"

class ExaminationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  test "muestra la exploración de una visita propia" do
    get visit_examination_url(visits(:visita_pepe))
    assert_response :success
    assert_select "#exploracion", text: /Hiperlordosis lumbar/
    assert_select "#exploracion", text: /Lasègue positivo/
  end

  test "sin exploración, la página de la exploración lleva al formulario de alta" do
    get visit_examination_url(visits(:visita_juan))
    assert_redirected_to new_visit_examination_url(visits(:visita_juan))
  end

  test "crea la exploración de una visita" do
    visita = visits(:visita_juan)
    get new_visit_examination_url(visita)
    assert_response :success
    assert_select "input[name='examination[examen_cardiovascular_tension_arterial]']"

    assert_difference -> { Examination.count } => 1 do
      post visit_examination_url(visita), params: { examination: { inspeccion_estatica: "Escoliosis leve" } }
    end
    assert_redirected_to visit_examination_url(visita)
    assert_equal "Escoliosis leve", visita.reload.examination.inspeccion_estatica
  end

  test "si la visita ya tiene exploración no se crea otra" do
    assert_no_difference -> { Examination.count } do
      post visit_examination_url(visits(:visita_pepe)), params: { examination: { inspeccion_estatica: "x" } }
    end
    assert_redirected_to edit_visit_examination_url(visits(:visita_pepe))
  end

  test "edita y borra la exploración" do
    visita = visits(:visita_pepe)
    patch visit_examination_url(visita), params: { examination: { examen_neurologico_reflejos: "Normales" } }
    assert_redirected_to visit_examination_url(visita)
    assert_equal "Normales", visita.reload.examination.examen_neurologico_reflejos

    assert_difference -> { Examination.count } => -1 do
      delete visit_examination_url(visita)
    end
    assert_redirected_to visit_url(visita)
  end

  test "no se accede a la exploración de una visita ajena" do
    get visit_examination_url(visits(:visita_maria_perez))
    assert_response :not_found
  end
end
