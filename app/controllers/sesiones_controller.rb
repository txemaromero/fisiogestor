# Sesiones de un diagnóstico ya guardado: añadir (/diagnoses/:diagnosis_id/sesiones/new), editar
# (/sesiones/:id/edit) y borrar. Se llama «sesiones» (y no «sessions») para no confundirlo con el
# controlador de login de Devise.
#
# Las técnicas llegan como una lista de filas { nombre, descripcion }: las del catálogo se reutilizan
# por su nombre y las nuevas se crean (la descripción solo se usa entonces). Al guardar, la sesión
# queda con exactamente esas técnicas; quitar una de la sesión no la borra del catálogo.
class SesionesController < ApplicationController
  MAX_TECNICAS = RegistroVisita::MAX_TECNICAS_POR_SESION

  before_action :set_diagnosis, only: %i[new create]
  before_action :set_sesion, only: %i[edit update destroy]
  before_action :cargar_catalogo, only: %i[new create edit update]

  def new
    @sesion = Session.new(diagnosis: @diagnosis, fecha: Date.current)
    @tecnicas = [ {} ]
  end

  def create
    @sesion = Session.new(diagnosis: @diagnosis)
    if guardar
      redirect_to @diagnosis.visit, notice: "Sesión añadida correctamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @tecnicas = @sesion.treatments.order(:nombre).map { |tecnica| { "nombre" => tecnica.nombre } }
  end

  def update
    if guardar
      redirect_to @diagnosis.visit, notice: "Sesión actualizada correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @sesion.destroy
    redirect_to @diagnosis.visit, notice: "Sesión borrada.", status: :see_other
  end

  private

  # Solo los diagnósticos y sesiones propios: los de otros osteópatas responden 404.
  def set_diagnosis
    @diagnosis = current_osteopath.diagnoses.find(params[:diagnosis_id])
  end

  def set_sesion
    @sesion = current_osteopath.sesiones.find(params[:id])
    @diagnosis = @sesion.diagnosis
  end

  def cargar_catalogo
    @nombres_tecnicas = Treatment.order(:nombre).pluck(:nombre)
  end

  def guardar
    datos = params.expect(sesion: [ :fecha, :escala_dolor_pre_sesion, :escala_dolor_post_sesion,
                                    tecnicas: [ %i[nombre descripcion] ] ])
    @tecnicas = Array(datos[:tecnicas]).map { |fila| { "nombre" => fila[:nombre].to_s, "descripcion" => fila[:descripcion].to_s } }
    @sesion.assign_attributes(datos.except(:tecnicas))
    return false unless tecnicas_validas?

    Session.transaction do
      @sesion.save!
      @sesion.treatments = tecnicas_rellenas.map { |fila| Treatment.buscar_o_crear!(fila["nombre"], fila["descripcion"]) }.uniq
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    unless error.record == @sesion
      error.record.errors.full_messages.each { |mensaje| @sesion.errors.add(:base, "Técnica: #{mensaje}") }
    end
    false
  end

  # Las filas que se dejan completamente vacías se ignoran (como los antecedentes del paciente).
  def tecnicas_rellenas
    @tecnicas.reject { |fila| fila["nombre"].blank? && fila["descripcion"].blank? }
  end

  def tecnicas_validas?
    return true if tecnicas_rellenas.size <= MAX_TECNICAS

    @sesion.errors.add(:base, "Una sesión admite como máximo #{MAX_TECNICAS} técnicas.")
    false
  end
end
