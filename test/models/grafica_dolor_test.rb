require "test_helper"

class GraficaDolorTest < ActiveSupport::TestCase
  test "toma las sesiones con alguna escala de todas las visitas del paciente, por fecha y las que no tienen al final" do
    visita = Visit.create!(patient: patients(:juan), osteopath: osteopaths(:paco), fecha: Date.new(2026, 1, 5))
    diagnostico = visita.diagnoses.create!(disease: diseases(:ciatica), sesiones_recomendadas: 2)
    sin_fecha = diagnostico.sessions.create!(escala_dolor_pre_sesion: 6)
    anterior = diagnostico.sessions.create!(fecha: Date.new(2026, 1, 7), escala_dolor_post_sesion: 7)
    diagnostico.sessions.create!(fecha: Date.new(2026, 1, 8)) # sin escalas: no se dibuja

    assert_equal [ anterior, sessions(:juan_1), sessions(:juan_2), sin_fecha ], GraficaDolor.de(patients(:juan)).sesiones
  end

  test "un paciente sin sesiones da una gráfica vacía" do
    paciente = osteopaths(:paco).patients.create!(nombre: "Ana", apellidos: "Ruiz", anyo_nacimiento: 1990, sexo: "mujer")
    assert GraficaDolor.de(paciente).vacia?
  end

  test "la escala va de 10 arriba a 0 en la base, con marcas cada 2" do
    grafica = GraficaDolor.new([ sessions(:juan_1) ])
    assert_equal GraficaDolor::MARGEN[:arriba], grafica.y(10)
    assert_equal GraficaDolor::ALTO - GraficaDolor::MARGEN[:abajo], grafica.y(0)
    assert_equal grafica.y(0), grafica.base
    assert_nil grafica.y(nil)
    assert_equal [ 0, 2, 4, 6, 8, 10 ], grafica.marcas_y.map(&:first)
  end

  test "una columna por sesión dentro de los márgenes, con el dolor antes y después" do
    grafica = GraficaDolor.de(patients(:pepe))
    primero, segundo = grafica.puntos
    assert_equal [ 9, 4, "Hernia discal", "18/5/26" ], [ primero.antes, primero.despues, primero.enfermedad, primero.fecha_eje ]
    assert_equal [ 1, 2 ], [ primero.numero, segundo.numero ]
    assert_nil segundo.y_despues # pepe_2 no tiene escala después
    assert_operator grafica.izquierda, :<, primero.x
    assert_operator primero.x, :<, segundo.x
    assert_operator segundo.x, :<, grafica.derecha
    assert_in_delta grafica.ancho_columna, segundo.x - primero.x, 0.2
  end

  test "con muchas sesiones solo se rotulan algunas fechas en el eje" do
    sesiones = Array.new(30) do |i|
      Session.new(diagnosis: diagnoses(:diag_juan), fecha: Date.new(2026, 1, 1) + i, escala_dolor_pre_sesion: 5)
    end
    puntos = GraficaDolor.new(sesiones).puntos
    assert_operator puntos.count(&:fecha_eje), :<=, GraficaDolor::MAX_FECHAS_EJE
    assert_equal "1/1/26", puntos.first.fecha_eje
  end

  test "rotula la cifra con la que empieza y con la que termina, y las resume" do
    juan = GraficaDolor.de(patients(:juan))
    assert_equal [ 8, 1 ], [ juan.inicio.last, juan.fin.last ]
    assert_equal "Evolución del dolor en 2 sesiones: empieza en 8 y termina en 1 sobre 10.", juan.resumen

    # Si a la última sesión le falta la escala después, termina en la de antes.
    assert_equal [ 9, 4 ], [ GraficaDolor.de(patients(:pepe)).inicio.last, GraficaDolor.de(patients(:pepe)).fin.last ]
    assert_match "en 1 sesión:", GraficaDolor.new([ sessions(:juan_1) ]).resumen
  end

  test "la gráfica de un caso clínico es anónima: días desde la primera sesión en lugar de fechas" do
    grafica = GraficaDolor.de_caso(casos(:caso_pepe))
    assert grafica.anonima?
    assert_equal [ "Día 0", "Día 7" ], grafica.puntos.map(&:fecha_eje)
    assert_equal "Día 7", grafica.momento(sessions(:pepe_2))

    ficha = GraficaDolor.de(patients(:pepe))
    assert_not ficha.anonima?
    assert_equal "25/5/2026", ficha.momento(sessions(:pepe_2))
    assert_nil ficha.momento(Session.new)
  end
end
