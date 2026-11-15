require "test_helper"

class OsteopathTest < ActiveSupport::TestCase
  def nuevo_osteopata(**atributos)
    Osteopath.new({ nombre: "Ana", apellidos: "Ruiz", email: "ana@example.com",
                    password: "demo-123456", password_confirmation: "demo-123456" }.merge(atributos))
  end

  test "es válido con todos los datos" do
    assert nuevo_osteopata.valid?
  end

  test "al registrarse queda sin confirmar y no puede entrar hasta confirmar el email (D103)" do
    ana = nuevo_osteopata
    ana.save!
    assert_not ana.confirmed?
    assert_not ana.active_for_authentication?
    assert_equal :unconfirmed, ana.inactive_message

    ana.confirm
    assert ana.active_for_authentication?
  end

  test "nombre y apellidos son obligatorios" do
    osteopata = nuevo_osteopata(nombre: "", apellidos: nil)
    assert_not osteopata.valid?
    assert osteopata.errors.added?(:nombre, :blank)
    assert osteopata.errors.added?(:apellidos, :blank)
  end

  test "el email es obligatorio, único y con formato válido" do
    assert nuevo_osteopata(email: "").invalid?
    assert nuevo_osteopata(email: "no-es-un-email").invalid?
    assert nuevo_osteopata(email: "PACO@example.com").invalid?, "debe chocar con paco@example.com"
  end

  test "la clave necesita al menos 10 caracteres y confirmación" do
    assert nuevo_osteopata(password: "123456789", password_confirmation: "123456789").invalid?
    assert nuevo_osteopata(password_confirmation: "654321").invalid?
  end

  test "nombre completo" do
    assert_equal "Maria Campos Gil", osteopaths(:maria).nombre_completo
  end

  test "tiene pacientes y visitas" do
    paco = osteopaths(:paco)
    assert_equal %w[Juan María Pepe], paco.patients.map(&:nombre).sort
    assert_equal 3, paco.visits.count
  end

  # --- Segundo factor (D84) --------------------------------------------------------------------

  test "un osteópata nuevo no tiene el segundo factor activado" do
    assert_not nuevo_osteopata.otp_activado?
    assert osteopaths(:paco).otp_activado?
  end

  test "el secreto se guarda cifrado en la base de datos" do
    paco = osteopaths(:paco)
    en_la_base = Osteopath.connection.select_value("SELECT otp_secret FROM osteopaths WHERE id = #{paco.id}")
    assert_not_includes en_la_base, paco.otp_secret
    assert_equal "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP", paco.otp_secret
  end

  test "la dirección del QR lleva el emisor, el email y el secreto" do
    uri = Osteopath.uri_otp("JBSWY3DPEHPK3PXP", "paco@example.com")
    assert_match %r{\Aotpauth://totp/RedSocialFisios:paco%40example.com\?}, uri
    assert_includes uri, "secret=JBSWY3DPEHPK3PXP"
    assert_includes uri, "issuer=RedSocialFisios"
  end

  test "acepta el código actual y los de 30 segundos antes o después, pero no los de más lejos" do
    paco = osteopaths(:paco)
    assert Osteopath.paso_otp(paco.otp_secret, codigo_otp(paco))
    assert Osteopath.paso_otp(paco.otp_secret, codigo_otp(paco, 30.seconds.ago))
    assert Osteopath.paso_otp(paco.otp_secret, codigo_otp(paco, 30.seconds.from_now))
    assert_nil Osteopath.paso_otp(paco.otp_secret, codigo_otp(paco, 2.minutes.ago))
    assert_nil Osteopath.paso_otp(paco.otp_secret, codigo_otp(paco, 2.minutes.from_now))
  end

  test "solo acepta códigos de 6 cifras (con espacios, también)" do
    paco = osteopaths(:paco)
    codigo = codigo_otp(paco)
    assert Osteopath.paso_otp(paco.otp_secret, "#{codigo[0, 3]} #{codigo[3, 3]}")
    [ "", nil, "12345", "1234567", "abcdef", "#{codigo}\n1" ].each do |codigo_malo|
      assert_nil Osteopath.paso_otp(paco.otp_secret, codigo_malo), codigo_malo.inspect
    end
  end

  test "un código del login solo vale una vez, ni siquiera el mismo paso con otro código" do
    paco = osteopaths(:paco)
    travel_to Time.zone.local(2026, 10, 19, 12, 0, 15) do
      assert paco.verificar_otp(codigo_otp(paco))
      assert_not paco.verificar_otp(codigo_otp(paco)), "el mismo código otra vez"
      assert_not paco.verificar_otp(codigo_otp(paco, 30.seconds.ago)), "un código anterior"
      assert_not Osteopath.find(paco.id).verificar_otp(codigo_otp(paco)), "desde otra petición"
      assert paco.verificar_otp(codigo_otp(paco, 30.seconds.from_now)), "el siguiente sí"
    end
  end

  test "sin el segundo factor activado no se acepta ningún código" do
    paco = osteopaths(:paco)
    paco.restablecer_otp!
    assert_not paco.verificar_otp(codigo_otp(osteopaths(:maria)))
    assert_not paco.usar_codigo_recuperacion("abcde-fghjk")
  end

  test "activar el segundo factor con un código del secreto nuevo devuelve 10 códigos de recuperación" do
    osteopata = nuevo_osteopata
    osteopata.save!
    secreto = Osteopath.nuevo_secreto_otp
    assert_equal 32, secreto.size

    assert_nil osteopata.activar_otp!(secreto, "000000")
    assert_nil osteopata.activar_otp!(secreto, codigo_otp(osteopaths(:paco)))
    assert_not osteopata.reload.otp_activado?

    codigos = osteopata.activar_otp!(secreto, ROTP::TOTP.new(secreto).now)
    assert_equal 10, codigos.size
    assert codigos.all? { |codigo| codigo.match?(/\A[a-z2-9]{5}-[a-z2-9]{5}\z/) }
    assert_equal 10, codigos.uniq.size
    osteopata.reload
    assert osteopata.otp_activado?
    assert_equal 10, osteopata.codigos_recuperacion_restantes
    codigos.each { |codigo| assert_not_includes osteopata.codigos_recuperacion, codigo, "solo se guarda la huella" }
    assert_not osteopata.verificar_otp(ROTP::TOTP.new(secreto).now), "el código del alta ya está usado"
  end

  test "un código de recuperación sirve una sola vez, sin distinguir mayúsculas ni el guion" do
    paco = osteopaths(:paco)
    assert_equal 2, paco.codigos_recuperacion_restantes
    assert paco.usar_codigo_recuperacion("ABCDE FGHJK")
    assert_not paco.usar_codigo_recuperacion("abcde-fghjk")
    assert_equal 1, paco.reload.codigos_recuperacion_restantes
    assert_not paco.usar_codigo_recuperacion("zzzzz-zzzzz")
    assert_not paco.usar_codigo_recuperacion("mnpqr")
    assert paco.usar_codigo_recuperacion("mnpqrstuvw")
    assert_equal 0, paco.reload.codigos_recuperacion_restantes
  end

  test "regenerar los códigos de recuperación invalida los anteriores" do
    paco = osteopaths(:paco)
    codigos = paco.regenerar_codigos_recuperacion!
    assert_equal 10, paco.reload.codigos_recuperacion_restantes
    assert_not paco.usar_codigo_recuperacion("abcde-fghjk")
    assert paco.usar_codigo_recuperacion(codigos.first)
  end

  # --- Límite de códigos incorrectos (D92) ---------------------------------------------------------

  test "comprobar un código de acceso: de la app, de recuperación o incorrecto" do
    paco = osteopaths(:paco)
    travel_to Time.zone.local(2026, 10, 20, 10, 0, 10) do
      assert_equal :app, paco.comprobar_codigo_de_acceso(codigo_otp(paco))
      assert_equal :app, paco.comprobar_codigo_de_acceso(codigo_otp(paco, 30.seconds.from_now).insert(3, " "))
      assert_equal :recuperacion, paco.comprobar_codigo_de_acceso(" ABCDE-FGHJK ")
      assert_nil paco.comprobar_codigo_de_acceso("000000")
      assert_nil paco.comprobar_codigo_de_acceso(nil)
      assert_equal 2, paco.reload.otp_fallos
    end
  end

  test "cada 5 códigos incorrectos seguidos se bloquea la cuenta, cada vez el doble de tiempo y como mucho 24 h" do
    paco = osteopaths(:paco)
    inicio = Time.zone.local(2026, 10, 20, 10, 0, 10)
    travel_to(inicio) do
      4.times { assert_nil paco.comprobar_codigo_de_acceso("000000") }
      assert_not paco.otp_bloqueado?
      assert_equal :recien_bloqueado, paco.comprobar_codigo_de_acceso("000000")
      assert_equal inicio + 15.minutes, paco.reload.otp_bloqueado_hasta
      assert_equal :bloqueado, paco.comprobar_codigo_de_acceso(codigo_otp(paco)), "ni siquiera el código correcto"
      assert_equal :bloqueado, paco.comprobar_codigo_de_acceso("mnpqr-stuvw")
      assert_equal 2, paco.reload.codigos_recuperacion_restantes, "el código de recuperación no se gasta"
      assert_equal 5, paco.otp_fallos, "los intentos bloqueados no cuentan"
    end

    travel_to(inicio + 16.minutes) do
      4.times { paco.comprobar_codigo_de_acceso("000000") }
      assert_equal :recien_bloqueado, paco.comprobar_codigo_de_acceso("000000")
      assert_equal 30.minutes.from_now, paco.reload.otp_bloqueado_hasta
    end

    paco.update_columns(otp_fallos: 54, otp_bloqueado_hasta: nil)
    travel_to(inicio + 2.hours) do
      assert_equal :recien_bloqueado, paco.comprobar_codigo_de_acceso("000000")
      assert_equal 24.hours.from_now, paco.reload.otp_bloqueado_hasta
    end

    travel_to(inicio + 27.hours) do
      assert_equal :app, paco.comprobar_codigo_de_acceso(codigo_otp(paco))
      paco.reload
      assert_equal [ 0, nil ], [ paco.otp_fallos, paco.otp_bloqueado_hasta ]
    end
  end

  test "restablecer el segundo factor quita también el bloqueo" do
    paco = osteopaths(:paco)
    paco.update_columns(otp_fallos: 5, otp_bloqueado_hasta: 1.hour.from_now)
    paco.restablecer_otp!
    assert_equal [ 0, nil ], [ paco.reload.otp_fallos, paco.otp_bloqueado_hasta ]
  end

  test "restablecer el segundo factor lo deja sin activar y sin códigos" do
    paco = osteopaths(:paco)
    paco.restablecer_otp!
    paco.reload
    assert_not paco.otp_activado?
    assert_nil paco.otp_secret
    assert_equal 0, paco.codigos_recuperacion_restantes
  end

  # --- Perfil profesional y verificación (D87, D88) ------------------------------------------------

  test "el perfil es opcional, con longitudes máximas y un número de colegiado sin símbolos raros" do
    assert nuevo_osteopata(numero_colegiado: "28/09999", especialidad: "Pediátrica", ciudad: "Madrid").valid?
    assert nuevo_osteopata(numero_colegiado: "x" * 31).invalid?
    assert nuevo_osteopata(numero_colegiado: "<b>1</b>").invalid?
    assert nuevo_osteopata(especialidad: "x" * 101).invalid?
    assert nuevo_osteopata(presentacion: "x" * 1001).invalid?
    assert_nil nuevo_osteopata(numero_colegiado: "  ", ciudad: " ").tap(&:valid?).numero_colegiado
  end

  test "verificado: con número de colegiado y fecha de verificación" do
    maria = osteopaths(:maria)
    assert maria.verificado?
    assert maria.acceso_a_la_red?
    maria.quitar_verificacion!
    assert_not maria.verificado?
    assert_not maria.acceso_a_la_red?
    maria.verificar!
    assert maria.reload.verificado?
    assert_equal [ maria, osteopaths(:paco) ].sort, Osteopath.verificados.sort
  end

  test "no se puede verificar sin número de colegiado" do
    osteopata = nuevo_osteopata.tap(&:save!)
    assert_raises(ArgumentError) { osteopata.verificar! }
    assert_not_includes Osteopath.pendientes_de_verificar, osteopata
    osteopata.update!(numero_colegiado: "08-999")
    assert_includes Osteopath.pendientes_de_verificar, osteopata
  end

  test "cambiar el número de colegiado quita la verificación; cambiar el resto del perfil, no" do
    maria = osteopaths(:maria)
    maria.update!(ciudad: "Alicante", presentacion: "Hola")
    assert maria.verificado?
    maria.update!(numero_colegiado: "03-111")
    assert_not maria.reload.verificado?
    assert_includes Osteopath.pendientes_de_verificar, maria
  end

  # --- Identidad de los colegiados (D95) -----------------------------------------------------------

  test "un número de colegiado solo puede estar en una cuenta, sin contar espacios, signos ni mayúsculas" do
    osteopata = nuevo_osteopata(numero_colegiado: " 46 / 05678 ")
    assert osteopata.invalid?
    assert_includes osteopata.errors[:numero_colegiado], "ya está en otra cuenta: si es el tuyo, avisa a un administrador"
    assert nuevo_osteopata(numero_colegiado: "46-05679").valid?
    assert_equal "AB1234", nuevo_osteopata(numero_colegiado: "ab.12-34").tap(&:valid?).clave_colegiado
    assert_nil nuevo_osteopata(numero_colegiado: "").tap(&:valid?).clave_colegiado
    assert_raises(ActiveRecord::RecordNotUnique) do
      nuevo_osteopata(numero_colegiado: "4605678").save!(validate: false)
    end
  end

  test "se guarda quién verifica, y se quita con la verificación" do
    maria = osteopaths(:maria)
    maria.verificar!(por: osteopaths(:paco))
    assert_equal osteopaths(:paco), maria.reload.verificado_por
    maria.update!(numero_colegiado: "46-00001")
    assert_nil maria.reload.verificado_por
    maria.verificar!
    assert_nil maria.reload.verificado_por, "desde la consola no hay administrador"
  end

  # --- Sesiones revocables (D99) -----------------------------------------------------------------

  test "renovar el token de sesión cambia lo que Devise guarda en la cookie" do
    paco = osteopaths(:paco)
    antes = paco.authenticatable_salt
    assert_equal paco.encrypted_password[0, 29], antes, "sin token, el de siempre: las sesiones abiertas siguen valiendo"
    paco.renovar_token_sesion!
    assert_not_equal antes, paco.authenticatable_salt
    assert_match(/\A[0-9a-f]{32}\z/, paco.reload.token_sesion)
  end
end
