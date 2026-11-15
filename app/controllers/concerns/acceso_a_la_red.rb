# Lo que es de otros osteópatas (sus pacientes en el filtro de tratamientos y en los informes de toda la
# plataforma, sus fichas, los casos clínicos y los perfiles) es solo para los osteópatas verificados y los
# administradores (D88, D94). A los demás, esas páginas les explican cómo conseguir la verificación.
module AccesoALaRed
  extend ActiveSupport::Concern

  included do
    before_action :exigir_acceso_a_la_red
  end

  private

  def exigir_acceso_a_la_red
    return if current_osteopath.acceso_a_la_red?

    redirect_to casos_path, alert: "Los datos de otros osteópatas son solo para osteópatas verificados."
  end

  # Lo que necesita la página de un caso (casos/show), también al volver a ella con un comentario con errores.
  def preparar_caso(caso)
    @caso = caso
    @grafica = GraficaDolor.de_caso(caso)
    @comentarios = caso.comentarios.includes(:osteopath, :treatments)
    @tecnicas = Treatment.order(:nombre)
    @comentario ||= Comentario.new
  end
end
