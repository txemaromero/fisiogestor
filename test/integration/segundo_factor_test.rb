require "test_helper"

# Segundo factor de autenticación obligatorio (D84): login en dos pasos, alta obligatoria, cambio de
# dispositivo y códigos de recuperación.
class SegundoFactorTest < ActionDispatch::IntegrationTest
  def dar_clave(email = "paco@example.com", clave = "demo-123456")
    post osteopath_session_url, params: { osteopath: { email: email, password: clave } }
  end

  def secreto_de_la_pagina
    css_select("#clave-segundo-factor").first.text.delete(" ")
  end

  # --- Login en dos pasos ------------------------------------------------------------------------

  test "con la clave correcta todavía no hay sesión: se pide el código" do
    dar_clave
    assert_redirected_to codigo_login_url
    follow_redirect!
    assert_select "h1", "Código de verificación"
    assert_select "#formulario-codigo input[name=codigo][autocomplete=one-time-code]"

    get patients_url
    assert_redirected_to new_osteopath_session_url
  end

  test "con la clave incorrecta no se llega a pedir el código" do
    dar_clave("paco@example.com", "incorrecta")
    assert_response :unprocessable_content
    get codigo_login_url
    assert_redirected_to new_osteopath_session_url
  end

  test "sin dar antes la clave, la página del código vuelve al login" do
    get codigo_login_url
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", "Vuelve a iniciar sesión."

    post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:paco)) }
    assert_redirected_to new_osteopath_session_url
  end

  def correos
    ActionMailer::Base.deliveries
  end

  test "tras 5 códigos incorrectos seguidos la cuenta no acepta códigos durante 15 minutos, desde ninguna sesión (D92)" do
    paco = osteopaths(:paco)
    travel_to Time.zone.local(2026, 10, 20, 10, 0, 10) do
      dar_clave
      4.times do
        post codigo_login_url, params: { codigo: "000000" }
        assert_response :unprocessable_content
        assert_select ".alert-danger", "El código no es correcto o ya se ha usado."
      end
      assert_difference -> { correos.size } => 1 do
        post codigo_login_url, params: { codigo: "000000" }
      end
      assert_redirected_to new_osteopath_session_url
      follow_redirect!
      assert_select ".alert", "Demasiados códigos incorrectos: esta cuenta no acepta códigos hasta las 10:15. " \
                              "Si no has sido tú, cambia tu clave."
      assert_equal [ [ "paco@example.com" ], "Códigos incorrectos en tu cuenta · RedSocialFisios" ],
                   [ correos.last.to, correos.last.subject ]

      # Otra sesión (como quien vuelve a enviar una cookie anterior, o desde otra IP): con la clave correcta
      # ni siquiera llega a pedir el código.
      open_session do |otra|
        otra.post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } },
                                         env: { "REMOTE_ADDR" => "10.1.1.1" }
        otra.assert_redirected_to new_osteopath_session_url
        otra.follow_redirect!
        otra.assert_select ".alert", /no acepta códigos hasta las 10:15/
      end
      assert paco.reload.otp_bloqueado?
    end

    travel_to Time.zone.local(2026, 10, 20, 10, 15, 20) do
      dar_clave
      post codigo_login_url, params: { codigo: codigo_otp(paco) }
      assert_redirected_to root_url
      assert_equal 0, paco.reload.otp_fallos
    end
  end

  test "un código correcto pone a cero los incorrectos" do
    travel_to Time.zone.local(2026, 10, 20, 10, 0, 10) do
      dar_clave
      4.times { post codigo_login_url, params: { codigo: "000000" } }
      post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:paco)) }
      assert_redirected_to root_url
      assert_equal 0, osteopaths(:paco).reload.otp_fallos
    end
  end

  test "hay 5 minutos para escribir el código" do
    dar_clave
    travel 6.minutes do
      post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:paco)) }
      assert_redirected_to new_osteopath_session_url
      get patients_url
      assert_redirected_to new_osteopath_session_url
    end
  end

  test "un código ya usado no vale para volver a entrar" do
    paco = osteopaths(:paco)
    travel_to Time.zone.local(2026, 10, 19, 12, 0, 5) do
      dar_clave
      post codigo_login_url, params: { codigo: codigo_otp(paco) }
      assert_redirected_to root_url
      delete destroy_osteopath_session_url

      dar_clave
      post codigo_login_url, params: { codigo: codigo_otp(paco) }
      assert_response :unprocessable_content
    end
  end

  test "se puede entrar con un código de recuperación, que ya no vale otra vez, y se avisa por correo" do
    dar_clave
    assert_difference -> { correos.size } => 1 do
      post codigo_login_url, params: { codigo: "ABCDE-FGHJK" }
    end
    assert_equal "Has entrado con un código de recuperación · RedSocialFisios", correos.last.subject
    assert_match "Te quedan 1 códigos de recuperación.", correos.last.text_part.body.to_s
    assert_redirected_to root_url
    follow_redirect!
    follow_redirect!
    assert_select ".alert", /Has entrado con un código de recuperación; te quedan 1\./
    delete destroy_osteopath_session_url

    dar_clave
    post codigo_login_url, params: { codigo: "abcde-fghjk" }
    assert_response :unprocessable_content
  end

  test "el código de otro osteópata no sirve" do
    dar_clave
    post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:maria)) }
    assert_response :unprocessable_content
  end

  test "tras 10 códigos en 5 minutos desde la misma conexión se rechazan los siguientes" do
    # 4 incorrectos y uno bueno, dos veces (sin llegar al límite de la cuenta): 10 códigos.
    dar_clave
    4.times { post codigo_login_url, params: { codigo: "000000" } }
    post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:paco)) }
    delete destroy_osteopath_session_url
    dar_clave
    4.times { post codigo_login_url, params: { codigo: "000000" } }
    post codigo_login_url, params: { codigo: "abcde-fghjk" }
    delete destroy_osteopath_session_url

    dar_clave
    post codigo_login_url, params: { codigo: "mnpqr-stuvw" }
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", "Demasiados intentos. Espera unos minutos."
  end

  # --- Alta obligatoria --------------------------------------------------------------------------

  test "sin el segundo factor activado solo se puede llegar al alta o salir" do
    paco = osteopaths(:paco)
    paco.restablecer_otp!
    dar_clave
    assert_redirected_to root_url, "sin segundo factor la clave basta para entrar…"

    [ patients_url, patient_url(patients(:juan)), informes_url, filtrar_tratamientos_url, cuenta_url ].each do |url|
      get url
      assert_redirected_to nuevo_segundo_factor_url, "…pero no se puede usar la aplicación (#{url})"
    end

    follow_redirect!
    assert_select "h1", "Activa el segundo factor"
    assert_select "nav .dropdown-toggle", 0, "el menú no se muestra"
    assert_select "nav form[action=?] button", destroy_osteopath_session_path, text: "Logout"
    assert_select "#formulario-segundo-factor input[name=clave]", 0

    delete destroy_osteopath_session_url
    assert_redirected_to new_osteopath_session_url
  end

  test "el alta muestra el QR y la clave, que no cambia al recargar, y se confirma con un código" do
    paco = osteopaths(:paco)
    paco.restablecer_otp!
    sign_in paco

    get nuevo_segundo_factor_url
    assert_response :success
    assert_select "img#qr-segundo-factor[src^='data:image/png;base64,']"
    secreto = secreto_de_la_pagina
    assert_match(/\A[A-Z2-7]{32}\z/, secreto)
    get nuevo_segundo_factor_url
    assert_equal secreto, secreto_de_la_pagina

    post segundo_factor_url, params: { codigo: "000000" }
    assert_response :unprocessable_content
    assert_select ".alert-danger", /El código no es correcto/
    assert_equal secreto, secreto_de_la_pagina
    assert_not paco.reload.otp_activado?

    assert_difference -> { correos.size } => 1 do
      post segundo_factor_url, params: { codigo: ROTP::TOTP.new(secreto).now }
    end
    assert_response :success
    assert_select "h1", "Códigos de recuperación"
    assert_select "#codigos-recuperacion li", 10
    assert_equal "no-store", response.headers["Cache-Control"], "los códigos no se guardan en la caché del navegador"
    assert paco.reload.otp_activado?
    assert_equal secreto, paco.otp_secret
    assert_equal "Se ha activado el segundo factor en tu cuenta · RedSocialFisios", correos.last.subject

    get patients_url
    assert_response :success
  end

  # --- Mi cuenta: cambio de dispositivo y códigos de recuperación ---------------------------------

  test "Mi cuenta muestra el segundo factor y los códigos que quedan" do
    sign_in osteopaths(:paco)
    get cuenta_url
    assert_response :success
    assert_select "nav a[href=?].active", cuenta_path, "Paco Martínez"
    assert_select "#datos-cuenta", /paco@example.com/
    assert_select "#segundo-factor", %r{Activado el 1/1/2026}
    assert_select "#codigos-restantes.text-warning-emphasis", /Te quedan\s+2 códigos de recuperación/
    assert_select "a[href=?]", nuevo_segundo_factor_path, "Cambiar de dispositivo"
  end

  test "cambiar de dispositivo pide la clave y un código del móvil actual, y deja de valer el anterior (D92)" do
    paco = osteopaths(:paco)
    sign_in paco
    get nuevo_segundo_factor_url
    assert_select "h1", "Cambiar de dispositivo"
    assert_select "#formulario-segundo-factor input[name=codigo_actual]"
    secreto = secreto_de_la_pagina
    assert_not_equal paco.otp_secret, secreto
    nuevo = ROTP::TOTP.new(secreto).now

    post segundo_factor_url, params: { codigo: nuevo, clave: "incorrecta", codigo_actual: codigo_otp(paco) }
    assert_response :unprocessable_content
    assert_select ".alert-danger", "La clave actual no es correcta."

    post segundo_factor_url, params: { codigo: "000000", clave: "demo-123456", codigo_actual: codigo_otp(paco) }
    assert_select ".alert-danger", /El código de la app nueva no es correcto/

    post segundo_factor_url, params: { codigo: nuevo, clave: "demo-123456", codigo_actual: "000000" }
    assert_response :unprocessable_content
    assert_select ".alert-danger", "El código no es correcto o ya se ha usado."
    assert_equal "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP", paco.reload.otp_secret

    assert_difference -> { correos.size } => 1 do
      post segundo_factor_url, params: { codigo: nuevo, clave: "demo-123456", codigo_actual: codigo_otp(paco) }
    end
    assert_response :success
    assert_select "#codigos-recuperacion li", 10
    assert_equal secreto, paco.reload.otp_secret
    assert_equal "Has cambiado de dispositivo para el segundo factor · RedSocialFisios", correos.last.subject

    delete destroy_osteopath_session_url
    dar_clave
    post codigo_login_url, params: { codigo: ROTP::TOTP.new("JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP").now }
    assert_response :unprocessable_content, "el código del móvil anterior ya no vale"
    post codigo_login_url, params: { codigo: "abcde-fghjk" }
    assert_response :unprocessable_content, "ni los códigos de recuperación anteriores"
  end

  test "sin el móvil anterior, se cambia de dispositivo con un código de recuperación" do
    paco = osteopaths(:paco)
    sign_in paco
    get nuevo_segundo_factor_url
    secreto = secreto_de_la_pagina
    post segundo_factor_url, params: { codigo: ROTP::TOTP.new(secreto).now, clave: "demo-123456", codigo_actual: "ABCDE-FGHJK" }
    assert_response :success
    assert_equal secreto, paco.reload.otp_secret
  end

  test "los códigos incorrectos al cambiar de dispositivo también bloquean la cuenta" do
    paco = osteopaths(:paco)
    sign_in paco
    get nuevo_segundo_factor_url
    nuevo = ROTP::TOTP.new(secreto_de_la_pagina).now
    4.times { post segundo_factor_url, params: { codigo: nuevo, clave: "demo-123456", codigo_actual: "000000" } }
    assert_difference -> { correos.size } => 1 do
      post segundo_factor_url, params: { codigo: nuevo, clave: "demo-123456", codigo_actual: "000000" }
    end
    assert_select ".alert-danger", /esta cuenta no acepta códigos hasta las/
    post segundo_factor_url, params: { codigo: nuevo, clave: "demo-123456", codigo_actual: codigo_otp(paco) }
    assert_select ".alert-danger", /esta cuenta no acepta códigos/, "ni siquiera el correcto"
    assert_equal "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP", paco.reload.otp_secret
  end

  test "generar códigos de recuperación nuevos pide un código de la app" do
    paco = osteopaths(:paco)
    sign_in paco
    get cuenta_url

    post codigos_recuperacion_url, params: { codigo: "000000" }
    assert_redirected_to cuenta_url
    follow_redirect!
    assert_select ".alert", "El código no es correcto o ya se ha usado."
    assert_equal 2, paco.reload.codigos_recuperacion_restantes

    assert_difference -> { correos.size } => 1 do
      post codigos_recuperacion_url, params: { codigo: codigo_otp(paco) }
    end
    assert_equal "Códigos de recuperación nuevos · RedSocialFisios", correos.last.subject
    assert_response :success
    assert_select ".alert", "Códigos de recuperación nuevos. Los anteriores ya no sirven."
    assert_select "#codigos-recuperacion li", 10
    assert_equal 10, paco.reload.codigos_recuperacion_restantes
    assert_not paco.usar_codigo_recuperacion("abcde-fghjk")
  end
end
