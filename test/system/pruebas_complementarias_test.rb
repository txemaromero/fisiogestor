require "application_system_test_case"

class PruebasComplementariasTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "subir el fichero escaneado de una prueba y abrirlo" do
    visit visit_supplementary_tests_path(visits(:visita_juan))
    click_on "Añadir prueba"

    select "RX", from: "Tipo de prueba"
    attach_file "Fichero escaneado", file_fixture("informe.pdf")
    fill_in "Resumen", with: "Rectificación de la lordosis lumbar"
    click_button "Guardar"

    assert_text "Prueba complementaria guardada correctamente."
    within "#pruebas" do
      assert_selector "td.escaneado", text: "informe.pdf"
      assert_selector "td.escaneado", text: "(PDF, 698 Bytes)"
      assert_link "Descargar"
    end

    # «Ver» abre el PDF en otra pestaña (sin Turbo), servido como PDF y no como página.
    pestana = window_opened_by { click_link "Ver" }
    within_window(pestana) do
      assert_equal "application/pdf", evaluate_script("document.contentType")
    end
  end

  test "un fichero que no es PDF, JPG ni PNG se rechaza" do
    visit new_visit_supplementary_test_path(visits(:visita_juan))
    select "IRM", from: "Tipo de prueba"
    attach_file "Fichero escaneado", file_fixture("falso.pdf")
    fill_in "Resumen", with: "Prueba"
    click_button "Guardar"

    assert_selector "#errores", text: "Fichero escaneado debe ser un PDF, JPG o PNG"
    assert_selector "#ayuda-archivo", text: "vuelve a elegirlo"
  end
end
