require "test_helper"

# Confirmación del email al registrarse (D103): sin confirmar no se entra; el enlace es de un solo uso y caduca a
# los 3 días; pedir otro no revela si el email tiene cuenta; y todo tiene límite de intentos. El enlace no confirma
# nada por sí solo: pide la clave de la cuenta (D104).
class ConfirmacionEmailTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  # Se sigue la redirección al login: así el aviso del registro no se queda para la página siguiente.
  def registrar(email = "ana@example.com", clave = "secreto-largo")
    post osteopath_registration_url, params: { osteopath: {
      nombre: "Ana", apellidos: "Ruiz Gómez", email: email, password: clave, password_confirmation: clave
    } }
    follow_redirect!
    Osteopath.find_by!(email: email)
  end

  def enlace_del_correo(correo = ActionMailer::Base.deliveries.last)
    correo.text_part.body.to_s[%r{http://\S+/osteopaths/confirmation\?confirmation_token=\S+}]
  end

  def token_del_enlace(enlace)
    Rack::Utils.parse_query(URI(enlace).query).fetch("confirmation_token")
  end

  # Lo que hace el formulario del enlace: el token y la clave.
  def confirmar(enlace, clave = "secreto-largo")
    patch osteopath_confirmation_url, params: { confirmation_token: token_del_enlace(enlace), osteopath: { password: clave } }
  end

  def entrar(email, clave = "secreto-largo")
    post osteopath_session_url, params: { osteopath: { email: email, password: clave } }
  end

  test "el correo, en español, lleva el enlace, explica que pedirá la clave y no la incluye" do
    registrar
    correo = ActionMailer::Base.deliveries.sole
    assert_equal "Confirma tu email en RedSocialFisios", correo.subject
    assert_equal [ "ana@example.com" ], correo.to
    [ correo.text_part.body.to_s, correo.html_part.body.to_s ].each do |cuerpo|
      assert_includes cuerpo, "Hola, Ana:"
      assert_includes cuerpo, "caduca"
      assert_includes cuerpo, "escribe la clave que elegiste al registrarte"
      # El token es base64 para URL: letras, números, «_» y «-» (también al principio).
      assert_match %r{/osteopaths/confirmation\?confirmation_token=[\w-]{20}}, cuerpo
      assert_no_match(/secreto-largo/, cuerpo)
    end
  end

  test "sin confirmar no se entra, ni con la clave correcta; tras confirmar, se entra y se da de alta el segundo factor" do
    ana = registrar
    entrar("ana@example.com")
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", /Antes de entrar tienes que confirmar tu email/
    get patients_url
    assert_redirected_to new_osteopath_session_url

    confirmar(enlace_del_correo)
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", "Tu email está confirmado. Ya puedes iniciar sesión."
    assert ana.reload.confirmed?

    entrar("ana@example.com")
    get patients_url
    assert_redirected_to nuevo_segundo_factor_url
    follow_redirect!
    assert_select "h1", "Activa el segundo factor"
  end

  test "abrir el enlace no confirma: enseña la cuenta y pide su clave (D104)" do
    ana = registrar
    enlace = enlace_del_correo
    get enlace
    assert_response :success
    assert_select "h1", "Confirma tu email"
    assert_select "p", /registro de Ana Ruiz Gómez con el email ana@example\.com/
    assert_select "form[action=?][method=post]", osteopath_confirmation_path do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[type=hidden][name=confirmation_token][value=?]", token_del_enlace(enlace)
      assert_select "input[type=password][name='osteopath[password]'][autocomplete=current-password]"
      assert_select "input[type=submit][value=?]", "Confirmar mi email"
    end
    assert_select "p", /Si no te has registrado tú, no hagas nada/
    assert_select "a[href=?]", new_osteopath_password_path, text: "¿Has olvidado tu clave?"

    # Abrirlo otra vez (un antivirus del correo, una vista previa…) tampoco confirma nada.
    get enlace
    assert_response :success
    assert_not ana.reload.confirmed?
  end

  test "con una clave que no es la de la cuenta, o sin clave, no se confirma (D104)" do
    ana = registrar
    enlace = enlace_del_correo
    [ "otra-clave-larga", "", nil ].each do |clave|
      confirmar(enlace, clave)
      assert_response :unprocessable_content
      assert_select "#errores", "La clave no es la de esta cuenta. Escribe la que elegiste al registrarte."
      assert_select "input[type=hidden][name=confirmation_token][value=?]", token_del_enlace(enlace)
    end
    # Datos manipulados: el mismo error, sin fallar.
    patch osteopath_confirmation_url, params: { confirmation_token: token_del_enlace(enlace), osteopath: "secreto-largo" }
    assert_response :unprocessable_content
    assert_not ana.reload.confirmed?

    # El enlace sigue valiendo con la clave buena.
    confirmar(enlace)
    assert_redirected_to new_osteopath_session_url
    assert ana.reload.confirmed?
  end

  test "si otro registra tu email, no puedes confirmarle la cuenta; la recuperas cambiando la clave (D104)" do
    cuenta = registrar("ana@example.com", "clave-del-intruso")
    enlace = enlace_del_correo

    # La dueña del email abre el enlace y prueba su clave: no sabe la del intruso.
    confirmar(enlace, "clave-de-ana-1")
    assert_response :unprocessable_content
    assert_not cuenta.reload.confirmed?

    # Pide cambiar la clave (el enlace le llega a ella), elige la suya y confirma con ella.
    post osteopath_password_url, params: { osteopath: { email: "ana@example.com" } }
    token_clave = ActionMailer::Base.deliveries.last.text_part.body.to_s[/reset_password_token=([^\s"&]+)/, 1]
    put osteopath_password_url, params: { osteopath: { reset_password_token: token_clave, password: "clave-de-ana-1",
                                                       password_confirmation: "clave-de-ana-1" } }
    assert_redirected_to new_osteopath_session_url
    confirmar(enlace, "clave-de-ana-1")
    assert_redirected_to new_osteopath_session_url
    assert cuenta.reload.confirmed?

    # El intruso ya no entra; ella, sí.
    entrar("ana@example.com", "clave-del-intruso")
    assert_response :unprocessable_content
    entrar("ana@example.com", "clave-de-ana-1")
    get patients_url
    assert_redirected_to nuevo_segundo_factor_url
  end

  test "con una clave incorrecta, el login da el error de siempre: no dice que la cuenta exista ni que esté sin confirmar" do
    registrar
    %w[ana@example.com paco@example.com nadie@example.com].each do |email|
      entrar(email, "otra-clave-larga")
      assert_response :unprocessable_content
      assert_select ".alert", count: 1, text: "Email o clave incorrectos."
    end
  end

  test "el enlace solo vale una vez" do
    registrar
    enlace = enlace_del_correo
    confirmar(enlace)
    assert_redirected_to new_osteopath_session_url

    get enlace
    assert_response :unprocessable_content
    assert_select "#errores", /ya está confirmado: inicia sesión/
    confirmar(enlace)
    assert_response :unprocessable_content
    assert_select "#errores", /ya está confirmado: inicia sesión/
  end

  test "un enlace cuyo token empieza por guion también vale" do
    # Devise genera los tokens en base64 para URL, que usa «-»: así se prueba siempre, no 1 vez de cada 64.
    ana = sustituir(Devise, :friendly_token, ->(longitud = 20) { "-#{'a' * (longitud - 1)}" }) { registrar }
    enlace = enlace_del_correo
    assert_includes enlace, "confirmation_token=-aaaa"

    get enlace
    assert_response :success
    confirmar(enlace)
    assert_redirected_to new_osteopath_session_url
    assert ana.reload.confirmed?
  end

  test "un enlace inventado, o sin token, no confirma nada" do
    ana = registrar
    get osteopath_confirmation_url(confirmation_token: "inventado")
    assert_response :unprocessable_content
    assert_select "#errores", /El enlace para confirmar el email no es válido/

    [ { confirmation_token: "inventado" }, {}, { confirmation_token: [ "inventado" ] } ].each do |datos|
      patch osteopath_confirmation_url, params: datos.merge(osteopath: { password: "secreto-largo" })
      assert_response :unprocessable_content
      assert_select "#errores", /El enlace para confirmar el email no es válido/
    end
    assert_not ana.reload.confirmed?
  end

  test "el enlace caduca a los 3 días, también con la clave correcta; se pide otro y ese sí vale" do
    ana = registrar
    enlace = enlace_del_correo

    travel 3.days + 1.hour do
      get enlace
      assert_select "#errores", /no se confirmó a tiempo \(el enlace caduca a los 3 días\): pide otro correo/
      confirmar(enlace)
      assert_response :unprocessable_content
      assert_select "#errores", /no se confirmó a tiempo/
      assert_not ana.reload.confirmed?

      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        post osteopath_confirmation_url, params: { osteopath: { email: "Ana@example.com " } }
      end
      assert_redirected_to new_osteopath_session_url
      follow_redirect!
      assert_select ".alert", /Si ese email tiene una cuenta sin confirmar, recibirás/

      nuevo = enlace_del_correo
      assert_not_equal enlace, nuevo
      confirmar(nuevo)
      assert_redirected_to new_osteopath_session_url
      assert ana.reload.confirmed?
    end
  end

  test "pedir otro enlace no dice si el email tiene cuenta ni si ya está confirmada, y en esos casos no envía nada" do
    %w[nadie@example.com paco@example.com].each do |email|
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        post osteopath_confirmation_url, params: { osteopath: { email: email } }
      end
      assert_redirected_to new_osteopath_session_url
      follow_redirect!
      assert_select ".alert", /Si ese email tiene una cuenta sin confirmar, recibirás/
    end
  end

  test "tras 5 peticiones de enlace en 15 minutos se rechazan las siguientes" do
    5.times { post osteopath_confirmation_url, params: { osteopath: { email: "nadie@example.com" } } }

    post osteopath_confirmation_url, params: { osteopath: { email: "nadie@example.com" } }
    assert_redirected_to new_osteopath_confirmation_url
    follow_redirect!
    assert_select ".alert-danger", "Demasiadas peticiones desde esta conexión. Espera unos minutos."
  end

  test "tras 10 intentos de abrir el enlace o confirmar en 15 minutos se rechazan los siguientes" do
    registrar
    enlace = enlace_del_correo
    5.times { get osteopath_confirmation_url(confirmation_token: "inventado") }
    5.times { confirmar(enlace, "otra-clave-larga") }

    [ -> { get enlace }, -> { confirmar(enlace) } ].each do |intento|
      intento.call
      assert_redirected_to new_osteopath_session_url
      follow_redirect!
      assert_select ".alert-danger", "Demasiados intentos de confirmar el email. Espera unos minutos."
    end
    assert_not Osteopath.find_by!(email: "ana@example.com").confirmed?
  end

  test "agotar los intentos de confirmar no impide pedir otro enlace: cada límite tiene su contador (D104)" do
    11.times { get osteopath_confirmation_url(confirmation_token: "inventado") }
    assert_redirected_to new_osteopath_session_url

    post osteopath_confirmation_url, params: { osteopath: { email: "nadie@example.com" } }
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", /Si ese email tiene una cuenta sin confirmar, recibirás/
  end

  test "el login enlaza con la página para pedir otro enlace" do
    get new_osteopath_session_url
    assert_select "a[href=?]", new_osteopath_confirmation_path, text: "¿No te ha llegado el correo para confirmar tu email?"
  end
end
