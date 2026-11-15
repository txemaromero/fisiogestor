require "test_helper"

# Perfil profesional (D87): «Mi cuenta», su edición y el perfil que ven los demás (/osteopatas/:id).
class PerfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:maria)
  end

  test "Mi cuenta muestra el perfil y el estado de la verificación" do
    get cuenta_url
    assert_select "#perfil-profesional dd", "46-05678"
    assert_select "#estado-verificacion", /Verificado el 2\/1\/2026/
    assert_select "#perfil-profesional a[href=?]", osteopata_path(osteopaths(:maria)), "Ver mi perfil"

    osteopaths(:maria).update!(numero_colegiado: nil)
    get cuenta_url
    assert_select "#estado-verificacion", /Sin número de colegiado/
  end

  test "edita el perfil" do
    get editar_perfil_url
    assert_select "#formulario-perfil input[name='osteopath[numero_colegiado]'][value='46-05678']"

    patch perfil_url, params: { osteopath: { especialidad: " Osteopatía  pediátrica ", ciudad: "Alicante",
                                             presentacion: "Hola", numero_colegiado: "46-05678" } }
    assert_redirected_to cuenta_url
    maria = osteopaths(:maria).reload
    assert_equal [ "Osteopatía pediátrica", "Alicante", "Hola" ], [ maria.especialidad, maria.ciudad, maria.presentacion ]
    assert maria.verificado?
    follow_redirect!
    assert_select ".alert", "Perfil guardado."
  end

  test "cambiar el número de colegiado avisa de que hay que volver a verificarlo" do
    patch perfil_url, params: { osteopath: { numero_colegiado: "46-99999" } }
    assert_not osteopaths(:maria).reload.verificado?
    follow_redirect!
    assert_select ".alert", /un administrador tiene que volver a verificarlo/
  end

  test "con errores vuelve al formulario, y no se cambian otros datos de la cuenta" do
    patch perfil_url, params: { osteopath: { numero_colegiado: "<script>", admin: "1", email: "otro@example.com" } }
    assert_response :unprocessable_content
    assert_select "#errores li", /Número de colegiado solo puede tener/
    patch perfil_url, params: { osteopath: { ciudad: "Elche", admin: "1", email: "otro@example.com", verificado_at: nil } }
    maria = osteopaths(:maria).reload
    assert_equal [ false, "maria_campos@example.com", true ], [ maria.admin?, maria.email, maria.verificado? ]
  end

  test "el perfil de un osteópata verificado muestra sus datos y sus casos" do
    get osteopata_url(osteopaths(:paco))
    assert_response :success
    assert_select "h1", "Paco Martínez"
    assert_select ".badge", "✓ Colegiado verificado"
    assert_select "#perfil-osteopata dd", "Osteopatía estructural"
    assert_select "#casos-osteopata a[href=?]", caso_path(casos(:caso_pepe))
    assert_select "#perfil-osteopata a", text: "Editar mi perfil", count: 0
  end

  test "el perfil de alguien sin verificar no se ve (salvo el propio)" do
    ana = Osteopath.create!(nombre: "Ana", apellidos: "Ruiz", email: "ana@example.com", password: "demo-123456")
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get osteopata_url(ana)
    assert_response :not_found
  end

  test "no se puede poner el número de colegiado de otra cuenta (D95)" do
    patch perfil_url, params: { osteopath: { numero_colegiado: "28 01234" } }
    assert_response :unprocessable_content
    assert_select "#errores li", "Número de colegiado ya está en otra cuenta: si es el tuyo, avisa a un administrador"
    assert_equal "46-05678", osteopaths(:maria).reload.numero_colegiado
  end
end
