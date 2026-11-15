require "test_helper"

class GraficaBarrasTest < ActiveSupport::TestCase
  def fila(valor, etiqueta: "Técnica", fiable: true)
    GraficaBarras::Fila.new(etiqueta: etiqueta, valor: valor, texto_valor: valor.to_s, titulo: etiqueta, fiable: fiable)
  end

  test "la escala va del cero a un máximo redondo, en pasos de 1, 2 o 5" do
    grafica = GraficaBarras.new([ fila(4.5), fila(2.67), fila(1.0) ])
    assert_equal [ 0, 1, 5 ], [ grafica.minimo, grafica.paso, grafica.maximo ]
    assert_equal [ 0, 1, 2, 3, 4, 5 ], grafica.marcas.map(&:first)
    assert_equal grafica.izquierda, grafica.cero
    assert_equal [ 0, 2, 4, 6, 8, 10 ], GraficaBarras.new([ fila(9.0) ]).marcas.map(&:first)
  end

  test "con valores negativos el cero se desplaza a la derecha y la barra va hacia la izquierda" do
    grafica = GraficaBarras.new([ fila(3.0), fila(-2.0) ])
    assert_equal [ -2, 3 ], [ grafica.minimo, grafica.maximo ]
    assert_operator grafica.cero, :>, grafica.izquierda
    positiva, negativa = grafica.barras
    assert_not positiva.negativa
    assert negativa.negativa
    assert_equal "end", negativa.ancla_texto
    assert_operator negativa.x_texto, :<, grafica.cero
    assert grafica.negativas?
  end

  test "las barras tienen el extremo redondeado y la base recta, y una barra de cero no se dibuja" do
    barra = GraficaBarras.new([ fila(2.0) ]).barras.first
    assert_match(/\AM230(\.0)? \S+ H\S+ Q/, barra.ruta)
    assert_nil GraficaBarras.new([ fila(0.0), fila(1.0) ]).barras.first.ruta
  end

  test "como mucho 15 barras, y las etiquetas largas se acortan" do
    grafica = GraficaBarras.new(Array.new(20) { |i| fila(i.to_f + 1, etiqueta: "Técnica #{i}") })
    assert_equal 15, grafica.barras.size
    assert grafica.recortada?
    larga = GraficaBarras.new([ fila(1.0, etiqueta: "x" * 40) ]).barras.first
    assert_equal 30, larga.etiqueta_corta.size
    assert larga.etiqueta_corta.end_with?("…")
  end
end
