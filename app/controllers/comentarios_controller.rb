# Comentarios de los casos clínicos, con técnicas del catálogo sugeridas (D90). Se comenta en los casos
# que ve el osteópata y que están compartidos; cada uno borra solo los suyos.
class ComentariosController < ApplicationController
  include AccesoALaRed

  rate_limit to: 20, within: 10.minutes, only: :create,
             with: -> { redirect_to casos_path, status: :see_other, alert: "Demasiados comentarios seguidos. Espera unos minutos." }

  def create
    caso = Caso.visibles_para(current_osteopath).find(params[:caso_id])
    unless caso.compartido?
      return redirect_to(caso, alert: "Este caso no está visible para los demás osteópatas: no admite comentarios.")
    end

    datos = params.expect(comentario: [ :texto, { treatment_ids: [] } ])
    @comentario = caso.comentarios.new(osteopath: current_osteopath, texto: datos[:texto])
    ids = Array(datos[:treatment_ids]).grep(String).first(Comentario::MAX_TECNICAS + 1)
    @comentario.treatments = Treatment.where(id: ids)
    if @comentario.save
      redirect_to caso_path(caso, anchor: "comentarios"), notice: "Comentario publicado."
    else
      preparar_caso(caso.reload)
      render "casos/show", status: :unprocessable_content
    end
  end

  def destroy
    comentario = current_osteopath.comentarios.find(params[:id])
    comentario.destroy
    redirect_to caso_path(comentario.caso, anchor: "comentarios"), notice: "Comentario borrado.", status: :see_other
  end
end
