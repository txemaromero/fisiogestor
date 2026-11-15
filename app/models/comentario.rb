# Comentario de un caso clínico (D90): un texto, técnicas del catálogo sugeridas, o las dos cosas.
# La moderación puede ocultarlo (D91): entonces se muestra solo un aviso en su lugar.
class Comentario < ApplicationRecord
  include Denunciable

  MAX_TECNICAS = 10

  belongs_to :caso
  belongs_to :osteopath # quien lo escribe
  has_and_belongs_to_many :treatments, -> { order(:nombre) }

  validates :texto, length: { maximum: 2000 }
  validate :texto_o_tecnicas
  validate :maximo_de_tecnicas

  scope :visibles, -> { where(oculto_at: nil) }

  def oculto?
    oculto_at.present?
  end

  def autor?(osteopath)
    osteopath.present? && osteopath_id == osteopath.id
  end

  private

  def texto_o_tecnicas
    errors.add(:base, "Escribe un comentario o sugiere alguna técnica") if texto.blank? && treatments.empty?
  end

  def maximo_de_tecnicas
    errors.add(:treatments, "no pueden ser más de #{MAX_TECNICAS}") if treatments.size > MAX_TECNICAS
  end
end
