require "test_helper"

class SupplementaryTestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  # Los ficheros se abren en binario (en Windows, en modo texto se cortan o se alteran).
  def prueba_con_fichero(nombre = "informe.pdf", tipo = "application/pdf")
    prueba = visits(:visita_juan).supplementary_tests.new(tipo_prueba: "rx", resumen: "Rectificación lumbar")
    prueba.archivo.attach(io: file_fixture(nombre).open("rb"), filename: nombre, content_type: tipo)
    prueba.save!
    prueba
  end

  test "lista las pruebas complementarias de una visita propia" do
    get visit_supplementary_tests_url(visits(:visita_pepe))
    assert_response :success
    assert_select "#pruebas tbody tr", 1
    assert_select "#pruebas td", "IRM"
    assert_select "#pruebas td.escaneado .font-monospace", "irm_pepe_campos.pdf"
    assert_select "#pruebas td.escaneado", text: /sin fichero/ # prueba antigua, solo con el nombre
  end

  test "las pruebas con fichero se pueden ver y descargar" do
    prueba = prueba_con_fichero
    get visit_supplementary_tests_url(visits(:visita_juan))
    ruta = archivo_visit_supplementary_test_path(visits(:visita_juan), prueba)
    assert_select "#pruebas td.escaneado", text: /\(PDF, 698 Bytes\)/
    assert_select "a[href=?][target=_blank][data-turbo=false]", ruta, text: "Ver"
    assert_select "a[href=?][download][data-turbo=false]", "#{ruta}?descargar=1", text: "Descargar"
  end

  test "crea una prueba complementaria con su fichero escaneado" do
    visita = visits(:visita_juan)
    get new_visit_supplementary_test_url(visita)
    assert_response :success
    assert_select "select[name='supplementary_test[tipo_prueba]'] option[value=rx]", "RX"
    assert_select "input[type=file][name='supplementary_test[archivo]'][accept='application/pdf,image/jpeg,image/png']"
    assert_select "input[name='supplementary_test[escaneado]']", 0

    assert_difference -> { visita.supplementary_tests.count } => 1, -> { ActiveStorage::Blob.count } => 1 do
      post visit_supplementary_tests_url(visita), params: { supplementary_test: {
        tipo_prueba: "rx", resumen: "Rectificación lumbar", archivo: fixture_file_upload("radiografia.png", "image/png", true)
      } }
    end
    assert_redirected_to visit_supplementary_tests_url(visita)
    prueba = visita.supplementary_tests.order(:id).last
    assert_equal "radiografia.png", prueba.escaneado
    assert_equal file_fixture("radiografia.png").binread, prueba.archivo.download
  end

  test "una prueba sin fichero o con un fichero no admitido vuelve al formulario con errores" do
    assert_no_difference %w[SupplementaryTest.count ActiveStorage::Blob.count] do
      post visit_supplementary_tests_url(visits(:visita_juan)), params: { supplementary_test: { tipo_prueba: "rx" } }
    end
    assert_response :unprocessable_content
    assert_select "#errores li", "Resumen no puede estar en blanco"
    assert_select "#errores li", "Fichero escaneado no puede estar en blanco"

    assert_no_difference %w[SupplementaryTest.count ActiveStorage::Blob.count] do
      post visit_supplementary_tests_url(visits(:visita_juan)), params: { supplementary_test: {
        tipo_prueba: "rx", resumen: "x", archivo: fixture_file_upload("falso.pdf", "application/pdf", true)
      } }
    end
    assert_response :unprocessable_content
    assert_select "#errores li", "Fichero escaneado debe ser un PDF, JPG o PNG"
    assert_select "#ayuda-archivo", /vuelve a elegirlo/
  end

  test "el nombre del fichero no se puede escribir a mano" do
    post visit_supplementary_tests_url(visits(:visita_juan)), params: { supplementary_test: {
      tipo_prueba: "rx", resumen: "x", escaneado: "../../etc/passwd", archivo: fixture_file_upload("informe.pdf", "application/pdf", true)
    } }
    assert_equal "informe.pdf", SupplementaryTest.order(:id).last.escaneado
  end

  test "editar sin elegir otro fichero conserva el que tenía; elegir otro lo sustituye" do
    prueba = prueba_con_fichero
    visita = visits(:visita_juan)
    get edit_visit_supplementary_test_url(visita, prueba)
    assert_select "#ayuda-archivo", /Fichero actual: informe\.pdf/

    patch visit_supplementary_test_url(visita, prueba), params: { supplementary_test: { resumen: "Revisado" } }
    assert_redirected_to visit_supplementary_tests_url(visita)
    assert_equal [ "Revisado", "informe.pdf" ], [ prueba.reload.resumen, prueba.escaneado ]
    assert prueba.archivo.attached?

    patch visit_supplementary_test_url(visita, prueba),
          params: { supplementary_test: { archivo: fixture_file_upload("foto.jpg", "image/jpeg", true) } }
    assert_equal [ "foto.jpg", "image/jpeg" ], [ prueba.reload.escaneado, prueba.archivo.blob.content_type ]
  end

  test "a una prueba antigua se le puede subir ahora el fichero" do
    visita = visits(:visita_pepe)
    prueba = supplementary_tests(:irm_pepe)
    get edit_visit_supplementary_test_url(visita, prueba)
    assert_select "#ayuda-archivo", /solo con el nombre del fichero/

    patch visit_supplementary_test_url(visita, prueba),
          params: { supplementary_test: { archivo: fixture_file_upload("informe.pdf", "application/pdf", true) } }
    assert_redirected_to visit_supplementary_tests_url(visita)
    assert prueba.reload.archivo.attached?
  end

  test "el fichero se abre en el navegador o se descarga, sin caché" do
    prueba = prueba_con_fichero
    get archivo_visit_supplementary_test_url(visits(:visita_juan), prueba)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline; filename="informe\.pdf"/, response.headers["Content-Disposition"])
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal file_fixture("informe.pdf").binread, response.body
    # CSP propia de los ficheros: estilos inline para el visor del navegador y nada más (sin nonce).
    assert_equal "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; base-uri 'none'; " \
                 "form-action 'none'; frame-ancestors 'none'", response.headers["Content-Security-Policy"]

    get archivo_visit_supplementary_test_url(visits(:visita_juan), prueba, descargar: 1)
    assert_match(/\Aattachment; filename="informe\.pdf"/, response.headers["Content-Disposition"])
  end

  test "una prueba sin fichero no tiene nada que descargar" do
    get archivo_visit_supplementary_test_url(visits(:visita_pepe), supplementary_tests(:irm_pepe))
    assert_response :not_found
  end

  test "borrar la prueba borra su fichero" do
    prueba = prueba_con_fichero
    assert_difference -> { SupplementaryTest.count } => -1, -> { ActiveStorage::Blob.count } => -1 do
      delete visit_supplementary_test_url(visits(:visita_juan), prueba)
    end
  end

  test "edita y borra una prueba complementaria" do
    visita = visits(:visita_pepe)
    prueba = supplementary_tests(:irm_pepe)
    patch visit_supplementary_test_url(visita, prueba), params: { supplementary_test: { resumen: "Sin cambios" } }
    assert_redirected_to visit_supplementary_tests_url(visita)
    assert_equal "Sin cambios", prueba.reload.resumen

    assert_difference -> { SupplementaryTest.count } => -1 do
      delete visit_supplementary_test_url(visita, prueba)
    end
  end

  test "no se accede a las pruebas de una visita ajena" do
    get visit_supplementary_tests_url(visits(:visita_maria_perez))
    assert_response :not_found
  end

  test "el fichero de una prueba de otro osteópata no se puede descargar" do
    prueba = prueba_con_fichero
    sign_in osteopaths(:maria)
    get patients_url # sign_in vale para la siguiente petición: si es un 404, la sesión no llega a guardarse
    get archivo_visit_supplementary_test_url(visits(:visita_juan), prueba)
    assert_response :not_found
  end

  test "no hay rutas públicas de Active Storage para los ficheros" do
    prueba = prueba_con_fichero
    assert_raises(NoMethodError) { rails_blob_path(prueba.archivo) }
    get "/rails/active_storage/blobs/redirect/#{prueba.archivo.blob.signed_id}/informe.pdf"
    assert_response :not_found
  end

  test "unos parámetros con forma inesperada responden 400" do
    post visit_supplementary_tests_url(visits(:visita_juan)), params: { supplementary_test: "texto" }
    assert_response :bad_request
  end
end
