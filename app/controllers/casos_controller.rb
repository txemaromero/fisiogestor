# Casos clínicos anonimizados (D89):
#   GET  /casos                              los casos que ve el osteópata (o cómo conseguir la verificación)
#   GET  /casos/:id                          el caso, con sus comentarios y técnicas sugeridas
#   GET  /diagnoses/:diagnosis_id/caso/new   publicar un diagnóstico propio como caso
#   /casos/:id/edit, PATCH, DELETE           solo su autor
#   PATCH /casos/:id/republicar              su autor lo vuelve a publicar tras retirarse (D96)
class CasosController < ApplicationController
  include AccesoALaRed

  POR_PAGINA = 20

  skip_before_action :exigir_acceso_a_la_red, only: :index
  before_action :set_diagnostico, only: %i[new create]
  before_action :set_caso_propio, only: %i[edit update destroy republicar]

  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_to casos_path, status: :see_other, alert: "Has publicado muchos casos seguidos. Espera un rato." }

  # Más recientes primero, con filtro por enfermedad (?enfermedad=) y de 20 en 20 (?pagina=).
  def index
    return render(:sin_acceso) unless current_osteopath.acceso_a_la_red?

    visibles = Caso.visibles_para(current_osteopath)
    @diseases = Disease.where(id: visibles.select("diagnoses.disease_id")).order(:nombre)
    @enfermedad = @diseases.find { |disease| disease.id.to_s == texto_param(:enfermedad) }
    casos = visibles.de_enfermedad(@enfermedad&.id)
    @paginacion = Paginacion.new(casos.count, texto_param(:pagina), por_pagina: POR_PAGINA)
    @casos = @paginacion.aplicar(casos.recientes.includes(:osteopath, diagnosis: [ :disease, { visit: :patient } ]))
    @comentarios = Comentario.visibles.where(caso_id: @casos.map(&:id)).group(:caso_id).count
  end

  def show
    preparar_caso(Caso.visibles_para(current_osteopath).find(params[:id]))
  end

  # El formulario enseña lo que se va a publicar.
  def new
    @caso = Caso.new(diagnosis: @diagnostico, osteopath: current_osteopath)
    @grafica = GraficaDolor.de_caso(@caso)
  end

  def create
    @caso = Caso.new(caso_params.merge(diagnosis: @diagnostico, osteopath: current_osteopath))
    if @caso.save(context: :publicacion)
      redirect_to @caso, notice: "Caso clínico publicado."
    else
      @grafica = GraficaDolor.de_caso(@caso)
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    # Dos envíos a la vez del mismo formulario: el índice único deja publicar solo uno.
    redirect_to @diagnostico.reload.caso, notice: "Este diagnóstico ya está publicado como caso clínico."
  end

  def edit
  end

  def update
    @caso.assign_attributes(caso_params)
    if @caso.save(context: :publicacion)
      redirect_to @caso, notice: "Caso clínico actualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @caso.destroy
    redirect_to casos_path, notice: "Caso clínico borrado, con sus comentarios.", status: :see_other
  end

  # Vuelve a publicar un caso que se retiró porque el paciente retiró el consentimiento, si ha vuelto a
  # consentir (D96).
  def republicar
    if @caso.republicar!
      redirect_to @caso, notice: "El caso vuelve a estar publicado.", status: :see_other
    else
      redirect_to @caso, alert: "Solo se puede volver a publicar si el paciente ha vuelto a consentir.", status: :see_other
    end
  end

  private

  # Solo los diagnósticos propios (los ajenos responden 404), de pacientes que consienten y sin publicar.
  def set_diagnostico
    @diagnostico = current_osteopath.diagnoses.find(params[:diagnosis_id])
    if @diagnostico.caso
      redirect_to @diagnostico.caso, notice: "Este diagnóstico ya está publicado como caso clínico."
    elsif !@diagnostico.visit.patient.consiente_compartir?
      redirect_to visit_path(@diagnostico.visit),
                  alert: "Para publicarlo, el paciente tiene que consentir compartir sus datos (en su ficha, «Editar»)."
    end
  end

  def set_caso_propio
    @caso = current_osteopath.casos.find(params[:id])
  end

  def caso_params
    params.expect(caso: %i[titulo resumen confirmacion_anonimato])
  end
end
