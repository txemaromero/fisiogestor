require "test_helper"

class VisitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  def params_visita(**cambios)
    sesiones = [
      { fecha: "2026-10-01", escala_dolor_pre_sesion: "7", escala_dolor_post_sesion: "4",
        tecnicas: [ { nombre: "Masaje espalda", descripcion: "" }, { nombre: "Punción seca", descripcion: "" } ] },
      { fecha: "2026-10-08", escala_dolor_pre_sesion: "5", escala_dolor_post_sesion: "2",
        tecnicas: [ { nombre: "Hipopresivos", descripcion: "" } ] }
    ]
    { visita: { patient_id: patients(:juan).id, anamnesis: "Dolor lumbar al levantarse", escala_dolor: "7",
                disease_id: diseases(:lumbago).id, descripcion: "Contractura", sesiones_recomendadas: "3",
                sesiones_json: sesiones.to_json }.merge(cambios) }
  end

  test "el asistente muestra los tres paneles, las pestañas y los modales" do
    get crear_visita_url
    assert_response :success
    assert_select "#pasos-asistente .nav-link", 3
    assert_select "#pasos-asistente a", 0 # las pestañas no son enlaces
    assert_select "#panel-visita"
    assert_select "#panel-diagnostico[hidden]"
    assert_select "#panel-sesiones[hidden]"
    assert_select "#osteopata[readonly][value=?]", "Paco Martínez"
    assert_select "select[name='visita[escala_dolor]'] option", 12 # vacía + 0..10
    assert_select "#modal-sesion .modal-title", "Introduzca los datos de la nueva sesión"
    assert_select "#modal-tecnica .modal-title", "Introduzca los datos de la nueva técnica"
    assert_select "#tabla-sesiones thead th", 6
  end

  test "el select de pacientes solo tiene los del osteópata conectado" do
    get crear_visita_url
    assert_select "select[name='visita[patient_id]'] option", 4 # vacía + 3 pacientes de Paco
    assert_select "select[name='visita[patient_id]'] option", text: /Pérez Gil/, count: 0
  end

  test "el select de enfermedades tiene el catálogo y la opción Otra…" do
    get crear_visita_url
    assert_select "select[name='visita[disease_id]'] option", Disease.count + 2
    assert_select "select[name='visita[disease_id]'] option[value=otra]", "Otra…"
  end

  test "con ?patient_id= el paciente queda preseleccionado" do
    get crear_visita_url(patient_id: patients(:pepe).id)
    assert_select "select[name='visita[patient_id]'] option[selected][value=?]", patients(:pepe).id.to_s
  end

  test "al guardar crea todo en un único POST y vuelve al paciente" do
    assert_difference -> { Visit.count } => 1, -> { Diagnosis.count } => 1, -> { Session.count } => 2,
                      -> { Treatment.count } => 1 do
      post crear_visita_url, params: params_visita
    end
    assert_redirected_to patient_url(patients(:juan))
    follow_redirect!
    assert_select ".alert-success", "Visita guardada correctamente."
    assert_select "#visitas-paciente tbody tr", 2

    visita = Visit.order(:id).last
    assert_equal osteopaths(:paco), visita.osteopath
    assert_equal [ 2, 1 ], visita.diagnoses.sole.sessions.map { |sesion| sesion.treatments.size }
  end

  test "si falla vuelve al asistente con los errores, sin guardar nada y sin perder los datos" do
    assert_no_difference %w[Visit.count Diagnosis.count Session.count Treatment.count] do
      post crear_visita_url, params: params_visita(sesiones_recomendadas: "0")
    end
    assert_response :unprocessable_content
    assert_select "#errores li", /Diagnóstico: Sesiones recomendadas/
    assert_select "textarea[name='visita[anamnesis]']", "Dolor lumbar al levantarse"
    assert_select "[data-asistente-visita-panel-inicial-value='1']"
    json = css_select("input[name='visita[sesiones_json]']").first["value"]
    assert_equal 2, JSON.parse(json).size
  end

  test "si falla la segunda sesión no queda guardado nada de lo anterior (transacción)" do
    sesiones = [
      { fecha: "2026-10-01", escala_dolor_pre_sesion: "7", escala_dolor_post_sesion: "4",
        tecnicas: [ { nombre: "Técnica nueva" } ] },
      { fecha: "2026-10-08", escala_dolor_pre_sesion: "5", escala_dolor_post_sesion: "11", tecnicas: [] }
    ]
    assert_no_difference %w[Visit.count Diagnosis.count Session.count Treatment.count Disease.count] do
      post crear_visita_url, params: params_visita(disease_id: "otra", nueva_enfermedad: "Enfermedad nueva",
                                                   sesiones_json: sesiones.to_json)
    end
    assert_response :unprocessable_content
    assert_select "#errores li", /Sesión 2: Escala de dolor postsesión/
    assert_select "[data-asistente-visita-panel-inicial-value='2']"
  end

  test "no se puede crear una visita para un paciente ajeno" do
    assert_no_difference -> { Visit.count } do
      post crear_visita_url, params: params_visita(patient_id: patients(:maria_perez).id)
    end
    assert_response :unprocessable_content
  end

  test "el resumen de una visita propia muestra paciente, diagnóstico, sesiones y técnicas" do
    get visit_url(visits(:visita_juan))
    assert_response :success
    assert_select "#resumen-visita", text: /Juan Martínez Campos/
    assert_select "#resumen-visita", text: /Dolor lumbar tras cargar peso/
    assert_select "h2", "Diagnóstico: Lumbago"
    assert_select "tbody tr", 2
    assert_select "tbody td", "Estiramiento columna, Masaje espalda"
    assert_select "a[href=?]", new_visit_examination_path(visits(:visita_juan))
    assert_select "a[href=?]", visit_supplementary_tests_path(visits(:visita_juan))
  end

  test "no se puede ver una visita de otro osteópata" do
    get visit_url(visits(:visita_maria_perez))
    assert_response :not_found
  end

  test "la ficha del paciente propio lista sus visitas con enlace al resumen" do
    get patient_url(patients(:juan))
    assert_select "#visitas-paciente tbody tr", 1
    assert_select "#visitas-paciente a[href=?]", visit_path(visits(:visita_juan)), text: "Ver"
    assert_select "#visitas-paciente a[href=?]", crear_visita_path(patient_id: patients(:juan).id)
  end

  test "la ficha de un paciente ajeno no lista sus visitas" do
    get patient_url(patients(:maria_perez).signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_response :success
    assert_select "#ficha-paciente"
    assert_select "#visitas-paciente", 0
  end

  # --- Seguimiento de una visita guardada --------------------------------------------------------

  test "el resumen tiene los botones para editar y borrar la visita, sus diagnósticos y sus sesiones" do
    visita = visits(:visita_juan)
    diagnostico = diagnoses(:diag_juan)
    get visit_url(visita)
    assert_select "a[href=?]", edit_visit_path(visita), text: "Editar visita"
    assert_select "form[action=?] button", visit_path(visita), text: "Borrar visita"
    assert_select "form[action=?][data-turbo-confirm]", visit_path(visita)
    assert_select "a[href=?]", edit_diagnosis_path(diagnostico), text: "Editar diagnóstico"
    assert_select "form[action=?] button", diagnosis_path(diagnostico), text: "Borrar diagnóstico"
    assert_select "a[href=?]", new_diagnosis_sesion_path(diagnostico), text: "Añadir sesión"
    assert_select "a[href=?]", edit_sesion_path(sessions(:juan_1)), text: "Editar"
    assert_select "form[action=?] button", sesion_path(sessions(:juan_2)), text: "Borrar"
    assert_select "a[href=?]", new_visit_diagnosis_path(visita), text: "Añadir diagnóstico"
  end

  test "el resumen muestra el progreso de cada diagnóstico" do
    get visit_url(visits(:visita_juan))
    assert_select "#diagnosis_#{diagnoses(:diag_juan).id} progress[value='2'][max='3']"
    assert_select "#diagnosis_#{diagnoses(:diag_juan).id} .progreso", text: /2 de 3 sesiones recomendadas/
    assert_select "#diagnosis_#{diagnoses(:diag_juan).id} .badge", 0

    get visit_url(visits(:visita_maria_torres)) # 1 de 2
    assert_select ".progreso", text: /1 de 2 sesiones recomendadas/
  end

  test "un diagnóstico con las sesiones recomendadas aparece como completado" do
    diagnoses(:diag_maria_torres).update!(sesiones_recomendadas: 1)
    get visit_url(visits(:visita_maria_torres))
    assert_select ".progreso", text: /1 de 1 sesión recomendada/
    assert_select ".progreso .badge", "✓ Completado"
  end

  test "la ficha muestra en cada visita las sesiones registradas frente a las recomendadas" do
    get patient_url(patients(:juan))
    assert_select "#visitas-paciente tbody td", "2 de 3"
  end

  test "edita los datos de la visita" do
    visita = visits(:visita_juan)
    get edit_visit_url(visita)
    assert_response :success
    assert_select "#paciente-visita[readonly][value=?]", "Juan Martínez Campos"
    assert_select "input[name='visit[fecha]'][value='2026-03-10']"

    patch visit_url(visita), params: { visit: { fecha: "2026-03-11", motivo: "Lumbalgia", anamnesis: "Revisada",
                                                escala_dolor: "6", patient_id: patients(:maria_perez).id } }
    assert_redirected_to visit_url(visita)
    follow_redirect!
    assert_select ".alert", /Visita actualizada correctamente/
    visita.reload
    assert_equal [ Date.new(2026, 3, 11), "Lumbalgia", "Revisada", 6 ], [ visita.fecha, visita.motivo, visita.anamnesis, visita.escala_dolor ]
    assert_equal patients(:juan), visita.patient # el paciente no se cambia
  end

  test "una visita con datos no válidos vuelve al formulario con los errores" do
    patch visit_url(visits(:visita_juan)), params: { visit: { escala_dolor: "15" } }
    assert_response :unprocessable_content
    assert_select "#errores", /Escala de dolor/
    assert_equal 8, visits(:visita_juan).reload.escala_dolor
  end

  test "borra la visita con sus diagnósticos y sesiones, pero no las técnicas del catálogo" do
    assert_difference -> { Visit.count } => -1, -> { Diagnosis.count } => -1, -> { Session.count } => -2,
                      -> { Treatment.count } => 0 do
      delete visit_url(visits(:visita_juan))
    end
    assert_response :see_other
    assert_redirected_to patient_url(patients(:juan))
  end

  test "no se puede editar ni borrar una visita ajena" do
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    ajena = visits(:visita_maria_perez)
    get edit_visit_url(ajena)
    assert_response :not_found
    patch visit_url(ajena), params: { visit: { motivo: "x" } }
    assert_response :not_found
    assert_no_difference -> { Visit.count } do
      delete visit_url(ajena)
    end
    assert_response :not_found
  end

  test "unos parámetros con forma inesperada responden 400" do
    patch visit_url(visits(:visita_juan)), params: { visit: "texto" }
    assert_response :bad_request
  end

  # --- Informe de la visita para el paciente -----------------------------------------------------

  test "el resumen de la visita enlaza al informe en otra pestaña y sin Turbo" do
    get visit_url(visits(:visita_pepe))
    assert_select "a[href=?][target=_blank][data-turbo=false]", informe_visit_path(visits(:visita_pepe)),
                  text: "Informe para el paciente"
  end

  test "el informe de la visita tiene diseño claro para imprimir y todos sus datos" do
    visita = visits(:visita_pepe)
    get informe_visit_url(visita)
    assert_response :success
    assert_select "html[data-bs-theme=light]"
    assert_select "nav.navbar", 0
    assert_select "button[data-action='imprimir#imprimir']", "Imprimir o guardar como PDF"
    assert_select "h1", "Informe de la visita del 15/5/2026"
    assert_select "#informe-paciente", /Pepe Campos Giménez/
    assert_select "#informe-consulta", /9 sobre 10/
    assert_select "#informe-diagnosis_#{diagnoses(:diag_pepe).id} h2", "Diagnóstico: Hernia discal"
    assert_select "#informe-diagnosis_#{diagnoses(:diag_pepe).id} tbody tr", 2
    assert_select "#informe-evolucion svg circle.punto-antes", 2
    assert_select "#informe-tecnicas dt", "Manipulación lumbar"
    assert_select "#informe-tecnicas dd", /alta velocidad y baja amplitud/
    assert_select "#informe-exploracion dd", "Lasègue positivo a 45º"
    assert_select "#informe-exploracion dt", text: /Examen craneal/, count: 0 # solo los campos rellenos
    assert_select "#informe-pruebas", /irm_pepe_campos\.pdf/
    assert_select "footer", /es confidencial/
  end

  test "una visita sin sesiones ni exploración da un informe sin esas secciones" do
    visita = Visit.create!(patient: patients(:juan), osteopath: osteopaths(:paco), fecha: Date.new(2026, 9, 1))
    get informe_visit_url(visita)
    assert_response :success
    assert_select "#informe-evolucion", 0
    assert_select "#informe-tecnicas", 0
    assert_select "#informe-exploracion", 0
    assert_select "#informe-pruebas", 0
  end

  test "no se puede ver el informe de una visita ajena" do
    get informe_visit_url(visits(:visita_maria_perez))
    assert_response :not_found
  end
end
