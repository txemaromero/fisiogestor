require "application_system_test_case"

class SeguimientoVisitaTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "añadir una sesión con técnicas a una visita guardada y verla en la evolución del dolor" do
    visit visit_path(visits(:visita_juan))
    assert_text "2 de 3 sesiones recomendadas"
    click_on "Añadir sesión"

    fill_in "Fecha", with: Date.new(2026, 3, 26)
    select "4", from: "Escala de dolor presesión"
    select "1", from: "Escala de dolor postsesión"
    within "#tecnicas-sesion" do
      within(all("tbody tr", count: 1)[0]) { fill_in "Nombre técnica", with: "Hipopresivos" }
      click_button "Añadir técnica"
      within(all("tbody tr", count: 2)[1]) do
        fill_in "Nombre técnica", with: "Punción seca"
        fill_in "Descripción de la técnica", with: "Agujas finas"
      end
      click_button "Añadir técnica"
      within(all("tbody tr", count: 3)[2]) { click_button "Borrar" }
      assert_selector "tbody tr", count: 2
    end
    click_button "Guardar"

    assert_text "Sesión añadida correctamente."
    within "#diagnosis_#{diagnoses(:diag_juan).id}" do
      assert_text "3 de 3 sesiones recomendadas"
      assert_text "✓ Completado"
      assert_selector "tbody tr", count: 3
      assert_selector "tbody tr:last-child td", text: "Hipopresivos, Punción seca"
    end

    click_on "Volver al paciente"
    within "#evolucion-dolor" do
      assert_selector "circle.punto-antes", count: 3
      assert_selector ".grafica-tooltip", visible: :hidden
      find("rect.zona[data-antes='4']").hover
      assert_selector ".grafica-tooltip", text: "4 antes"
      assert_selector ".grafica-tooltip", text: "1 después"
      assert_selector ".grafica-tooltip", text: "26/3/2026 · Lumbago"
    end
  end

  test "editar un diagnóstico con una enfermedad nueva y después borrarlo" do
    visit visit_path(visits(:visita_juan))
    click_on "Editar diagnóstico"

    assert_no_field "Nombre de la nueva enfermedad"
    select "Otra…", from: "Enfermedad"
    fill_in "Nombre de la nueva enfermedad", with: "Lumbalgia crónica"
    fill_in "Sesiones recomendadas", with: "6"
    click_button "Guardar"

    assert_text "Diagnóstico actualizado correctamente."
    assert_selector "h2", text: "Diagnóstico: Lumbalgia crónica"
    assert_text "2 de 6 sesiones recomendadas"

    accept_confirm { click_button "Borrar diagnóstico" }
    assert_text "Diagnóstico borrado."
    assert_text "Esta visita no tiene diagnósticos."
  end
end
