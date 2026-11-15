# Perfil profesional de un osteópata verificado (D87), con los casos que ha publicado: /osteopatas/:id.
# Solo para quienes entran en los casos clínicos; el de un osteópata sin verificar responde 404 (salvo el
# propio).
class OsteopatasController < ApplicationController
  include AccesoALaRed

  def show
    @osteopata = Osteopath.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @osteopata.verificado? || @osteopata == current_osteopath

    @casos = Caso.visibles_para(current_osteopath).where(osteopath: @osteopata).recientes.includes(diagnosis: :disease)
  end
end
