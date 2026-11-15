require "application_system_test_case"

class GestionDiariaTest < ApplicationSystemTestCase
  test "buscar un paciente en la lista" do
    sign_in osteopaths(:paco)
    visit patients_path
    fill_in "Buscar por nombre o apellidos", with: "torres"
    click_button "Buscar"

    assert_selector "#pacientes tbody tr", count: 1
    assert_selector "#pacientes td", text: "Torres Gutiérrez"
    click_on "Limpiar"
    assert_selector "#pacientes tbody tr", count: 3
  end

  test "recuperar la clave con el enlace del correo" do
    ActionMailer::Base.deliveries.clear
    visit new_osteopath_session_path
    click_on "¿Has olvidado tu clave?"
    fill_in "Usuario (email)", with: "paco@example.com"
    click_button "Enviar el enlace"
    assert_text "Si ese email tiene una cuenta"

    # El correo lo envía el hilo del servidor de los tests: se espera a que llegue (falló una vez sin esperar).
    correo = nil
    50.times { (correo = ActionMailer::Base.deliveries.last) ? break : sleep(0.1) }
    assert correo, "no ha llegado el correo de recuperar la clave"
    enlace = correo.text_part.body.to_s[%r{http://\S+/osteopaths/password/edit\?\S+}]
    visit URI(enlace).request_uri
    fill_in "Clave nueva", with: "clave-nueva-1"
    fill_in "Confirmación de la clave", with: "clave-nueva-1"
    click_button "Cambiar la clave"

    # No se entra solo: el login con la clave nueva pide el segundo factor (D84).
    assert_text "Tu clave se ha cambiado. Ya puedes iniciar sesión."
    fill_in "Usuario (email)", with: "paco@example.com"
    fill_in "Clave", with: "clave-nueva-1"
    click_button "login"
    fill_in "Código", with: codigo_otp(osteopaths(:paco))
    click_button "Verificar"
    assert_selector "nav a", text: "Paco Martínez"
  end

  test "la agenda se abre desde la barra de navegación" do
    diagnoses(:diag_pepe).sessions.create!(fecha: Date.current + 2)
    sign_in osteopaths(:paco)
    visit patients_path
    within("nav") { click_on "Agenda" }

    assert_selector "h1", text: "Agenda"
    assert_selector "#dia-#{(Date.current + 2).iso8601}", text: "Pepe Campos Giménez"
  end

  test "el informe de la visita se abre en otra pestaña y su botón abre el diálogo de impresión" do
    sign_in osteopaths(:paco)
    visit visit_path(visits(:visita_pepe))
    pestana = window_opened_by { click_on "Informe para el paciente" }

    within_window(pestana) do
      assert_selector "h1", text: "Informe de la visita del 15/5/2026"
      # El diálogo de impresión no se puede manejar desde el test: se comprueba que se pide.
      execute_script("window.print = () => { window.impreso = true }")
      click_button "Imprimir o guardar como PDF"
      assert evaluate_script("window.impreso === true")
    end
  end
end
