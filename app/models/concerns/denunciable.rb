# Lo que se puede denunciar: casos clínicos y comentarios (D91). Las denuncias se conservan aunque se borre
# el contenido (D97), con su autor, para que borrar no sirva para esquivar la moderación; las pendientes se
# cierran como «Contenido borrado».
module Denunciable
  extend ActiveSupport::Concern

  included do
    has_many :denuncias, as: :denunciable
    before_destroy :cerrar_denuncias_pendientes
  end

  private

  def cerrar_denuncias_pendientes
    denuncias.pendientes.update_all(resuelta_at: Time.current, resultado: "borrado", updated_at: Time.current)
  end
end
