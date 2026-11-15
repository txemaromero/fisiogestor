require "test_helper"

class VerificacionesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco) # administrador
  end

  def nuevo_osteopata(**atributos)
    Osteopath.create!({ nombre: "Ana", apellidos: "Ruiz", email: "ana@example.com", password: "demo-123456" }.merge(atributos))
  end

  test "lista los pendientes (con número de colegiado) y los verificados" do
    ana = nuevo_osteopata(numero_colegiado: "08-12345", ciudad: "Barcelona")
    nuevo_osteopata(email: "luis@example.com", nombre: "Luis")
    get verificaciones_url
    assert_response :success
    assert_select "#pendientes h2", "Pendientes (1)"
    assert_select "#pendiente_osteopath_#{ana.id} td", "08-12345"
    assert_select "#pendiente_osteopath_#{ana.id} form[action=?] button", verificacion_path(ana), "Verificar"
    assert_select "#sin-numero", /1 osteópata no ha escrito/
    assert_select "#verificados h2", "Verificados (2)"
  end

  test "verificar y quitar la verificación" do
    ana = nuevo_osteopata(numero_colegiado: "08-12345")
    post verificacion_url(ana)
    assert_redirected_to verificaciones_url
    assert ana.reload.verificado?

    delete verificacion_url(ana)
    assert_not ana.reload.verificado?
    follow_redirect!
    assert_select ".alert", "Ana Ruiz ya no está verificado: no verá lo de otros osteópatas."
  end

  test "no se verifica a quien no tiene número de colegiado" do
    ana = nuevo_osteopata
    post verificacion_url(ana)
    assert_not ana.reload.verificado?
    follow_redirect!
    assert_select ".alert", "Ana Ruiz no tiene número de colegiado en su perfil."
  end

  test "se guarda y se muestra quién verificó a cada uno (D95)" do
    ana = nuevo_osteopata(numero_colegiado: "08-12345")
    post verificacion_url(ana)
    assert_equal osteopaths(:paco), ana.reload.verificado_por
    get verificaciones_url
    assert_select "#verificado_osteopath_#{ana.id}", /por Paco Martínez/
    assert_select "#verificado_osteopath_#{osteopaths(:maria).id}", /por la consola del servidor/
    assert_select "p.text-body-secondary", /nombre y los apellidos/
  end
end
