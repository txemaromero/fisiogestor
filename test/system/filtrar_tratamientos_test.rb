require "application_system_test_case"

class FiltrarTratamientosTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "filtrar tratamientos y navegar a las técnicas y al paciente" do
    visit patients_path
    within("nav") { click_on "Filtrar tratamientos" }

    assert_selector "h1", text: "Filtrar tratamientos"
    assert_no_selector "#resultados-tratamientos"

    # Con los valores por defecto aparecen todos los diagnósticos de la plataforma.
    click_button "Mostrar tratamientos"
    assert_selector "#resultados-tratamientos tbody tr", count: 5

    select "Mujer", from: "Género"
    fill_in "Edad mínima", with: "35"
    select "Lumbago", from: "Dolencias"
    click_button "Mostrar tratamientos"

    assert_selector "#total-resultados", text: "1 diagnóstico encontrado"
    assert_selector "#resultados-tratamientos tbody tr", count: 1
    assert_current_path(/sexo=mujer/) # la URL refleja el filtro

    within("#resultados-tratamientos") { click_on "Mostrar técnicas" }
    assert_selector "h1", text: "Técnicas aplicadas"
    within "#tecnicas-aplicadas" do
      assert_selector "tbody tr", count: 2
      assert_text "Masaje espalda"
      assert_text "Hipopresivos"
    end

    click_on "Volver"
    assert_selector "#resultados-tratamientos tbody tr", count: 1

    # El paciente es de otro osteópata: no se ven su nombre ni sus apellidos.
    within("#resultados-tratamientos") { click_on "Mostrar paciente" }
    within "#ficha-paciente" do
      assert_text "40 años"
      assert_text "Mujer"
      assert_no_text "Pérez Gil"
    end
  end
end
