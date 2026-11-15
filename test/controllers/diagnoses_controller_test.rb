require "test_helper"

class DiagnosesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  def params_diagnostico(**cambios)
    { diagnosis: { disease_id: diseases(:ciatica).id, nueva_enfermedad: "", descripcion: "Irradiado a la pierna",
                   sesiones_recomendadas: "4" }.merge(cambios) }
  end

  test "el formulario de alta tiene el catálogo, la opción Otra… y el nombre nuevo oculto" do
    get new_visit_diagnosis_url(visits(:visita_juan))
    assert_response :success
    assert_select "select[name='diagnosis[disease_id]'] option", Disease.count + 2
    assert_select "select[name='diagnosis[disease_id]'] option[value=otra]", "Otra…"
    assert_select "[data-enfermedad-nueva-target=grupo][hidden]"
    assert_select "input[name='diagnosis[nueva_enfermedad]'][disabled]"
  end

  test "añade a la visita un diagnóstico de una enfermedad del catálogo" do
    visita = visits(:visita_juan)
    assert_difference -> { visita.diagnoses.count } => 1, -> { Disease.count } => 0 do
      post visit_diagnoses_url(visita), params: params_diagnostico
    end
    assert_redirected_to visit_url(visita)
    diagnostico = visita.diagnoses.order(:id).last
    assert_equal [ diseases(:ciatica), 4, "Irradiado a la pierna" ],
                 [ diagnostico.disease, diagnostico.sesiones_recomendadas, diagnostico.descripcion ]
  end

  test "con «Otra…» crea la enfermedad nueva con la descripción del diagnóstico" do
    assert_difference -> { Disease.count } => 1 do
      post visit_diagnoses_url(visits(:visita_juan)),
           params: params_diagnostico(disease_id: "otra", nueva_enfermedad: "Escoliosis", descripcion: "Curva lumbar")
    end
    assert_equal "Curva lumbar", Disease.find_by(nombre: "Escoliosis").descripcion
  end

  test "con «Otra…» y un nombre que ya existe se reutiliza la enfermedad" do
    assert_no_difference -> { Disease.count } do
      post visit_diagnoses_url(visits(:visita_juan)), params: params_diagnostico(disease_id: "otra", nueva_enfermedad: "LUMBAGO")
    end
    assert_equal diseases(:lumbago), visits(:visita_juan).diagnoses.order(:id).last.disease
  end

  test "si el diagnóstico no es válido no se guarda ni se queda la enfermedad nueva en el catálogo" do
    assert_no_difference %w[Diagnosis.count Disease.count] do
      post visit_diagnoses_url(visits(:visita_juan)),
           params: params_diagnostico(disease_id: "otra", nueva_enfermedad: "Escoliosis", sesiones_recomendadas: "0")
    end
    assert_response :unprocessable_content
    assert_select "#errores", /Sesiones recomendadas/
    # El formulario recuerda la elección «Otra…» y el nombre escrito.
    assert_select "option[value=otra][selected]"
    assert_select "input[name='diagnosis[nueva_enfermedad]'][value=Escoliosis]:not([disabled])"
  end

  test "sin enfermedad, o con «Otra…» sin nombre, da error" do
    post visit_diagnoses_url(visits(:visita_juan)), params: params_diagnostico(disease_id: "")
    assert_response :unprocessable_content
    assert_select "#errores", /Enfermedad debe existir/

    post visit_diagnoses_url(visits(:visita_juan)), params: params_diagnostico(disease_id: "otra", nueva_enfermedad: " ")
    assert_response :unprocessable_content
    assert_select "#errores", /Enfermedad nueva: Nombre no puede estar en blanco/
  end

  test "edita el diagnóstico" do
    diagnostico = diagnoses(:diag_juan)
    get edit_diagnosis_url(diagnostico)
    assert_response :success
    assert_select "option[selected][value=?]", diseases(:lumbago).id.to_s
    assert_select "input[name='diagnosis[sesiones_recomendadas]'][value='3']"

    patch diagnosis_url(diagnostico), params: params_diagnostico(disease_id: diseases(:hernia_discal).id, sesiones_recomendadas: "5")
    assert_redirected_to visit_url(visits(:visita_juan))
    diagnostico.reload
    assert_equal [ diseases(:hernia_discal), 5 ], [ diagnostico.disease, diagnostico.sesiones_recomendadas ]
    assert_equal 2, diagnostico.sessions.count # las sesiones se conservan
  end

  test "borra el diagnóstico con sus sesiones, pero no las técnicas del catálogo" do
    assert_difference -> { Diagnosis.count } => -1, -> { Session.count } => -2, -> { Treatment.count } => 0 do
      delete diagnosis_url(diagnoses(:diag_juan))
    end
    assert_response :see_other
    assert_redirected_to visit_url(visits(:visita_juan))
    assert Visit.exists?(visits(:visita_juan).id)
  end

  test "no se pueden añadir, editar ni borrar diagnósticos de visitas ajenas" do
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get new_visit_diagnosis_url(visits(:visita_maria_perez))
    assert_response :not_found
    assert_no_difference -> { Diagnosis.count } do
      post visit_diagnoses_url(visits(:visita_maria_perez)), params: params_diagnostico
    end
    assert_response :not_found

    ajeno = diagnoses(:diag_maria_perez)
    get edit_diagnosis_url(ajeno)
    assert_response :not_found
    patch diagnosis_url(ajeno), params: params_diagnostico
    assert_response :not_found
    assert_no_difference -> { Diagnosis.count } do
      delete diagnosis_url(ajeno)
    end
    assert_response :not_found
  end

  test "unos parámetros con forma inesperada responden 400" do
    post visit_diagnoses_url(visits(:visita_juan)), params: { diagnosis: "texto" }
    assert_response :bad_request
  end
end
