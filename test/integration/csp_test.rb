require "test_helper"

# Política de seguridad de contenidos (config/initializers/content_security_policy.rb).
class CspTest < ActionDispatch::IntegrationTest
  def nonce_de_la_cabecera
    response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
  end

  test "la primera visita, sin sesión, ya lleva un nonce y los scripts del importmap lo usan" do
    get new_osteopath_session_url
    cabecera = response.headers["Content-Security-Policy"]
    assert_includes cabecera, "script-src 'self'"
    assert_includes cabecera, "object-src 'none'"
    assert_includes cabecera, "frame-ancestors 'none'"

    nonce = nonce_de_la_cabecera
    assert nonce.present?, "el nonce no puede estar vacío: el navegador bloquearía el JavaScript"
    assert_select "script[type=importmap][nonce=?]", nonce
    assert_select "script[type=module][nonce=?]", nonce
  end

  test "el nonce se mantiene entre páginas y al iniciar sesión (necesario con Turbo)" do
    get new_osteopath_session_url
    nonce = nonce_de_la_cabecera

    get new_osteopath_registration_url
    assert_equal nonce, nonce_de_la_cabecera

    post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } }
    follow_redirect!
    assert_select "h1", "Código de verificación"
    assert_equal nonce, nonce_de_la_cabecera

    post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:paco)) }
    follow_redirect!
    follow_redirect!
    assert_select "h1", "Mostrar pacientes"
    assert_equal nonce, nonce_de_la_cabecera
  end

  test "las páginas no tienen estilos inline (la CSP los bloquearía)" do
    sign_in osteopaths(:paco)
    [ patients_path, new_patient_path, edit_patient_path(patients(:juan)), crear_visita_path, informes_path,
      filtrar_tratamientos_path(sexo: "ambos"), casos_path, caso_path(casos(:caso_pepe)),
      new_diagnosis_caso_path(diagnoses(:diag_juan)), osteopata_path(osteopaths(:paco)), cuenta_path, editar_perfil_path,
      verificaciones_path, moderacion_path ].each do |ruta|
      get ruta
      assert_select "[style]", 0, "#{ruta} tiene atributos style"
    end
  end
end
