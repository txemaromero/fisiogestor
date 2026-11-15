require "application_system_test_case"

class PacientesTest < ApplicationSystemTestCase
  setup do
    sign_in osteopaths(:paco)
  end

  test "crear un paciente con antecedentes añadidos dinámicamente" do
    visit patients_path
    within "nav" do
      click_on "Pacientes"
      click_on "Crear paciente"
    end

    fill_in "Nombre", with: "Lucía"
    fill_in "Apellidos", with: "Fernández Ruiz"
    select "2004", from: "Año nacimiento"
    select "Mujer", from: "Sexo"

    within "#antecedentes-familiares" do
      3.times { click_button "Añadir antecedente familiar" }
      assert_selector "tbody tr", count: 3

      filas = all("tbody tr")
      within(filas[0]) do
        fill_in "Familiar", with: "Padre"
        select "Digestivos", from: "Tipo"
        fill_in "Descripción", with: "Problemas de intestino permeable"
      end
      within(filas[1]) do
        fill_in "Familiar", with: "Madre"
        select "Cardio-respiratorios", from: "Tipo"
        fill_in "Descripción", with: "Arritmia"
      end
      within(filas[2]) { click_button "Borrar" }
      assert_selector "tbody tr", count: 2
    end

    within "#antecedentes-personales" do
      click_button "Añadir antecedente personal"
      select "Endocrinos", from: "Tipo"
      fill_in "Descripción", with: "Hipotiroidismo"
    end

    click_button "Crear"

    assert_text "Paciente creado correctamente."
    within("#ficha-paciente") { assert_text "Fernández Ruiz" }
    click_on "Mostrar antecedentes"

    within "#antecedentes-familiares" do
      assert_selector "tbody tr", count: 2
      assert_text "Problemas de intestino permeable"
      assert_text "Arritmia"
    end
    within "#antecedentes-personales" do
      assert_selector "tbody tr", count: 1
      assert_text "Hipotiroidismo"
    end
  end

  test "editar un paciente quitando un antecedente existente" do
    visit edit_patient_path(patients(:juan))

    within "#antecedentes-familiares" do
      fila_padre = all("tbody tr").find { |fila| fila.find_field("Familiar").value == "Padre" }
      within(fila_padre) { click_button "Borrar" }
      assert_selector "tbody tr", count: 1
    end
    click_button "Guardar"

    assert_text "Paciente actualizado correctamente."
    click_on "Mostrar antecedentes"
    within "#antecedentes-familiares" do
      assert_no_text "Padre"
      assert_text "Madre"
    end
  end

  test "borrar un paciente pide confirmación" do
    visit patients_path
    within("#patient_#{patients(:juan).id}") do
      accept_confirm { click_button "Borrar" }
    end

    assert_text "Paciente borrado."
    assert_no_selector "#patient_#{patients(:juan).id}"
  end
end
