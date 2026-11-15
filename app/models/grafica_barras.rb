# Geometría de la gráfica de barras horizontales de los informes (informes/_grafica_barras, D79): una barra
# por técnica, en el orden del ranking, con su valor rotulado en el extremo. Admite valores negativos (una
# reducción media negativa: el dolor aumentó), que salen hacia la izquierda del cero. Las medidas están en
# las unidades del viewBox del SVG.
class GraficaBarras
  ANCHO = 720
  ALTO_FILA = 30
  GROSOR = 18
  RADIO = 4
  MARGEN = { izquierda: 230, derecha: 64, arriba: 6, abajo: 28 }.freeze
  MAX_BARRAS = 15
  MAX_LETRAS_ETIQUETA = 30

  # fiable: false dibuja la barra hueca (pocas sesiones).
  Fila = Data.define(:etiqueta, :valor, :texto_valor, :titulo, :fiable)
  Barra = Data.define(:fila, :y, :ruta, :x_texto, :ancla_texto, :negativa) do
    def etiqueta_corta
      etiqueta = fila.etiqueta
      etiqueta.size > MAX_LETRAS_ETIQUETA ? "#{etiqueta[0, MAX_LETRAS_ETIQUETA - 1]}…" : etiqueta
    end
  end

  attr_reader :filas, :total

  def initialize(filas)
    @total = filas.size
    @filas = filas.first(MAX_BARRAS)
  end

  def vacia?
    filas.empty?
  end

  def recortada?
    total > filas.size
  end

  def negativas?
    filas.any? { |fila| fila.valor.negative? }
  end

  def alto
    MARGEN[:arriba] + filas.size * ALTO_FILA + MARGEN[:abajo]
  end

  def izquierda = MARGEN[:izquierda]
  def derecha = ANCHO - MARGEN[:derecha]
  def base = MARGEN[:arriba] + filas.size * ALTO_FILA

  # Escala «redonda»: pasos de 1, 2 o 5 (por una potencia de 10), desde el cero o el mínimo negativo.
  def paso
    @paso ||= begin
      rango = [ valores.max, 0 ].max - [ valores.min, 0 ].min
      rango = 1.0 if rango.zero?
      bruto = rango / 5.0
      magnitud = 10**Math.log10(bruto).floor
      [ 1, 2, 5, 10 ].map { |factor| factor * magnitud }.find { |candidato| candidato >= bruto }
    end
  end

  def maximo = [ (valores.max / paso).ceil * paso, paso ].max
  def minimo = [ (valores.min / paso).floor * paso, 0 ].min

  def x(valor)
    (izquierda + (valor - minimo) * (derecha - izquierda) / (maximo - minimo).to_f).round(1)
  end

  def cero = x(0)

  def marcas
    pasos = ((maximo - minimo) / paso).round
    (0..pasos).map { |i| minimo + i * paso }.map { |valor| [ valor, x(valor) ] }
  end

  def barras
    filas.each_with_index.map do |fila, i|
      y = (MARGEN[:arriba] + i * ALTO_FILA + (ALTO_FILA - GROSOR) / 2.0).round(1)
      fin = x(fila.valor)
      negativa = fila.valor.negative?
      Barra.new(fila: fila, y: y, ruta: ruta(cero, fin, y), negativa: negativa,
                x_texto: negativa ? fin - 6 : fin + 6, ancla_texto: negativa ? "end" : "start")
    end
  end

  private

  def valores
    @valores ||= filas.map(&:valor)
  end

  # Barra con el extremo redondeado y la base (en el cero) recta. nil si mide cero.
  def ruta(inicio, fin, y)
    largo = (fin - inicio).abs
    return if largo < 0.5

    r = [ RADIO, largo, GROSOR / 2.0 ].min
    abajo = (y + GROSOR).round(1)
    sentido = fin >= inicio ? -1 : 1
    "M#{inicio} #{y} H#{(fin + sentido * r).round(1)} Q#{fin} #{y} #{fin} #{(y + r).round(1)} " \
      "V#{(abajo - r).round(1)} Q#{fin} #{abajo} #{(fin + sentido * r).round(1)} #{abajo} H#{inicio} Z"
  end
end
