require "test_helper"

# Todas las páginas de la aplicación, salvo las de Devise, exigen haber iniciado sesión.
class AccesoTest < ActionDispatch::IntegrationTest
  test "sin sesión, todas las páginas redirigen al login" do
    visita = visits(:visita_pepe)
    paciente = patients(:juan)
    rutas = {
      get: [ patients_path, new_patient_path, patient_path(paciente), edit_patient_path(paciente),
             medical_background_patient_path(paciente), crear_visita_path, visit_path(visita),
             visit_examination_path(visita), new_visit_examination_path(visita),
             visit_supplementary_tests_path(visita), new_visit_supplementary_test_path(visita),
             filtrar_tratamientos_path, tecnicas_aplicadas_path(ids: [ treatments(:masaje).id ]), informes_path ],
      post: [ patients_path, crear_visita_path, visit_examination_path(visita), visit_supplementary_tests_path(visita) ],
      patch: [ patient_path(paciente), visit_examination_path(visita) ],
      delete: [ patient_path(paciente), visit_examination_path(visita),
                visit_supplementary_test_path(visita, supplementary_tests(:irm_pepe)) ]
    }

    rutas.each do |metodo, urls|
      urls.each do |url|
        public_send(metodo, url)
        assert_redirected_to new_osteopath_session_url, "#{metodo.upcase} #{url} debería exigir login"
      end
    end
  end

  test "sin sesión no se modifica nada" do
    assert_no_difference %w[Patient.count Visit.count] do
      post patients_path, params: { patient: { nombre: "X", apellidos: "Y", anyo_nacimiento: 2000, sexo: "mujer" } }
      delete patient_path(patients(:juan))
    end
  end

  test "las páginas de login, registro y confirmación del email son públicas" do
    get new_osteopath_session_path
    assert_response :success
    get new_osteopath_registration_path
    assert_response :success
    get new_osteopath_confirmation_path
    assert_response :success
  end
end
