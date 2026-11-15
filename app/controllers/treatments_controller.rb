class TreatmentsController < ApplicationController
  # Máximo de técnicas (en /tecnicas_aplicadas) o de dolencias (en el filtro) que se aceptan a la vez.
  MAX_IDS = 100

  # /filtrar_tratamientos: diagnósticos de toda la plataforma (de cualquier osteópata) que cumplen el
  # perfil de paciente indicado. Los resultados solo se calculan al pulsar «Mostrar tratamientos».
  # De los pacientes de otros osteópatas solo salen los que consienten compartir sus datos (D83).
  def filtrar
    # Sin verificar no se ven los pacientes de otros osteópatas (D94): la página explica cómo conseguirlo.
    return render(:sin_acceso) unless current_osteopath.acceso_a_la_red?

    @diseases = Disease.order(:nombre)
    @sexo = sexo_param
    @edad_min = texto_param(:edad_min)
    @edad_max = texto_param(:edad_max)
    @dolencias = lista_param(:dolencias).first(MAX_IDS)
    return unless params.key?(:sexo)

    @diagnoses = Diagnosis.filtrar(sexo: @sexo, edad_min: @edad_min, edad_max: @edad_max, dolencias: @dolencias)
                          .visibles_para(current_osteopath)
                          .joins(:disease)
                          .order("diseases.nombre", :id)
                          .preload(:disease, visit: :patient, sessions: :treatments)
  end

  # /tecnicas_aplicadas?ids[]=…: las técnicas indicadas (sin decir en qué sesión se aplicó cada una).
  def aplicadas
    @treatments = Treatment.where(id: lista_param(:ids).first(MAX_IDS)).order(:nombre)
    # «Volver» regresa a la página anterior solo si es de esta misma aplicación.
    @volver = url_from(request.referer) || filtrar_tratamientos_path
  end
end
