require "test_helper"

class EntradaCatalogoTest < ActiveSupport::TestCase
  test "la clave de duplicado ignora tildes, mayúsculas, signos y palabras vacías" do
    assert_equal "masaje espalda", Treatment.new(nombre: "Masaje de la Espalda").clave_duplicado
    assert_equal "puncion seca", Treatment.new(nombre: "Punción  seca.").clave_duplicado
    assert_equal "hernia discal l4 l5", Disease.new(nombre: "Hernia discal L4-L5").clave_duplicado
  end

  test "posibles_duplicados agrupa las entradas que parecen la misma" do
    duplicada = Treatment.create!(nombre: "Masaje de espalda")
    duplicados = Treatment.posibles_duplicados
    assert_equal [ "Masaje de espalda" ], duplicados[treatments(:masaje).id]
    assert_equal [ "Masaje espalda" ], duplicados[duplicada.id]
    assert_nil duplicados[treatments(:hipopresivos).id]
    assert_empty Disease.posibles_duplicados
  end
end
