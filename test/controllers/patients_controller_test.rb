require "test_helper"

class PatientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  def datos_paciente(**cambios)
    { nombre: "Lucía", apellidos: "Fernández Ruiz", anyo_nacimiento: 2000, sexo: "mujer" }.merge(cambios)
  end

  # --- Listado ---------------------------------------------------------------------------------

  test "la raíz redirige al listado de pacientes" do
    get root_url
    assert_redirected_to "/patients"
  end

  test "el listado muestra solo los pacientes del osteópata conectado" do
    get patients_url
    assert_response :success
    assert_select "h1", "Mostrar pacientes"
    assert_select "#pacientes thead th", %w[Nombre Apellidos Mostrar Borrar Editar].size
    assert_select "#pacientes tbody tr", 3
    assert_select "#pacientes", text: /Martínez Campos/
    assert_select "#pacientes", text: /Pérez Gil/, count: 0
  end

  # --- Buscador y paginación -------------------------------------------------------------------

  def crear_pacientes(cuantos)
    cuantos.times do |i|
      osteopaths(:paco).patients.create!(nombre: "Paciente", apellidos: format("Prueba %02d", i),
                                         anyo_nacimiento: 1990, sexo: "mujer")
    end
  end

  test "el buscador encuentra pacientes por nombre o apellidos sin distinguir tildes ni mayúsculas" do
    get patients_url(busqueda: "MARIA")
    assert_select "#buscador-pacientes input[name=busqueda][value=MARIA]"
    assert_select "#pacientes tbody tr", 1
    assert_select "#pacientes td", "María"
    assert_select "#total-pacientes", /1 paciente\s+coincide con «MARIA»/
    assert_select "a[href=?]", patients_path, text: "Limpiar"

    get patients_url(busqueda: "campos juan")
    assert_select "#pacientes tbody tr", 1
    assert_select "#pacientes td", "Juan"
  end

  test "el buscador solo busca entre los pacientes propios" do
    get patients_url(busqueda: "Pérez")
    assert_select "#pacientes", 0
    assert_select ".alert", "Ningún paciente coincide con «Pérez»."
  end

  test "la lista se pagina de 20 en 20" do
    crear_pacientes(22) # más los 3 de Paco
    get patients_url
    assert_select "#pacientes tbody tr", 20
    assert_select "#total-pacientes", /25 pacientes/
    assert_select "#paginacion", /Página 1 de 2/
    assert_select "#paginacion a[href=?]", patients_path(pagina: 2), text: "Siguiente"

    get patients_url(pagina: 2)
    assert_select "#pacientes tbody tr", 5
    assert_select "#paginacion a[href=?]", patients_path(pagina: 1), text: "Anterior"

    get patients_url(pagina: 99)
    assert_select "#paginacion", /Página 2 de 2/
  end

  test "la paginación conserva la búsqueda" do
    crear_pacientes(22)
    get patients_url(busqueda: "prueba")
    assert_select "#total-pacientes", /22 pacientes/
    assert_select "#paginacion a[href=?]", patients_path(busqueda: "prueba", pagina: 2), text: "Siguiente"
  end

  test "con pocos pacientes no hay paginación" do
    get patients_url
    assert_select "#paginacion", 0
  end

  test "unos parámetros de búsqueda con forma inesperada se ignoran" do
    get patients_url(busqueda: [ "a", "b" ], pagina: { x: 1 })
    assert_response :success
    assert_select "#pacientes tbody tr", 3
  end

  test "el botón Borrar pide confirmación" do
    get patients_url
    assert_select "#patient_#{patients(:juan).id} form[data-turbo-confirm] button", "Borrar"
  end

  # --- Alta ------------------------------------------------------------------------------------

  test "el formulario de alta tiene los campos y las dos tablas de antecedentes" do
    get new_patient_url
    assert_response :success
    assert_select "input[name='patient[nombre]']"
    assert_select "input[name='patient[apellidos]']"
    assert_select "select[name='patient[anyo_nacimiento]'] option[value='1900']"
    assert_select "select[name='patient[anyo_nacimiento]'] option[value='#{Date.current.year}']"
    assert_select "select[name='patient[sexo]'] option[value=hombre]", "Hombre"
    assert_select "select[name='patient[sexo]'] option[value=mujer]", "Mujer"
    assert_select "#antecedentes-familiares thead th", text: "Familiar"
    assert_select "#antecedentes-familiares button", "+"
    assert_select "#antecedentes-personales button", "+"
    assert_select "template", 2
    assert_select "input[type=submit][value=Crear]"
  end

  test "crea un paciente del osteópata conectado con sus antecedentes" do
    assert_difference -> { Patient.count } => 1,
                      -> { FamilyMedicalBackground.count } => 2,
                      -> { PersonalMedicalBackground.count } => 1 do
      post patients_url, params: { patient: datos_paciente(
        family_medical_backgrounds_attributes: {
          "1" => { familiar: "Padre", tipo: "digestivos", descripcion: "Intestino permeable" },
          "2" => { familiar: "Madre", tipo: "cardio_respiratorios", descripcion: "Arritmia" }
        },
        personal_medical_backgrounds_attributes: {
          "3" => { tipo: "endocrinos", descripcion: "Hipotiroidismo" }
        }
      ) }
    end

    paciente = Patient.order(:id).last
    assert_redirected_to patient_url(paciente)
    assert_equal osteopaths(:paco), paciente.osteopath
    assert_equal %w[Madre Padre], paciente.family_medical_backgrounds.map(&:familiar).sort
    assert_equal [ "Hipotiroidismo" ], paciente.personal_medical_backgrounds.map(&:descripcion)
  end

  test "no se puede asignar el paciente a otro osteópata desde el formulario" do
    post patients_url, params: { patient: datos_paciente(osteopath_id: osteopaths(:maria).id) }
    assert_equal osteopaths(:paco), Patient.order(:id).last.osteopath
  end

  test "las filas de antecedentes vacías se ignoran" do
    assert_difference -> { Patient.count } => 1, -> { FamilyMedicalBackground.count } => 0 do
      post patients_url, params: { patient: datos_paciente(
        family_medical_backgrounds_attributes: { "1" => { familiar: "", tipo: "", descripcion: "", _destroy: "false" } }
      ) }
    end
  end

  test "si faltan datos vuelve al formulario con los errores y sin perder los antecedentes" do
    assert_no_difference -> { Patient.count } do
      post patients_url, params: { patient: datos_paciente(
        nombre: "", sexo: "",
        family_medical_backgrounds_attributes: { "1" => { familiar: "Padre", tipo: "digestivos", descripcion: "" } }
      ) }
    end
    assert_response :unprocessable_content
    assert_select "#errores li", text: "Nombre no puede estar en blanco"
    assert_select "#errores li", text: /Antecedente familiar: descripción no puede estar en blanco/
    assert_select "input[name='patient[nombre]'].is-invalid"
    assert_select "#antecedentes-familiares tbody input[value=Padre]"
  end

  # --- Ficha y antecedentes --------------------------------------------------------------------

  test "la ficha de un paciente propio muestra nombre y apellidos" do
    get patient_url(patients(:juan))
    assert_response :success
    assert_select "#ficha-paciente", text: /Juan/
    assert_select "#ficha-paciente", text: /Martínez Campos/
    assert_select "#ficha-paciente", text: /46 años/
    assert_select "#ficha-paciente", text: /Hombre/
    assert_select "a[href=?]", medical_background_patient_path(patients(:juan)), text: "Mostrar antecedentes"
    assert_select "a[href=?]", edit_patient_path(patients(:juan))
  end

  test "la ficha de un paciente ajeno (con su identificador firmado) oculta nombre y apellidos" do
    freeze_time # el identificador lleva su caducidad: así coincide con el de la página
    maria_perez = patients(:maria_perez)
    firmado = maria_perez.id_ficha_para(osteopaths(:paco))
    get patient_url(firmado)
    assert_response :success
    assert_select "#ficha-paciente", text: /Pérez Gil/, count: 0
    assert_select "#ficha-paciente dt", text: "Nombre", count: 0
    assert_select "#ficha-paciente", text: /40 años/
    assert_select "#ficha-paciente", text: /Mujer/
    assert_select "a[href=?]", medical_background_patient_path(firmado), text: "Mostrar antecedentes"
    assert_select "a[href=?]", edit_patient_path(maria_perez), count: 0
  end

  test "la ficha de un paciente propio con sesiones muestra la evolución del dolor" do
    get patient_url(patients(:juan))
    assert_select "#evolucion-dolor svg[role=group]"
    assert_select "#evolucion-dolor title", "Evolución del dolor en 2 sesiones: empieza en 8 y termina en 1 sobre 10."
    assert_select "#evolucion-dolor circle.punto-antes", 2
    assert_select "#evolucion-dolor circle.punto-despues", 2
    assert_select "#evolucion-dolor line.tramo", 2
    assert_select "#evolucion-dolor rect.zona[tabindex='0'][data-antes='8'][data-despues='5'][data-enfermedad='Lumbago']"
    assert_select "#evolucion-dolor rect.zona[aria-label=?]", "Sesión 1, 12/3/2026, Lumbago: dolor 8 antes y 5 después"
    assert_select "#tabla-evolucion-dolor tbody tr", 2
  end

  test "no hay gráfica de evolución sin sesiones ni en la ficha de un paciente ajeno" do
    sin_sesiones = osteopaths(:paco).patients.create!(nombre: "Ana", apellidos: "Ruiz", anyo_nacimiento: 1990, sexo: "mujer")
    get patient_url(sin_sesiones)
    assert_response :success
    assert_select "#evolucion-dolor", 0

    get patient_url(patients(:maria_perez).signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_response :success
    assert_select "#evolucion-dolor", 0
  end

  test "la ficha de un paciente ajeno no se abre con su número (no se pueden recorrer)" do
    get patient_url(patients(:maria_perez))
    assert_response :not_found
  end

  test "los antecedentes de un paciente ajeno no se abren con su número" do
    get medical_background_patient_url(patients(:maria_perez))
    assert_response :not_found
  end

  test "un identificador firmado falso o con otro propósito no abre ninguna ficha" do
    get patient_url("eyJfcmFpbHMiOnsiZGF0YSI6MX19--falso")
    assert_response :not_found
  end

  test "un identificador firmado con otro propósito no abre la ficha" do
    get patient_url(patients(:maria_perez).signed_id(purpose: :otra_cosa))
    assert_response :not_found
  end

  test "el osteópata del paciente puede abrir su ficha con el número o con el identificador firmado" do
    juan = patients(:juan)
    get patient_url(juan)
    assert_response :success
    get patient_url(juan.signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_response :success
    assert_select "#ficha-paciente", text: /Martínez Campos/
  end

  test "los antecedentes de un paciente propio se muestran con su nombre" do
    get medical_background_patient_url(patients(:juan))
    assert_response :success
    assert_select "#resumen-paciente", text: /Juan Martínez Campos/
    assert_select "#antecedentes-familiares tbody tr", 2
    assert_select "#antecedentes-familiares tbody tr td", text: "Digestivos"
    assert_select "#antecedentes-personales tbody tr td", text: "Condromalacia rotuliana"
  end

  test "los antecedentes de un paciente ajeno se muestran sin su nombre" do
    freeze_time # el identificador lleva su caducidad: así coincide con el de la página
    firmado = patients(:maria_perez).id_ficha_para(osteopaths(:paco))
    get medical_background_patient_url(firmado)
    assert_response :success
    assert_select "body", text: /Pérez Gil/, count: 0
    assert_select "a[href=?]", patient_path(firmado), text: "Volver al paciente"
    assert_select "#antecedentes-familiares tbody tr td", text: "Diabetes tipo 2"
    assert_select "#antecedentes-personales tbody tr td", text: "Hipotiroidismo"
  end

  # --- Edición y borrado -----------------------------------------------------------------------

  test "edita un paciente propio, añade un antecedente y borra otro" do
    juan = patients(:juan)
    padre = family_medical_backgrounds(:juan_padre)
    get edit_patient_url(juan)
    assert_response :success
    assert_select "input[type=hidden][name$='[id]'][value='#{padre.id}']"

    patch patient_url(juan), params: { patient: {
      apellidos: "Martínez Campillo",
      family_medical_backgrounds_attributes: {
        "0" => { id: padre.id, _destroy: "1" },
        "1" => { familiar: "Abuelo", tipo: "neurologicos", descripcion: "Alzheimer" }
      }
    } }
    assert_redirected_to patient_url(juan)
    juan.reload
    assert_equal "Martínez Campillo", juan.apellidos
    assert_equal %w[Abuelo Madre], juan.family_medical_backgrounds.map(&:familiar).sort
  end

  test "no se puede abrir el formulario de edición de un paciente ajeno" do
    get edit_patient_url(patients(:maria_perez))
    assert_response :not_found
  end

  test "no se puede modificar un paciente ajeno" do
    maria_perez = patients(:maria_perez)
    patch patient_url(maria_perez), params: { patient: { nombre: "Cambiado" } }
    assert_response :not_found
    assert_equal "María", maria_perez.reload.nombre
  end

  test "borra un paciente propio" do
    assert_difference -> { Patient.count } => -1 do
      delete patient_url(patients(:juan))
    end
    assert_redirected_to patients_url
  end

  test "no se puede borrar un paciente ajeno" do
    assert_no_difference -> { Patient.count } do
      delete patient_url(patients(:maria_perez))
    end
    assert_response :not_found
  end

  test "sin sesión no se accede a los pacientes" do
    sign_out :osteopath
    get patient_url(patients(:juan))
    assert_redirected_to new_osteopath_session_url
  end

  # --- Consentimiento para compartir (D83) -----------------------------------------------------

  test "el formulario tiene el consentimiento, sin marcar en los pacientes nuevos" do
    get new_patient_url
    assert_select "#consentimiento input[type=checkbox][name='patient[consiente_compartir]']:not([checked])"
    assert_select "#consentimiento label", /consiente compartir sus datos clínicos/

    get edit_patient_url(patients(:juan))
    assert_select "#consentimiento input[type=checkbox][name='patient[consiente_compartir]'][checked]"
  end

  test "un paciente nuevo no consiente si no se marca, y se anota la fecha cuando se marca" do
    post patients_url, params: { patient: datos_paciente }
    paciente = Patient.order(:id).last
    assert_not paciente.consiente_compartir?
    assert_nil paciente.consentimiento_actualizado_at

    patch patient_url(paciente), params: { patient: { consiente_compartir: "1" } }
    assert paciente.reload.consiente_compartir?
    assert_not_nil paciente.consentimiento_actualizado_at
    follow_redirect!
    assert_select "#consentimiento-paciente", /Sí, sin nombre ni apellidos, desde el #{Date.current.day}\//
  end

  test "la ficha propia dice si el paciente no consiente compartir sus datos" do
    patients(:juan).update!(consiente_compartir: false)
    get patient_url(patients(:juan))
    assert_select "#consentimiento-paciente", /No: sus datos clínicos solo los ves tú \(lo retiró el /
  end

  test "si el paciente de otro osteópata retira el consentimiento, su ficha y sus antecedentes ya no se abren" do
    maria_perez = patients(:maria_perez)
    firmado = maria_perez.signed_id(purpose: Patient::PROPOSITO_FICHA)
    maria_perez.update!(consiente_compartir: false)

    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get patient_url(firmado)
    assert_response :not_found
    get medical_background_patient_url(firmado)
    assert_response :not_found
  end

  test "el osteópata del paciente lo sigue viendo aunque no consienta" do
    patients(:juan).update!(consiente_compartir: false)
    get patient_url(patients(:juan))
    assert_response :success
    get patient_url(patients(:juan).signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_response :success
  end

  # --- Registro de accesos (D85) ---------------------------------------------------------------

  test "abrir la ficha o los antecedentes de un paciente de otro osteópata queda registrado" do
    maria_perez = patients(:maria_perez)
    firmado = maria_perez.signed_id(purpose: Patient::PROPOSITO_FICHA)

    assert_difference -> { maria_perez.accesos_fichas.count } => 2 do
      get patient_url(firmado)
      get medical_background_patient_url(firmado)
    end
    assert_equal [ %w[paco@example.com antecedentes], %w[paco@example.com ficha] ],
                 maria_perez.accesos_fichas.map { |acceso| [ acceso.osteopath.email, acceso.pagina ] }
  end

  test "los accesos a los pacientes propios no se registran" do
    assert_no_difference -> { AccesoFicha.count } do
      get patient_url(patients(:juan))
      get medical_background_patient_url(patients(:juan))
      get patient_url(patients(:juan).signed_id(purpose: Patient::PROPOSITO_FICHA))
    end
  end

  test "un acceso rechazado (sin consentimiento) no se registra" do
    patients(:maria_perez).update!(consiente_compartir: false)
    assert_no_difference -> { AccesoFicha.count } do
      get patient_url(patients(:maria_perez).signed_id(purpose: Patient::PROPOSITO_FICHA))
    end
  end

  test "el osteópata del paciente ve en la ficha quién la ha abierto" do
    get patient_url(patients(:maria_perez).signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_select "#accesos-ficha", 0, "un osteópata ajeno no ve los accesos"

    sign_in osteopaths(:maria)
    get patient_url(patients(:maria_perez))
    assert_select "#accesos-ficha tbody tr", 1
    assert_select "#accesos-ficha tbody td", "Paco Martínez"
    assert_select "#accesos-ficha tbody td", "Ficha"

    get patient_url(patients(:antonio))
    assert_select "#accesos-ficha", /Ningún otro osteópata ha abierto la ficha/
  end

  test "la ficha muestra los 20 accesos más recientes" do
    maria_perez = patients(:maria_perez)
    25.times { |i| osteopaths(:paco).accesos_fichas.create!(patient: maria_perez, pagina: "ficha", created_at: i.hours.ago) }
    sign_in osteopaths(:maria)
    get patient_url(maria_perez)
    assert_select "#accesos-ficha tbody tr", 20
    assert_select "#accesos-ficha", /Los 20 más recientes de 25/
  end

  # --- Exportación y borrado de todos sus datos (D86) ------------------------------------------

  test "exporta todos los datos de un paciente propio en JSON" do
    pepe = patients(:pepe)
    supplementary_tests(:irm_pepe).archivo.attach(io: file_fixture("informe.pdf").open("rb"), filename: "informe.pdf",
                                                  content_type: "application/pdf")
    osteopaths(:maria).accesos_fichas.create!(patient: pepe, pagina: "antecedentes")

    get exportar_patient_url(pepe)
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_match(/attachment; filename="datos-pepe-campos-gimenez-#{Date.current.iso8601}.json"/,
                 response.headers["Content-Disposition"])

    datos = JSON.parse(response.body)
    assert_equal %w[formato paciente osteopata antecedentes_familiares antecedentes_personales visitas
                    casos_clinicos accesos_de_otros_osteopatas], datos.keys
    assert_equal({ "nombre" => "Pepe", "apellidos" => "Campos Giménez" }, datos["paciente"].slice("nombre", "apellidos"))
    assert_equal "Hombre", datos["paciente"]["sexo"]
    assert_equal true, datos["paciente"]["consentimiento_compartir"]["consiente"]
    assert_equal "paco@example.com", datos["osteopata"]["email"]

    visita = datos["visitas"].sole
    diagnostico = visita["diagnosticos"].sole
    assert_equal "Hernia discal", diagnostico["enfermedad"]
    assert_equal [ [ "2026-05-18", 9, 4, [ "Manipulación lumbar" ] ], [ "2026-05-25", 4, nil, [ "Hipopresivos" ] ] ],
                 diagnostico["sesiones"].map { |sesion| sesion.values_at("fecha", "dolor_antes", "dolor_despues", "tecnicas") }

    prueba = visita["pruebas_complementarias"].sole
    assert_equal "IRM", prueba["tipo"]
    assert_equal file_fixture("informe.pdf").binread, Base64.strict_decode64(prueba["archivo"]["base64"])

    assert_equal [ [ "Maria Campos Gil", "Antecedentes" ] ],
                 datos["accesos_de_otros_osteopatas"].map { |acceso| acceso.values_at("osteopata", "pagina") }

    caso = datos["casos_clinicos"].sole
    assert_equal [ "Hernia discal que no termina de mejorar", "Hernia discal", false ],
                 caso.values_at("titulo", "enfermedad", "oculto_por_la_moderacion")
    assert_equal [ [ "Maria Campos Gil", "Yo añadiría estiramientos de la columna.", [ "Estiramiento columna" ] ] ],
                 caso["comentarios"].map { |comentario| comentario.values_at("osteopata", "texto", "tecnicas_sugeridas") }
  end

  test "la ficha propia tiene los botones Exportar datos y Borrar; la ajena, no" do
    get patient_url(patients(:juan))
    assert_select "a[href=?]", exportar_patient_path(patients(:juan)), "Exportar datos"
    assert_select "form[action=?][data-turbo-confirm*='Se borrarán todos sus datos'] button", patient_path(patients(:juan)), "Borrar"

    get patient_url(patients(:maria_perez).signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_select "a", text: "Exportar datos", count: 0
    assert_select "button", text: "Borrar", count: 0
  end

  test "no se pueden exportar los datos de un paciente ajeno" do
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get exportar_patient_url(patients(:maria_perez))
    assert_response :not_found
    get exportar_patient_url(patients(:maria_perez).signed_id(purpose: Patient::PROPOSITO_FICHA))
    assert_response :not_found
  end

  test "al borrar un paciente se borra también su registro de accesos" do
    juan = patients(:juan)
    osteopaths(:maria).accesos_fichas.create!(patient: juan, pagina: "ficha")
    assert_difference -> { AccesoFicha.count } => -1, -> { Patient.count } => -1 do
      delete patient_url(juan)
    end
  end

  # --- Solo para verificados (D94) -------------------------------------------------------------

  test "sin verificar no se abren fichas ni antecedentes de otros osteópatas, aunque se tenga el enlace" do
    firmado = patients(:maria_perez).id_ficha_para(osteopaths(:paco))
    osteopaths(:paco).update!(verificado_at: nil, admin: false)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    assert_no_difference -> { AccesoFicha.count } do
      get patient_url(firmado)
      assert_response :not_found
      get medical_background_patient_url(firmado)
      assert_response :not_found
    end
    get patient_url(patients(:juan))
    assert_response :success, "los propios, siempre"
  end

  test "el enlace firmado de una ficha ajena caduca en un día" do
    firmado = patients(:maria_perez).id_ficha_para(osteopaths(:paco))
    get patient_url(firmado)
    assert_response :success
    travel 25.hours do
      reset! # la sesión anterior ya ha caducado (30 minutos sin actividad): se entra en una nueva
      sign_in osteopaths(:paco)
      get patients_url
      get patient_url(firmado)
      assert_response :not_found
    end
  end
end
