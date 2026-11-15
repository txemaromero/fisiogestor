# Paginación sencilla de una lista (sin gemas): qué página se muestra y qué registros le tocan.
# La página llega de la URL: si no es un número o se sale del rango, se usa la más cercana.
class Paginacion
  attr_reader :total, :por_pagina, :pagina

  def initialize(total, pagina, por_pagina: 20)
    @total = total
    @por_pagina = por_pagina
    @pagina = Integer(pagina.to_s, exception: false).to_i.clamp(1, paginas)
  end

  def paginas
    [ (total / por_pagina.to_f).ceil, 1 ].max
  end

  def varias?
    paginas > 1
  end

  def primera?
    pagina == 1
  end

  def ultima?
    pagina == paginas
  end

  # Registros de la página actual.
  def aplicar(relacion)
    relacion.offset((pagina - 1) * por_pagina).limit(por_pagina)
  end

  # Números de página que se enlazan: la primera, la última y las dos de cada lado de la actual.
  # nil marca un hueco («…»).
  def numeros
    visibles = ([ 1, paginas ] + ((pagina - 2)..(pagina + 2)).to_a).select { |numero| numero.between?(1, paginas) }.uniq.sort
    visibles.each_with_object([]) do |numero, lista|
      lista << nil if lista.last && numero - lista.last > 1
      lista << numero
    end
  end
end
