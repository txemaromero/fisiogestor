# Entradas de los catálogos compartidos (técnicas y enfermedades): detección de posibles duplicados para
# la página del catálogo (D82). Dos nombres son posibles duplicados si coinciden sin tildes, mayúsculas,
# signos ni palabras vacías: «Masaje espalda» y «Masaje de espalda».
module EntradaCatalogo
  extend ActiveSupport::Concern

  PALABRAS_VACIAS = %w[a al de del el en la las los y].freeze

  def clave_duplicado
    palabras = I18n.transliterate(nombre.to_s, locale: :es).downcase.gsub(/[^a-z0-9]+/, " ").split
    (palabras - PALABRAS_VACIAS).join(" ")
  end

  class_methods do
    # { id => nombres de las otras entradas que parecen la misma } de las entradas con posibles duplicados.
    def posibles_duplicados
      all.group_by(&:clave_duplicado).values.select { |grupo| grupo.size > 1 }.each_with_object({}) do |grupo, duplicados|
        grupo.each { |entrada| duplicados[entrada.id] = (grupo - [ entrada ]).map(&:nombre) }
      end
    end
  end
end
