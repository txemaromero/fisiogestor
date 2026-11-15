# /informes: informes de efectividad de las técnicas. Los cálculos están en los métodos de clase de Treatment.
# Todos se pueden limitar a unas fechas y a los pacientes propios (D78), y descargar en CSV (D80). De los
# pacientes de otros osteópatas solo cuentan los que consienten compartir sus datos (D83).
class InformesController < ApplicationController
  TIPOS = {
    "mas_frecuentes" => "Técnicas realizadas con mayor frecuencia",
    "mas_efectivas" => "Técnicas más efectivas",
    "menos_efectivas" => "Técnicas menos efectivas",
    "cuadro_clinico" => "Técnicas posibles para un cuadro clínico"
  }.freeze

  AMBITOS = { "plataforma" => "Toda la plataforma", "mios" => "Mis pacientes" }.freeze

  def index
    @diseases = Disease.order(:nombre)
    @tipo = texto_param(:tipo).presence_in(TIPOS.keys)
    @sexo = sexo_param
    @edad_min = texto_param(:edad_min)
    @edad_max = texto_param(:edad_max)
    @ambito = if current_osteopath.acceso_a_la_red?
      texto_param(:ambito).presence_in(AMBITOS.keys) || "plataforma"
    else
      "mios" # sin verificar, solo los pacientes propios (D94)
    end
    @desde = fecha_param(:desde)
    @hasta = fecha_param(:hasta)
    @tecnicas = generar&.to_a if @tipo && fechas_validas?

    respond_to do |format|
      format.html
      format.csv do
        next head(:unprocessable_content) unless @tecnicas

        send_data InformeCsv.new(@tipo, @tecnicas).generar, type: "text/csv; charset=utf-8",
                                                            filename: "informe-#{@tipo.dasherize}-#{Date.current.iso8601}.csv"
      end
    end
  end

  private

  def generar
    case @tipo
    when "mas_frecuentes" then Treatment.mas_frecuentes(sesiones)
    when "mas_efectivas" then Treatment.mas_efectivas(sesiones)
    when "menos_efectivas" then Treatment.menos_efectivas(sesiones)
    when "cuadro_clinico" then cuadro_clinico
    end
  end

  def cuadro_clinico
    @disease = Disease.find_by(id: texto_param(:disease_id))
    if @disease
      Treatment.para_cuadro_clinico(@disease.id, sexo: @sexo, edad_min: @edad_min, edad_max: @edad_max, sesiones: sesiones)
    else
      flash.now[:alert] = "Elige la enfermedad del cuadro clínico."
      nil
    end
  end

  # Sesiones que cuentan: siempre solo las que puede ver el osteópata (D83), y con el resto de filtros.
  def sesiones
    Session.para_informe(visibles_para: current_osteopath, desde: @desde, hasta: @hasta,
                         osteopath: (current_osteopath if @ambito == "mios"))
  end

  # Fecha en formato ISO (la que envía un campo de fecha), o nil si no hay o no es válida.
  def fecha_param(clave)
    Date.iso8601(texto_param(clave).to_s)
  rescue Date::Error
    nil
  end

  def fechas_validas?
    return true unless @desde && @hasta && @desde > @hasta

    flash.now[:alert] = "La fecha «desde» es posterior a la fecha «hasta»."
    false
  end
end
