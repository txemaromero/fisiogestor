module ModeracionHelper
  # El caso de un contenido denunciado u oculto: el propio caso o el del comentario.
  def caso_de(contenido)
    contenido.is_a?(Caso) ? contenido : contenido.caso
  end

  # Si se puede enseñar lo que dice: no, si el paciente retiró el consentimiento (D96). Tampoco a los
  # administradores: sus datos ya no se comparten.
  def contenido_disponible?(contenido)
    caso_de(contenido).en_la_red?
  end

  # Qué se denunció, en la lista de denuncias resueltas (el contenido puede estar borrado, D97).
  def contenido_denunciado(denuncia)
    contenido = denuncia.denunciable
    tipo = denuncia.denunciable_type == "Caso" ? "Caso" : "Comentario"
    if contenido.nil?
      "#{tipo} borrado#{" (de #{denuncia.autor_contenido.nombre_completo})" if denuncia.autor_contenido}"
    elsif !contenido_disponible?(contenido)
      "#{tipo} de un caso no disponible"
    elsif contenido.is_a?(Caso)
      "Caso «#{contenido.titulo}»"
    else
      "Comentario en «#{contenido.caso.titulo}»"
    end
  end
end
