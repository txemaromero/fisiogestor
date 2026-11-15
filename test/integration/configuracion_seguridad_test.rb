require "test_helper"
require_relative "../../config/correo_smtp"

class ConfiguracionSeguridadTest < ActiveSupport::TestCase
  test "los datos personales y de salud no se escriben en los logs" do
    filtro = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtrado = filtro.filter(
      "patient" => {
        "nombre" => "Elena", "apellidos" => "Sanz", "anyo_nacimiento" => "1984", "sexo" => "mujer",
        "family_medical_backgrounds_attributes" => { "0" => { "familiar" => "Padre", "tipo" => "digestivos",
                                                              "descripcion" => "Colon irritable" } }
      },
      "visita" => { "patient_id" => "3", "anamnesis" => "Dolor lumbar", "escala_dolor" => "7",
                    "nueva_enfermedad" => "Escoliosis", "sesiones_json" => "[]" },
      "examination" => { "inspeccion_estatica" => "Escoliosis", "examen_neurologico_reflejos" => "Normales" },
      "supplementary_test" => { "resumen" => "Curva lumbar", "escaneado" => "rx_elena.jpg" },
      "commit" => "Crear"
    )

    paciente = filtrado["patient"]
    antecedente = paciente["family_medical_backgrounds_attributes"]["0"]
    valores = [ paciente.values_at("nombre", "apellidos", "anyo_nacimiento", "sexo"),
                antecedente.values_at("familiar", "tipo", "descripcion"),
                filtrado["visita"].values_at("anamnesis", "escala_dolor", "nueva_enfermedad", "sesiones_json"),
                filtrado["examination"].values, filtrado["supplementary_test"].values ].flatten
    assert valores.all?("[FILTERED]"), valores.inspect
    # Lo que no es sensible se sigue viendo, para poder depurar.
    assert_equal "3", filtrado["visita"]["patient_id"]
    assert_equal "Crear", filtrado["commit"]
  end

  test "la clave actual, los códigos del segundo factor y los textos de los casos no se escriben en los logs (D92)" do
    filtro = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtrado = filtro.filter(
      "clave" => "demo-123456", "codigo" => "123456", "codigo_actual" => "abcde-fghjk",
      "caso" => { "titulo" => "Lumbago", "resumen" => "Mejora poco" }, "comentario" => { "texto" => "Probaría…" },
      "denuncia" => { "motivo" => "Identifica al paciente" }
    )
    valores = [ filtrado.values_at("clave", "codigo", "codigo_actual"), filtrado["caso"].values,
                filtrado["comentario"].values, filtrado["denuncia"].values ].flatten
    assert valores.all?("[FILTERED]"), valores.inspect
  end

  test "las seeds se niegan a ejecutarse en producción" do
    sustituir(Rails, :env, -> { ActiveSupport::EnvironmentInquirer.new("production") }) do
      assert_no_difference "Osteopath.count" do
        assert_output(nil, /no se cargan en producción/) do
          assert_raises(SystemExit) { load Rails.root.join("db/seeds.rb").to_s }
        end
      end
    end
  end

  # --- Producción (D98) ------------------------------------------------------------------------

  test "Solid Cache guarda y cuenta en la tabla de la base de datos principal, como necesitan los límites de intentos" do
    cache = ActiveSupport::Cache.lookup_store(:solid_cache_store)
    # Solid Cache guarda en su caché de consultas lo que lee: hay que contar fuera de ella.
    assert_difference -> { SolidCache::Entry.uncached { SolidCache::Entry.count } } => 1 do
      assert_equal 1, cache.increment("rate-limit:prueba", 1, expires_in: 3.minutes)
    end
    assert_equal 2, cache.increment("rate-limit:prueba", 1, expires_in: 3.minutes)
    assert_equal 2, cache.read("rate-limit:prueba", raw: true).to_i
  end

  test "producción usa Solid Cache y, por defecto, Puma solo escucha en la propia máquina" do
    assert_match(/^  config\.cache_store = :solid_cache_store$/, Rails.root.join("config/environments/production.rb").read)
    assert_match(/bind ENV\.fetch\("BINDING"\) \{ "tcp:\/\/127\.0\.0\.1:/, Rails.root.join("config/puma.rb").read)
  end

  # La configuración de producción como la deja config/database.yml, con la URL y el modo que se quieran.
  def configuracion_bd(url: "postgres://usuario:clave@servidor:5432/red_social_fisios", sslmode: "require")
    { "production" => { "adapter" => "postgresql", "url" => url, "sslmode" => sslmode }.compact }
  end

  def comprobar_ssl(configuracion, entorno = {})
    ComprobacionesDeProduccion.ssl_de_la_base_de_datos!(configuracion, entorno)
  end

  # Cambia variables de entorno mientras dura el bloque (nil la quita) y después las deja como estaban.
  def con_entorno(variables)
    antes = variables.keys.index_with { |nombre| ENV[nombre] }
    variables.each { |nombre, valor| ENV[nombre] = valor }
    yield
  ensure
    antes.each { |nombre, valor| ENV[nombre] = valor }
  end

  test "en producción no se arranca con la base de datos sin cifrar, salvo que se permita a propósito" do
    %w[disable allow prefer].each do |modo|
      error = assert_raises(RuntimeError) { comprobar_ssl(configuracion_bd(sslmode: modo)) }
      assert_match(/sslmode=#{modo} .*sin cifrar: son datos de salud/, error.message)
    end
    assert_nil comprobar_ssl(configuracion_bd)
    assert_nil comprobar_ssl(configuracion_bd(sslmode: "verify-full"))
    assert_nil comprobar_ssl(configuracion_bd(sslmode: "disable"), "PERMITIR_BD_SIN_SSL" => "1")
  end

  test "el sslmode de DATABASE_URL manda sobre el de database.yml, y también se comprueba (D104)" do
    url = "postgres://usuario:clave@servidor:5432/red_social_fisios?sslmode=disable"
    error = assert_raises(RuntimeError) { comprobar_ssl(configuracion_bd(url: url)) }
    assert_match(/sslmode=disable/, error.message)
    assert_nil comprobar_ssl(configuracion_bd(url: url.sub("disable", "verify-full"), sslmode: "disable"))
  end

  test "sin sslmode en ningún sitio, PostgreSQL usaría PGSSLMODE o «prefer», que puede no cifrar (D104)" do
    assert_raises(RuntimeError) { comprobar_ssl(configuracion_bd(sslmode: nil)) }
    assert_nil comprobar_ssl(configuracion_bd(sslmode: nil), "PGSSLMODE" => "require")
  end

  test "la comprobación lee el config/database.yml de verdad, con PGSSLMODE y DATABASE_URL (D104)" do
    url = "postgres://usuario:clave@servidor:5432/red_social_fisios"
    con_entorno("DATABASE_URL" => url, "PGSSLMODE" => nil, "PERMITIR_BD_SIN_SSL" => nil) do
      assert_nil ComprobacionesDeProduccion.ssl_de_la_base_de_datos!
    end
    con_entorno("DATABASE_URL" => url, "PGSSLMODE" => "disable", "PERMITIR_BD_SIN_SSL" => nil) do
      assert_raises(RuntimeError) { ComprobacionesDeProduccion.ssl_de_la_base_de_datos! }
    end
    con_entorno("DATABASE_URL" => "#{url}?sslmode=disable", "PGSSLMODE" => nil, "PERMITIR_BD_SIN_SSL" => nil) do
      error = assert_raises(RuntimeError) { ComprobacionesDeProduccion.ssl_de_la_base_de_datos! }
      assert_match(/sslmode=disable/, error.message)
    end
  end

  test "el correo de producción va siempre cifrado: STARTTLS obligatorio, o TLS en el puerto 465 (D104)" do
    entorno = { "SMTP_ADDRESS" => "smtp.example.com", "SMTP_USER_NAME" => "app", "SMTP_PASSWORD" => "secreto" }

    ajustes = CorreoSmtp.ajustes(entorno)
    assert_equal [ "smtp.example.com", 587 ], ajustes.values_at(:address, :port)
    smtp = Mail::SMTP.new(ajustes).send(:build_smtp_session)
    assert smtp.starttls_always?, "STARTTLS tiene que ser obligatorio, no «si el servidor lo ofrece»"
    assert_not smtp.tls?

    smtp = Mail::SMTP.new(CorreoSmtp.ajustes(entorno.merge("SMTP_PORT" => "465"))).send(:build_smtp_session)
    assert smtp.tls?
    assert_not smtp.starttls?

    contexto = Mail::SMTP.new(ajustes).send(:ssl_context)
    assert_equal OpenSSL::SSL::VERIFY_PEER, contexto.verify_mode
    assert_match(/^    config\.action_mailer\.smtp_settings = CorreoSmtp\.ajustes$/,
                 Rails.root.join("config/environments/production.rb").read)
  end

  test "avisa si la carpeta de los ficheros escaneados la pueden leer otros usuarios" do
    carpeta = Rails.root.join("tmp").to_s
    sustituir(Gem, :win_platform?, -> { false }) do
      sustituir(File, :stat, ->(_ruta) { Struct.new(:mode).new(0o40755) }) do
        assert_match(/tiene permisos 755.*Deberían ser 700/, ComprobacionesDeProduccion.permisos_de_storage(carpeta))
      end
      sustituir(File, :stat, ->(_ruta) { Struct.new(:mode).new(0o40700) }) do
        assert_nil ComprobacionesDeProduccion.permisos_de_storage(carpeta)
      end
    end
    assert_nil ComprobacionesDeProduccion.permisos_de_storage(Rails.root.join("no-existe").to_s)
  end
end
