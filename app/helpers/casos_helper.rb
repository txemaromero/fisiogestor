module CasosHelper
  # Nombre del osteópata, con enlace a su perfil si está verificado (D87).
  def enlace_osteopata(osteopata)
    return osteopata.nombre_completo unless osteopata.verificado?

    link_to osteopata.nombre_completo, osteopata_path(osteopata), class: "link-light"
  end

  # Lo que se publica del paciente en un caso clínico: «Mujer, 40–44 años» (D89).
  def perfil_paciente_caso(caso)
    "#{etiqueta_enum(:sex_type, caso.sexo)}, #{caso.tramo_edad}"
  end

  # Solo el mes y el año de publicación de un caso (D96): la fecha exacta ayudaría a situar al paciente.
  def mes_publicacion(caso)
    l(caso.created_at, format: "%B de %Y")
  end

  def fecha_y_hora(momento)
    l(momento, format: "%d/%m/%Y %H:%M")
  end

  # Formulario plegado para denunciar un caso o un comentario (D91), sin JavaScript.
  def formulario_denuncia(url, etiqueta)
    render "casos/denuncia", url: url, etiqueta: etiqueta
  end
end
