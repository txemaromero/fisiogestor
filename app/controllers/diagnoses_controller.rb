# Diagnósticos de una visita ya guardada: añadir otro (/visits/:visit_id/diagnoses/new), editarlo
# (/diagnoses/:id/edit) y borrarlo. Como en el asistente, la enfermedad se elige del catálogo o con
# «Otra…» se escribe una nueva.
class DiagnosesController < ApplicationController
  before_action :set_visit, only: %i[new create]
  before_action :set_diagnosis, only: %i[edit update destroy]
  before_action :cargar_enfermedades, only: %i[new create edit update]

  def new
    @diagnosis = @visit.diagnoses.new
  end

  def create
    @diagnosis = @visit.diagnoses.new
    if guardar
      redirect_to @visit, notice: "Diagnóstico añadido correctamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @eleccion = @diagnosis.disease_id.to_s
  end

  def update
    if guardar
      redirect_to @visit, notice: "Diagnóstico actualizado correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Borra también sus sesiones (las técnicas siguen en el catálogo).
  def destroy
    @diagnosis.destroy
    redirect_to @visit, notice: "Diagnóstico borrado.", status: :see_other
  end

  private

  # Solo las visitas y diagnósticos propios: los de otros osteópatas responden 404.
  def set_visit
    @visit = current_osteopath.visits.find(params[:visit_id])
  end

  def set_diagnosis
    @diagnosis = current_osteopath.diagnoses.find(params[:id])
    @visit = @diagnosis.visit
  end

  def cargar_enfermedades
    @diseases = Disease.order(:nombre)
  end

  # La enfermedad nueva (con «Otra…») y el diagnóstico se guardan en una transacción: si el diagnóstico
  # no es válido, tampoco se queda la enfermedad en el catálogo.
  def guardar
    datos = params.expect(diagnosis: %i[disease_id nueva_enfermedad descripcion sesiones_recomendadas])
    @eleccion = datos[:disease_id]
    @nueva_enfermedad = datos[:nueva_enfermedad]
    @diagnosis.assign_attributes(datos.slice(:descripcion, :sesiones_recomendadas))

    Diagnosis.transaction do
      @diagnosis.disease = Disease.elegida(@eleccion, @nueva_enfermedad, @diagnosis.descripcion)
      @diagnosis.save!
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    unless error.record == @diagnosis
      error.record.errors.full_messages.each { |mensaje| @diagnosis.errors.add(:base, "Enfermedad nueva: #{mensaje}") }
    end
    false
  end
end
