# Verificación de los profesionales (D88), solo para administradores: comprueban el número de colegiado
# de cada osteópata (en el registro de su colegio profesional) y lo verifican; solo los verificados
# entran en los casos clínicos.
#   GET    /verificaciones        pendientes (con número y sin verificar) y verificados
#   POST   /verificaciones/:id    verificar
#   DELETE /verificaciones/:id    quitar la verificación
class VerificacionesController < ApplicationController
  include SoloAdministradores

  before_action :set_osteopata, only: %i[create destroy]

  def index
    @pendientes = Osteopath.pendientes_de_verificar.order(:apellidos, :nombre)
    @verificados = Osteopath.verificados.includes(:verificado_por).order(:apellidos, :nombre)
    @sin_numero = Osteopath.where(numero_colegiado: nil).count
  end

  def create
    @osteopata.verificar!(por: current_osteopath)
    redirect_to verificaciones_path, status: :see_other, notice: "#{@osteopata.nombre_completo} está verificado."
  rescue ArgumentError
    redirect_to verificaciones_path, status: :see_other,
                                     alert: "#{@osteopata.nombre_completo} no tiene número de colegiado en su perfil."
  end

  def destroy
    @osteopata.quitar_verificacion!
    redirect_to verificaciones_path, status: :see_other,
                                     notice: "#{@osteopata.nombre_completo} ya no está verificado: no verá lo de otros osteópatas."
  end

  private

  def set_osteopata
    @osteopata = Osteopath.find(params[:id])
  end
end
