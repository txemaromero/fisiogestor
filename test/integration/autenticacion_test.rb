require "test_helper"

class AutenticacionTest < ActionDispatch::IntegrationTest
  test "sin sesión no se puede acceder a la aplicación" do
    get patients_url
    assert_redirected_to new_osteopath_session_url
  end

  test "la raíz lleva al login si no hay sesión" do
    get root_url
    follow_redirect!
    assert_redirected_to new_osteopath_session_url
  end

  test "la página de login tiene usuario, clave, botón login y enlace a registro" do
    get new_osteopath_session_url
    assert_response :success
    assert_select "input[type=email][name='osteopath[email]']"
    assert_select "input[type=password][name='osteopath[password]']"
    assert_select "input[type=submit][value=login]"
    assert_select "a[href=?]", new_osteopath_registration_path, text: "¿Nuevo usuario?"
    assert_select "button", text: "Logout", count: 0
  end

  test "login correcto pide el código del segundo factor y después lleva a los pacientes" do
    post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } }
    assert_redirected_to codigo_login_url

    post codigo_login_url, params: { codigo: codigo_otp(osteopaths(:paco)) }
    assert_redirected_to root_url
    follow_redirect!
    follow_redirect!
    assert_response :success
    assert_select "h1", "Mostrar pacientes"
    assert_select "nav a[href=?]", cuenta_path, "Paco Martínez"
  end

  test "login con clave incorrecta muestra un error" do
    post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "incorrecta" } }
    assert_response :unprocessable_content
    assert_select ".alert-danger"
  end

  test "un login fallido calcula la clave las mismas veces tenga o no la cuenta el segundo factor, y exista o no (D104)" do
    # Calcular la clave (bcrypt) es lo que más tarda: si unos intentos lo hicieran más veces que otros, el
    # tiempo de respuesta diría qué emails tienen cuenta.
    Osteopath.create!(nombre: "Ana", apellidos: "Ruiz", email: "ana@example.com", password: "secreto-largo",
                      confirmed_at: Time.current)
    Osteopath.create!(nombre: "Eva", apellidos: "Gil", email: "eva@example.com", password: "secreto-largo")

    calculos = 0
    original = BCrypt::Engine.method(:hash_secret)
    sustituir(BCrypt::Engine, :hash_secret, ->(*argumentos) { calculos += 1; original.call(*argumentos) }) do
      calculos_al_entrar = lambda do |email, clave|
        reset!
        Rails.cache.clear # son más intentos que el límite por IP
        calculos = 0
        post osteopath_session_url, params: { osteopath: { email: email, password: clave } }
        calculos
      end

      sin_cuenta = calculos_al_entrar.("nadie@example.com", "incorrecta-larga")
      assert_operator sin_cuenta, :>=, 1
      # Con segundo factor, sin él y sin confirmar el email.
      %w[paco@example.com ana@example.com eva@example.com].each do |email|
        assert_equal sin_cuenta, calculos_al_entrar.(email, "incorrecta-larga"), email
      end
      # Sin clave, no se calcula en ningún caso.
      %w[nadie@example.com paco@example.com ana@example.com].each do |email|
        assert_equal 0, calculos_al_entrar.(email, ""), "#{email} sin clave"
      end
      # Con la clave buena, una vez: se pasa al código del segundo factor, o se entra.
      assert_equal 1, calculos_al_entrar.("paco@example.com", "demo-123456")
      assert_redirected_to codigo_login_url
      assert_equal 1, calculos_al_entrar.("ana@example.com", "secreto-largo")
      assert_redirected_to root_url
    end
  end

  test "la página de registro tiene los campos y los botones Guardar y Cancelar" do
    get new_osteopath_registration_url
    assert_response :success
    %w[nombre apellidos email password password_confirmation].each do |campo|
      assert_select "[name='osteopath[#{campo}]']"
    end
    assert_select ".form-text", "Al menos debe contener 10 caracteres."
    assert_select "input[type=submit][value=Guardar]"
    assert_select "a[href=?]", new_osteopath_session_path, text: "Cancelar"
  end

  test "registro con datos válidos crea el osteópata sin iniciar sesión y le envía el enlace para confirmar el email (D103)" do
    assert_difference [ "Osteopath.count", "ActionMailer::Base.deliveries.size" ], 1 do
      post osteopath_registration_url, params: { osteopath: {
        nombre: "Ana", apellidos: "Ruiz Gómez", email: "ana@example.com",
        password: "secreto-largo", password_confirmation: "secreto-largo"
      } }
    end
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert", /Te hemos enviado un correo con un enlace para confirmar tu email/
    assert_not Osteopath.find_by!(email: "ana@example.com").confirmed?
    assert_equal [ "ana@example.com" ], ActionMailer::Base.deliveries.last.to

    get patients_url
    assert_redirected_to new_osteopath_session_url, "sin confirmar el email no hay sesión"
  end

  test "registro con datos inválidos muestra los errores sin crear nada" do
    assert_no_difference "Osteopath.count" do
      post osteopath_registration_url, params: { osteopath: {
        nombre: "", apellidos: "", email: "paco@example.com", password: "123", password_confirmation: "321"
      } }
    end
    assert_response :unprocessable_content
    assert_select "#errores li", 5
    %w[nombre apellidos email password password_confirmation].each do |campo|
      assert_select "[name='osteopath[#{campo}]'].is-invalid"
    end
  end

  test "logout cierra la sesión y vuelve al login" do
    sign_in osteopaths(:paco)
    delete destroy_osteopath_session_url
    assert_redirected_to new_osteopath_session_url

    get patients_url
    assert_redirected_to new_osteopath_session_url
  end

  test "tras 10 intentos de login en 3 minutos se rechazan los siguientes, hasta que pasa ese tiempo" do
    10.times do
      post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "incorrecta" } }
      assert_response :unprocessable_content
    end

    post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } }
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert-danger", "Demasiados intentos de inicio de sesión. Espera unos minutos."

    travel 4.minutes do
      post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } }
      assert_redirected_to codigo_login_url
    end
  end

  test "tras 20 intentos de login de una cuenta en 15 minutos se rechazan los siguientes, desde cualquier IP (D92)" do
    20.times do |i|
      post osteopath_session_url, params: { osteopath: { email: "Paco@example.com", password: "incorrecta" } },
                                  env: { "REMOTE_ADDR" => "10.0.0.#{i + 1}" }
      assert_response :unprocessable_content
    end

    post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } },
                                env: { "REMOTE_ADDR" => "10.0.1.1" }
    assert_redirected_to new_osteopath_session_url
    follow_redirect!
    assert_select ".alert-danger", "Demasiados intentos de inicio de sesión en esta cuenta. Espera unos minutos."

    post osteopath_session_url, params: { osteopath: { email: "maria_campos@example.com", password: "demo-123456" } },
                                env: { "REMOTE_ADDR" => "10.0.1.2" }
    assert_redirected_to codigo_login_url, "las demás cuentas no se ven afectadas"

    travel 16.minutes do
      post osteopath_session_url, params: { osteopath: { email: "paco@example.com", password: "demo-123456" } },
                                  env: { "REMOTE_ADDR" => "10.0.1.3" }
      assert_redirected_to codigo_login_url
    end
  end

  test "tras 5 registros en una hora desde la misma conexión se rechazan los siguientes" do
    5.times do
      post osteopath_registration_url, params: { osteopath: { nombre: "", apellidos: "", email: "x@example.com",
                                                              password: "demo-123456", password_confirmation: "demo-123456" } }
      assert_response :unprocessable_content
    end

    assert_no_difference "Osteopath.count" do
      post osteopath_registration_url, params: { osteopath: {
        nombre: "Ana", apellidos: "Ruiz", email: "ana@example.com", password: "secreto-largo", password_confirmation: "secreto-largo"
      } }
    end
    assert_redirected_to new_osteopath_registration_url
    follow_redirect!
    assert_select ".alert-danger", "Demasiados registros desde esta conexión. Inténtalo más tarde."
  end

  test "la sesión caduca tras 30 minutos sin actividad" do
    sign_in osteopaths(:paco)
    get patients_url
    assert_response :success

    travel 29.minutes do
      get patients_url
      assert_response :success, "con actividad reciente la sesión sigue abierta"
    end

    travel 60.minutes do
      # Devise cierra la sesión y vuelve a pedir la misma página, que ya exige login.
      get patients_url
      assert_redirected_to patients_url
      follow_redirect!
      assert_redirected_to new_osteopath_session_url
      follow_redirect!
      assert_select ".alert-danger", /sesión expiró/
    end
  end

  test "con sesión iniciada la navbar muestra el menú y el botón Logout" do
    sign_in osteopaths(:paco)
    get patients_url
    assert_select "nav .dropdown-toggle", "Pacientes"
    assert_select "nav form[action=?] button", destroy_osteopath_session_path, text: "Logout"
  end

  # --- Sesiones revocables (D99) ---------------------------------------------------------------

  COOKIE_DE_SESION = "_red_social_fisios_session".freeze

  test "al cerrar sesión, una copia de la cookie de sesión deja de valer" do
    sign_in osteopaths(:paco)
    get patients_url
    assert_response :success
    copia = cookies[COOKIE_DE_SESION]

    delete destroy_osteopath_session_url
    cookies[COOKIE_DE_SESION] = copia
    get patients_url
    assert_redirected_to new_osteopath_session_url
  end

  test "sin cerrar sesión, la copia de la cookie sigue valiendo (es la misma sesión)" do
    sign_in osteopaths(:paco)
    get patients_url
    copia = cookies[COOKIE_DE_SESION]
    get agenda_url
    cookies[COOKIE_DE_SESION] = copia
    get patients_url
    assert_response :success
  end

  test "que una sesión caduque por inactividad no cierra las demás" do
    sign_in osteopaths(:paco)
    get patients_url
    travel 60.minutes do
      get patients_url
      follow_redirect!
      assert_redirected_to new_osteopath_session_url
    end
    assert_nil osteopaths(:paco).reload.token_sesion
  end
end
