require "test_helper"

class SesionesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  def params_sesion(tecnicas: [], **cambios)
    { sesion: { fecha: "2026-03-26", escala_dolor_pre_sesion: "4", escala_dolor_post_sesion: "1",
                tecnicas: tecnicas }.merge(cambios) }
  end

  test "el formulario de alta tiene la fecha de hoy, una fila de técnica vacía y el catálogo" do
    get new_diagnosis_sesion_url(diagnoses(:diag_juan))
    assert_response :success
    assert_select "input[name='sesion[fecha]'][value=?]", Date.current.iso8601
    assert_select "select[name='sesion[escala_dolor_pre_sesion]'] option", 12
    assert_select "#tecnicas-sesion tbody tr", 1
    assert_select "#tecnicas-sesion tbody input[name='sesion[tecnicas][][nombre]'][list=catalogo-tecnicas]"
    assert_select "template input[name='sesion[tecnicas][][nombre]']"
    assert_select "datalist#catalogo-tecnicas option", Treatment.count
    assert_select "p", text: /2 de 3 sesiones recomendadas/
  end

  test "añade una sesión reutilizando técnicas del catálogo y creando las nuevas" do
    diagnostico = diagnoses(:diag_juan)
    tecnicas = [ { nombre: "masaje ESPALDA", descripcion: "" },            # del catálogo
                 { nombre: "Punción seca", descripcion: "Agujas finas" },  # nueva
                 { nombre: "Masaje espalda", descripcion: "" },            # repetida
                 { nombre: "", descripcion: "" } ]                         # fila vacía
    assert_difference -> { diagnostico.sessions.count } => 1, -> { Treatment.count } => 1 do
      post diagnosis_sesiones_url(diagnostico), params: params_sesion(tecnicas: tecnicas)
    end
    assert_redirected_to visit_url(visits(:visita_juan))
    follow_redirect!
    assert_select ".alert", /Sesión añadida correctamente/
    assert_select ".progreso", text: /3 de 3 sesiones recomendadas/
    assert_select ".progreso .badge", "✓ Completado"

    sesion = diagnostico.sessions.last
    assert_equal [ Date.new(2026, 3, 26), 4, 1 ], [ sesion.fecha, sesion.escala_dolor_pre_sesion, sesion.escala_dolor_post_sesion ]
    assert_equal [ "Masaje espalda", "Punción seca" ], sesion.treatments.map(&:nombre).sort
    assert_equal "Agujas finas", Treatment.find_by(nombre: "Punción seca").descripcion
  end

  test "una sesión sin técnicas también se guarda" do
    assert_difference -> { Session.count } => 1 do
      post diagnosis_sesiones_url(diagnoses(:diag_juan)), params: params_sesion
    end
    assert_empty Session.order(:id).last.treatments
  end

  test "una técnica con descripción pero sin nombre impide guardar y no deja nada a medias" do
    tecnicas = [ { nombre: "Técnica nueva", descripcion: "" }, { nombre: " ", descripcion: "Sin nombre" } ]
    assert_no_difference %w[Session.count Treatment.count] do
      post diagnosis_sesiones_url(diagnoses(:diag_juan)), params: params_sesion(tecnicas: tecnicas)
    end
    assert_response :unprocessable_content
    assert_select "#errores", /Técnica: Nombre técnica no puede estar en blanco/
    # Vuelve con las filas tal como se enviaron.
    assert_select "#tecnicas-sesion tbody input[name='sesion[tecnicas][][nombre]'][value=?]", "Técnica nueva"
  end

  test "una escala de dolor fuera de rango da error" do
    assert_no_difference -> { Session.count } do
      post diagnosis_sesiones_url(diagnoses(:diag_juan)), params: params_sesion(escala_dolor_pre_sesion: "11")
    end
    assert_response :unprocessable_content
    assert_select "#errores", /Escala de dolor presesión/
  end

  test "una sesión admite como máximo 30 técnicas" do
    tecnicas = Array.new(SesionesController::MAX_TECNICAS + 1) { |i| { nombre: "Técnica #{i}", descripcion: "" } }
    assert_no_difference %w[Session.count Treatment.count] do
      post diagnosis_sesiones_url(diagnoses(:diag_juan)), params: params_sesion(tecnicas: tecnicas)
    end
    assert_response :unprocessable_content
    assert_select "#errores", /como máximo 30 técnicas/
  end

  test "el formulario de edición muestra las técnicas de la sesión" do
    get edit_sesion_url(sessions(:juan_1))
    assert_response :success
    assert_select "input[name='sesion[fecha]'][value='2026-03-12']"
    assert_select "select[name='sesion[escala_dolor_pre_sesion]'] option[selected][value='8']"
    nombres = css_select("#tecnicas-sesion tbody input[name='sesion[tecnicas][][nombre]']").map { |campo| campo["value"] }
    assert_equal [ "Estiramiento columna", "Masaje espalda" ], nombres
  end

  test "edita la sesión: cambia las escalas y deja solo las técnicas enviadas" do
    sesion = sessions(:juan_1)
    patch sesion_url(sesion), params: params_sesion(escala_dolor_post_sesion: "3",
                                                   tecnicas: [ { nombre: "Masaje espalda", descripcion: "" },
                                                               { nombre: "Hipopresivos", descripcion: "" } ])
    assert_redirected_to visit_url(visits(:visita_juan))
    sesion.reload
    assert_equal 3, sesion.escala_dolor_post_sesion
    assert_equal [ "Hipopresivos", "Masaje espalda" ], sesion.treatments.map(&:nombre).sort
    assert Treatment.exists?(nombre: "Estiramiento columna") # quitarla de la sesión no la borra del catálogo
  end

  test "editar una sesión sin filas de técnicas le quita todas" do
    patch sesion_url(sessions(:juan_1)), params: { sesion: { fecha: "2026-03-12" } }
    assert_redirected_to visit_url(visits(:visita_juan))
    assert_empty sessions(:juan_1).reload.treatments
  end

  test "borra una sesión" do
    assert_difference -> { Session.count } => -1, -> { Treatment.count } => 0 do
      delete sesion_url(sessions(:juan_2))
    end
    assert_response :see_other
    assert_redirected_to visit_url(visits(:visita_juan))
  end

  test "no se pueden añadir, editar ni borrar sesiones de diagnósticos ajenos" do
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get new_diagnosis_sesion_url(diagnoses(:diag_maria_perez))
    assert_response :not_found
    assert_no_difference -> { Session.count } do
      post diagnosis_sesiones_url(diagnoses(:diag_maria_perez)), params: params_sesion
    end
    assert_response :not_found

    ajena = sessions(:maria_perez_1)
    get edit_sesion_url(ajena)
    assert_response :not_found
    patch sesion_url(ajena), params: params_sesion
    assert_response :not_found
    assert_no_difference -> { Session.count } do
      delete sesion_url(ajena)
    end
    assert_response :not_found
  end

  test "unos parámetros con forma inesperada responden 400" do
    post diagnosis_sesiones_url(diagnoses(:diag_juan)), params: { sesion: "texto" }
    assert_response :bad_request
  end

  test "unas técnicas con forma inesperada se ignoran" do
    assert_difference -> { Session.count } => 1, -> { Treatment.count } => 0 do
      post diagnosis_sesiones_url(diagnoses(:diag_juan)), params: params_sesion(tecnicas: "Masaje")
    end
    assert_empty Session.order(:id).last.treatments
  end
end
