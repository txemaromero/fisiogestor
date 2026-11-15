require "test_helper"

class DenunciaTest < ActiveSupport::TestCase
  def nueva_denuncia(**atributos)
    Denuncia.new({ osteopath: osteopaths(:maria), denunciable: casos(:caso_pepe), motivo: "Identifica al paciente" }.merge(atributos))
  end

  test "necesita un motivo de hasta 500 caracteres" do
    assert nueva_denuncia.valid?
    assert nueva_denuncia(motivo: "").invalid?
    assert nueva_denuncia(motivo: "x" * 501).invalid?
  end

  test "no se denuncia lo propio" do
    denuncia = nueva_denuncia(osteopath: osteopaths(:paco))
    assert denuncia.invalid?
    assert_includes denuncia.errors[:base], "No puedes denunciar lo que has escrito tú"
    assert Denuncia.new(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "Spam").valid?
  end

  test "cada osteópata denuncia un mismo contenido una sola vez" do
    nueva_denuncia.save!
    repetida = nueva_denuncia(motivo: "Otra vez")
    assert repetida.invalid?
    assert_includes repetida.errors[:base], "Ya has denunciado este contenido"
    assert_raises(ActiveRecord::RecordNotUnique) { repetida.save!(validate: false) }
  end

  test "solo se denuncian casos y comentarios" do
    assert nueva_denuncia(denunciable: patients(:juan)).invalid?
  end

  test "resolver ocultando oculta el contenido y resuelve todas sus denuncias pendientes" do
    caso = casos(:caso_pepe)
    nueva_denuncia.save!
    travel_to Time.zone.local(2026, 10, 19, 12) do
      Denuncia.resolver!(caso, "ocultado", osteopaths(:paco))
    end
    assert caso.reload.oculto?
    denuncia = caso.denuncias.sole
    assert_equal [ "ocultado", osteopaths(:paco), Time.zone.local(2026, 10, 19, 12) ],
                 [ denuncia.resultado, denuncia.resuelta_por, denuncia.resuelta_at ]
    assert_empty Denuncia.pendientes
    assert_equal "Contenido ocultado", denuncia.nombre_resultado
  end

  test "resolver descartando no oculta el contenido" do
    Denuncia.create!(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "Spam")
    Denuncia.resolver!(comentarios(:comentario_maria), "descartado", osteopaths(:paco))
    assert_not comentarios(:comentario_maria).reload.oculto?
    assert_equal "descartado", comentarios(:comentario_maria).denuncias.sole.resultado
    assert_raises(ArgumentError) { Denuncia.resolver!(casos(:caso_pepe), "borrado", osteopaths(:paco)) }
  end
end
