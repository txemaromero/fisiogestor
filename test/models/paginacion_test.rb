require "test_helper"

class PaginacionTest < ActiveSupport::TestCase
  test "calcula las páginas y la actual" do
    paginacion = Paginacion.new(45, "2", por_pagina: 20)
    assert_equal [ 3, 2 ], [ paginacion.paginas, paginacion.pagina ]
    assert paginacion.varias?
    assert_not paginacion.primera?
    assert_not paginacion.ultima?
  end

  test "una página fuera de rango o que no es un número se lleva a la más cercana" do
    assert_equal 3, Paginacion.new(45, "99", por_pagina: 20).pagina
    assert_equal 1, Paginacion.new(45, "-4", por_pagina: 20).pagina
    assert_equal 1, Paginacion.new(45, "abc", por_pagina: 20).pagina
    assert_equal 1, Paginacion.new(45, nil, por_pagina: 20).pagina
  end

  test "sin registros hay una sola página" do
    paginacion = Paginacion.new(0, "3")
    assert_equal [ 1, 1 ], [ paginacion.paginas, paginacion.pagina ]
    assert_not paginacion.varias?
  end

  test "aplicar devuelve los registros de la página" do
    paginacion = Paginacion.new(Patient.count, "2", por_pagina: 2)
    assert_equal Patient.order(:id).offset(2).limit(2).to_a, paginacion.aplicar(Patient.order(:id)).to_a
  end

  test "los números de página dejan huecos lejos de la actual" do
    assert_equal [ 1, 2, 3, 4, 5, 6, 7 ], Paginacion.new(140, "4", por_pagina: 20).numeros
    assert_equal [ 1, nil, 8, 9, 10, 11, 12, nil, 20 ], Paginacion.new(400, "10", por_pagina: 20).numeros
    assert_equal [ 1, 2, 3, nil, 20 ], Paginacion.new(400, "1", por_pagina: 20).numeros
  end
end
