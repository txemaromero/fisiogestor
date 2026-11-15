# Prueba complementaria de una visita, con su fichero escaneado (PDF o imagen) en Active Storage.
# "escaneado" guarda el nombre del fichero: se toma del fichero subido. Las pruebas registradas antes de
# poder subir ficheros solo tienen el nombre, y siguen siendo válidas.
class SupplementaryTest < ApplicationRecord
  TEST_TYPE = { analitica: "analitica", rx: "rx", irm: "irm", otra: "otra" }.freeze

  # Tipos de fichero admitidos y los primeros bytes que debe tener cada uno: no basta con la extensión
  # o con el tipo que declare el navegador.
  FIRMAS_ARCHIVO = {
    "application/pdf" => "%PDF-".b,
    "image/jpeg" => "\xFF\xD8\xFF".b,
    "image/png" => "\x89PNG\r\n\x1A\n".b
  }.freeze
  MAX_ARCHIVO = 10.megabytes

  belongs_to :visit

  # El fichero se borra a la vez que la prueba (no en segundo plano): son datos de salud.
  has_one_attached :archivo, dependent: :purge

  # El enum valida los valores no vacíos; el vacío lo valida presence.
  enum :tipo_prueba, TEST_TYPE, validate: { allow_nil: true }

  before_validation :tomar_nombre_del_archivo

  validates :tipo_prueba, :resumen, presence: true
  validates :resumen, length: { maximum: 2000 }
  validate :archivo_valido

  # Solo el nombre del fichero, sin rutas: ni barras (/ o \), ni unidad (C:), ni caracteres de control
  # (saltos de línea, NUL...), ni empezar por punto (".."). Así no se podría usar para salir de una
  # carpeta si algún día se abre el fichero.
  NOMBRE_DE_RUTA = %r{[/\\:\p{Cc}]|\A\.}
  validates :escaneado, length: { maximum: 255 },
                        format: { without: NOMBRE_DE_RUTA, message: "debe ser solo el nombre del fichero, sin rutas" }

  # Si tiene un fichero guardado (en el formulario puede llegar otro que todavía no se ha guardado).
  def archivo_guardado?
    persisted? && ActiveStorage::Attachment.exists?(record: self, name: "archivo")
  end

  # "PDF", "JPG" o "PNG".
  def formato_archivo
    { "application/pdf" => "PDF", "image/jpeg" => "JPG", "image/png" => "PNG" }[archivo.blob&.content_type]
  end

  private

  # Al subir un fichero, su nombre (ya saneado por Active Storage) pasa a "escaneado".
  def tomar_nombre_del_archivo
    return unless attachment_changes["archivo"] && archivo.attached?

    self.escaneado = archivo.filename.sanitized.gsub(/\p{Cc}/, "").sub(/\A\.+/, "").last(255)
  end

  # Hace falta el fichero, salvo en las pruebas antiguas que solo tienen el nombre.
  def archivo_valido
    unless archivo.attached?
      errors.add(:archivo, :blank) if escaneado.blank?
      return
    end
    return unless attachment_changes["archivo"]

    if !FIRMAS_ARCHIVO.key?(archivo.blob.content_type) || !firma_correcta?
      errors.add(:archivo, "debe ser un PDF, JPG o PNG")
    elsif archivo.blob.byte_size > MAX_ARCHIVO
      errors.add(:archivo, "no puede ocupar más de #{MAX_ARCHIVO / 1.megabyte} MB")
    end
  end

  # Comprueba que el contenido empieza como corresponde a su tipo (el fichero aún no se ha guardado).
  def firma_correcta?
    subido = attachment_changes["archivo"].attachable
    io = subido.is_a?(Hash) ? subido[:io] : subido
    return true unless io.respond_to?(:read) && io.respond_to?(:rewind)

    io.rewind
    cabecera = io.read(8).to_s.b
    io.rewind
    cabecera.start_with?(FIRMAS_ARCHIVO.fetch(archivo.blob.content_type))
  end
end
