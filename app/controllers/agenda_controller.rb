# Agenda del osteópata: sus sesiones a partir de hoy, agrupadas por día. Una sesión con fecha futura es
# una sesión programada (se crea desde la visita, con «Añadir sesión»).
class AgendaController < ApplicationController
  MAX_SESIONES = 200

  def index
    @hoy = Date.current
    @sesiones = current_osteopath.sesiones
                                 .where(fecha: @hoy..)
                                 .reorder(:fecha, :id)
                                 .includes(:treatments, diagnosis: [ :disease, :sessions, { visit: :patient } ])
                                 .limit(MAX_SESIONES)
    @dias = @sesiones.group_by(&:fecha)
  end
end
