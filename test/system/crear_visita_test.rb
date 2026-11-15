require "application_system_test_case"

class CrearVisitaTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "flujo completo: visita, diagnóstico con enfermedad nueva, dos sesiones con técnicas y guardar" do
    visit patients_path
    within("nav") { click_on "Crear visita" }

    # --- Panel Visita ---
    assert_selector "#pasos-asistente .active", text: "Visita"
    click_button "Siguiente"
    assert_selector "#visita_patient_id.is-invalid" # el paciente es obligatorio
    select "Juan Martínez Campos", from: "Paciente"
    assert_field "Osteópata", with: "Paco Martínez", readonly: true
    fill_in "Anamnesis", with: "Dolor lumbar al levantarse"
    select "7", from: "Escala dolor"
    click_button "Siguiente"

    # --- Panel Diagnóstico ---
    assert_selector "#pasos-asistente .active", text: "Diagnóstico"
    assert_no_field "Nombre de la nueva enfermedad"
    select "Otra…", from: "Enfermedad"
    fill_in "Nombre de la nueva enfermedad", with: "Escoliosis"
    fill_in "Descripción", with: "Curvatura lateral leve"
    fill_in "Sesiones recomendadas", with: "2"

    click_button "Anterior"
    assert_selector "#pasos-asistente .active", text: "Visita"
    assert_field "Anamnesis", with: "Dolor lumbar al levantarse"
    click_button "Siguiente"
    click_button "Siguiente"

    # --- Panel Sesiones ---
    assert_selector "#pasos-asistente .active", text: "Sesiones"
    assert_text "Todavía no hay sesiones."
    crear_sesion(Date.new(2026, 10, 1), "8", "5")
    crear_sesion(Date.new(2026, 10, 8), "5", "2")
    crear_sesion(Date.new(2026, 10, 15), "4", "4")
    assert_selector "#tabla-sesiones tbody tr", count: 3

    # Borrar la tercera sesión
    within(all("#tabla-sesiones tbody tr")[2]) { click_button "Borrar" }
    assert_selector "#tabla-sesiones tbody tr", count: 2

    # Subpanel de la primera sesión: cambiar la escala post y añadir dos técnicas
    within(all("#tabla-sesiones tbody tr")[0]) { click_button "Ver" }
    within "#detalle-sesion" do
      assert_text "Sesión 1"
      select "3", from: "Post"
    end
    crear_tecnica("Masaje espalda")
    crear_tecnica("Punción seca", "Agujas finas en el cuadrado lumbar")
    within("#tabla-tecnicas") { assert_selector "tbody tr", count: 2 }
    within("#detalle-sesion") { click_button "Guardar" }

    within(all("#tabla-sesiones tbody tr")[0]) do
      assert_selector "td", exact_text: "1/10/2026"
      assert_selector "td", exact_text: "3"
      assert_selector "td", exact_text: "Masaje espalda, Punción seca"
    end

    # Subpanel de la segunda sesión: una técnica, que luego se borra y se sustituye
    within(all("#tabla-sesiones tbody tr")[1]) { click_button "Ver" }
    crear_tecnica("Estiramiento columna")
    crear_tecnica("Hipopresivos")
    within(find("#tabla-tecnicas tbody tr", text: "Estiramiento columna")) { click_button "Borrar" }
    within("#tabla-tecnicas") { assert_selector "tbody tr", count: 1 }
    within("#detalle-sesion") { click_button "Guardar" }
    within(all("#tabla-sesiones tbody tr")[1]) { assert_selector "td", exact_text: "Hipopresivos" }

    # Nada se ha guardado todavía
    assert_equal 1, patients(:juan).visits.count

    click_button "Guardar"

    assert_text "Visita guardada correctamente."
    assert_selector "#visitas-paciente tbody tr", count: 2

    visita = patients(:juan).visits.order(:id).last
    diagnostico = visita.diagnoses.sole
    assert_equal "Dolor lumbar al levantarse", visita.anamnesis
    assert_equal 7, visita.escala_dolor
    assert_equal "Escoliosis", diagnostico.disease.nombre
    assert_equal 2, diagnostico.sesiones_recomendadas
    primera, segunda = diagnostico.sessions
    assert_equal [ Date.new(2026, 10, 1), 8, 3 ], [ primera.fecha, primera.escala_dolor_pre_sesion, primera.escala_dolor_post_sesion ]
    assert_equal [ "Masaje espalda", "Punción seca" ], primera.treatments.map(&:nombre).sort
    assert_equal [ "Hipopresivos" ], segunda.treatments.map(&:nombre)
    assert_equal "Agujas finas en el cuadrado lumbar", Treatment.find_by(nombre: "Punción seca").descripcion

    # El resumen de la visita muestra lo guardado
    within("#visitas-paciente tbody tr", text: "Escoliosis") { click_on "Ver" }
    assert_selector "h2", text: "Diagnóstico: Escoliosis"
    assert_text "Masaje espalda, Punción seca"
  end

  test "una técnica no se puede añadir dos veces a la misma sesión" do
    visit crear_visita_path(patient_id: patients(:juan).id)
    click_button "Siguiente"
    select "Lumbago", from: "Enfermedad"
    fill_in "Sesiones recomendadas", with: "1"
    click_button "Siguiente"
    crear_sesion(Date.new(2026, 10, 1), "6", "4")
    within(all("#tabla-sesiones tbody tr")[0]) { click_button "Ver" }
    crear_tecnica("Masaje espalda")

    abrir_modal "Nueva técnica", "#modal-tecnica"
    within "#modal-tecnica" do
      fill_in "Nombre técnica", with: "masaje espalda"
      click_button "Crear técnica"
      assert_text "Esa técnica ya está añadida a la sesión."
      within(".modal-footer") { click_button "Cerrar" }
    end
    within("#tabla-tecnicas") { assert_selector "tbody tr", count: 1 }
  end

  test "si el servidor rechaza la visita, el asistente vuelve con los errores y sin perder las sesiones" do
    visit crear_visita_path(patient_id: patients(:juan).id)
    fill_in "Anamnesis", with: "Dolor cervical"
    click_button "Siguiente"
    select "Lumbago", from: "Enfermedad"
    # Se salta la validación del navegador para forzar un error en el servidor.
    execute_script("document.getElementById('visita_sesiones_recomendadas').removeAttribute('min')")
    fill_in "Sesiones recomendadas", with: "0"
    click_button "Siguiente"
    crear_sesion(Date.new(2026, 10, 1), "6", "4")
    within(all("#tabla-sesiones tbody tr")[0]) { click_button "Ver" }
    crear_tecnica("Masaje espalda")
    within("#detalle-sesion") { click_button "Guardar" }

    assert_no_difference -> { Visit.count } do
      click_button "Guardar"
      assert_selector "#errores", text: "Diagnóstico: Sesiones recomendadas"
    end

    # Vuelve al panel con el error, con los datos y la sesión intactos.
    assert_selector "#pasos-asistente .active", text: "Diagnóstico"
    fill_in "Sesiones recomendadas", with: "2"
    click_button "Anterior"
    assert_field "Anamnesis", with: "Dolor cervical"
    click_button "Siguiente"
    click_button "Siguiente"
    within(all("#tabla-sesiones tbody tr")[0]) { assert_selector "td", text: "Masaje espalda" }

    click_button "Guardar"
    assert_text "Visita guardada correctamente."
  end

  private

  # Abre un modal y espera a que termine su animación: al terminar, Bootstrap mueve el foco y lo que se
  # estuviera escribiendo en ese momento acabaría en otro campo.
  def abrir_modal(boton, modal)
    click_on boton
    assert_selector "#{modal}[data-abriendo='false']"
  end

  def crear_sesion(fecha, pre, post)
    abrir_modal "Nueva sesión", "#modal-sesion"
    within "#modal-sesion" do
      fill_in "Fecha", with: fecha
      select pre, from: "Escala de dolor presesión"
      select post, from: "Escala de dolor postsesión"
      click_button "Crear sesión"
    end
    assert_no_selector "#modal-sesion", visible: true
  end

  def crear_tecnica(nombre, descripcion = nil)
    abrir_modal "Nueva técnica", "#modal-tecnica"
    within "#modal-tecnica" do
      fill_in "Nombre técnica", with: nombre
      fill_in "Descripción (opcional)", with: descripcion if descripcion
      click_button "Crear técnica"
    end
    assert_no_selector "#modal-tecnica", visible: true
  end
end
