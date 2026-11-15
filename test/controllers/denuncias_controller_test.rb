require "test_helper"

class DenunciasControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:maria)
  end

  test "denuncia un caso de otro osteópata con un motivo" do
    assert_difference -> { Denuncia.count } => 1 do
      post denuncia_caso_url(casos(:caso_pepe)), params: { denuncia: { motivo: "Da la profesión del paciente" } }
    end
    assert_redirected_to caso_url(casos(:caso_pepe))
    follow_redirect!
    assert_select ".alert", "Gracias: un administrador revisará la denuncia."
    denuncia = Denuncia.order(:id).last
    assert_equal [ osteopaths(:maria), casos(:caso_pepe), "Da la profesión del paciente", nil ],
                 [ denuncia.osteopath, denuncia.denunciable, denuncia.motivo, denuncia.resuelta_at ]
  end

  test "denuncia un comentario de otro osteópata" do
    sign_in osteopaths(:paco)
    assert_difference -> { comentarios(:comentario_maria).denuncias.count } => 1 do
      post denuncia_comentario_url(comentarios(:comentario_maria)), params: { denuncia: { motivo: "Es publicidad" } }
    end
    assert_redirected_to caso_url(casos(:caso_pepe))
  end

  test "no se denuncia sin motivo, dos veces, ni lo propio" do
    post denuncia_caso_url(casos(:caso_pepe)), params: { denuncia: { motivo: "Motivo" } }
    assert_no_difference -> { Denuncia.count } do
      post denuncia_caso_url(casos(:caso_pepe)), params: { denuncia: { motivo: "Otra vez" } }
      follow_redirect!
      assert_select ".alert", "No se ha enviado la denuncia: Ya has denunciado este contenido."

      post denuncia_comentario_url(comentarios(:comentario_maria)), params: { denuncia: { motivo: "Mío" } }
      follow_redirect!
      assert_select ".alert", /No puedes denunciar lo que has escrito tú/

      sign_in osteopaths(:paco)
      post denuncia_comentario_url(comentarios(:comentario_maria)), params: { denuncia: { motivo: "" } }
      follow_redirect!
      assert_select ".alert", "No se ha enviado la denuncia: Motivo no puede estar en blanco."
    end
  end

  test "lo que no se ve no se puede denunciar (404)" do
    patients(:pepe).update!(consiente_compartir: false)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    post denuncia_caso_url(casos(:caso_pepe)), params: { denuncia: { motivo: "Motivo" } }
    assert_response :not_found
    post denuncia_comentario_url(comentarios(:comentario_maria)), params: { denuncia: { motivo: "Motivo" } }
    assert_response :not_found
  end
end
