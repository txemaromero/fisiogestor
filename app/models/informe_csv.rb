# CSV de un informe de técnicas (D80), pensado para abrirlo con Excel o LibreOffice en español: separador
# «;», coma decimal y UTF-8 con BOM (sin él, Excel no reconoce las tildes). Se escribe a mano, sin la gema
# csv, siguiendo RFC 4180: los textos van entre comillas y sus comillas se duplican.
#
# Inyección de CSV: un texto que empieza por =, +, -, @, tabulador o retorno se tomaría como fórmula al
# abrirlo en una hoja de cálculo; se le antepone un apóstrofo. Los números no llevan esa protección.
class InformeCsv
  SEPARADOR = ";".freeze
  FIN_DE_LINEA = "\r\n".freeze
  INICIO_DE_FORMULA = /\A[=+\-@\t\r]/

  def initialize(tipo, tecnicas)
    @tipo = tipo
    @tecnicas = tecnicas
  end

  def generar
    filas = [ cabecera ] + @tecnicas.each.with_index(1).map { |tecnica, posicion| fila(tecnica, posicion) }
    "﻿" + filas.map { |valores| valores.map { |valor| celda(valor) }.join(SEPARADOR) }.join(FIN_DE_LINEA) + FIN_DE_LINEA
  end

  private

  def frecuencia?
    @tipo == "mas_frecuentes"
  end

  def cabecera
    if frecuencia?
      [ "Posición", "Técnica", "Sesiones en las que se aplicó" ]
    else
      [ "Posición", "Técnica", "Reducción media del dolor", "Nº de sesiones", "Pocas sesiones" ]
    end
  end

  def fila(tecnica, posicion)
    if frecuencia?
      [ posicion, tecnica.nombre, tecnica.num_sesiones.to_i ]
    else
      [ posicion, tecnica.nombre, tecnica.reduccion_media&.to_d, tecnica.num_sesiones.to_i,
        tecnica.pocas_sesiones? ? "Sí" : "No" ]
    end
  end

  def celda(valor)
    case valor
    when nil then ""
    when Integer then valor.to_s
    when Numeric then format("%.2f", valor).tr(".", ",")
    else
      texto = valor.to_s
      texto = "'#{texto}" if texto.match?(INICIO_DE_FORMULA)
      %("#{texto.gsub('"', '""')}")
    end
  end
end
