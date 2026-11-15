module AgendaHelper
  # Título de un día de la agenda: "Hoy, lunes 19 de octubre", "Mañana, martes 20 de octubre",
  # "Jueves 22 de octubre" (con el año si no es el actual).
  def dia_agenda(fecha, hoy = Date.current)
    formato = fecha.year == hoy.year ? "%A %-d de %B" : "%A %-d de %B de %Y"
    texto = l(fecha, format: formato)
    case fecha
    when hoy then "Hoy, #{texto}"
    when hoy + 1 then "Mañana, #{texto}"
    else texto.upcase_first
    end
  end
end
