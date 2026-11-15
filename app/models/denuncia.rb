# Denuncia de un caso clínico o de un comentario (D91). Cualquier osteópata con acceso a los casos puede
# denunciar lo que han escrito otros, una vez por contenido. Los administradores la resuelven ocultando el
# contenido o descartándola; se guarda quién la resolvió, cuándo y cómo. Si el contenido se borra, la
# denuncia se conserva con su autor y se cierra como «Contenido borrado» (D97).
class Denuncia < ApplicationRecord
  TIPOS = { "caso" => "Caso", "comentario" => "Comentario" }.freeze
  RESULTADOS = { "ocultado" => "Contenido ocultado", "descartado" => "Descartada", "borrado" => "Contenido borrado" }.freeze

  belongs_to :osteopath # quien denuncia
  # Puede ya no existir (D97).
  belongs_to :denunciable, polymorphic: true, optional: true
  belongs_to :autor_contenido, class_name: "Osteopath", optional: true
  belongs_to :resuelta_por, class_name: "Osteopath", optional: true

  before_validation(on: :create) { self.autor_contenido_id = denunciable&.osteopath_id }

  validates :denunciable, presence: true, on: :create
  validates :motivo, presence: true, length: { maximum: 500 }
  validates :denunciable_type, inclusion: { in: TIPOS.values }
  validates :resultado, inclusion: { in: RESULTADOS.keys }, allow_nil: true
  validate :no_es_propio
  validate :una_por_osteopata

  scope :pendientes, -> { where(resuelta_at: nil) }

  # Resuelve todas las denuncias pendientes de un contenido: «ocultado» lo oculta, «descartado» lo deja.
  def self.resolver!(denunciable, resultado, administrador)
    raise ArgumentError, "Resultado desconocido: #{resultado}" unless %w[ocultado descartado].include?(resultado)

    transaction do
      denunciable.update!(oculto_at: Time.current) if resultado == "ocultado"
      denunciable.denuncias.pendientes.update_all(resuelta_at: Time.current, resuelta_por_id: administrador.id,
                                                  resultado: resultado, updated_at: Time.current)
    end
  end

  def nombre_resultado
    RESULTADOS[resultado]
  end

  private

  def no_es_propio
    errors.add(:base, "No puedes denunciar lo que has escrito tú") if denunciable && denunciable.osteopath_id == osteopath_id
  end

  # También lo impide el índice único (si llegan dos a la vez).
  def una_por_osteopata
    return unless denunciable && osteopath_id

    repetida = self.class.where(osteopath_id: osteopath_id, denunciable: denunciable).where.not(id: id).exists?
    errors.add(:base, "Ya has denunciado este contenido") if repetida
  end
end
