# Páginas solo para los osteópatas administradores (D81): el catálogo, la verificación de los
# profesionales y la moderación. A los demás les responden 404, como si no existieran.
module SoloAdministradores
  extend ActiveSupport::Concern

  included do
    before_action :requiere_administrador
  end

  private

  def requiere_administrador
    raise ActiveRecord::RecordNotFound unless current_osteopath.admin?
  end
end
