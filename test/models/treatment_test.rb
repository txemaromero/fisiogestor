require "test_helper"

class TreatmentTest < ActiveSupport::TestCase
  test "el nombre es obligatorio y la descripción opcional" do
    assert_not Treatment.new.valid?
    assert Treatment.new(nombre: "Punción seca").valid?
  end

  test "el nombre es único sin distinguir mayúsculas" do
    assert Treatment.new(nombre: "masaje ESPALDA").invalid?
  end

  test "buscar_o_crear! reutiliza la técnica sin distinguir mayúsculas" do
    assert_no_difference -> { Treatment.count } do
      assert_equal treatments(:masaje), Treatment.buscar_o_crear!("  MASAJE   espalda ")
    end
  end

  test "la base de datos tampoco admite el mismo nombre con otras mayúsculas" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Treatment.new(nombre: "MASAJE ESPALDA").save(validate: false)
    end
  end

  test "buscar_o_crear! devuelve la técnica existente si otra petición la crea a la vez" do
    # Simula la carrera: la primera búsqueda no la encuentra y la inserción choca con el índice único.
    busquedas = 0
    buscar_real = Treatment.method(:buscar_por_nombre)
    sustituir(Treatment, :buscar_por_nombre, ->(nombre) { (busquedas += 1) == 1 ? nil : buscar_real.call(nombre) }) do
      sustituir(Treatment, :create!, ->(**) { raise ActiveRecord::RecordNotUnique }) do
        assert_equal treatments(:masaje), Treatment.buscar_o_crear!("Masaje espalda")
      end
    end
    assert_equal 2, busquedas
  end

  test "longitudes máximas de nombre y descripción" do
    assert Treatment.new(nombre: "x" * 101).invalid?
    assert Treatment.new(nombre: "Nueva", descripcion: "x" * 1001).invalid?
  end

  test "buscar_o_crear! crea la técnica si no existe" do
    assert_difference -> { Treatment.count } => 1 do
      tecnica = Treatment.buscar_o_crear!("Punción seca", "Agujas finas")
      assert_equal [ "Punción seca", "Agujas finas" ], [ tecnica.nombre, tecnica.descripcion ]
    end
  end

  # --- Informes --------------------------------------------------------------------------------
  # Sesiones de los fixtures (reducción = pre − post):
  #   juan_1 (lumbago)    8 -> 5  (3)  masaje, estiramiento
  #   juan_2 (lumbago)    5 -> 1  (4)  masaje, manipulacion
  #   maria_torres_1      6 -> 5  (1)  estiramiento
  #   pepe_1 (hernia)     9 -> 4  (5)  manipulacion
  #   pepe_2 (hernia)     4 -> ?       hipopresivos   (sin escala post)
  #   maria_perez_1 (lumbago, mujer de 40)  7 -> 6 (1)  masaje, hipopresivos
  #   antonio_1           6 -> 6  (0)  estiramiento
  # Descompresión columna no se ha aplicado nunca.

  def ranking(tecnicas)
    tecnicas.map { |tecnica| [ tecnica.nombre, tecnica.num_sesiones, tecnica.reduccion_media&.to_f&.round(2) ] }
  end

  test "mas_frecuentes ordena por número de sesiones (y por nombre si empatan)" do
    assert_equal [ [ "Estiramiento columna", 3 ], [ "Masaje espalda", 3 ], [ "Hipopresivos", 2 ], [ "Manipulación lumbar", 2 ] ],
                 Treatment.mas_frecuentes.map { |tecnica| [ tecnica.nombre, tecnica.num_sesiones ] }
  end

  test "mas_efectivas ordena por reducción media e ignora las sesiones sin ambas escalas" do
    assert_equal [ [ "Manipulación lumbar", 2, 4.5 ],
                   [ "Masaje espalda", 3, 2.67 ],
                   [ "Estiramiento columna", 3, 1.33 ],
                   [ "Hipopresivos", 1, 1.0 ] ],
                 ranking(Treatment.mas_efectivas)
  end

  test "menos_efectivas es el mismo ranking en orden inverso" do
    assert_equal Treatment.mas_efectivas.map(&:nombre).reverse, Treatment.menos_efectivas.map(&:nombre)
  end

  test "las técnicas que nunca se han aplicado no aparecen en los informes" do
    %i[mas_frecuentes mas_efectivas menos_efectivas].each do |informe|
      assert_not_includes Treatment.public_send(informe).map(&:nombre), "Descompresión columna", informe
    end
  end

  test "para_cuadro_clinico lista las técnicas de los diagnósticos de esa enfermedad por efectividad" do
    assert_equal [ [ "Manipulación lumbar", 1, 4.0 ],
                   [ "Estiramiento columna", 1, 3.0 ],
                   [ "Masaje espalda", 3, 2.67 ],
                   [ "Hipopresivos", 1, 1.0 ] ],
                 ranking(Treatment.para_cuadro_clinico(diseases(:lumbago).id))
  end

  test "para_cuadro_clinico acota por sexo y edad del paciente" do
    assert_equal [ [ "Manipulación lumbar", 1, 4.0 ], [ "Masaje espalda", 2, 3.5 ], [ "Estiramiento columna", 1, 3.0 ] ],
                 ranking(Treatment.para_cuadro_clinico(diseases(:lumbago).id, sexo: "hombre"))
    assert_equal [ [ "Hipopresivos", 1, 1.0 ], [ "Masaje espalda", 1, 1.0 ] ],
                 ranking(Treatment.para_cuadro_clinico(diseases(:lumbago).id, edad_max: "40"))
    assert_equal Treatment.para_cuadro_clinico(diseases(:lumbago).id, sexo: "hombre").map(&:nombre),
                 Treatment.para_cuadro_clinico(diseases(:lumbago).id, edad_min: 41).map(&:nombre)
  end

  test "para_cuadro_clinico deja al final las técnicas sin sesiones con ambas escalas" do
    assert_equal [ [ "Manipulación lumbar", 1, 5.0 ], [ "Hipopresivos", 1, nil ] ],
                 ranking(Treatment.para_cuadro_clinico(diseases(:hernia_discal).id))
  end

  test "para_cuadro_clinico de una enfermedad sin diagnósticos está vacío" do
    assert_empty Treatment.para_cuadro_clinico(diseases(:miopia).id)
  end

  test "se aplica en sesiones" do
    assert_equal sessions(:juan_1, :juan_2, :maria_perez_1).sort, treatments(:masaje).sessions.sort
    assert_empty treatments(:descompresion).sessions
  end
end
