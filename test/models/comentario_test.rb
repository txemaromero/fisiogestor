require "test_helper"

class ComentarioTest < ActiveSupport::TestCase
  def nuevo_comentario(**atributos)
    Comentario.new({ caso: casos(:caso_pepe), osteopath: osteopaths(:maria) }.merge(atributos))
  end

  test "lleva un texto, técnicas sugeridas o las dos cosas" do
    assert nuevo_comentario(texto: "Probaría hipopresivos").valid?
    assert nuevo_comentario(treatments: [ treatments(:hipopresivos) ]).valid?
    comentario = nuevo_comentario(texto: " ")
    assert comentario.invalid?
    assert_includes comentario.errors[:base], "Escribe un comentario o sugiere alguna técnica"
  end

  test "el texto tiene un máximo de 2000 caracteres y se sugieren hasta 10 técnicas" do
    assert nuevo_comentario(texto: "x" * 2001).invalid?
    tecnicas = Array.new(11) { |i| Treatment.create!(nombre: "Técnica #{i}") }
    assert nuevo_comentario(treatments: tecnicas).invalid?
    assert nuevo_comentario(treatments: tecnicas.first(10)).valid?
  end

  test "autor? y oculto?" do
    comentario = comentarios(:comentario_maria)
    assert comentario.autor?(osteopaths(:maria))
    assert_not comentario.autor?(osteopaths(:paco))
    assert_not comentario.oculto?
    comentario.update!(oculto_at: Time.current)
    assert comentario.oculto?
    assert_empty Comentario.visibles
  end

  test "al borrar una técnica sin usos se quita de las sugerencias" do
    tecnica = Treatment.create!(nombre: "Punción seca")
    comentarios(:comentario_maria).treatments << tecnica
    tecnica.destroy
    assert_equal [ treatments(:estiramiento) ], comentarios(:comentario_maria).reload.treatments
  end

  test "al borrar un comentario denunciado, la denuncia se conserva y se cierra como borrado (D97)" do
    denuncia = Denuncia.create!(osteopath: osteopaths(:paco), denunciable: comentarios(:comentario_maria), motivo: "Spam")
    comentarios(:comentario_maria).destroy
    denuncia.reload
    assert_equal [ "borrado", osteopaths(:maria), "Contenido borrado" ],
                 [ denuncia.resultado, denuncia.autor_contenido, denuncia.nombre_resultado ]
  end
end
