require "test_helper"

class InformeCsvTest < ActiveSupport::TestCase
  Tecnica = Struct.new(:nombre, :num_sesiones, :reduccion_media, keyword_init: true) do
    def pocas_sesiones? = num_sesiones < Treatment::MIN_SESIONES_FIABLE
  end

  def lineas(csv) = csv.delete_prefix("﻿").split("\r\n")

  test "empieza con BOM, separa con punto y coma y termina las líneas con CRLF" do
    csv = InformeCsv.new("mas_frecuentes", [ Tecnica.new(nombre: "Masaje", num_sesiones: 3) ]).generar
    assert csv.start_with?("﻿")
    assert csv.end_with?("\r\n")
    assert_equal [ '"Posición";"Técnica";"Sesiones en las que se aplicó"', '1;"Masaje";3' ], lineas(csv)
  end

  test "los decimales llevan coma y las comillas se duplican" do
    tecnica = Tecnica.new(nombre: 'Técnica "Plus"', num_sesiones: 6, reduccion_media: 2.666)
    assert_equal '1;"Técnica ""Plus""";2,67;6;"No"', lineas(InformeCsv.new("mas_efectivas", [ tecnica ]).generar).second
  end

  test "los textos que empiezan como una fórmula se protegen; los números negativos no" do
    tecnicas = [ "=HYPERLINK(\"http://x\")", "+1", "-2", "@SUMA(A1)", "\tTab" ].map do |nombre|
      Tecnica.new(nombre: nombre, num_sesiones: 1, reduccion_media: -1.5)
    end
    filas = lineas(InformeCsv.new("menos_efectivas", tecnicas).generar).drop(1)
    assert_equal [ '"\'=HYPERLINK(""http://x"")"', %("'+1"), %("'-2"), %("'@SUMA(A1)"), %("'\tTab") ],
                 filas.map { |fila| fila.split(";")[1] }
    assert(filas.all? { |fila| fila.split(";")[2] == "-1,50" })
  end

  test "una técnica sin media deja la celda vacía" do
    tecnica = Tecnica.new(nombre: "Sin escalas", num_sesiones: 2, reduccion_media: nil)
    assert_equal '1;"Sin escalas";;2;"Sí"', lineas(InformeCsv.new("cuadro_clinico", [ tecnica ]).generar).second
  end
end
