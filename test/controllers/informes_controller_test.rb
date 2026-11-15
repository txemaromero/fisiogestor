require "test_helper"

class InformesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in osteopaths(:paco)
  end

  def filas_informe
    css_select("#tabla-informe tbody tr").map { |fila| fila.css("td").map { |celda| celda.text.strip } }
  end

  test "muestra el selector de tipo de informe y el botón Generar" do
    get informes_url
    assert_response :success
    assert_select "h1", "Generar informe"
    assert_select "select[name=tipo] option", InformesController::TIPOS.size + 1
    assert_select "#controles-cuadro-clinico[hidden]"
    assert_select "#controles-cuadro-clinico select[disabled]", 2
    assert_select "input[type=submit][value=Generar]"
    assert_select "#resultado-informe", 0
  end

  test "informe de técnicas realizadas con mayor frecuencia" do
    get informes_url, params: { tipo: "mas_frecuentes" }
    assert_select "#resultado-informe h2", "Técnicas realizadas con mayor frecuencia"
    assert_equal [ "1", "Estiramiento columna", "3" ], filas_informe.first
    assert_equal 4, filas_informe.size
  end

  test "informe de técnicas más efectivas, con la reducción media y el número de sesiones" do
    get informes_url, params: { tipo: "mas_efectivas" }
    # En los fixtures todas las técnicas tienen menos de 5 sesiones: todas salen como poco fiables.
    assert_equal [ [ "1", "Manipulación lumbar", "4,50", "2", "⚠ Pocas sesiones" ],
                   [ "2", "Masaje espalda", "2,67", "3", "⚠ Pocas sesiones" ],
                   [ "3", "Estiramiento columna", "1,33", "3", "⚠ Pocas sesiones" ],
                   [ "4", "Hipopresivos", "1,00", "1", "⚠ Pocas sesiones" ] ], filas_informe
  end

  test "informe de técnicas menos efectivas" do
    get informes_url, params: { tipo: "menos_efectivas" }
    assert_equal [ "1", "Hipopresivos", "1,00", "1", "⚠ Pocas sesiones" ], filas_informe.first
    assert_equal "Manipulación lumbar", filas_informe.last[1]
  end

  test "informe de técnicas para un cuadro clínico con filtros opcionales" do
    get informes_url, params: { tipo: "cuadro_clinico", disease_id: diseases(:lumbago).id, sexo: "hombre",
                                edad_min: "", edad_max: "" }
    assert_select "#controles-cuadro-clinico:not([hidden])"
    assert_select "#resultado-informe p", /Lumbago/
    assert_equal [ "Manipulación lumbar", "Masaje espalda", "Estiramiento columna" ], filas_informe.map(&:second)
  end

  test "el cuadro clínico sin enfermedad muestra un aviso" do
    get informes_url, params: { tipo: "cuadro_clinico" }
    assert_select ".alert-danger", "Elige la enfermedad del cuadro clínico."
    assert_select "#resultado-informe", 0
  end

  test "un informe sin datos muestra un aviso" do
    get informes_url, params: { tipo: "cuadro_clinico", disease_id: diseases(:miopia).id }
    assert_select ".alert-secondary", "No hay datos para este informe."
  end

  test "parámetros con forma inesperada no provocan errores" do
    get informes_url, params: { tipo: "cuadro_clinico", disease_id: diseases(:lumbago).id, sexo: { a: "b" },
                                edad_min: { a: "b" } }
    assert_response :success
    assert_equal 4, filas_informe.size # sexo y edad se ignoran: todas las técnicas del lumbago

    get informes_url, params: { tipo: { a: "b" }, disease_id: [ "1" ] }
    assert_response :success
    assert_select "#resultado-informe", 0
  end

  test "un tipo desconocido no genera nada" do
    get informes_url, params: { tipo: "inventado" }
    assert_response :success
    assert_select "#resultado-informe", 0
  end

  # --- Filtros por fechas y por pacientes propios (D78) ------------------------------------------

  def lineas_csv
    response.body.force_encoding("UTF-8").delete_prefix("﻿").split("\r\n")
  end

  test "el formulario tiene los filtros de pacientes y fechas, comunes a todos los informes" do
    get informes_url
    assert_select "select[name=ambito] option", 2
    assert_select "select[name=ambito] option[selected][value=plataforma]", "Toda la plataforma"
    assert_select "input[type=date][name=desde]"
    assert_select "input[type=date][name=hasta]"
  end

  test "las fechas limitan las sesiones que cuentan" do
    # Sesiones de marzo de 2026 en los fixtures: juan_1 (12/3) y juan_2 (19/3).
    get informes_url, params: { tipo: "mas_frecuentes", desde: "2026-03-01", hasta: "2026-03-31" }
    assert_equal [ [ "1", "Masaje espalda", "2" ], [ "2", "Estiramiento columna", "1" ], [ "3", "Manipulación lumbar", "1" ] ],
                 filas_informe
    assert_select "#filtros-informe", "Toda la plataforma · del 1/3/2026 al 31/3/2026"
    assert_select "input[name=desde][value='2026-03-01']"

    get informes_url, params: { tipo: "mas_frecuentes", desde: "2026-06-01" }
    assert_equal [ [ "1", "Estiramiento columna", "1" ] ], filas_informe # antonio_1 (4/6)
    assert_select "#filtros-informe", "Toda la plataforma · desde el 1/6/2026"
  end

  test "«Mis pacientes» solo cuenta las sesiones de los pacientes propios" do
    get informes_url, params: { tipo: "mas_efectivas", ambito: "mios" }
    assert_equal [ "Manipulación lumbar", "Masaje espalda", "Estiramiento columna" ], filas_informe.map(&:second)
    assert_select "#filtros-informe", "Mis pacientes"
    # El masaje de Maria (maria_perez_1, 7 -> 6) ya no cuenta: Masaje espalda pasa de 2,67 a 3,50.
    assert_equal [ "2", "Masaje espalda", "3,50", "2", "⚠ Pocas sesiones" ], filas_informe.second
  end

  test "el cuadro clínico también admite los filtros comunes" do
    get informes_url, params: { tipo: "cuadro_clinico", disease_id: diseases(:lumbago).id, ambito: "mios",
                                desde: "2026-03-15" }
    assert_equal [ [ "1", "Manipulación lumbar", "4,00", "1", "⚠ Pocas sesiones" ],
                   [ "2", "Masaje espalda", "4,00", "1", "⚠ Pocas sesiones" ] ], filas_informe
  end

  test "una fecha «desde» posterior a «hasta» no genera el informe" do
    get informes_url, params: { tipo: "mas_frecuentes", desde: "2026-06-01", hasta: "2026-01-01" }
    assert_select ".alert-danger", "La fecha «desde» es posterior a la fecha «hasta»."
    assert_select "#resultado-informe", 0
  end

  test "las fechas mal escritas y los ámbitos desconocidos se ignoran" do
    get informes_url, params: { tipo: "mas_frecuentes", desde: "ayer", hasta: { a: 1 }, ambito: "todos" }
    assert_response :success
    assert_equal 4, filas_informe.size
    assert_select "#filtros-informe", "Toda la plataforma"
  end

  # --- Pocas sesiones y gráfica (D79) ----------------------------------------------------------

  test "una técnica con 5 sesiones o más no se marca como poco fiable" do
    3.times do |i|
      diagnoses(:diag_pepe).sessions.create!(fecha: Date.new(2026, 5, 26 + i), escala_dolor_pre_sesion: 6,
                                             escala_dolor_post_sesion: 4, treatments: [ treatments(:masaje) ])
    end
    get informes_url, params: { tipo: "mas_efectivas" }
    masaje = filas_informe.find { |fila| fila[1] == "Masaje espalda" }
    assert_equal [ "6", "" ], masaje.last(2)
    assert_select "#aviso-pocas-sesiones", /menos de 5 sesiones son poco fiables/
    assert_select ".grafica-barras path.barra-positiva:not(.barra-hueca)", 1
    assert_select ".grafica-barras path.barra-hueca", 3
  end

  test "la gráfica tiene una barra por técnica con su valor y la leyenda de efectividad" do
    get informes_url, params: { tipo: "mas_efectivas" }
    assert_select ".grafica-barras svg[role=img]"
    assert_select ".grafica-barras .fila-barra", 4
    assert_select ".grafica-barras .fila-barra title", "Manipulación lumbar: reducción media de 4,50 en 2 sesiones"
    assert_select ".grafica-barras text.valor-barra", "4,50"
    assert_select "#leyenda-grafica-informe li", 2 # sin medias negativas no sale «El dolor aumentó»

    get informes_url, params: { tipo: "mas_frecuentes" }
    assert_select ".grafica-barras .fila-barra", 4
    assert_select ".grafica-barras path.barra-hueca", 0
    assert_select "#leyenda-grafica-informe", 0
  end

  test "una reducción media negativa se dibuja en rojo" do
    diagnoses(:diag_pepe).sessions.create!(fecha: Date.new(2026, 6, 1), escala_dolor_pre_sesion: 3,
                                           escala_dolor_post_sesion: 7, treatments: [ treatments(:descompresion) ])
    get informes_url, params: { tipo: "menos_efectivas" }
    assert_equal [ "1", "Descompresión columna", "-4,00", "1", "⚠ Pocas sesiones" ], filas_informe.first
    assert_select ".grafica-barras path.barra-negativa", 1
    assert_select "#leyenda-grafica-informe li", 3
  end

  # --- CSV (D80) --------------------------------------------------------------------------------

  test "el informe se descarga en CSV con los mismos filtros" do
    get informes_url, params: { tipo: "mas_efectivas", ambito: "mios" }
    assert_select "a[href=?][data-turbo=false]", informes_path(format: :csv, tipo: "mas_efectivas", ambito: "mios"),
                  text: "Descargar CSV"

    get informes_url(format: :csv), params: { tipo: "mas_efectivas", ambito: "mios" }
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment; filename="informe-mas-efectivas-#{Date.current.iso8601}\.csv"/, response.headers["Content-Disposition"])
    assert_equal '"Posición";"Técnica";"Reducción media del dolor";"Nº de sesiones";"Pocas sesiones"', lineas_csv.first
    assert_equal '1;"Manipulación lumbar";4,50;2;"Sí"', lineas_csv.second
    assert_equal 4, lineas_csv.size
  end

  test "el CSV de frecuencia tiene sus propias columnas" do
    get informes_url(format: :csv), params: { tipo: "mas_frecuentes" }
    assert_equal '"Posición";"Técnica";"Sesiones en las que se aplicó"', lineas_csv.first
    assert_equal '1;"Estiramiento columna";3', lineas_csv.second
  end

  test "sin un informe válido no hay CSV" do
    get informes_url(format: :csv), params: { tipo: "cuadro_clinico" }
    assert_response :unprocessable_content
  end

  test "de los pacientes de otros osteópatas solo cuentan los que consienten; los propios, siempre (D83)" do
    patients(:juan).update!(consiente_compartir: false)
    get informes_url, params: { tipo: "mas_frecuentes" }
    assert_equal [ "1", "Estiramiento columna", "3" ], filas_informe.first

    # Para Maria ya no cuentan las dos sesiones de Juan.
    sign_in osteopaths(:maria)
    get informes_url, params: { tipo: "mas_frecuentes" }
    assert_equal [ [ "1", "Estiramiento columna", "2" ], [ "2", "Hipopresivos", "2" ],
                   [ "3", "Manipulación lumbar", "1" ], [ "4", "Masaje espalda", "1" ] ], filas_informe
  end

  test "el cuadro clínico tampoco cuenta los pacientes de otros que no consienten" do
    patients(:maria_perez).update!(consiente_compartir: false)
    get informes_url, params: { tipo: "cuadro_clinico", disease_id: diseases(:lumbago).id }
    assert_equal [ "Manipulación lumbar", "Masaje espalda", "Estiramiento columna" ], filas_informe.map(&:second)

    get informes_url(format: :csv), params: { tipo: "cuadro_clinico", disease_id: diseases(:lumbago).id }
    assert_not_includes response.body, "Hipopresivos"
  end

  # --- Solo para verificados (D94) -------------------------------------------------------------

  test "sin verificar, los informes solo son de los pacientes propios" do
    sign_in osteopaths(:maria).tap { |maria| maria.update!(verificado_at: nil) }
    get informes_url, params: { tipo: "mas_frecuentes", ambito: "plataforma" }
    assert_select "#filtros-informe", "Mis pacientes"
    assert_select "select[name=ambito] option", 1
    assert_select "select[name=ambito] option[value=mios]", "Mis pacientes"
    assert_select "#ayuda-ambito", /son para osteópatas verificados/
    # Las sesiones de Maria: maria_perez_1 (masaje, hipopresivos) y antonio_1 (estiramiento).
    assert_equal [ "Estiramiento columna", "Hipopresivos", "Masaje espalda" ], filas_informe.map(&:second)

    get informes_url(format: :csv), params: { tipo: "mas_frecuentes", ambito: "plataforma" }
    assert_not_includes response.body, "Manipulación lumbar", "las sesiones de Paco no cuentan"
  end
end
