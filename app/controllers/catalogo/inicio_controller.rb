# /catalogo: las técnicas y enfermedades con sus usos y posibles duplicados, y las últimas fusiones.
class Catalogo::InicioController < Catalogo::BaseController
  def index
    # to_a: en una consulta con group, size y count devuelven un recuento por grupo, no el total.
    @tecnicas = Treatment.left_joins(:sessions).group(:id)
                         .select("treatments.*", "COUNT(sessions.id) AS usos").order(:nombre).to_a
    @enfermedades = Disease.left_joins(:diagnoses).group(:id)
                           .select("diseases.*", "COUNT(diagnoses.id) AS usos").order(:nombre).to_a
    @duplicados_tecnicas = Treatment.posibles_duplicados
    @duplicados_enfermedades = Disease.posibles_duplicados
    @fusiones = FusionCatalogo.includes(:osteopath).order(created_at: :desc, id: :desc).limit(20)
  end
end
