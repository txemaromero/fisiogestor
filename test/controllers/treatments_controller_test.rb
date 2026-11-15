require "test_helper"

class TreatmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  test "sin pulsar el botón se muestra el formulario y no la tabla de resultados" do
    get filtrar_tratamientos_url
    assert_response :success
    assert_select "select[name=sexo] option[selected][value=ambos]", "Ambos"
    assert_select "input[name=edad_min]:not([value])"
    assert_select "input[name=edad_max]:not([value])"
    assert_select "select[name='dolencias[]'][multiple] option", Disease.count
    assert_select "input[type=submit][value='Mostrar tratamientos']"
    assert_select "turbo-frame#resultados"
    assert_select "#resultados-tratamientos", 0
  end

  test "con «ambos» y los campos vacíos aparecen todos los diagnósticos de la plataforma" do
    freeze_time # el identificador firmado lleva su caducidad: así coincide con el de la página
    get filtrar_tratamientos_url, params: { sexo: "ambos", edad_min: "", edad_max: "" }
    assert_response :success
    assert_select "#resultados-tratamientos tbody tr", Diagnosis.count
    assert_select "#total-resultados", "5 diagnósticos encontrados"
    # Incluye diagnósticos de pacientes de otro osteópata, enlazados con su identificador firmado
    # (y los propios, con su número).
    firmado = patients(:maria_perez).id_ficha_para(osteopaths(:paco))
    assert_select "#resultados-tratamientos a[href=?]", patient_path(firmado), text: "Mostrar paciente"
    assert_select "#resultados-tratamientos a[href=?]", patient_path(patients(:juan)), text: "Mostrar paciente"
    assert_select "#resultados-tratamientos a[href=?]", patient_path(patients(:maria_perez)), count: 0
  end

  test "filtra por género" do
    get filtrar_tratamientos_url, params: { sexo: "mujer" }
    assert_select "#resultados-tratamientos tbody tr", 2
    assert_select "#resultados-tratamientos tbody td", text: /Hombre/, count: 0
  end

  test "filtra por edad mínima y máxima, incluyendo los límites" do
    get filtrar_tratamientos_url, params: { sexo: "ambos", edad_min: "40", edad_max: "46" }
    assert_select "#resultados-tratamientos tbody tr", 2
    assert_select "#resultados-tratamientos tbody td", text: /40 años/
    assert_select "#resultados-tratamientos tbody td", text: /46 años/
  end

  test "filtra por varias dolencias" do
    get filtrar_tratamientos_url, params: { sexo: "ambos", dolencias: [ diseases(:lumbago).id, diseases(:hernia_discal).id ] }
    assert_select "#resultados-tratamientos tbody tr", 3
    assert_select "#resultados-tratamientos tbody tr td:first-child", text: "Ciática", count: 0
    assert_select "select[name='dolencias[]'] option[selected]", 2
  end

  test "combina todos los criterios" do
    get filtrar_tratamientos_url, params: { sexo: "hombre", edad_min: "40", edad_max: "70",
                                            dolencias: [ diseases(:hernia_discal).id ] }
    assert_select "#resultados-tratamientos tbody tr", 1
    assert_select "##{ActionView::RecordIdentifier.dom_id(diagnoses(:diag_pepe))}"
  end

  test "sin resultados muestra un aviso" do
    get filtrar_tratamientos_url, params: { sexo: "ambos", dolencias: [ diseases(:miopia).id ] }
    assert_select "#total-resultados", "0 diagnósticos encontrados"
    assert_select ".alert", "Ningún diagnóstico cumple el filtro."
  end

  test "«Mostrar técnicas» pasa los ids de las técnicas del diagnóstico sin duplicados" do
    get filtrar_tratamientos_url, params: { sexo: "hombre", dolencias: [ diseases(:lumbago).id ] }
    enlace = css_select("#resultados-tratamientos a").find { |a| a.text == "Mostrar técnicas" }
    ids = Rack::Utils.parse_nested_query(URI(enlace["href"]).query)["ids"].map(&:to_i)
    assert_equal treatments(:masaje, :estiramiento, :manipulacion).map(&:id).sort, ids.sort
    assert_select "#resultados-tratamientos td", text: /3 técnicas/
  end

  test "tecnicas_aplicadas muestra nombre y descripción de las técnicas indicadas" do
    get tecnicas_aplicadas_url, params: { ids: [ treatments(:masaje).id, treatments(:hipopresivos).id ] }
    assert_response :success
    assert_select "#tecnicas-aplicadas thead th", 2
    assert_select "#tecnicas-aplicadas tbody tr", 2
    assert_select "#tecnicas-aplicadas td", "Masaje espalda"
    assert_select "#tecnicas-aplicadas td", "Ejercicios respiratorios que reducen la presión abdominal."
  end

  test "tecnicas_aplicadas sin ids muestra un aviso" do
    get tecnicas_aplicadas_url
    assert_response :success
    assert_select ".alert", "No hay técnicas que mostrar."
  end

  test "un género con forma inesperada se trata como «ambos» (sin error)" do
    get filtrar_tratamientos_url, params: { sexo: { a: "b" }, dolencias: { a: "b" }, edad_min: [ "1" ] }
    assert_response :success
    assert_select "#total-resultados", "5 diagnósticos encontrados"
    assert_select "select[name=sexo] option[selected][value=ambos]"
  end

  test "un sexo que no existe se trata como «ambos»" do
    get filtrar_tratamientos_url, params: { sexo: "otro" }
    assert_select "#total-resultados", "5 diagnósticos encontrados"
  end

  test "tecnicas_aplicadas ignora ids con forma inesperada" do
    get tecnicas_aplicadas_url, params: { ids: { a: "b" } }
    assert_response :success
    assert_select ".alert", "No hay técnicas que mostrar."
  end

  test "«Volver» solo lleva a páginas de la propia aplicación" do
    get tecnicas_aplicadas_url, params: { ids: [ treatments(:masaje).id ] },
                                headers: { "Referer" => "https://otro-sitio.example/trampa" }
    assert_select "a[href=?]", filtrar_tratamientos_path, text: "Volver"

    anterior = filtrar_tratamientos_url(sexo: "mujer")
    get tecnicas_aplicadas_url, params: { ids: [ treatments(:masaje).id ] }, headers: { "Referer" => anterior }
    assert_select "a[href=?]", anterior, text: "Volver"
  end

  test "sin sesión no se puede filtrar" do
    sign_out :osteopath
    get filtrar_tratamientos_url
    assert_redirected_to new_osteopath_session_url
  end

  test "de los pacientes de otros osteópatas solo salen los que consienten compartir sus datos (D83)" do
    freeze_time
    patients(:antonio).update!(consiente_compartir: false)
    patients(:juan).update!(consiente_compartir: false)
    get filtrar_tratamientos_url, params: { sexo: "ambos" }
    assert_select "#total-resultados", "4 diagnósticos encontrados"
    # Juan es de Paco: aunque no consienta, Paco lo sigue viendo.
    assert_select "#resultados-tratamientos a[href=?]", patient_path(patients(:juan))
    assert_select "#resultados-tratamientos a[href=?]", patient_path(patients(:antonio).id_ficha_para(osteopaths(:paco))), 0
  end

  # --- Solo para verificados (D94) -------------------------------------------------------------

  test "sin verificar, el filtro explica cómo conseguir la verificación y no muestra nada" do
    sign_in osteopaths(:maria).tap { |maria| maria.update!(verificado_at: nil) }
    get filtrar_tratamientos_url, params: { sexo: "ambos" }
    assert_response :success
    assert_select "h1", "Filtrar tratamientos"
    assert_select "#sin-verificar", /pendiente de verificación/
    assert_select "#resultados-tratamientos", 0
    assert_select "#filtro-tratamientos", 0
  end

  test "un administrador sin verificar sí usa el filtro" do
    osteopaths(:paco).update!(verificado_at: nil)
    get filtrar_tratamientos_url, params: { sexo: "ambos" }
    assert_select "#resultados-tratamientos tbody tr", Diagnosis.count
  end
end
