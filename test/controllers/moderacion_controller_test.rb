require "test_helper"

class ModeracionControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco) # administrador
  end

  def denunciar_caso
    Denuncia.create!(osteopath: osteopaths(:maria), denunciable: casos(:caso_pepe), motivo: "Da su profesión")
  end

  test "quien no es administrador no ve la moderación ni la verificación: 404" do
    sign_in osteopaths(:maria)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    [ moderacion_url, verificaciones_url ].each do |url|
      get url
      assert_response :not_found
    end
    post ocultar_moderacion_url("caso", casos(:caso_pepe))
    assert_response :not_found
    assert_not casos(:caso_pepe).reload.oculto?
  end

  test "la barra de navegación avisa de lo pendiente en Administración" do
    get patients_url
    assert_select "#pendientes-administracion", 0
    denunciar_caso
    osteopaths(:maria).update!(numero_colegiado: "46-00001") # pierde la verificación: pendiente
    get patients_url
    assert_select "#pendientes-administracion", "2"
    assert_select "nav a.dropdown-item[href=?]", moderacion_path, /Moderación \(1 por revisar\)/
    assert_select "nav a.dropdown-item[href=?]", verificaciones_path, /Profesionales \(1 por verificar\)/
  end

  test "lista las denuncias pendientes con el contenido y sus motivos" do
    denunciar_caso
    Denuncia.create!(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "Es publicidad")
    get moderacion_url
    assert_response :success
    assert_select "#denuncias-pendientes h2", "Denuncias pendientes (2)"
    assert_select "#denunciado_caso_#{casos(:caso_pepe).id}", /Hernia discal que no termina de mejorar/
    assert_select "#denunciado_caso_#{casos(:caso_pepe).id} li", /Maria Campos Gil.*Da su profesión/
    assert_select "#denunciado_comentario_#{comentarios(:comentario_maria).id}", /Comentario en «Hernia discal/
    assert_select "#denunciado_comentario_#{comentarios(:comentario_maria).id}", /Yo añadiría estiramientos/
  end

  test "ocultar un contenido resuelve sus denuncias, y se puede volver a mostrar" do
    denunciar_caso
    post ocultar_moderacion_url("caso", casos(:caso_pepe))
    assert_redirected_to moderacion_url
    assert casos(:caso_pepe).reload.oculto?
    assert_empty Denuncia.pendientes

    follow_redirect!
    assert_select "#denuncias-pendientes", /No hay denuncias pendientes/
    assert_select "#oculto_caso_#{casos(:caso_pepe).id}", /Hernia discal/
    assert_select "#denuncias-resueltas td", "Contenido ocultado"

    post mostrar_moderacion_url("caso", casos(:caso_pepe))
    assert_not casos(:caso_pepe).reload.oculto?
  end

  test "descartar las denuncias deja el contenido visible" do
    Denuncia.create!(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "No me gusta")
    post descartar_moderacion_url("comentario", comentarios(:comentario_maria))
    assert_not comentarios(:comentario_maria).reload.oculto?
    assert_equal "descartado", comentarios(:comentario_maria).denuncias.sole.resultado
  end

  test "un tipo de contenido desconocido no existe" do
    post "/moderacion/paciente/#{patients(:juan).id}/ocultar"
    assert_response :not_found
  end

  # --- Casos retirados y contenido borrado (D96, D97) -----------------------------------------

  test "de un caso retirado (sin consentimiento) no se enseña el contenido, tampoco a los administradores" do
    denunciar_caso
    Denuncia.create!(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "Spam")
    patients(:pepe).update!(consiente_compartir: false)
    get moderacion_url
    assert_select "#denunciado_caso_#{casos(:caso_pepe).id}", /No disponible: el paciente retiró el consentimiento/
    assert_select "#denunciado_caso_#{casos(:caso_pepe).id}", text: /Hernia discal que no termina/, count: 0
    assert_select "#denunciado_comentario_#{comentarios(:comentario_maria).id}", text: /Yo añadiría/, count: 0
    assert_select "#denunciado_caso_#{casos(:caso_pepe).id} form[action=?]", ocultar_moderacion_path("caso", casos(:caso_pepe))
  end

  test "si el autor borra lo denunciado, la denuncia queda en las resueltas como contenido borrado" do
    denunciar_caso
    casos(:caso_pepe).destroy
    get moderacion_url
    assert_select "#denuncias-pendientes", /No hay denuncias pendientes/
    assert_select "#denuncias-resueltas td", "Caso borrado (de Paco Martínez)"
    assert_select "#denuncias-resueltas td", "Contenido borrado"
  end
end
