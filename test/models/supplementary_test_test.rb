require "test_helper"

class SupplementaryTestTest < ActiveSupport::TestCase
  def prueba_nueva(**atributos)
    SupplementaryTest.new({ visit: visits(:visita_juan), tipo_prueba: "rx", resumen: "Rectificación lumbar" }.merge(atributos))
  end

  def fichero(nombre, como: nil)
    { io: file_fixture(nombre).open("rb"), filename: como || nombre } # en binario: en Windows, en modo texto se alteran
  end

  test "tipo de prueba, resumen y fichero son obligatorios" do
    prueba = SupplementaryTest.new(visit: visits(:visita_juan))
    assert_not prueba.valid?
    assert prueba.errors.key?(:tipo_prueba)
    assert prueba.errors.added?(:resumen, :blank)
    assert prueba.errors.added?(:archivo, :blank)
    assert_includes prueba.errors.full_messages, "Fichero escaneado no puede estar en blanco"
  end

  test "las pruebas antiguas que solo tienen el nombre del fichero siguen siendo válidas" do
    prueba = supplementary_tests(:irm_pepe)
    assert_not prueba.archivo.attached?
    assert prueba.valid?
  end

  test "admite PDF, JPG y PNG y toma el nombre del fichero" do
    { "informe.pdf" => "PDF", "foto.jpg" => "JPG", "radiografia.png" => "PNG" }.each do |nombre, formato|
      prueba = prueba_nueva(archivo: fichero(nombre))
      assert prueba.save, "#{nombre}: #{prueba.errors.full_messages.to_sentence}"
      assert_equal nombre, prueba.escaneado
      assert_equal formato, prueba.formato_archivo
      assert prueba.archivo_guardado?
    end
  end

  test "el nombre del fichero se sanea: sin rutas, caracteres de control ni punto inicial" do
    prueba = prueba_nueva(archivo: fichero("informe.pdf", como: "..\\informes/rx:1.pdf"))
    assert prueba.save, prueba.errors.full_messages.to_sentence
    assert_equal "-informes-rx-1.pdf", prueba.escaneado
    assert_no_match SupplementaryTest::NOMBRE_DE_RUTA, prueba.escaneado

    prueba = prueba_nueva(archivo: fichero("informe.pdf", como: ".oculto.pdf"))
    assert prueba.save
    assert_equal "oculto.pdf", prueba.escaneado
  end

  test "rechaza otros tipos de fichero aunque tengan la extensión de uno admitido" do
    prueba = prueba_nueva(archivo: fichero("falso.pdf")) # HTML con extensión .pdf
    assert_not prueba.valid?
    assert_includes prueba.errors.full_messages, "Fichero escaneado debe ser un PDF, JPG o PNG"

    # Un texto sin formato reconocible que el navegador declara como PDF: no empieza como un PDF.
    prueba = prueba_nueva(archivo: { io: StringIO.new("Solo texto"), filename: "nota.pdf", content_type: "application/pdf" })
    assert_equal "application/pdf", prueba.archivo.blob.content_type
    assert_not prueba.valid?
    assert_includes prueba.errors.full_messages, "Fichero escaneado debe ser un PDF, JPG o PNG"
  end

  test "el tipo lo decide el contenido: un PNG con nombre .pdf se guarda y se sirve como PNG" do
    prueba = prueba_nueva(archivo: { io: file_fixture("radiografia.png").open("rb"), filename: "informe.pdf",
                                     content_type: "application/pdf" })
    assert prueba.valid?
    assert_equal [ "image/png", "PNG" ], [ prueba.archivo.blob.content_type, prueba.formato_archivo ]
  end

  test "rechaza los ficheros de más de 10 MB" do
    grande = StringIO.new("%PDF-1.4\n".b + ("x" * SupplementaryTest::MAX_ARCHIVO))
    prueba = prueba_nueva(archivo: { io: grande, filename: "grande.pdf", content_type: "application/pdf" })
    assert_not prueba.valid?
    assert_includes prueba.errors.full_messages, "Fichero escaneado no puede ocupar más de 10 MB"
  end

  test "un fichero no válido no se guarda en el almacenamiento" do
    assert_no_difference %w[ActiveStorage::Blob.count SupplementaryTest.count] do
      prueba_nueva(archivo: fichero("falso.pdf")).save
    end
  end

  test "al borrar la prueba se borra su fichero" do
    prueba = prueba_nueva(archivo: fichero("informe.pdf"))
    prueba.save!
    assert_difference -> { ActiveStorage::Blob.count } => -1, -> { ActiveStorage::Attachment.count } => -1 do
      prueba.destroy
    end
  end

  test "el tipo de prueba es la enumeración test_type" do
    assert_equal %w[analitica rx irm otra], SupplementaryTest.tipo_pruebas.keys
    assert supplementary_tests(:irm_pepe).irm?
    assert_not prueba_nueva(tipo_prueba: "tac", archivo: fichero("informe.pdf")).valid?
  end
end
