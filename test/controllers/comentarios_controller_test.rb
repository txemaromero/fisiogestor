require "test_helper"

class ComentariosControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:maria)
  end

  test "comenta un caso y sugiere técnicas del catálogo" do
    assert_difference -> { Comentario.count } => 1 do
      post caso_comentarios_url(casos(:caso_pepe)),
           params: { comentario: { texto: "Probaría hipopresivos.", treatment_ids: [ "", treatments(:hipopresivos).id.to_s ] } }
    end
    assert_redirected_to caso_url(casos(:caso_pepe), anchor: "comentarios")
    comentario = Comentario.order(:id).last
    assert_equal [ osteopaths(:maria), "Probaría hipopresivos.", [ treatments(:hipopresivos) ] ],
                 [ comentario.osteopath, comentario.texto, comentario.treatments.to_a ]
  end

  test "un comentario vacío vuelve al caso con el error y sin perder lo escrito" do
    assert_no_difference -> { Comentario.count } do
      post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: " " } }
    end
    assert_response :unprocessable_content
    assert_select "h1", "Hernia discal que no termina de mejorar"
    assert_select "#formulario-comentario #errores li", "Escribe un comentario o sugiere alguna técnica"
    assert_select "#comentarios article", 1, "el comentario fallido no aparece en la lista"
  end

  test "las técnicas que no existen se ignoran y no se pueden sugerir más de 10" do
    post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola", treatment_ids: [ "999999", "basura" ] } }
    assert_empty Comentario.order(:id).last.treatments

    tecnicas = Array.new(11) { |i| Treatment.create!(nombre: "Técnica #{i}") }
    assert_no_difference -> { Comentario.count } do
      post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { treatment_ids: tecnicas.map { |t| t.id.to_s } } }
    end
    assert_select "#errores li", "Técnicas sugeridas no pueden ser más de 10"
  end

  test "no se comentan los casos ocultos ni los de pacientes que ya no consienten" do
    casos(:caso_pepe).update!(oculto_at: Time.current)
    sign_in osteopaths(:paco) # el autor sí ve su caso oculto
    assert_no_difference -> { Comentario.count } do
      post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola" } }
    end
    assert_redirected_to caso_url(casos(:caso_pepe))

    casos(:caso_pepe).update!(oculto_at: nil)
    patients(:pepe).update!(consiente_compartir: false)
    assert_no_difference -> { Comentario.count } do
      post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola" } }
    end
    follow_redirect!
    assert_select ".alert", /no está visible para los demás osteópatas/
  end

  test "un caso que no se ve no se puede comentar (404)" do
    patients(:pepe).update!(consiente_compartir: false)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola" } }
    assert_response :not_found
  end

  test "cada uno borra solo sus comentarios" do
    sign_in osteopaths(:paco)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    assert_no_difference -> { Comentario.count } do
      delete comentario_url(comentarios(:comentario_maria))
    end
    assert_response :not_found

    sign_in osteopaths(:maria)
    assert_difference -> { Comentario.count } => -1 do
      delete comentario_url(comentarios(:comentario_maria))
    end
    assert_redirected_to caso_url(casos(:caso_pepe), anchor: "comentarios")
  end

  test "tras 20 comentarios en 10 minutos se rechazan los siguientes" do
    20.times { post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola" } } }
    assert_no_difference -> { Comentario.count } do
      post caso_comentarios_url(casos(:caso_pepe)), params: { comentario: { texto: "Hola" } }
    end
    assert_redirected_to casos_url
  end
end
