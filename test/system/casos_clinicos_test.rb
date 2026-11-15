require "application_system_test_case"

class CasosClinicosTest < ApplicationSystemTestCase
  test "publicar un caso, comentarlo sugiriendo una técnica, denunciarlo y moderarlo" do
    # Paco publica el diagnóstico de Juan como caso clínico.
    sign_in osteopaths(:paco)
    visit visit_path(visits(:visita_juan))
    click_on "Publicar como caso clínico"
    assert_selector "#datos-caso", text: "Hombre, 45–49 años"
    fill_in "Título", with: "Lumbago tras un esfuerzo"
    fill_in "Resumen", with: "Mejora rápida en dos sesiones. ¿Lo habríais tratado igual?"
    check "Confirmo que el título y el resumen no identifican al paciente"
    click_button "Publicar"
    assert_text "Caso clínico publicado."
    caso = Caso.find_by!(titulo: "Lumbago tras un esfuerzo")

    # Maria lo encuentra en la lista, lo comenta sugiriendo una técnica y lo denuncia.
    sign_in osteopaths(:maria)
    visit casos_path
    click_on "Lumbago tras un esfuerzo"
    assert_selector "#sesiones-caso tbody tr", count: 2
    fill_in "Tu opinión", with: "Yo habría añadido hipopresivos."
    select "Hipopresivos", from: "Técnicas que sugieres (opcional)"
    click_button "Publicar comentario"
    assert_text "Comentario publicado."
    within("#tecnicas-sugeridas") { assert_text "Hipopresivos · 1 vez" }

    find("summary[aria-label='Denunciar este caso']").click
    fill_in "¿Por qué lo denuncias?", with: "Creo que da demasiados detalles"
    click_button "Enviar la denuncia"
    assert_text "Gracias: un administrador revisará la denuncia."

    # Paco, administrador, lo oculta desde la moderación.
    sign_in osteopaths(:paco)
    visit patients_path
    within("nav") do
      click_on "Administración"
      click_on "Moderación"
    end
    within("#denunciado_caso_#{caso.id}") do
      assert_text "Creo que da demasiados detalles"
      accept_confirm { click_button "Ocultar" }
    end
    assert_text "Contenido ocultado"
    assert caso.reload.oculto?

    sign_in osteopaths(:maria)
    visit casos_path
    assert_no_text "Lumbago tras un esfuerzo"
  end

  test "completar el perfil y quedar pendiente de verificación" do
    maria = osteopaths(:maria)
    maria.update!(numero_colegiado: nil)
    sign_in maria
    visit casos_path
    click_on "Completar mi perfil"
    fill_in "Número de colegiado", with: "46-11111"
    fill_in "Ciudad", with: "Valencia"
    click_button "Guardar"
    assert_text "Perfil guardado."
    within("#estado-verificacion") { assert_text "Pendiente de verificación" }

    visit casos_path
    assert_text "Tu número de colegiado (46-11111) está pendiente de verificación"
  end
end
