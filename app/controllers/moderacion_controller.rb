# Moderación de los casos clínicos y sus comentarios (D91), solo para administradores:
#   GET  /moderacion                              denuncias pendientes, contenido oculto y últimas resueltas
#   POST /moderacion/:tipo/:id/ocultar            oculta el contenido y resuelve sus denuncias
#   POST /moderacion/:tipo/:id/descartar          resuelve sus denuncias sin ocultarlo
#   POST /moderacion/:tipo/:id/mostrar            vuelve a mostrar un contenido oculto
class ModeracionController < ApplicationController
  include SoloAdministradores

  TIPOS = { "caso" => Caso, "comentario" => Comentario }.freeze

  def index
    # Las de contenido ya borrado se cierran al borrarlo (D97); por si acaso, no se agrupan aquí.
    @pendientes = Denuncia.pendientes.includes(:osteopath, :denunciable).order(:created_at).group_by(&:denunciable).except(nil)
    @casos_ocultos = Caso.where.not(oculto_at: nil).includes(:osteopath).order(oculto_at: :desc)
    @comentarios_ocultos = Comentario.where.not(oculto_at: nil).includes(:osteopath, :caso).order(oculto_at: :desc)
    @resueltas = Denuncia.where.not(resuelta_at: nil).includes(:osteopath, :resuelta_por, :autor_contenido, :denunciable)
                         .order(resuelta_at: :desc, id: :desc).limit(20)
  end

  def ocultar
    Denuncia.resolver!(contenido, "ocultado", current_osteopath)
    redirect_to moderacion_path, status: :see_other, notice: "Contenido ocultado: solo lo ven su autor y los administradores."
  end

  def descartar
    Denuncia.resolver!(contenido, "descartado", current_osteopath)
    redirect_to moderacion_path, status: :see_other, notice: "Denuncias descartadas: el contenido sigue visible."
  end

  def mostrar
    contenido.update!(oculto_at: nil)
    redirect_to moderacion_path, status: :see_other, notice: "El contenido vuelve a estar visible."
  end

  private

  def contenido
    @contenido ||= TIPOS.fetch(params[:tipo]) { raise ActiveRecord::RecordNotFound }.find(params[:id])
  end
end
