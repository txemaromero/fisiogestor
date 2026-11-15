require "test_helper"

class CasoTest < ActiveSupport::TestCase
  def nuevo_caso(diagnostico = diagnoses(:diag_juan), **atributos)
    Caso.new({ diagnosis: diagnostico, osteopath: diagnostico.visit.osteopath, titulo: "Lumbalgia",
               resumen: "Mejora poco.", confirmacion_anonimato: "1" }.merge(atributos))
  end

  def sin_verificar(osteopata)
    osteopata.update!(verificado_at: nil, admin: false)
    osteopata
  end

  test "es válido con título, resumen y la confirmación de anonimato" do
    assert nuevo_caso.valid?(:publicacion)
  end

  test "al publicar o editar hay que confirmar que no identifica al paciente" do
    caso = nuevo_caso(confirmacion_anonimato: "0")
    assert caso.invalid?(:publicacion)
    assert_includes caso.errors.full_messages, "La confirmación de que no identifican al paciente es obligatoria"
    assert nuevo_caso(confirmacion_anonimato: nil).invalid?(:publicacion), "sin la casilla tampoco"
    assert nuevo_caso(confirmacion_anonimato: nil).valid?, "fuera de los formularios (moderación, seeds) no se pide"
  end

  test "título y resumen son obligatorios y con longitud máxima" do
    assert nuevo_caso(titulo: "").invalid?
    assert nuevo_caso(resumen: " ").invalid?
    assert nuevo_caso(titulo: "x" * 121).invalid?
    assert nuevo_caso(resumen: "x" * 4001).invalid?
  end

  test "solo lo publica el osteópata del paciente, si el paciente consiente, y una vez por diagnóstico" do
    assert nuevo_caso(osteopath: osteopaths(:maria)).invalid?

    patients(:juan).update!(consiente_compartir: false)
    caso = nuevo_caso(diagnoses(:diag_juan).reload)
    assert caso.invalid?
    assert_includes caso.errors[:base], "El paciente no consiente compartir sus datos"

    repetido = nuevo_caso(diagnoses(:diag_pepe))
    assert repetido.invalid?
    assert_includes repetido.errors.full_messages, "Diagnóstico ya está publicado como caso clínico"
  end

  test "si el paciente retira el consentimiento después, el caso sigue existiendo (pero deja de verse)" do
    patients(:pepe).update!(consiente_compartir: false)
    assert casos(:caso_pepe).reload.valid?
    assert_not casos(:caso_pepe).compartido?
  end

  test "la edad se publica en tramos de 5 años, con el sexo y la enfermedad" do
    caso = casos(:caso_pepe) # Pepe tiene 68 años
    assert_equal "65–69 años", caso.tramo_edad
    assert_equal "hombre", caso.sexo
    assert_equal diseases(:hernia_discal), caso.enfermedad
    assert_equal "45–49 años", nuevo_caso.tramo_edad # Juan, 46
  end

  test "las sesiones son las realizadas, en días desde la primera y sin fechas" do
    caso = casos(:caso_pepe)
    caso.diagnosis.sessions.create!(fecha: Date.current + 3) # programada: no se publica
    sin_fecha = caso.diagnosis.sessions.create!(escala_dolor_pre_sesion: 3)
    assert_equal [ sessions(:pepe_1), sessions(:pepe_2), sin_fecha ], caso.reload.sesiones
    assert_equal [ 0, 7, nil ], caso.sesiones.map { |sesion| caso.dia(sesion) } # 18/5 y 25/5
  end

  test "visibles_para: nada sin verificar; los propios siempre; los ajenos si se comparten" do
    caso = casos(:caso_pepe) # de Paco
    assert_includes Caso.visibles_para(osteopaths(:paco)), caso
    assert_includes Caso.visibles_para(osteopaths(:maria)), caso
    assert_empty Caso.visibles_para(sin_verificar(osteopaths(:maria)))
    assert_empty Caso.visibles_para(nil)
  end

  test "visibles_para: un caso oculto lo ven su autor y los administradores; sin consentimiento, solo su autor" do
    maria = osteopaths(:maria)
    caso_de_maria = nuevo_caso(diagnoses(:diag_maria_perez))
    caso_de_maria.save!
    caso_de_maria.update!(oculto_at: Time.current)
    assert_includes Caso.visibles_para(maria), caso_de_maria
    assert_includes Caso.visibles_para(osteopaths(:paco)), caso_de_maria, "Paco es administrador"
    paco_sin_admin = osteopaths(:paco).tap { |paco| paco.update!(admin: false) }
    assert_not_includes Caso.visibles_para(paco_sin_admin), caso_de_maria

    patients(:pepe).update!(consiente_compartir: false)
    assert_includes Caso.visibles_para(osteopaths(:paco)), casos(:caso_pepe)
    assert_not_includes Caso.visibles_para(maria), casos(:caso_pepe)
  end

  test "un administrador sin verificar entra en los casos" do
    paco = osteopaths(:paco)
    paco.update!(verificado_at: nil)
    assert paco.acceso_a_la_red?
    assert_includes Caso.visibles_para(paco), casos(:caso_pepe)
  end

  test "de_enfermedad filtra por la enfermedad del diagnóstico" do
    assert_equal [ casos(:caso_pepe) ], Caso.de_enfermedad(diseases(:hernia_discal).id).to_a
    assert_empty Caso.de_enfermedad(diseases(:lumbago).id)
    assert_equal Caso.count, Caso.de_enfermedad(nil).count
  end

  test "técnicas sugeridas en los comentarios visibles, de la más sugerida a la menos" do
    caso = casos(:caso_pepe)
    otro = caso.comentarios.create!(osteopath: osteopaths(:maria), treatments: treatments(:estiramiento, :hipopresivos))
    assert_equal [ [ "Estiramiento columna", 2 ], [ "Hipopresivos", 1 ] ],
                 caso.tecnicas_sugeridas.map { |tecnica| [ tecnica.nombre, tecnica.veces ] }

    otro.update!(oculto_at: Time.current)
    assert_equal [ [ "Estiramiento columna", 1 ] ], caso.tecnicas_sugeridas.map { |tecnica| [ tecnica.nombre, tecnica.veces ] }
  end

  test "se borra con su diagnóstico, con sus comentarios y sus técnicas sugeridas; sus denuncias se conservan (D97)" do
    caso = casos(:caso_pepe)
    del_caso = Denuncia.create!(osteopath: osteopaths(:maria), denunciable: caso, motivo: "Identifica al paciente")
    del_comentario = Denuncia.create!(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "Ofensivo")
    assert_difference -> { Caso.count } => -1, -> { Comentario.count } => -1, -> { Denuncia.count } => 0 do
      diagnoses(:diag_pepe).destroy
    end
    assert_equal 0, Comentario.connection.select_value("SELECT COUNT(*) FROM comentarios_treatments")

    del_caso.reload
    assert_nil del_caso.denunciable
    assert_equal [ "borrado", osteopaths(:paco), nil ], [ del_caso.resultado, del_caso.autor_contenido, del_caso.resuelta_por ]
    assert_not_nil del_caso.resuelta_at
    assert_equal [ "borrado", osteopaths(:maria) ], [ del_comentario.reload.resultado, del_comentario.autor_contenido ]
  end

  test "al borrar el paciente se borra su caso" do
    assert_difference -> { Caso.count } => -1 do
      patients(:pepe).destroy
    end
  end

  # --- Datos identificativos y casos retirados (D96) ------------------------------------------

  test "al publicar o editar, el título y el resumen no pueden llevar fechas, años, teléfonos, DNI ni emails" do
    [ "Empezó el 12/03/2025", "desde el 3 de marzo", "en 2019", "llamad al 612 345 678", "DNI 12345678Z",
      "escribid a ana@ejemplo.es" ].each do |texto|
      caso = nuevo_caso(resumen: "Lumbalgia. #{texto}.")
      assert caso.invalid?(:publicacion), texto
      assert_match(/parecen contener/, caso.errors[:base].sole, texto)
    end
    caso = nuevo_caso(titulo: "Hernia L4-L5 en 2020", resumen: "Llamar al 612345678")
    caso.valid?(:publicacion)
    assert_equal "El título o el resumen parecen contener un año y un teléfono: quítalo, para que no se pueda " \
                 "reconocer al paciente", caso.errors[:base].sole
    assert nuevo_caso(resumen: "Dolor de 8 a 4 en 3 sesiones; L4-L5 y S1; mejora 8-4; sesión 1/3.").valid?(:publicacion)
  end

  test "un caso retirado no lo ven los demás ni los administradores, y su autor lo vuelve a publicar" do
    caso = casos(:caso_pepe)
    patients(:pepe).update!(consiente_compartir: false)
    caso.reload
    assert_not caso.republicar!, "sin consentimiento no se puede"
    assert_includes Caso.visibles_para(osteopaths(:paco)), caso, "su autor sí lo ve"
    assert_not_includes Caso.visibles_para(osteopaths(:maria).tap { |maria| maria.update!(admin: true) }), caso

    patients(:pepe).update!(consiente_compartir: true)
    assert caso.reload.republicar!
    assert caso.compartido?
    assert_includes Caso.visibles_para(osteopaths(:maria)), caso
  end
end
