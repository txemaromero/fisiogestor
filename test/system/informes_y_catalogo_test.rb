require "application_system_test_case"

class InformesYCatalogoTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "un informe de mis pacientes entre dos fechas, con su gráfica y su descarga en CSV" do
    visit informes_path
    select "Técnicas más efectivas", from: "Tipo de informe"
    select "Mis pacientes", from: "Pacientes"
    fill_in "Sesiones desde (opcional)", with: Date.new(2026, 3, 1)
    fill_in "Sesiones hasta (opcional)", with: Date.new(2026, 3, 31)
    click_button "Generar"

    assert_selector "#filtros-informe", text: "Mis pacientes · del 1/3/2026 al 31/3/2026"
    assert_selector ".grafica-barras .fila-barra", count: 3
    assert_selector "#aviso-pocas-sesiones"
    assert_selector "#tabla-informe tbody tr", count: 3
    assert_link "Descargar CSV", href: /\/informes\.csv\?.*ambito=mios/
  end

  test "el administrador fusiona una técnica duplicada desde el catálogo" do
    duplicada = Treatment.create!(nombre: "Masaje de espalda")
    sessions(:pepe_1).treatments << duplicada

    visit patients_path
    within("nav") do
      click_on "Administración"
      click_on "Catálogo"
    end
    within("#tecnicas-#{duplicada.id}") do
      assert_text "Posible duplicado de «Masaje espalda»"
      click_on "Fusionar"
    end
    select "Masaje espalda", from: "Fusionar con"
    accept_confirm { click_button "Fusionar" }

    assert_text "«Masaje de espalda» se ha fusionado con «Masaje espalda»"
    assert_no_selector "#tecnicas-#{duplicada.id}"
    within("#fusiones") { assert_text "«Masaje de espalda» → «Masaje espalda»" }
  end
end
