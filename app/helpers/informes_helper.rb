module InformesHelper
  # Filas de la gráfica de un informe: en el de frecuencia, el número de sesiones; en los de efectividad,
  # la reducción media (las técnicas sin ninguna sesión con las dos escalas no tienen media y no se dibujan).
  def grafica_informe(tipo, tecnicas)
    filas = tecnicas.filter_map do |tecnica|
      sesiones = pluralize(tecnica.num_sesiones.to_i, "sesión", plural: "sesiones")
      if tipo == "mas_frecuentes"
        GraficaBarras::Fila.new(etiqueta: tecnica.nombre, valor: tecnica.num_sesiones.to_f, fiable: true,
                                texto_valor: tecnica.num_sesiones.to_s, titulo: "#{tecnica.nombre}: #{sesiones}")
      elsif tecnica.reduccion_media
        valor = tecnica.reduccion_media.to_f
        GraficaBarras::Fila.new(etiqueta: tecnica.nombre, valor: valor, fiable: !tecnica.pocas_sesiones?,
                                texto_valor: reduccion_dolor(valor),
                                titulo: "#{tecnica.nombre}: reducción media de #{reduccion_dolor(valor)} en #{sesiones}")
      end
    end
    GraficaBarras.new(filas)
  end

  # Resumen de los filtros comunes: "Mis pacientes · del 1/1/2026 al 30/6/2026".
  def filtros_informe(ambito, desde, hasta)
    partes = [ InformesController::AMBITOS.fetch(ambito) ]
    partes << "desde el #{l(desde)}" if desde && !hasta
    partes << "hasta el #{l(hasta)}" if hasta && !desde
    partes << "del #{l(desde)} al #{l(hasta)}" if desde && hasta
    partes.join(" · ")
  end

  # Parámetros del informe actual, para el enlace de descarga en CSV.
  def parametros_informe
    { tipo: @tipo, ambito: @ambito, desde: @desde&.iso8601, hasta: @hasta&.iso8601 }.tap do |parametros|
      if @tipo == "cuadro_clinico"
        parametros.merge!(disease_id: @disease&.id, sexo: @sexo, edad_min: @edad_min, edad_max: @edad_max)
      end
    end.compact_blank
  end
end
