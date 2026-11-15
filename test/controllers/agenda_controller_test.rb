require "test_helper"

class AgendaControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  test "lista las sesiones propias de hoy en adelante, agrupadas por día" do
    hoy = diagnoses(:diag_juan).sessions.create!(fecha: Date.current)
    hoy.treatments << treatments(:masaje)
    manana = diagnoses(:diag_pepe).sessions.create!(fecha: Date.current + 1)
    diagnoses(:diag_juan).sessions.create!(fecha: Date.current + 9)
    diagnoses(:diag_juan).sessions.create!(fecha: Date.current - 1)          # pasada: no sale
    diagnoses(:diag_maria_perez).sessions.create!(fecha: Date.current + 1)   # de otro osteópata: no sale

    get agenda_url
    assert_response :success
    assert_select "section[id^=dia-]", 3
    assert_select "#dia-#{Date.current.iso8601} h2", /\AHoy, /
    assert_select "#dia-#{(Date.current + 1).iso8601} h2", /\AMañana, /
    assert_select "#dia-#{(Date.current + 1).iso8601} tbody tr", 1
    assert_select "#session_#{hoy.id} a[href=?]", patient_path(patients(:juan)), text: "Juan Martínez Campos"
    assert_select "#session_#{hoy.id} td", "Masaje espalda"
    assert_select "#session_#{hoy.id} td", /4 de 3 sesiones recomendadas · 1 programada/ # 2 de los fixtures, ayer y hoy
    assert_select "#session_#{manana.id} a[href=?]", visit_path(visits(:visita_pepe)), text: "Ver"
    assert_select "#session_#{manana.id} a[href=?]", edit_sesion_path(manana), text: "Editar"
    assert_select "tr", text: /Pérez Gil/, count: 0
  end

  test "sin sesiones programadas muestra un aviso" do
    get agenda_url
    assert_select "section[id^=dia-]", 0
    assert_select ".alert", /No hay sesiones programadas a partir de hoy/
  end

  test "la barra de navegación enlaza a la agenda y la marca como activa" do
    get agenda_url
    assert_select "nav a.nav-link.active[href=?]", agenda_path, text: "Agenda"
  end
end
