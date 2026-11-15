require "test_helper"

class FusionCatalogoTest < ActiveSupport::TestCase
  test "fusionar técnicas mueve sus sesiones sin duplicar la técnica en las que ya tenían las dos" do
    duplicada = Treatment.create!(nombre: "Masaje de espalda")
    sessions(:juan_1).treatments << duplicada # juan_1 ya tenía Masaje espalda
    sessions(:pepe_1).treatments << duplicada # pepe_1 no

    fusion = nil
    assert_difference -> { Treatment.count } => -1, -> { FusionCatalogo.count } => 1 do
      fusion = FusionCatalogo.fusionar!(duplicada, treatments(:masaje), osteopath: osteopaths(:paco))
    end

    assert_equal [ treatments(:masaje).id ], sessions(:juan_1).reload.treatments.where(id: treatments(:masaje).id).pluck(:id)
    assert_includes sessions(:pepe_1).reload.treatments, treatments(:masaje)
    assert_equal [ "tecnica", "Masaje de espalda", "Masaje espalda", 2, osteopaths(:paco) ],
                 [ fusion.tipo, fusion.origen_nombre, fusion.destino_nombre, fusion.usos, fusion.osteopath ]
    assert_equal "Técnica", fusion.tipo_legible
  end

  test "fusionar enfermedades mueve sus diagnósticos" do
    lumbalgia = Disease.create!(nombre: "Lumbalgia", descripcion: "Dolor lumbar.")
    diagnoses(:diag_pepe).update!(disease: lumbalgia)

    fusion = FusionCatalogo.fusionar!(lumbalgia, diseases(:lumbago), osteopath: osteopaths(:paco))
    assert_equal diseases(:lumbago), diagnoses(:diag_pepe).reload.disease
    assert_not Disease.exists?(lumbalgia.id)
    assert_equal [ "enfermedad", 1 ], [ fusion.tipo, fusion.usos ]
  end

  test "si el destino no tiene descripción se queda con la del origen" do
    sin_descripcion = Treatment.create!(nombre: "Punción seca")
    con_descripcion = Treatment.create!(nombre: "Puncion seca", descripcion: "Agujas finas.")
    FusionCatalogo.fusionar!(con_descripcion, sin_descripcion, osteopath: nil)
    assert_equal "Agujas finas.", sin_descripcion.reload.descripcion
  end

  test "solo se fusionan entradas distintas del mismo catálogo" do
    assert_raises(ArgumentError) { FusionCatalogo.fusionar!(treatments(:masaje), treatments(:masaje), osteopath: nil) }
    assert_raises(ArgumentError) { FusionCatalogo.fusionar!(treatments(:masaje), diseases(:lumbago), osteopath: nil) }
  end

  test "si algo falla no se cambia nada (transacción)" do
    duplicada = Treatment.create!(nombre: "Masaje de espalda")
    sessions(:pepe_1).treatments << duplicada
    sustituir(FusionCatalogo, :create!, ->(*) { raise ActiveRecord::RecordInvalid }) do
      assert_raises(ActiveRecord::RecordInvalid) do
        FusionCatalogo.fusionar!(duplicada, treatments(:masaje), osteopath: nil)
      end
    end
    assert Treatment.exists?(duplicada.id)
    assert_includes sessions(:pepe_1).reload.treatments, duplicada
  end

  test "fusionar técnicas mueve también las sugeridas en los comentarios de los casos clínicos (D90)" do
    duplicada = Treatment.create!(nombre: "Estiramiento de columna")
    comentarios(:comentario_maria).treatments << duplicada # ya sugería Estiramiento columna
    otro = casos(:caso_pepe).comentarios.create!(osteopath: osteopaths(:maria), treatments: [ duplicada ])

    fusion = FusionCatalogo.fusionar!(duplicada, treatments(:estiramiento), osteopath: osteopaths(:paco))
    assert_equal [ treatments(:estiramiento) ], comentarios(:comentario_maria).reload.treatments
    assert_equal [ treatments(:estiramiento) ], otro.reload.treatments
    assert_equal 0, fusion.usos, "los usos son las sesiones"
  end
end
