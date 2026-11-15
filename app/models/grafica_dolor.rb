# Datos y geometría de la gráfica «Evolución del dolor» de la ficha del paciente
# (patients/_grafica_dolor): una columna por sesión, en orden de fecha, con el dolor antes y después
# de la sesión (escala de 0 a 10) unidos por un tramo vertical. Las medidas están en las unidades del
# viewBox del SVG, que se escala al ancho de la ficha.
class GraficaDolor
  ANCHO = 720
  ALTO = 260
  # Arriba y a la derecha hay sitio para las dos cifras rotuladas (ver inicio y fin).
  MARGEN = { izquierda: 34, derecha: 32, arriba: 26, abajo: 34 }.freeze
  # Con muchas sesiones solo se rotulan algunas fechas en el eje (todas están en el tooltip y la tabla).
  MAX_FECHAS_EJE = 12

  Punto = Data.define(:sesion, :numero, :x, :y_antes, :y_despues, :fecha_eje) do
    def antes = sesion.escala_dolor_pre_sesion
    def despues = sesion.escala_dolor_post_sesion
    def enfermedad = sesion.diagnosis.disease.nombre
  end

  attr_reader :sesiones

  # Sesiones de un paciente (de todas sus visitas) por fecha; las que no tienen fecha van al final.
  def self.de(patient)
    new(por_fecha(Session.joins(diagnosis: :visit).where(visits: { patient_id: patient.id })))
  end

  # Sesiones de una sola visita (para el informe de la visita).
  def self.de_visita(visit)
    new(por_fecha(Session.joins(:diagnosis).where(diagnoses: { visit_id: visit.id })))
  end

  # Sesiones realizadas de un caso clínico (D89), sin fechas: cada sesión se rotula con los días que han
  # pasado desde la primera.
  def self.de_caso(caso)
    new(caso.sesiones, dias: caso.method(:dia))
  end

  def self.por_fecha(sesiones)
    sesiones.includes(diagnosis: :disease).order(Session.arel_table[:fecha].asc.nulls_last, :id)
  end
  private_class_method :por_fecha

  # Solo se dibujan las sesiones que tienen al menos una de las dos escalas. Con «dias» (lo que da, para
  # una sesión, los días desde el inicio), la gráfica es anónima: sin fechas.
  def initialize(sesiones, dias: nil)
    @sesiones = sesiones.select { |sesion| sesion.escala_dolor_pre_sesion || sesion.escala_dolor_post_sesion }
    @dias = dias
  end

  def anonima?
    @dias.present?
  end

  # Cuándo fue la sesión: su fecha o, en una gráfica anónima, «Día 7». nil si la sesión no tiene fecha.
  def momento(sesion)
    return unless sesion.fecha

    anonima? ? "Día #{@dias.(sesion)}" : I18n.l(sesion.fecha)
  end

  def vacia?
    sesiones.empty?
  end

  def puntos
    @puntos ||= begin
      cada = (sesiones.size / MAX_FECHAS_EJE.to_f).ceil
      sesiones.each_with_index.map do |sesion, i|
        Punto.new(sesion: sesion, numero: i + 1, x: (MARGEN[:izquierda] + ancho_columna * (i + 0.5)).round(1),
                  y_antes: y(sesion.escala_dolor_pre_sesion), y_despues: y(sesion.escala_dolor_post_sesion),
                  fecha_eje: (rotulo_eje(sesion) if (i % cada).zero?))
      end
    end
  end

  # Altura en el viewBox de un valor de la escala de dolor (nil si no hay valor).
  def y(valor)
    valor && (MARGEN[:arriba] + alto_util * (10 - valor) / 10.0).round(1)
  end

  def marcas_y
    (0..10).step(2).map { |valor| [ valor, y(valor) ] }
  end

  def izquierda = MARGEN[:izquierda]
  def derecha = ANCHO - MARGEN[:derecha]
  def arriba = MARGEN[:arriba]
  def base = y(0)

  def ancho_columna
    (ANCHO - MARGEN[:izquierda] - MARGEN[:derecha]) / sesiones.size.to_f
  end

  # Valor con el que empieza el tratamiento (el «antes» de la primera sesión) y con el que va (el
  # «después» de la última); son las dos únicas cifras rotuladas en la gráfica.
  def inicio
    primero = puntos.first
    primero.antes ? [ primero.x, primero.y_antes, primero.antes ] : [ primero.x, primero.y_despues, primero.despues ]
  end

  def fin
    ultimo = puntos.last
    ultimo.despues ? [ ultimo.x, ultimo.y_despues, ultimo.despues ] : [ ultimo.x, ultimo.y_antes, ultimo.antes ]
  end

  def resumen
    sesiones_texto = sesiones.size == 1 ? "1 sesión" : "#{sesiones.size} sesiones"
    "Evolución del dolor en #{sesiones_texto}: empieza en #{inicio.last} y termina en #{fin.last} sobre 10."
  end

  private

  def rotulo_eje(sesion)
    return "—" unless sesion.fecha

    anonima? ? momento(sesion) : sesion.fecha.strftime("%-d/%-m/%y")
  end

  def alto_util
    ALTO - MARGEN[:arriba] - MARGEN[:abajo]
  end
end
