require "test_helper"

class RecuperarClaveTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  def pedir_enlace(email)
    post osteopath_password_url, params: { osteopath: { email: email } }
  end

  def token_del_ultimo_correo
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/reset_password_token=([^\s"&]+)/, 1]
  end

  def cambiar_clave(token, clave)
    put osteopath_password_url, params: { osteopath: { reset_password_token: token, password: clave,
                                                       password_confirmation: clave } }
  end

  test "el login enlaza con la recuperación de la clave" do
    get new_osteopath_session_url
    assert_select "a[href=?]", new_osteopath_password_path, text: "¿Has olvidado tu clave?"

    get new_osteopath_password_url
    assert_response :success
    assert_select "h1", "¿Has olvidado tu clave?"
    assert_select "input[type=email][name='osteopath[email]']"
    assert_select "input[type=submit][value=?]", "Enviar el enlace"
  end

  test "con un email registrado se envía un correo con el enlace para cambiar la clave" do
    assert_emails 1 do
      pedir_enlace("paco@example.com")
    end
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", /Si ese email tiene una cuenta, recibirás en unos minutos un correo/

    correo = ActionMailer::Base.deliveries.last
    assert_equal [ "paco@example.com" ], correo.to
    assert_equal "Cambiar la clave de RedSocialFisios", correo.subject
    assert_match "Hola, Paco:", correo.text_part.body.to_s
    assert_match "caduca en una hora", correo.html_part.body.to_s
    assert_match %r{http://example\.com/osteopaths/password/edit\?reset_password_token=\S+}, correo.text_part.body.to_s
  end

  test "con un email desconocido la respuesta es la misma, pero no se envía nada" do
    assert_no_emails do
      pedir_enlace("nadie@example.com")
    end
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", /Si ese email tiene una cuenta/
  end

  test "con el enlace se elige una clave nueva y el enlace ya no vale otra vez" do
    pedir_enlace("paco@example.com")
    token = token_del_ultimo_correo

    get edit_osteopath_password_url(reset_password_token: token)
    assert_response :success
    assert_select "input[type=hidden][name='osteopath[reset_password_token]'][value=?]", token

    # No se entra solo: hay que pasar por el login para que se pida el segundo factor (D84).
    cambiar_clave(token, "nueva-clave-1")
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", "Tu clave se ha cambiado. Ya puedes iniciar sesión."
    assert osteopaths(:paco).reload.valid_password?("nueva-clave-1")
    get patients_url
    assert_redirected_to new_osteopath_session_url

    cambiar_clave(token, "otra-clave-2")
    assert_response :unprocessable_content
    assert_select "#errores", /El enlace para cambiar la clave no es válido/
    assert osteopaths(:paco).reload.valid_password?("nueva-clave-1")
  end

  test "un enlace inventado no sirve" do
    cambiar_clave("inventado", "nueva-clave-1")
    assert_response :unprocessable_content
    assert_select "#errores", /El enlace para cambiar la clave no es válido/
    assert osteopaths(:paco).reload.valid_password?("demo-123456")
  end

  test "el enlace caduca a la hora" do
    pedir_enlace("paco@example.com")
    token = token_del_ultimo_correo
    travel 61.minutes do
      cambiar_clave(token, "nueva-clave-1")
      assert_response :unprocessable_content
      assert_select "#errores", /El enlace para cambiar la clave ha caducado: pide uno nuevo/
    end
    assert osteopaths(:paco).reload.valid_password?("demo-123456")
  end

  test "la clave nueva tiene que cumplir las mismas reglas que en el registro" do
    pedir_enlace("paco@example.com")
    cambiar_clave(token_del_ultimo_correo, "123")
    assert_response :unprocessable_content
    assert_select "#errores", /Clave es demasiado corto/
  end

  test "sin el enlace del correo no se puede abrir la página de cambiar la clave" do
    get edit_osteopath_password_url
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", /Solo se puede llegar a esta página con el enlace del correo/
  end

  test "tras 5 peticiones en 15 minutos desde la misma conexión se rechazan las siguientes" do
    5.times { pedir_enlace("nadie@example.com") }
    assert_no_emails do
      pedir_enlace("paco@example.com")
    end
    assert_redirected_to new_osteopath_password_url
    follow_redirect!
    assert_select ".alert-danger", "Demasiadas peticiones desde esta conexión. Espera unos minutos."

    travel 16.minutes do
      pedir_enlace("paco@example.com")
      assert_redirected_to new_osteopath_session_url
    end
  end

  test "tras 10 intentos de cambiar la clave en 15 minutos se rechazan los siguientes, con un contador propio (D104)" do
    10.times { cambiar_clave("inventado", "clave-nueva-larga") }
    cambiar_clave("inventado", "clave-nueva-larga")
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert-danger", "Demasiados intentos de cambiar la clave. Espera unos minutos."

    # Pedir el enlace sigue funcionando: antes, los dos límites compartían el contador.
    assert_emails 1 do
      pedir_enlace("paco@example.com")
    end
    assert_redirected_to new_osteopath_session_url
  end
end
