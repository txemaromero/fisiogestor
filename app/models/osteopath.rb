class Osteopath < ApplicationRecord
  # Login con email y clave, registro, y validaciones de Devise: email obligatorio, único y con
  # formato válido; clave obligatoria de 10 a 128 caracteres (D92) y con confirmación.
  # timeoutable cierra la sesión tras 30 minutos sin actividad (config.timeout_in en devise.rb).
  # recoverable permite recuperar la clave con un enlace por email que caduca en una hora (D76).
  # confirmable obliga a confirmar el email con el enlace que llega al registrarse, antes de poder entrar; el
  # enlace caduca en 3 días (D103).
  devise :database_authenticatable, :registerable, :confirmable, :validatable, :timeoutable, :recoverable

  has_many :patients, dependent: :destroy
  has_many :visits, dependent: :destroy
  # Para buscar diagnósticos y sesiones solo entre los propios (los ajenos responden 404).
  has_many :diagnoses, through: :visits
  has_many :sesiones, through: :diagnoses, source: :sessions
  # Fichas de pacientes de otros osteópatas que ha abierto (D85).
  has_many :accesos_fichas, class_name: "AccesoFicha", dependent: :delete_all
  # Casos clínicos que ha publicado, sus comentarios en los casos y lo que ha denunciado (D89-D91).
  has_many :casos, dependent: :destroy
  has_many :comentarios, dependent: :destroy
  has_many :denuncias, dependent: :delete_all
  # El administrador que lo verificó (D95).
  belongs_to :verificado_por, class_name: "Osteopath", optional: true

  normalizes :numero_colegiado, :especialidad, :ciudad, with: ->(texto) { texto.squish.presence }

  validates :nombre, :apellidos, presence: true, length: { maximum: 100 }
  validates :numero_colegiado, length: { maximum: 30 },
                               format: { with: %r{\A[\p{Alnum} ./-]*\z}, message: "solo puede tener letras, números, espacios, puntos, guiones y barras" }
  validates :especialidad, :ciudad, length: { maximum: 100 }
  validates :presentacion, length: { maximum: 1000 }
  validate :numero_colegiado_unico

  # El número sin espacios, puntos, guiones, barras ni mayúsculas, para compararlo (D95). También al
  # guardar, por si se guarda sin validar.
  before_validation :calcular_clave_colegiado
  before_save :calcular_clave_colegiado
  # Lo verificado es el número de colegiado: si cambia, hay que volver a verificarlo (D88).
  before_save :quitar_verificacion, if: -> { persisted? && will_save_change_to_numero_colegiado? }

  def nombre_completo
    "#{nombre} #{apellidos}"
  end

  # --- Sesiones revocables (D99) --------------------------------------------------------------------
  # Devise guarda en la cookie de sesión este «salt» y lo compara en cada petición. Con el token de sesión
  # dentro, al cambiar el token (al cerrar sesión) dejan de valer todas las cookies anteriores, también una
  # copiada. Las sesiones de antes de existir el token (nil) siguen valiendo hasta el primer cierre.
  def authenticatable_salt
    "#{super}#{token_sesion}"
  end

  def renovar_token_sesion!
    update_column(:token_sesion, SecureRandom.hex(16))
  end

  # --- Confirmación del email con la clave (D104) ---------------------------------------------------
  # Abrir el enlace del correo no confirma nada: enseña un formulario que pide la clave de la cuenta. Así no
  # la confirma un clic sin querer, ni un antivirus que abre los enlaces del correo, ni el dueño del email
  # una cuenta que otro registró con su email (no sabe la clave).

  # La cuenta del enlace, sin confirmarla, con un error si el enlace no vale, ya se usó o ha caducado (los
  # mismos mensajes que Devise).
  def self.para_confirmar(token)
    osteopata = find_by(confirmation_token: token) if token.is_a?(String) && token.present?
    return new.tap { |nuevo| nuevo.errors.add(:confirmation_token, :invalid) } unless osteopata

    if osteopata.confirmed?
      osteopata.errors.add(:email, :already_confirmed)
    elsif osteopata.send(:confirmation_period_expired?)
      osteopata.errors.add(:email, :confirmation_period_expired,
                           period: Devise::TimeInflector.time_ago_in_words(confirm_within.ago))
    end
    osteopata
  end

  # Confirma el email si la clave es la de la cuenta. Si no, false con el error. (Devise vuelve a comprobar
  # al confirmar que no ha caducado ni estaba ya confirmado.)
  def confirmar_con_clave(clave)
    return confirm if clave.is_a?(String) && clave.present? && valid_password?(clave)

    errors.add(:base, "La clave no es la de esta cuenta. Escribe la que elegiste al registrarte.")
    false
  end

  # --- Perfil profesional y verificación (D87, D88, D95) --------------------------------------------
  # Un administrador comprueba el número de colegiado y el nombre en el registro de su colegio profesional
  # y lo verifica. Solo los verificados, y los administradores, ven lo de otros osteópatas (D94). Un mismo
  # número solo puede estar en una cuenta.

  scope :verificados, -> { where.not(verificado_at: nil).where.not(numero_colegiado: nil) }
  scope :pendientes_de_verificar, -> { where(verificado_at: nil).where.not(numero_colegiado: nil) }

  def verificado?
    verificado_at.present? && numero_colegiado.present?
  end

  def acceso_a_la_red?
    verificado? || admin?
  end

  # «por»: el administrador que lo verifica (nil desde la consola del servidor).
  def verificar!(por: nil)
    raise ArgumentError, "No tiene número de colegiado" if numero_colegiado.blank?

    update!(verificado_at: Time.current, verificado_por: por)
  end

  def quitar_verificacion!
    update!(verificado_at: nil, verificado_por: nil)
  end

  # --- Segundo factor de autenticación (D84) --------------------------------------------------------
  # Obligatorio para todos: códigos TOTP (RFC 6238) de una app de autenticación, de 6 cifras y 30 s,
  # con un paso de tolerancia antes y después por el desfase del reloj del móvil. Cada paso de tiempo
  # solo vale una vez. El secreto se guarda cifrado; de los códigos de recuperación, solo su huella.

  EMISOR_OTP = "RedSocialFisios".freeze
  TOLERANCIA_OTP = 30 # segundos
  NUM_CODIGOS_RECUPERACION = 10
  # Sin letras ni números que se confundan al copiarlos (i, l, o, 0, 1).
  ALFABETO_RECUPERACION = "abcdefghjkmnpqrstuvwxyz23456789".chars.freeze

  encrypts :otp_secret

  def otp_activado?
    otp_activado_at.present? && otp_secret.present?
  end

  # Secreto nuevo de 160 bits en base32, el formato que leen las apps de autenticación.
  def self.nuevo_secreto_otp
    ROTP::Base32.random
  end

  # Dirección otpauth:// que se codifica en el QR del alta.
  def self.uri_otp(secreto, email)
    ROTP::TOTP.new(secreto, issuer: EMISOR_OTP).provisioning_uri(email)
  end

  # Marca de tiempo del paso al que corresponde el código, o nil si no vale. Con «despues_de», solo valen
  # los pasos posteriores (así un código ya usado no se acepta otra vez).
  def self.paso_otp(secreto, codigo, despues_de: nil)
    limpio = codigo.to_s.gsub(/\s/, "")
    return unless secreto.present? && limpio.match?(/\A\d{6}\z/)

    ROTP::TOTP.new(secreto).verify(limpio, drift_behind: TOLERANCIA_OTP, drift_ahead: TOLERANCIA_OTP, after: despues_de)
  end

  # Comprueba un código del login y lo da por usado. La actualización es atómica: si llegan a la vez dos
  # peticiones con el mismo código, solo una lo consigue.
  def verificar_otp(codigo)
    return false unless otp_activado?

    paso = self.class.paso_otp(otp_secret, codigo, despues_de: otp_ultimo_paso)
    return false unless paso

    usado = self.class.where(id: id).where("otp_ultimo_paso IS NULL OR otp_ultimo_paso < ?", paso)
                .update_all(otp_ultimo_paso: paso)
    return false unless usado == 1

    # Ya está guardado: el objeto lo refleja sin quedar como un cambio pendiente.
    self.otp_ultimo_paso = paso
    clear_attribute_changes(%i[otp_ultimo_paso])
    true
  end

  # Da de alta (o cambia) el segundo factor si el código corresponde al secreto nuevo. Devuelve los códigos
  # de recuperación nuevos (para enseñarlos una sola vez) o nil si el código no vale.
  def activar_otp!(secreto, codigo)
    paso = self.class.paso_otp(secreto, codigo)
    return unless paso

    codigos = self.class.generar_codigos_recuperacion
    update!(otp_secret: secreto, otp_activado_at: Time.current, otp_ultimo_paso: paso,
            codigos_recuperacion: codigos.map { |codigo_nuevo| self.class.huella_codigo(codigo_nuevo) }.to_json)
    codigos
  end

  # Sin segundo factor: en el próximo login tendrá que darlo de alta otra vez (lo hace el administrador
  # del servidor si alguien pierde el móvil y los códigos de recuperación).
  def restablecer_otp!
    update!(otp_secret: nil, otp_activado_at: nil, otp_ultimo_paso: nil, codigos_recuperacion: nil,
            otp_fallos: 0, otp_bloqueado_hasta: nil)
  end

  # --- Límite de códigos incorrectos (D92) ---
  # Se cuenta por cuenta y en la base de datos, venga de la sesión o de la IP que venga: así no se puede
  # probar códigos sin fin. Cada 5 incorrectos seguidos, la cuenta no acepta códigos durante un tiempo que
  # se dobla cada vez (15 min, 30 min, 1 h... hasta 24 h). Un código correcto pone la cuenta a cero.

  MAX_FALLOS_OTP = 5
  BLOQUEO_OTP = 15.minutes
  BLOQUEO_OTP_MAXIMO = 24.hours

  def otp_bloqueado?
    otp_bloqueado_hasta&.future? || false
  end

  # Comprueba un código de acceso: los 6 dígitos de la app o un código de recuperación. Devuelve :app,
  # :recuperacion, :bloqueado (la cuenta no acepta códigos ahora, ni siquiera el correcto), :recien_bloqueado
  # (este código incorrecto ha hecho que se bloquee) o nil (incorrecto).
  def comprobar_codigo_de_acceso(codigo)
    return :bloqueado if otp_bloqueado?

    limpio = codigo.to_s.gsub(/\s/, "")
    tipo = if limpio.match?(/\A\d{6}\z/)
      :app if verificar_otp(limpio)
    elsif usar_codigo_recuperacion(limpio)
      :recuperacion
    end
    return limpiar_fallos_otp! && tipo if tipo

    anotar_fallo_otp! ? :recien_bloqueado : nil
  end

  # Avisa por correo de un cambio en el acceso a la cuenta (D93; tipos en AvisosSeguridadMailer::AVISOS).
  # Si el correo falla en producción, se anota en el log y la acción sigue: no debe impedir entrar.
  def avisar(tipo, detalle: nil)
    AvisosSeguridadMailer.with(osteopata: self, detalle: detalle).public_send(tipo).deliver_now
  rescue StandardError => error
    raise if Rails.env.local?

    Rails.logger.error("No se ha podido enviar el aviso #{tipo} al osteópata #{id}: #{error.class}")
  end

  # --- Códigos de recuperación ---
  # Diez códigos de un solo uso para entrar sin el móvil. Se guarda su HMAC con una clave derivada de
  # secret_key_base: con la base de datos sola no se pueden obtener.

  def self.generar_codigos_recuperacion
    Array.new(NUM_CODIGOS_RECUPERACION) do
      Array.new(10) { ALFABETO_RECUPERACION[SecureRandom.random_number(ALFABETO_RECUPERACION.size)] }.join.insert(5, "-")
    end
  end

  def self.huella_codigo(codigo)
    clave = Rails.application.key_generator.generate_key("osteopath/codigos_recuperacion", 32)
    OpenSSL::HMAC.hexdigest("SHA256", clave, codigo.to_s.downcase.gsub(/[^a-z0-9]/, ""))
  end

  def codigos_recuperacion_restantes
    JSON.parse(codigos_recuperacion.presence || "[]").size
  end

  def regenerar_codigos_recuperacion!
    codigos = self.class.generar_codigos_recuperacion
    update!(codigos_recuperacion: codigos.map { |codigo| self.class.huella_codigo(codigo) }.to_json)
    codigos
  end

  # Usa un código de recuperación (y lo borra). Con bloqueo, para que no sirva dos veces a la vez.
  def usar_codigo_recuperacion(codigo)
    return false unless otp_activado? && codigo.to_s.gsub(/[^a-zA-Z0-9]/, "").size == 10

    huella = self.class.huella_codigo(codigo)
    with_lock do
      huellas = JSON.parse(codigos_recuperacion.presence || "[]")
      encontrada = huellas.find { |guardada| ActiveSupport::SecurityUtils.secure_compare(guardada, huella) }
      next false unless encontrada

      update!(codigos_recuperacion: (huellas - [ encontrada ]).to_json)
      true
    end
  end

  private

  # Suma un fallo (de forma atómica) y, al llegar a un múltiplo de 5, bloquea los códigos. Devuelve si ha
  # bloqueado.
  def anotar_fallo_otp!
    self.class.where(id: id).update_all("otp_fallos = otp_fallos + 1")
    self.otp_fallos = self.class.where(id: id).pick(:otp_fallos)
    return false unless (otp_fallos % MAX_FALLOS_OTP).zero?

    duracion = [ BLOQUEO_OTP * 2**(otp_fallos / MAX_FALLOS_OTP - 1), BLOQUEO_OTP_MAXIMO ].min
    update_columns(otp_bloqueado_hasta: duracion.from_now)
    true
  end

  def limpiar_fallos_otp!
    self.class.where(id: id).update_all(otp_fallos: 0, otp_bloqueado_hasta: nil)
    self.otp_fallos = 0
    self.otp_bloqueado_hasta = nil
    true
  end

  def quitar_verificacion
    self.verificado_at = nil
    self.verificado_por = nil
  end

  def calcular_clave_colegiado
    self.clave_colegiado = numero_colegiado&.upcase&.gsub(/[^[:alnum:]]/, "").presence
  end

  # También lo impide el índice único (si dos cuentas lo guardan a la vez).
  def numero_colegiado_unico
    return if clave_colegiado.blank?

    repetido = self.class.where(clave_colegiado: clave_colegiado).where.not(id: id).exists?
    errors.add(:numero_colegiado, "ya está en otra cuenta: si es el tuyo, avisa a un administrador") if repetido
  end
end
