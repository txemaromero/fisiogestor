require "test_helper"

class CasosControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  def datos_caso(**cambios)
    { titulo: "Lumbalgia que no mejora", resumen: "Tras dos sesiones el dolor sigue en 5.", confirmacion_anonimato: "1" }.merge(cambios)
  end

  def sin_verificar(osteopata)
    osteopata.update!(verificado_at: nil, admin: false)
  end

  # --- Acceso ------------------------------------------------------------------------------------

  test "sin verificar, /casos explica cómo conseguirlo y el resto lleva ahí" do
    maria = osteopaths(:maria)
    sin_verificar(maria)
    sign_in maria
    get casos_url
    assert_response :success
    assert_select "#sin-verificar", /pendiente de verificación/
    assert_select "#casos", 0

    maria.update!(numero_colegiado: nil)
    get casos_url
    assert_select "#sin-verificar a[href=?]", editar_perfil_path, "Completar mi perfil"

    [ caso_url(casos(:caso_pepe)), new_diagnosis_caso_url(diagnoses(:diag_maria_perez)), osteopata_url(osteopaths(:paco)) ].each do |url|
      get url
      assert_redirected_to casos_url, url
    end
    post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola" } }
    assert_redirected_to casos_url
    assert_equal 1, Comentario.count
  end

  test "la barra de navegación tiene el enlace a los casos clínicos" do
    get casos_url
    assert_select "nav a.nav-link.active[href=?]", casos_path, "Casos clínicos"
  end

  # --- Lista --------------------------------------------------------------------------------------

  test "la lista muestra los casos con enfermedad, sexo y tramo de edad, autor y comentarios" do
    get casos_url
    assert_response :success
    assert_select "#total-casos", "1 caso"
    fila = "#caso_#{casos(:caso_pepe).id}"
    assert_select "#{fila} a[href=?]", caso_path(casos(:caso_pepe)), "Hernia discal que no termina de mejorar"
    assert_select "#{fila} td", "Hernia discal"
    assert_select "#{fila} td", "Hombre, 65–69 años"
    assert_select "#{fila} td a[href=?]", osteopata_path(osteopaths(:paco)), "Paco Martínez"
    assert_select "#{fila} td.text-center", "1"
    assert_select "body", text: /Campos Giménez/, count: 0
  end

  test "la lista se filtra por enfermedad" do
    Caso.create!(diagnosis: diagnoses(:diag_maria_perez), osteopath: osteopaths(:maria), titulo: "Lumbago", resumen: "Caso.")
    get casos_url
    assert_select "#casos tbody tr", 2
    assert_select "select[name=enfermedad] option", %w[Todas Hernia\ discal Lumbago].size

    get casos_url(enfermedad: diseases(:lumbago).id)
    assert_select "#casos tbody tr", 1
    assert_select "#total-casos", "1 caso de Lumbago"
    get casos_url(enfermedad: "basura")
    assert_select "#casos tbody tr", 2
  end

  test "los casos de pacientes que ya no consienten no aparecen a los demás" do
    patients(:pepe).update!(consiente_compartir: false)
    sign_in osteopaths(:maria)
    get casos_url
    assert_select "#casos", 0
    assert_select ".alert", "Todavía no hay casos publicados."

    sign_in osteopaths(:paco)
    get casos_url
    assert_select "#caso_#{casos(:caso_pepe).id} .badge", "Retirado: solo lo ves tú"
  end

  # --- Ver un caso ------------------------------------------------------------------------------

  test "el caso muestra los datos anonimizados, la gráfica sin fechas, las técnicas sugeridas y los comentarios" do
    sign_in osteopaths(:maria)
    get caso_url(casos(:caso_pepe))
    assert_response :success
    assert_select "h1", "Hernia discal que no termina de mejorar"
    assert_select "#resumen-caso", /se estanca/
    assert_select "#datos-caso dd", "Hombre, 65–69 años"
    assert_select "#sesiones-caso tbody tr", 2
    assert_select "#sesiones-caso tbody tr:first-child td", "Manipulación lumbar"
    assert_select "#sesiones-caso tbody tr:nth-child(2) td:nth-child(2)", "7"
    assert_select "#evolucion-dolor, .grafica-dolor svg"
    assert_select "rect.zona[data-fecha='Día 7']"
    assert_select "body", text: %r{18/5/|25/5/|2026-05}, count: 0 # ni las fechas de las sesiones (18 y 25 de mayo)
    assert_select "body", text: /15\/5\/2026|68 años/, count: 0 # ni la de la visita ni la edad exacta
    assert_select "body", text: /Pepe|Campos Giménez|Hormigueo|Protrusión/, count: 0
    assert_select "#tecnicas-sugeridas .badge", /Estiramiento columna · 1 vez/
    assert_select "#comentario_#{comentarios(:comentario_maria).id}", /Yo añadiría estiramientos/
    assert_select "#formulario-comentario select[name='comentario[treatment_ids][]'] option", Treatment.count
  end

  test "el autor ve Editar y Borrar; los demás, Denunciar" do
    get caso_url(casos(:caso_pepe))
    assert_select "a[href=?]", edit_caso_path(casos(:caso_pepe)), "Editar"
    assert_select "form[action=?] button", caso_path(casos(:caso_pepe)), "Borrar"
    assert_select "form[action=?]", denuncia_caso_path(casos(:caso_pepe)), 0
    assert_select "form[action=?]", denuncia_comentario_path(comentarios(:comentario_maria))

    sign_in osteopaths(:maria)
    get caso_url(casos(:caso_pepe))
    assert_select "a[href=?]", edit_caso_path(casos(:caso_pepe)), 0
    assert_select "details.denunciar form[action=?] textarea[name='denuncia[motivo]']", denuncia_caso_path(casos(:caso_pepe))
    assert_select "form[action=?] button", comentario_path(comentarios(:comentario_maria)), "Borrar"
  end

  test "un caso oculto: el autor lo ve con un aviso y sin poder comentarlo; los demás, 404" do
    casos(:caso_pepe).update!(oculto_at: Time.current)
    get caso_url(casos(:caso_pepe))
    assert_select "#aviso-caso", /Oculto por la moderación/
    assert_select "#formulario-comentario", 0

    paco_sin_admin = osteopaths(:paco)
    paco_sin_admin.update!(admin: false)
    sign_in osteopaths(:maria)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get caso_url(casos(:caso_pepe))
    assert_response :not_found
  end

  test "un comentario oculto se sustituye por un aviso" do
    comentarios(:comentario_maria).update!(oculto_at: Time.current)
    get caso_url(casos(:caso_pepe))
    assert_select "#comentario_#{comentarios(:comentario_maria).id}", "Comentario oculto por la moderación."
    assert_select "#tecnicas-sugeridas", /Nadie ha sugerido técnicas/
  end

  # --- Publicar ---------------------------------------------------------------------------------

  test "la visita ofrece publicar el diagnóstico si el paciente consiente, o ver el caso ya publicado" do
    get visit_url(visits(:visita_juan))
    assert_select "a[href=?]", new_diagnosis_caso_path(diagnoses(:diag_juan)), "Publicar como caso clínico"
    get visit_url(visits(:visita_pepe))
    assert_select "a[href=?]", caso_path(casos(:caso_pepe)), "Ver caso clínico"

    patients(:juan).update!(consiente_compartir: false)
    get visit_url(visits(:visita_juan))
    assert_select "a", text: "Publicar como caso clínico", count: 0
  end

  test "el formulario enseña lo que se publica y pide título, resumen y la confirmación" do
    get new_diagnosis_caso_url(diagnoses(:diag_juan))
    assert_response :success
    assert_select "#datos-caso dd", "Hombre, 45–49 años"
    assert_select "#datos-caso dd", "Lumbago"
    assert_select "#formulario-caso input[name='caso[titulo]']"
    assert_select "#formulario-caso textarea[name='caso[resumen]']"
    assert_select "#formulario-caso input[type=checkbox][name='caso[confirmacion_anonimato]']"
    assert_select "body", text: /Martínez Campos|Dolor lumbar tras cargar/, count: 0
  end

  test "publica un diagnóstico propio como caso" do
    assert_difference -> { Caso.count } => 1 do
      post diagnosis_caso_url(diagnoses(:diag_juan)), params: { caso: datos_caso }
    end
    caso = Caso.order(:id).last
    assert_redirected_to caso_url(caso)
    assert_equal [ osteopaths(:paco), diagnoses(:diag_juan), "Lumbalgia que no mejora" ], [ caso.osteopath, caso.diagnosis, caso.titulo ]
  end

  test "sin la confirmación de anonimato no se publica" do
    assert_no_difference -> { Caso.count } do
      post diagnosis_caso_url(diagnoses(:diag_juan)), params: { caso: datos_caso(confirmacion_anonimato: "0") }
    end
    assert_response :unprocessable_content
    assert_select "#errores li", "La confirmación de que no identifican al paciente es obligatoria"
    assert_select "#formulario-caso input[name='caso[titulo]'][value='Lumbalgia que no mejora']"
  end

  test "no se publica un diagnóstico ajeno, uno ya publicado ni uno de un paciente que no consiente" do
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    assert_no_difference -> { Caso.count } do
      post diagnosis_caso_url(diagnoses(:diag_maria_perez)), params: { caso: datos_caso }
      assert_response :not_found

      post diagnosis_caso_url(diagnoses(:diag_pepe)), params: { caso: datos_caso }
      assert_redirected_to caso_url(casos(:caso_pepe))

      patients(:juan).update!(consiente_compartir: false)
      post diagnosis_caso_url(diagnoses(:diag_juan)), params: { caso: datos_caso }
      assert_redirected_to visit_url(visits(:visita_juan))
    end
    follow_redirect!
    assert_select ".alert", /el paciente tiene que consentir compartir sus datos/
  end

  test "no se puede asignar otro autor ni otro diagnóstico desde el formulario" do
    post diagnosis_caso_url(diagnoses(:diag_juan)),
         params: { caso: datos_caso(osteopath_id: osteopaths(:maria).id, diagnosis_id: diagnoses(:diag_antonio).id) }
    caso = Caso.order(:id).last
    assert_equal [ osteopaths(:paco), diagnoses(:diag_juan) ], [ caso.osteopath, caso.diagnosis ]
  end

  # --- Editar y borrar ----------------------------------------------------------------------------

  test "el autor edita el título y el resumen, confirmando otra vez el anonimato" do
    caso = casos(:caso_pepe)
    patch caso_url(caso), params: { caso: { titulo: "Nuevo título", resumen: "Nuevo resumen", confirmacion_anonimato: "0" } }
    assert_response :unprocessable_content
    assert_equal "Hernia discal que no termina de mejorar", caso.reload.titulo

    patch caso_url(caso), params: { caso: { titulo: "Nuevo título", resumen: "Nuevo resumen", confirmacion_anonimato: "1" } }
    assert_redirected_to caso_url(caso)
    assert_equal "Nuevo título", caso.reload.titulo
  end

  test "el autor borra el caso con sus comentarios" do
    assert_difference -> { Caso.count } => -1, -> { Comentario.count } => -1 do
      delete caso_url(casos(:caso_pepe))
    end
    assert_redirected_to casos_url
    assert Diagnosis.exists?(diagnoses(:diag_pepe).id), "el diagnóstico no se toca"
  end

  test "nadie más edita ni borra un caso" do
    sign_in osteopaths(:maria)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get edit_caso_url(casos(:caso_pepe))
    assert_response :not_found
    patch caso_url(casos(:caso_pepe)), params: { caso: { titulo: "Otro", confirmacion_anonimato: "1" } }
    assert_response :not_found
    assert_no_difference -> { Caso.count } do
      delete caso_url(casos(:caso_pepe))
    end
    assert_response :not_found
  end

  # --- Anonimato y casos retirados (D96) ------------------------------------------------------

  test "de la publicación solo se ve el mes, no la fecha exacta" do
    travel_to Time.zone.local(2026, 10, 7, 9) do
      casos(:caso_pepe).update_columns(created_at: Time.current)
      get casos_url
      assert_select "#caso_#{casos(:caso_pepe).id} .small", "octubre de 2026"
      get caso_url(casos(:caso_pepe))
      assert_select "h1 + p", /en octubre de 2026/
      assert_select "body", text: %r{7/10/2026}, count: 0
    end
  end

  test "no se publica un caso con fechas, años, teléfonos, DNI o emails en el título o el resumen" do
    assert_no_difference -> { Caso.count } do
      post diagnosis_caso_url(diagnoses(:diag_juan)), params: { caso: datos_caso(resumen: "Empezó en 2019 tras una caída.") }
    end
    assert_response :unprocessable_content
    assert_select "#errores li", /parecen contener un año/
  end

  test "al retirar el paciente el consentimiento, el autor ve el caso retirado y lo puede volver a publicar" do
    caso = casos(:caso_pepe)
    patients(:pepe).update!(consiente_compartir: false)
    get caso_url(caso)
    assert_select "#aviso-caso", /Retirado de la red porque el paciente retiró el consentimiento/
    assert_select "#aviso-caso form[action=?]", republicar_caso_path(caso), 0, "sin consentimiento no se puede"
    patch republicar_caso_url(caso)
    assert caso.reload.retirado?

    patients(:pepe).update!(consiente_compartir: true)
    get caso_url(caso)
    assert_select "#aviso-caso", /Ha vuelto a consentir/
    assert_select "#aviso-caso form[action=?] button", republicar_caso_path(caso), "Volver a publicar"
    patch republicar_caso_url(caso)
    assert_redirected_to caso_url(caso)
    assert_not caso.reload.retirado?
  end

  test "nadie más vuelve a publicar un caso" do
    patients(:pepe).update!(consiente_compartir: false)
    patients(:pepe).update!(consiente_compartir: true)
    sign_in osteopaths(:maria)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    patch republicar_caso_url(casos(:caso_pepe))
    assert_response :not_found
    assert casos(:caso_pepe).reload.retirado?
  end

  test "si dos envíos publican a la vez el mismo diagnóstico, el segundo lleva al caso del primero" do
    nuevo_original = Caso.method(:new)
    envio_simultaneo = lambda do |*argumentos, **opciones|
      nuevo_original.call(*argumentos, **opciones).tap do |caso|
        caso.define_singleton_method(:save) do |**_contexto|
          nuevo_original.call(diagnosis: diagnosis, osteopath: osteopath, titulo: "El otro envío", resumen: "Caso.").save!
          raise ActiveRecord::RecordNotUnique, "casos.diagnosis_id"
        end
      end
    end
    sustituir(Caso, :new, envio_simultaneo) do
      post diagnosis_caso_url(diagnoses(:diag_juan)), params: { caso: datos_caso }
    end
    caso = diagnoses(:diag_juan).reload.caso
    assert_equal "El otro envío", caso.titulo
    assert_redirected_to caso_url(caso)
  end
end
