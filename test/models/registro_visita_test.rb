require "test_helper"

class RegistroVisitaTest < ActiveSupport::TestCase
  def registro(**atributos)
    sesiones = [
      { fecha: "2026-10-01", escala_dolor_pre_sesion: "7", escala_dolor_post_sesion: "4",
        tecnicas: [ { nombre: "masaje espalda", descripcion: "" }, { nombre: "Punción seca", descripcion: "Agujas finas" } ] },
      { fecha: "2026-10-08", escala_dolor_pre_sesion: "5", escala_dolor_post_sesion: "2",
        tecnicas: [ { nombre: "Punción seca", descripcion: "" } ] }
    ]
    RegistroVisita.new({
      osteopath: osteopaths(:paco), patient_id: patients(:juan).id, anamnesis: "Dolor lumbar", escala_dolor: "7",
      disease_id: diseases(:lumbago).id.to_s, descripcion: "Contractura", sesiones_recomendadas: "3",
      sesiones_json: sesiones.to_json
    }.merge(atributos))
  end

  test "crea la visita, el diagnóstico, las sesiones y sus técnicas" do
    nuevo = registro
    assert_difference -> { Visit.count } => 1, -> { Diagnosis.count } => 1, -> { Session.count } => 2,
                      -> { Treatment.count } => 1 do
      assert nuevo.guardar, nuevo.errors.full_messages.to_sentence
    end

    visita = nuevo.visita
    assert_equal patients(:juan), visita.patient
    assert_equal osteopaths(:paco), visita.osteopath
    assert_equal Date.current, visita.fecha
    assert_equal 7, visita.escala_dolor

    diagnostico = visita.diagnoses.sole
    assert_equal diseases(:lumbago), diagnostico.disease
    assert_equal 3, diagnostico.sesiones_recomendadas

    primera, segunda = diagnostico.sessions
    assert_equal [ 7, 4 ], [ primera.escala_dolor_pre_sesion, primera.escala_dolor_post_sesion ]
    assert_equal [ "Masaje espalda", "Punción seca" ], primera.treatments.map(&:nombre).sort
    assert_equal [ "Punción seca" ], segunda.treatments.map(&:nombre)
  end

  test "reutiliza las técnicas del catálogo sin distinguir mayúsculas y crea una sola vez las nuevas" do
    nuevo = registro
    nuevo.guardar
    sesiones = nuevo.visita.diagnoses.sole.sessions
    assert_includes sesiones.first.treatments, treatments(:masaje)
    assert_equal sesiones.first.treatments.find_by(nombre: "Punción seca"), sesiones.second.treatments.sole
    assert_equal "Agujas finas", Treatment.find_by(nombre: "Punción seca").descripcion
  end

  test "con «Otra…» crea la enfermedad nueva usando la descripción del diagnóstico" do
    nuevo = registro(disease_id: RegistroVisita::OTRA_ENFERMEDAD, nueva_enfermedad: "Escoliosis",
                     descripcion: "Curvatura lateral de la columna")
    assert_difference -> { Disease.count } => 1 do
      assert nuevo.guardar
    end
    assert_equal "Curvatura lateral de la columna", Disease.find_by(nombre: "Escoliosis").descripcion
  end

  test "con «Otra…» reutiliza la enfermedad si ya existe con ese nombre" do
    nuevo = registro(disease_id: RegistroVisita::OTRA_ENFERMEDAD, nueva_enfermedad: "LUMBAGO")
    assert_no_difference -> { Disease.count } do
      assert nuevo.guardar
    end
    assert_equal diseases(:lumbago), nuevo.visita.diagnoses.sole.disease
  end

  test "las sesiones son opcionales" do
    nuevo = registro(sesiones_json: "[]")
    assert nuevo.guardar
    assert_empty nuevo.visita.diagnoses.sole.sessions
  end

  test "unas sesiones con forma inesperada no se guardan y dan error en el panel de sesiones" do
    invalidos = [
      "no es json",
      '{"fecha": "2026-01-01"}',                                  # objeto en lugar de lista
      '[{"fecha": {"x": 1}}]',                                    # fecha que no es texto
      '[{"tecnicas": [{"nombre": {"a": 1}}]}]',                   # nombre de técnica que no es texto
      '[{"tecnicas": "Masaje"}]',                                 # técnicas que no son una lista
      '["texto"]'                                                 # sesión que no es un objeto
    ]
    invalidos.each do |json|
      nuevo = registro(sesiones_json: json)
      assert_no_difference %w[Visit.count Treatment.count] do
        assert_not nuevo.guardar, json
      end
      assert_includes nuevo.errors.full_messages, "Los datos de las sesiones no son válidos.", json
      assert_equal 2, nuevo.panel_con_errores
    end
  end

  test "hay un máximo de sesiones, de técnicas por sesión y de tamaño" do
    muchas_sesiones = Array.new(RegistroVisita::MAX_SESIONES + 1) { { fecha: "2026-10-01" } }.to_json
    nuevo = registro(sesiones_json: muchas_sesiones)
    assert_not nuevo.guardar
    assert_includes nuevo.errors.full_messages, "Una visita admite como máximo 50 sesiones."

    muchas_tecnicas = [ { tecnicas: Array.new(RegistroVisita::MAX_TECNICAS_POR_SESION + 1) { |i| { nombre: "T#{i}" } } } ].to_json
    nuevo = registro(sesiones_json: muchas_tecnicas)
    assert_not nuevo.guardar
    assert_includes nuevo.errors.full_messages, "Una sesión admite como máximo 30 técnicas."

    enorme = [ { tecnicas: [ { nombre: "x", descripcion: "a" * RegistroVisita::MAX_BYTES_SESIONES } ] } ].to_json
    nuevo = registro(sesiones_json: enorme)
    assert_not nuevo.guardar
    assert_includes nuevo.errors.full_messages, "Los datos de las sesiones son demasiado grandes."
  end

  test "una escala de dolor con un número enorme da error de validación (no un error 500)" do
    nuevo = registro(sesiones_json: [ { escala_dolor_pre_sesion: 10**30 } ].to_json)
    assert_no_difference "Visit.count" do
      assert_not nuevo.guardar
    end
    assert(nuevo.errors.full_messages.any? { |mensaje| mensaje.start_with?("Sesión 1: Escala de dolor presesión") })
  end

  test "una técnica con un nombre demasiado largo impide guardar" do
    nuevo = registro(sesiones_json: [ { tecnicas: [ { nombre: "x" * 101 } ] } ].to_json)
    assert_not nuevo.guardar
    assert_includes nuevo.errors.full_messages, "Técnica de la sesión 1: Nombre técnica es demasiado largo (100 caracteres máximo)"
  end

  test "no se pueden crear visitas de pacientes de otro osteópata" do
    nuevo = registro(patient_id: patients(:maria_perez).id)
    assert_no_difference -> { Visit.count } do
      assert_not nuevo.guardar
    end
    assert_includes nuevo.errors.full_messages, "Visita: Paciente debe existir"
    assert_equal 0, nuevo.panel_con_errores
  end

  test "sin enfermedad no se guarda y se señala el panel de diagnóstico" do
    nuevo = registro(disease_id: "")
    assert_not nuevo.guardar
    assert_includes nuevo.errors.full_messages, "Diagnóstico: Enfermedad debe existir"
    assert_equal 1, nuevo.panel_con_errores
  end

  test "si falla una sesión no queda nada a medias (transacción)" do
    sesiones = [
      { fecha: "2026-10-01", escala_dolor_pre_sesion: "7", escala_dolor_post_sesion: "4",
        tecnicas: [ { nombre: "Técnica nueva" } ] },
      { fecha: "2026-10-08", escala_dolor_pre_sesion: "15", escala_dolor_post_sesion: "2", tecnicas: [] }
    ]
    nuevo = registro(disease_id: RegistroVisita::OTRA_ENFERMEDAD, nueva_enfermedad: "Enfermedad nueva",
                     sesiones_json: sesiones.to_json)

    assert_no_difference %w[Visit.count Diagnosis.count Session.count Treatment.count Disease.count] do
      assert_not nuevo.guardar
    end
    assert_nil nuevo.visita
    assert(nuevo.errors.full_messages.any? { |mensaje| mensaje.start_with?("Sesión 2: Escala de dolor presesión") })
    assert_equal 2, nuevo.panel_con_errores
  end

  test "una técnica sin nombre impide guardar" do
    sesiones = [ { fecha: "2026-10-01", tecnicas: [ { nombre: "  " } ] } ]
    nuevo = registro(sesiones_json: sesiones.to_json)
    assert_no_difference -> { Visit.count } do
      assert_not nuevo.guardar
    end
    assert_includes nuevo.errors.full_messages, "Técnica de la sesión 1: Nombre técnica no puede estar en blanco"
  end
end
