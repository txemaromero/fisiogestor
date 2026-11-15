require "test_helper"

class CatalogoControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco) # administrador del catálogo
  end

  test "un osteópata que no es administrador no ve el catálogo: todo responde 404" do
    sign_in osteopaths(:maria)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    assert_select "nav a", text: "Catálogo", count: 0
    assert_select "nav .dropdown-toggle", text: /Administración/, count: 0

    get catalogo_url
    assert_response :not_found
    get edit_catalogo_tecnica_url(treatments(:masaje))
    assert_response :not_found
    patch catalogo_tecnica_url(treatments(:masaje)), params: { treatment: { nombre: "Otro" } }
    assert_response :not_found
    get fusion_catalogo_enfermedad_url(diseases(:lumbago))
    assert_response :not_found
    assert_no_difference -> { Treatment.count } do
      post fusionar_catalogo_tecnica_url(treatments(:masaje)), params: { destino_id: treatments(:estiramiento).id }
      delete catalogo_tecnica_url(treatments(:descompresion))
    end
    assert_equal "Masaje espalda", treatments(:masaje).reload.nombre
  end

  test "el administrador ve las técnicas y enfermedades con sus usos, los posibles duplicados y las fusiones" do
    Treatment.create!(nombre: "Masaje de espalda")
    get catalogo_url
    assert_response :success
    assert_select "nav .dropdown-toggle.active", text: /Administración/
    assert_select "nav a.dropdown-item[href=?]", catalogo_path, text: "Catálogo"
    assert_select "#tecnicas h2 .badge", Treatment.count.to_s
    assert_select "#enfermedades h2 .badge", Disease.count.to_s
    assert_select "#tecnicas-#{treatments(:masaje).id} td.text-end", "3" # juan_1, juan_2 y maria_perez_1
    assert_select "#tecnicas-#{treatments(:masaje).id}", /Posible duplicado de «Masaje de espalda»/
    assert_select "#enfermedades-#{diseases(:lumbago).id} td.text-end", "2"
    # Solo se pueden borrar las que no se usan.
    assert_select "#tecnicas-#{treatments(:descompresion).id} form[action=?] button", catalogo_tecnica_path(treatments(:descompresion)), text: "Borrar"
    assert_select "#tecnicas-#{treatments(:masaje).id} button", text: "Borrar", count: 0
    assert_select "#fusiones", /Todavía no se ha fusionado ninguna entrada/
  end

  test "edita el nombre y la descripción de una técnica" do
    get edit_catalogo_tecnica_url(treatments(:masaje))
    assert_select "input[name='treatment[nombre]'][value=?]", "Masaje espalda"

    patch catalogo_tecnica_url(treatments(:masaje)), params: { treatment: { nombre: "Masaje de espalda", descripcion: "Nueva" } }
    assert_redirected_to catalogo_url(anchor: "tecnicas")
    assert_equal [ "Masaje de espalda", "Nueva" ], [ treatments(:masaje).reload.nombre, treatments(:masaje).descripcion ]
  end

  test "un nombre repetido no se guarda" do
    patch catalogo_tecnica_url(treatments(:masaje)), params: { treatment: { nombre: "HIPOPRESIVOS" } }
    assert_response :unprocessable_content
    assert_select "#errores", /Nombre técnica ya está en uso/
  end

  test "una enfermedad necesita descripción" do
    patch catalogo_enfermedad_url(diseases(:lumbago)), params: { disease: { descripcion: "" } }
    assert_response :unprocessable_content
    assert_select "#errores", /Descripción no puede estar en blanco/
  end

  test "fusiona una técnica duplicada con la buena y lo registra" do
    duplicada = Treatment.create!(nombre: "Masaje de espalda")
    sessions(:pepe_1).treatments << duplicada

    get fusion_catalogo_tecnica_url(duplicada)
    assert_select "h1", "Fusionar «Masaje de espalda»"
    assert_select "p", /Se usa en 1 sesión/
    assert_select "select[name=destino_id] option[value=?]", treatments(:masaje).id.to_s, text: "Masaje espalda"
    assert_select "select[name=destino_id] option[value=?]", duplicada.id.to_s, count: 0
    assert_select "form[data-turbo-confirm]"

    post fusionar_catalogo_tecnica_url(duplicada), params: { destino_id: treatments(:masaje).id }
    assert_redirected_to catalogo_url(anchor: "tecnicas")
    follow_redirect!
    assert_select ".alert", "«Masaje de espalda» se ha fusionado con «Masaje espalda»: 1 sesión pasa a usar «Masaje espalda»."
    assert_select "#fusiones td", "«Masaje de espalda» → «Masaje espalda»"
    assert_select "#fusiones td", "Paco Martínez"
    assert_not Treatment.exists?(duplicada.id)
    assert_includes sessions(:pepe_1).reload.treatments, treatments(:masaje)
  end

  test "fusiona una enfermedad y sus diagnósticos pasan a la elegida" do
    lumbalgia = Disease.create!(nombre: "Lumbalgia", descripcion: "Dolor lumbar.")
    diagnoses(:diag_pepe).update!(disease: lumbalgia)
    post fusionar_catalogo_enfermedad_url(lumbalgia), params: { destino_id: diseases(:lumbago).id }
    follow_redirect!
    assert_select ".alert", /1 diagnóstico pasa a usar «Lumbago»/
    assert_equal diseases(:lumbago), diagnoses(:diag_pepe).reload.disease
  end

  test "sin destino, o con la misma entrada como destino, no se fusiona nada" do
    assert_no_difference %w[Treatment.count FusionCatalogo.count] do
      post fusionar_catalogo_tecnica_url(treatments(:masaje)), params: { destino_id: "" }
      assert_redirected_to fusion_catalogo_tecnica_url(treatments(:masaje))
      post fusionar_catalogo_tecnica_url(treatments(:masaje)), params: { destino_id: treatments(:masaje).id }
      assert_redirected_to fusion_catalogo_tecnica_url(treatments(:masaje))
      post fusionar_catalogo_tecnica_url(treatments(:masaje)), params: { destino_id: diseases(:lumbago).id + 1000 }
    end
    follow_redirect!
    assert_select ".alert", "Elige con qué entrada fusionarla."
  end

  test "borra una técnica que no se usa, pero no una que se usa" do
    assert_difference -> { Treatment.count } => -1 do
      delete catalogo_tecnica_url(treatments(:descompresion))
    end
    assert_redirected_to catalogo_url(anchor: "tecnicas")

    assert_no_difference -> { Treatment.count } do
      delete catalogo_tecnica_url(treatments(:masaje))
    end
    follow_redirect!
    assert_select ".alert", /no se puede borrar porque se usa/
  end

  test "nadie se hace administrador al registrarse" do
    sign_out :osteopath # con sesión iniciada, Devise no deja registrarse
    post osteopath_registration_url, params: { osteopath: {
      nombre: "Eva", apellidos: "Ruiz", email: "eva@example.com", password: "clave-segura",
      password_confirmation: "clave-segura", admin: "1"
    } }
    assert_not Osteopath.find_by(email: "eva@example.com").admin?
  end
end
