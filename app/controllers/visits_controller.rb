class VisitsController < ApplicationController
  before_action :cargar_catalogos, only: %i[new create]
  # Solo las visitas propias: las de otros osteópatas responden 404.
  before_action :set_visit, only: %i[show edit update destroy informe]

  def new
    # Desde la ficha de un paciente se llega con ?patient_id= para dejarlo preseleccionado.
    @registro = RegistroVisita.new(patient_id: params[:patient_id])
  end

  def create
    @registro = RegistroVisita.new(registro_params)
    @registro.osteopath = current_osteopath

    if @registro.guardar
      redirect_to @registro.visita.patient, notice: "Visita guardada correctamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Resumen de una visita, con sus diagnósticos y sesiones.
  def show
  end

  # Datos de la propia visita (el paciente no se cambia); diagnósticos y sesiones tienen sus formularios.
  def edit
  end

  def update
    if @visit.update(visit_params)
      redirect_to @visit, notice: "Visita actualizada correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Informe de la visita para el paciente, con un diseño claro para imprimir o guardar como PDF desde el
  # navegador (layout «informe», sin barra de navegación).
  def informe
    @grafica = GraficaDolor.de_visita(@visit)
    render layout: "informe"
  end

  # Borra también sus diagnósticos, sesiones, exploración y pruebas complementarias.
  def destroy
    @visit.destroy
    redirect_to @visit.patient, notice: "Visita borrada.", status: :see_other
  end

  private

  def set_visit
    @visit = current_osteopath.visits.find(params[:id])
  end

  def registro_params
    params.require(:visita).permit(:patient_id, :anamnesis, :escala_dolor, :disease_id, :nueva_enfermedad,
                                   :descripcion, :sesiones_recomendadas, :sesiones_json)
  end

  def visit_params
    params.expect(visit: %i[fecha motivo anamnesis escala_dolor])
  end

  def cargar_catalogos
    @patients = current_osteopath.patients.order(:apellidos, :nombre)
    @diseases = Disease.order(:nombre)
    @nombres_tecnicas = Treatment.order(:nombre).pluck(:nombre)
  end
end
