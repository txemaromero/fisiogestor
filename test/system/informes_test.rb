require "application_system_test_case"

class InformesTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "generar los informes y mostrar los controles del cuadro clínico solo cuando hacen falta" do
    visit patients_path
    within("nav") { click_on "Informes" }

    assert_selector "h1", text: "Generar informe"
    assert_no_selector "#controles-cuadro-clinico", visible: true

    select "Técnicas más efectivas", from: "Tipo de informe"
    click_button "Generar"
    within "#tabla-informe" do
      assert_selector "tbody tr", count: 4
      assert_selector "tbody tr:first-child", text: "Manipulación lumbar"
    end

    select "Técnicas posibles para un cuadro clínico", from: "Tipo de informe"
    assert_selector "#controles-cuadro-clinico", visible: true
    select "Lumbago", from: "Enfermedad"
    select "Hombre", from: "Género (opcional)"
    click_button "Generar"
    within("#tabla-informe") { assert_selector "tbody tr", count: 3 }
    assert_current_path(/disease_id=/)

    # Al volver a un informe sin controles, estos no se envían.
    select "Técnicas realizadas con mayor frecuencia", from: "Tipo de informe"
    assert_no_selector "#controles-cuadro-clinico", visible: true
    click_button "Generar"
    assert_selector "#resultado-informe h2", text: "Técnicas realizadas con mayor frecuencia"
    assert_no_current_path(/disease_id=/)
  end
end
