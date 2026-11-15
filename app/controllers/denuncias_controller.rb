# Denunciar un caso clínico o un comentario (D91): POST /casos/:id/denuncia y /comentarios/:id/denuncia.
# El tipo lo fija la ruta, no la petición.
class DenunciasController < ApplicationController
  include AccesoALaRed

  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_to casos_path, status: :see_other, alert: "Demasiadas denuncias seguidas. Espera un rato." }

  def create
    denunciable = buscar_denunciable
    caso = denunciable.is_a?(Caso) ? denunciable : denunciable.caso
    denuncia = current_osteopath.denuncias.new(denunciable: denunciable, motivo: params.expect(denuncia: [ :motivo ])[:motivo])
    if denuncia.save
      redirect_to caso, notice: "Gracias: un administrador revisará la denuncia."
    else
      redirect_to caso, alert: "No se ha enviado la denuncia: #{denuncia.errors.full_messages.to_sentence}."
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to caso, alert: "Ya has denunciado este contenido."
  end

  private

  # Solo se denuncia lo que el osteópata puede ver.
  def buscar_denunciable
    casos = Caso.visibles_para(current_osteopath)
    case params[:tipo]
    when "caso" then casos.find(params[:id])
    when "comentario" then Comentario.where(caso: casos).find(params[:id])
    else raise ActiveRecord::RecordNotFound
    end
  end
end
