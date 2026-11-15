require "test_helper"

class AvisosSeguridadMailerTest < ActionMailer::TestCase
  test "cada aviso va al osteópata, desde el remitente de la aplicación, con texto y HTML" do
    paco = osteopaths(:paco)
    AvisosSeguridadMailer::AVISOS.each do |tipo, aviso|
      correo = AvisosSeguridadMailer.with(osteopata: paco).public_send(tipo)
      assert_equal [ "paco@example.com" ], correo.to, tipo
      assert_equal [ Devise.mailer_sender[/<(.+)>/, 1] ], correo.from, tipo
      assert_equal "#{aviso[:asunto]} · RedSocialFisios", correo.subject
      assert_match "Hola, Paco:", correo.text_part.body.to_s
      assert_match aviso[:texto], correo.text_part.body.to_s.squish
      assert_match "http://example.com/osteopaths/password/new", correo.text_part.body.to_s
      assert_match "cámbiala ahora", correo.html_part.body.to_s
    end
  end

  test "el detalle y la fecha aparecen en el aviso" do
    travel_to Time.zone.local(2026, 10, 20, 10, 5) do
      correo = AvisosSeguridadMailer.with(osteopata: osteopaths(:paco), detalle: "Te quedan 1 códigos de recuperación.")
                                    .entrada_con_codigo_de_recuperacion
      texto = correo.text_part.body.to_s
      assert_match "Te quedan 1 códigos de recuperación.", texto
      assert_match "Fecha: 20/10/2026 a las 10:05.", texto
    end
  end

  test "el aviso no contiene códigos ni la clave" do
    correo = AvisosSeguridadMailer.with(osteopata: osteopaths(:paco)).codigos_regenerados
    assert_no_match(/[a-z2-9]{5}-[a-z2-9]{5}/, correo.text_part.body.to_s)
    assert_no_match "demo-123456", correo.text_part.body.to_s
  end
end
