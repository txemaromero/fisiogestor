module VisitsHelper
  # "2 de 3 sesiones recomendadas" (o "1 de 1 sesión recomendada"), y las programadas si hay:
  # "2 de 3 sesiones recomendadas · 1 programada".
  def texto_progreso(diagnostico)
    recomendadas = diagnostico.sesiones_recomendadas
    texto = "#{diagnostico.sesiones_realizadas} de #{recomendadas} #{recomendadas == 1 ? 'sesión recomendada' : 'sesiones recomendadas'}"
    programadas = diagnostico.sesiones_programadas
    programadas.zero? ? texto : "#{texto} · #{programadas} #{programadas == 1 ? 'programada' : 'programadas'}"
  end

  # Barra de progreso del diagnóstico (sesiones realizadas), su texto y, si ya tiene las sesiones
  # recomendadas, «Completado» (con icono: el color nunca va solo).
  def progreso_sesiones(diagnostico)
    recomendadas = diagnostico.sesiones_recomendadas
    safe_join([
      tag.progress(value: [ diagnostico.sesiones_realizadas, recomendadas ].min, max: recomendadas,
                   class: "progreso-sesiones", aria: { label: texto_progreso(diagnostico) }),
      tag.span(texto_progreso(diagnostico), class: "small text-body-secondary"),
      (tag.span("✓ Completado", class: "badge text-bg-success") if diagnostico.completado?)
    ].compact, " ")
  end

  # Para la lista de visitas de la ficha: sesiones realizadas frente a recomendadas de todos sus
  # diagnósticos ("2 de 3"), o "—" si la visita no tiene diagnósticos.
  def progreso_visita(visita)
    return "—" if visita.diagnoses.empty?

    "#{visita.diagnoses.sum(&:sesiones_realizadas)} de #{visita.diagnoses.sum(&:sesiones_recomendadas)}"
  end
end
