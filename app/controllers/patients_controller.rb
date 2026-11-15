class PatientsController < ApplicationController
  # Cualquier osteópata puede ver un paciente de la plataforma que consiente compartir sus datos (llegando
  # desde el filtro de tratamientos, con un identificador firmado en la URL); la vista oculta nombre y
  # apellidos si no es suyo, y el acceso queda registrado (D85).
  before_action :set_patient, only: %i[show medical_background]
  # Solo el dueño puede editarlo, exportar sus datos o borrarlo: un paciente ajeno responde 404.
  before_action :set_patient_propio, only: %i[edit update destroy exportar]

  POR_PAGINA = 20

  # Lista de los pacientes propios, con buscador por nombre y apellidos (?busqueda=) y paginada (?pagina=).
  def index
    @busqueda = texto_param(:busqueda).to_s.squish.first(100)
    pacientes = current_osteopath.patients.buscar(@busqueda)
    @paginacion = Paginacion.new(pacientes.count, texto_param(:pagina), por_pagina: POR_PAGINA)
    @patients = @paginacion.aplicar(pacientes.order(:apellidos, :nombre, :id))
  end

  def show
    # Las visitas, la evolución del dolor y los accesos de otros osteópatas solo se muestran al osteópata del
    # paciente.
    if @patient.pertenece_a?(current_osteopath)
      @visits = @patient.visits.includes(diagnoses: %i[disease sessions]).order(fecha: :desc, id: :desc)
      @grafica = GraficaDolor.de(@patient)
      @accesos = @patient.accesos_fichas.includes(:osteopath).limit(AccesoFicha::ULTIMOS)
      @total_accesos = @patient.accesos_fichas.count
    else
      registrar_acceso("ficha")
    end
  end

  def medical_background
    registrar_acceso("antecedentes") unless @patient.pertenece_a?(current_osteopath)
  end

  # Todos los datos del paciente en un JSON (D86), para entregárselos si los pide.
  def exportar
    exportacion = ExportacionPaciente.new(@patient)
    response.headers["Cache-Control"] = "private, no-store"
    send_data exportacion.generar, filename: exportacion.nombre_fichero, type: "application/json", disposition: :attachment
  end

  def new
    @patient = current_osteopath.patients.build
  end

  def create
    @patient = current_osteopath.patients.build(patient_params)
    if @patient.save
      redirect_to @patient, notice: "Paciente creado correctamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: "Paciente actualizado correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @patient.destroy
    redirect_to patients_path, notice: "Paciente borrado.", status: :see_other
  end

  private

  def set_patient
    @patient = Patient.ficha(params[:id], current_osteopath)
  end

  def set_patient_propio
    @patient = current_osteopath.patients.find(params[:id])
  end

  def registrar_acceso(pagina)
    current_osteopath.accesos_fichas.create!(patient: @patient, pagina: pagina)
  end

  def patient_params
    params.require(:patient).permit(
      :nombre, :apellidos, :anyo_nacimiento, :sexo, :consiente_compartir,
      family_medical_backgrounds_attributes: %i[id familiar tipo descripcion _destroy],
      personal_medical_backgrounds_attributes: %i[id tipo descripcion _destroy]
    )
  end
end
