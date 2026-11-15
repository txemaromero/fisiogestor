require "test_helper"

class DiagnosisTest < ActiveSupport::TestCase
  test "las sesiones recomendadas son obligatorias y la descripción opcional" do
    diagnostico = Diagnosis.new(visit: visits(:visita_juan), disease: diseases(:lumbago))
    assert_not diagnostico.valid?
    assert diagnostico.errors.added?(:sesiones_recomendadas, :blank)

    diagnostico.sesiones_recomendadas = 2
    assert diagnostico.valid?
  end

  test "las sesiones recomendadas son un entero positivo" do
    diagnostico = diagnoses(:diag_juan)
    [ 0, -1, "1.5" ].each { |valor| diagnostico.sesiones_recomendadas = valor; assert diagnostico.invalid?, valor.inspect }
  end

  test "necesita visita y enfermedad" do
    diagnostico = Diagnosis.new(sesiones_recomendadas: 1)
    assert_not diagnostico.valid?
    assert diagnostico.errors.key?(:visit)
    assert diagnostico.errors.key?(:disease)
  end

  # --- Filtro de tratamientos ------------------------------------------------------------------
  # Diagnósticos de los fixtures (paciente, sexo, edad, enfermedad):
  #   diag_juan          Juan         hombre 46  lumbago
  #   diag_maria_torres  María Torres mujer  34  ciática
  #   diag_pepe          Pepe         hombre 68  hernia discal
  #   diag_maria_perez   María Pérez  mujer  40  lumbago   (de otro osteópata)
  #   diag_antonio       Antonio      hombre 76  ciática   (de otro osteópata)

  def nombres(diagnosticos)
    diagnosticos.map { |diagnostico| diagnostico.visit.patient.nombre_completo }.sort
  end

  test "por_sexo filtra por el sexo del paciente" do
    assert_equal diagnoses(:diag_juan, :diag_pepe, :diag_antonio).sort, Diagnosis.por_sexo("hombre").sort
    assert_equal diagnoses(:diag_maria_torres, :diag_maria_perez).sort, Diagnosis.por_sexo("mujer").sort
  end

  test "por_sexo devuelve todos con «ambos» o vacío" do
    [ "ambos", "", nil ].each do |valor|
      assert_equal Diagnosis.count, Diagnosis.por_sexo(valor).count, valor.inspect
    end
  end

  test "por_edad_minima incluye a los pacientes que tienen justo esa edad" do
    assert_equal diagnoses(:diag_juan, :diag_pepe, :diag_maria_perez, :diag_antonio).sort,
                 Diagnosis.por_edad_minima(40).sort
    assert_equal 3, Diagnosis.por_edad_minima("41").count
  end

  test "por_edad_maxima incluye a los pacientes que tienen justo esa edad" do
    assert_equal diagnoses(:diag_maria_torres, :diag_maria_perez).sort, Diagnosis.por_edad_maxima(40).sort
    assert_equal [ diagnoses(:diag_maria_torres) ], Diagnosis.por_edad_maxima("39").to_a
  end

  test "las edades vacías o no numéricas no filtran" do
    [ "", nil, "abc" ].each do |valor|
      assert_equal Diagnosis.count, Diagnosis.por_edad_minima(valor).count, valor.inspect
      assert_equal Diagnosis.count, Diagnosis.por_edad_maxima(valor).count, valor.inspect
    end
  end

  test "por_dolencias combina varias enfermedades con OR" do
    assert_equal diagnoses(:diag_juan, :diag_maria_perez).sort, Diagnosis.por_dolencias([ diseases(:lumbago).id ]).sort
    assert_equal 4, Diagnosis.por_dolencias([ diseases(:lumbago).id, diseases(:ciatica).id.to_s ]).count
    assert_empty Diagnosis.por_dolencias([ diseases(:miopia).id ])
  end

  test "por_dolencias devuelve todos si no se elige ninguna" do
    [ nil, [], [ "" ] ].each do |valor|
      assert_equal Diagnosis.count, Diagnosis.por_dolencias(valor).count, valor.inspect
    end
  end

  test "filtrar sin criterios devuelve todos los diagnósticos de la plataforma" do
    assert_equal Diagnosis.count, Diagnosis.filtrar.count
    assert_equal Diagnosis.count, Diagnosis.filtrar(sexo: "ambos", edad_min: "", edad_max: "", dolencias: [ "" ]).count
  end

  test "filtrar combina los criterios con AND" do
    assert_equal [ diagnoses(:diag_maria_perez) ],
                 Diagnosis.filtrar(sexo: "mujer", edad_min: "35", dolencias: [ diseases(:lumbago).id ]).to_a
    assert_equal [ "Juan Martínez Campos", "Pepe Campos Giménez" ],
                 nombres(Diagnosis.filtrar(sexo: "hombre", edad_min: 40, edad_max: 70))
  end

  test "filtrar aplica a la vez la edad mínima y la máxima" do
    assert_equal [ diagnoses(:diag_maria_perez), diagnoses(:diag_juan) ].sort, Diagnosis.filtrar(edad_min: 40, edad_max: 46).sort
    assert_empty Diagnosis.filtrar(edad_min: 50, edad_max: 60)
  end

  test "progreso: sesiones realizadas frente a las recomendadas" do
    diagnostico = diagnoses(:diag_juan)
    assert_equal [ 2, 0 ], [ diagnostico.sesiones_realizadas, diagnostico.sesiones_programadas ]
    assert_not diagnostico.completado?

    diagnostico.sessions.create!(fecha: Date.new(2026, 3, 26))
    assert diagnostico.reload.completado?
  end

  test "las sesiones de fecha futura son programadas y no cuentan como realizadas" do
    diagnostico = diagnoses(:diag_juan)
    diagnostico.sessions.create!(fecha: Date.current + 1)
    diagnostico.sessions.create!(fecha: Date.current) # la de hoy ya cuenta como realizada
    diagnostico.reload
    assert_equal [ 3, 1 ], [ diagnostico.sesiones_realizadas, diagnostico.sesiones_programadas ]
    assert diagnostico.completado?
  end

  test "tecnicas_aplicadas lista las técnicas de todas sus sesiones sin repetir" do
    assert_equal treatments(:masaje, :estiramiento, :manipulacion).sort, diagnoses(:diag_juan).tecnicas_aplicadas.sort
  end

  test "al borrar el diagnóstico se borran sus sesiones y su relación con las técnicas" do
    ids_sesiones = diagnoses(:diag_juan).session_ids
    assert_difference -> { Session.count } => -2, -> { Treatment.count } => 0 do
      diagnoses(:diag_juan).destroy
    end
    assert_empty Treatment.joins(:sessions).where(sessions: { id: ids_sesiones })
    assert_empty Session.joins(:treatments).where(id: ids_sesiones)
  end

  test "visibles_para: los diagnósticos de los pacientes propios y de los de otros que consienten" do
    patients(:antonio).update!(consiente_compartir: false)
    assert_equal Diagnosis.count - 1, Diagnosis.visibles_para(osteopaths(:paco)).count
    assert_equal Diagnosis.count, Diagnosis.visibles_para(osteopaths(:maria)).count
    assert_equal [ diagnoses(:diag_juan), diagnoses(:diag_pepe) ].sort,
                 Diagnosis.filtrar(sexo: "hombre").visibles_para(osteopaths(:paco)).sort
  end
end
