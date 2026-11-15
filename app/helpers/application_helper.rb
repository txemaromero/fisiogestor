module ApplicationHelper
  # Enlace de la navbar; se resalta si es la sección en la que está el usuario.
  def enlace_navbar(texto, ruta, activo)
    link_to texto, ruta, class: [ "nav-link", { active: activo } ], aria: { current: ("page" if activo) }
  end

  # Clases de Bootstrap de un campo de formulario; lo marca en rojo si el atributo tiene errores.
  def clase_campo(objeto, atributo, base = "form-control")
    objeto.errors[atributo].any? ? "#{base} is-invalid" : base
  end

  # Etiqueta en español de un valor de enumeración (claves enums.<enum>.<valor> de es.yml).
  # Ejemplo: etiqueta_enum(:background_type, "digestivos") => "Digestivos"
  def etiqueta_enum(enum, valor)
    valor.present? ? t("enums.#{enum}.#{valor}") : ""
  end

  # Opciones [etiqueta, valor] de una enumeración para un select.
  def opciones_enum(enum, valores)
    valores.map { |valor| [ etiqueta_enum(enum, valor), valor ] }
  end

  # Opciones de un select de escala de dolor: vacía ("—") y de 0 a 10.
  def opciones_escala_dolor
    [ [ "—", "" ] ] + (0..10).map { |valor| [ valor.to_s, valor ] }
  end

  # Fecha en formato dd/mm/aaaa, o "—" si no hay.
  def fecha_o_guion(fecha)
    fecha ? l(fecha) : "—"
  end

  # Reducción media del dolor con dos decimales ("2,33"), o "—" si no se puede calcular.
  def reduccion_dolor(valor)
    valor.nil? ? "—" : number_with_precision(valor, precision: 2)
  end

  # El valor, o "—" si está vacío.
  def valor_o_guion(valor)
    valor.presence || "—"
  end
end
