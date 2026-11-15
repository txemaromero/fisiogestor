require "test_helper"

class PatientTest < ActiveSupport::TestCase
  def nuevo_paciente(**atributos)
    Patient.new({ osteopath: osteopaths(:paco), nombre: "Lucía", apellidos: "Fernández Ruiz",
                  anyo_nacimiento: 2000, sexo: "mujer" }.merge(atributos))
  end

  test "es válido con todos los datos" do
    assert nuevo_paciente.valid?
  end

  test "nombre, apellidos, año de nacimiento, sexo y osteópata son obligatorios" do
    paciente = Patient.new
    assert_not paciente.valid?
    %i[nombre apellidos anyo_nacimiento sexo].each { |campo| assert paciente.errors.added?(campo, :blank), campo }
    assert paciente.errors.key?(:osteopath)
    assert_equal 1, paciente.errors.where(:sexo).size, "el sexo vacío da un solo error"
  end

  test "el año de nacimiento está entre 1900 y el año actual" do
    assert nuevo_paciente(anyo_nacimiento: 1900).valid?
    assert nuevo_paciente(anyo_nacimiento: Date.current.year).valid?
    assert nuevo_paciente(anyo_nacimiento: 1899).invalid?
    assert nuevo_paciente(anyo_nacimiento: Date.current.year + 1).invalid?
    assert nuevo_paciente(anyo_nacimiento: "1990.5").invalid?
  end

  test "nombre y apellidos tienen una longitud máxima" do
    assert nuevo_paciente(nombre: "x" * 100).valid?
    assert nuevo_paciente(nombre: "x" * 101).invalid?
    assert nuevo_paciente(apellidos: "x" * 101).invalid?
  end

  test "sexo es la enumeración sex_type" do
    assert_equal %w[hombre mujer], Patient.sexos.keys
    assert patients(:juan).hombre?
    assert patients(:maria_torres).mujer?
    assert_equal patients(:maria_torres, :maria_perez).sort, Patient.mujer.sort
  end

  test "un sexo fuera de la enumeración no es válido (y no lanza excepción)" do
    paciente = nuevo_paciente(sexo: "otro")
    assert_not paciente.valid?
    assert paciente.errors.key?(:sexo)
  end

  test "la edad se calcula a partir del año de nacimiento" do
    assert_equal 46, patients(:juan).edad
    assert_equal Date.current.year - 1980, nuevo_paciente(anyo_nacimiento: 1980).edad
  end

  test "pertenece_a? indica si el paciente es del osteópata" do
    juan = patients(:juan)
    assert juan.pertenece_a?(osteopaths(:paco))
    assert_not juan.pertenece_a?(osteopaths(:maria))
    assert_not juan.pertenece_a?(nil)
  end

  test "nombre completo" do
    assert_equal "Juan Martínez Campos", patients(:juan).nombre_completo
  end

  test "acepta antecedentes anidados, ignora las filas vacías y permite borrarlos" do
    paciente = nuevo_paciente(
      family_medical_backgrounds_attributes: [
        { familiar: "Padre", tipo: "digestivos", descripcion: "Intestino permeable" },
        { familiar: "", tipo: "", descripcion: "" }
      ],
      personal_medical_backgrounds_attributes: [ { tipo: "endocrinos", descripcion: "Hipotiroidismo" } ]
    )
    assert paciente.save
    assert_equal 1, paciente.family_medical_backgrounds.count
    assert_equal 1, paciente.personal_medical_backgrounds.count

    antecedente = paciente.family_medical_backgrounds.first
    paciente.update!(family_medical_backgrounds_attributes: [ { id: antecedente.id, _destroy: "1" } ])
    assert_empty paciente.family_medical_backgrounds.reload
  end

  test "un antecedente anidado incompleto impide guardar el paciente" do
    paciente = nuevo_paciente(family_medical_backgrounds_attributes: [ { familiar: "Padre", tipo: "digestivos" } ])
    assert_not paciente.save
    assert_includes paciente.errors.full_messages, "Antecedente familiar: descripción no puede estar en blanco"
  end

  test "id_ficha_para: el id para su osteópata y un identificador firmado para los demás" do
    juan = patients(:juan)
    assert_equal juan.id, juan.id_ficha_para(osteopaths(:paco))
    firmado = juan.id_ficha_para(osteopaths(:maria))
    assert_not_equal juan.id.to_s, firmado.to_s
    assert_equal juan, Patient.ficha(firmado, osteopaths(:maria))
  end

  test "Patient.ficha no encuentra pacientes ajenos por su número" do
    assert_equal patients(:juan), Patient.ficha(patients(:juan).id.to_s, osteopaths(:paco))
    assert_raises(ActiveRecord::RecordNotFound) { Patient.ficha(patients(:juan).id.to_s, osteopaths(:maria)) }
    assert_raises(ActiveRecord::RecordNotFound) { Patient.ficha("basura", osteopaths(:maria)) }
  end

  test "texto_busqueda se guarda sin tildes ni mayúsculas y se actualiza al cambiar el nombre" do
    paciente = osteopaths(:paco).patients.create!(nombre: "Íñigo", apellidos: "Muñoz  Peña", anyo_nacimiento: 1990, sexo: "hombre")
    assert_equal "inigo munoz pena", paciente.texto_busqueda
    paciente.update!(apellidos: "Ábalos")
    assert_equal "inigo abalos", paciente.texto_busqueda
  end

  test "buscar no distingue tildes ni mayúsculas y exige todas las palabras, en cualquier orden" do
    de_paco = osteopaths(:paco).patients
    assert_equal [ patients(:maria_torres) ], de_paco.buscar("MARÍA").to_a
    assert_equal [ patients(:maria_torres) ], de_paco.buscar("maria").to_a
    assert_equal [ patients(:juan) ], de_paco.buscar("campos  juan").to_a
    assert_equal [ patients(:juan), patients(:pepe) ].sort_by(&:id), de_paco.buscar("camp").to_a.sort_by(&:id)
    assert_empty de_paco.buscar("campos maria").to_a
  end

  test "buscar sin texto devuelve todos, y los comodines de LIKE se buscan tal cual" do
    assert_equal 3, osteopaths(:paco).patients.buscar("").count
    assert_equal 3, osteopaths(:paco).patients.buscar(nil).count
    assert_empty osteopaths(:paco).patients.buscar("%").to_a
    assert_empty osteopaths(:paco).patients.buscar("_").to_a
  end

  test "al borrar un paciente se borran sus antecedentes y sus visitas" do
    assert_difference -> { FamilyMedicalBackground.count } => -2,
                      -> { PersonalMedicalBackground.count } => -1,
                      -> { Visit.count } => -1,
                      -> { Diagnosis.count } => -1,
                      -> { Session.count } => -2 do
      patients(:juan).destroy
    end
  end

  # --- Consentimiento (D83) y registro de accesos (D85) ---------------------------------------

  test "un paciente nuevo no consiente compartir sus datos" do
    assert_not Patient.new.consiente_compartir?
  end

  test "visibles_para: los pacientes propios y los de otros osteópatas que consienten" do
    patients(:antonio).update!(consiente_compartir: false)
    patients(:juan).update!(consiente_compartir: false)
    assert_equal %w[Juan María María Pepe], Patient.visibles_para(osteopaths(:paco)).map(&:nombre).sort
    assert_equal %w[Antonio María María Pepe], Patient.visibles_para(osteopaths(:maria)).map(&:nombre).sort
  end

  test "Patient.ficha solo abre un paciente ajeno si consiente; el propio, siempre" do
    juan = patients(:juan)
    firmado = juan.id_ficha_para(osteopaths(:maria))
    juan.update!(consiente_compartir: false)
    assert_raises(ActiveRecord::RecordNotFound) { Patient.ficha(firmado, osteopaths(:maria)) }
    assert_equal juan, Patient.ficha(firmado, osteopaths(:paco))
    assert_equal juan, Patient.ficha(juan.id.to_s, osteopaths(:paco))
  end

  test "la fecha del consentimiento se anota solo cuando cambia" do
    juan = patients(:juan)
    retirado = Time.zone.local(2026, 10, 1, 10)
    travel_to(retirado) { juan.update!(consiente_compartir: false) }
    travel_to(retirado + 1.day) { juan.update!(nombre: "Juanito") }
    assert_equal retirado, juan.reload.consentimiento_actualizado_at
  end

  test "al borrar un paciente se borra su registro de accesos" do
    osteopaths(:maria).accesos_fichas.create!(patient: patients(:juan), pagina: "ficha")
    assert_difference -> { AccesoFicha.count } => -1 do
      patients(:juan).destroy
    end
  end

  test "un acceso tiene que ser a la ficha o a los antecedentes" do
    acceso = AccesoFicha.new(osteopath: osteopaths(:maria), patient: patients(:juan), pagina: "visitas")
    assert acceso.invalid?
    acceso.pagina = "antecedentes"
    assert acceso.valid?
    assert_equal "Antecedentes", acceso.nombre_pagina
  end

  # --- Solo para verificados y casos retirados (D94, D96) -------------------------------------

  test "sin verificar, un osteópata solo ve sus pacientes" do
    maria = osteopaths(:maria).tap { |osteopata| osteopata.update!(verificado_at: nil) }
    assert_equal %w[Antonio María], Patient.visibles_para(maria).map(&:nombre).sort
    assert_not patients(:juan).visible_para?(maria)
    assert patients(:maria_perez).visible_para?(maria)
    assert_raises(ActiveRecord::RecordNotFound) { Patient.ficha(patients(:juan).id_ficha_para(maria), maria) }
  end

  test "al retirar el consentimiento se retiran sus casos, y no vuelven solos al volver a consentir" do
    pepe = patients(:pepe)
    travel_to Time.zone.local(2026, 10, 20, 12) do
      pepe.update!(consiente_compartir: false)
    end
    caso = casos(:caso_pepe).reload
    assert_equal Time.zone.local(2026, 10, 20, 12), caso.retirado_at
    pepe.update!(consiente_compartir: true)
    assert caso.reload.retirado?
    assert_not caso.compartido?
    assert_not_includes Caso.visibles_para(osteopaths(:maria)), caso
  end

  test "cambiar otros datos del paciente no retira sus casos" do
    patients(:pepe).update!(nombre: "José")
    assert_not casos(:caso_pepe).reload.retirado?
  end
end
