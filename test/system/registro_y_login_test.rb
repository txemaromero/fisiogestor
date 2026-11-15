require "application_system_test_case"

class RegistroYLoginTest < ApplicationSystemTestCase
  def escribir_codigo(codigo)
    fill_in "Código", with: codigo
    click_button "Verificar"
  end

  test "un osteópata se registra, confirma su email, da de alta el segundo factor, cierra sesión y vuelve a entrar" do
    ActionMailer::Base.deliveries.clear
    visit root_url
    assert_current_path new_osteopath_session_path
    click_on "¿Nuevo usuario?"

    fill_in "Nombre", with: "Ana"
    fill_in "Apellidos", with: "Ruiz Gómez"
    fill_in "Email", with: "ana@example.com"
    fill_in "osteopath_password", with: "secreto-largo"
    fill_in "Confirmación de la clave", with: "secreto-largo"
    click_button "Guardar"

    # No se entra hasta confirmar el email con el enlace del correo (D103).
    assert_text "Te hemos enviado un correo con un enlace para confirmar tu email"
    assert_current_path new_osteopath_session_path
    # El correo lo envía el hilo del servidor de los tests: se espera a que llegue.
    correo = nil
    50.times { (correo = ActionMailer::Base.deliveries.last) ? break : sleep(0.1) }
    assert correo, "no ha llegado el correo para confirmar el email"
    visit URI(correo.text_part.body.to_s[%r{http://\S+/osteopaths/confirmation\?\S+}]).request_uri
    # El enlace pide la clave de la cuenta (D104).
    assert_selector "h1", text: "Confirma tu email"
    fill_in "Clave", with: "otra-clave-larga"
    click_button "Confirmar mi email"
    assert_selector "#errores", text: "La clave no es la de esta cuenta."
    fill_in "Clave", with: "secreto-largo"
    click_button "Confirmar mi email"
    assert_text "Tu email está confirmado. Ya puedes iniciar sesión."

    fill_in "Usuario (email)", with: "ana@example.com"
    fill_in "Clave", with: "secreto-largo"
    click_button "login"

    # Antes de nada, el alta del segundo factor (D84): el QR, o la clave para escribirla en la app.
    assert_selector "h1", text: "Activa el segundo factor"
    assert_selector ".navbar-text", text: "Ana Ruiz Gómez"
    assert_selector "img#qr-segundo-factor"
    secreto = find("#clave-segundo-factor").text.delete(" ")
    fill_in "Código de la app", with: ROTP::TOTP.new(secreto).now
    click_button "Activar"

    assert_selector "h1", text: "Códigos de recuperación"
    codigos = all("#codigos-recuperacion li").map(&:text)
    assert_equal 10, codigos.size
    click_on "He guardado los códigos"
    assert_selector "h1", text: "Mostrar pacientes"

    click_button "Logout"
    assert_current_path new_osteopath_session_path

    fill_in "Usuario (email)", with: "ana@example.com"
    fill_in "Clave", with: "secreto-largo"
    click_button "login"
    assert_selector "h1", text: "Código de verificación"
    # El código de la app de este momento ya se usó en el alta: entra con un código de recuperación.
    escribir_codigo(codigos.first)
    assert_selector "h1", text: "Mostrar pacientes"
    assert_text "te quedan 9"
  end

  test "un osteópata entra con su clave y el código de la app, y ve su cuenta" do
    visit new_osteopath_session_path
    fill_in "Usuario (email)", with: "paco@example.com"
    fill_in "Clave", with: "demo-123456"
    click_button "login"

    escribir_codigo("000000")
    assert_text "El código no es correcto o ya se ha usado."
    escribir_codigo(codigo_otp(osteopaths(:paco)))
    assert_selector "h1", text: "Mostrar pacientes"

    within("nav") { click_on "Paco Martínez" }
    assert_selector "h1", text: "Mi cuenta"
    assert_selector "#segundo-factor", text: "Activado el 1/1/2026"
    assert_selector "#codigos-restantes", text: "Te quedan 2 códigos de recuperación"
  end

  test "el registro muestra los errores y Cancelar vuelve al login" do
    visit new_osteopath_registration_path
    fill_in "Email", with: "paco@example.com"
    fill_in "osteopath_password", with: "123"
    click_button "Guardar"

    assert_selector "#errores", text: "Nombre no puede estar en blanco"
    click_on "Cancelar"
    assert_current_path new_osteopath_session_path
  end

  test "el menú Pacientes se despliega" do
    sign_in osteopaths(:paco)
    visit patients_path

    assert_no_selector ".dropdown-menu", visible: true
    click_on "Pacientes"
    assert_selector ".dropdown-menu .dropdown-item", text: "Crear paciente", visible: true
  end
end
