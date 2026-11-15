require "test_helper"
require "rake"

class DosFactoresTaskTest < ActiveSupport::TestCase
  TAREAS = %w[dos_factores:estado dos_factores:restablecer dos_factores:codigo].freeze

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |tarea| tarea.name == "dos_factores:restablecer" }
    @email_anterior = ENV["EMAIL"]
  end

  teardown do
    ENV["EMAIL"] = @email_anterior
    TAREAS.each { |nombre| Rake::Task[nombre].reenable }
  end

  test "estado lista quién tiene activado el segundo factor y cuántos códigos le quedan" do
    osteopaths(:maria).restablecer_otp!
    assert_output(%r{maria_campos@example.com: sin activar.*paco@example.com: activado el 1/1/2026, 2 códigos}m) do
      Rake::Task["dos_factores:estado"].invoke
    end
  end

  test "restablecer quita el segundo factor: al entrar tendrá que darlo de alta otra vez" do
    ENV["EMAIL"] = " PACO@example.com"
    assert_output(/paco@example.com ya no tiene segundo factor/) { Rake::Task["dos_factores:restablecer"].invoke }
    assert_not osteopaths(:paco).reload.otp_activado?
    assert osteopaths(:maria).reload.otp_activado?
  end

  test "codigo muestra el código actual (solo en desarrollo y test)" do
    ENV["EMAIL"] = "paco@example.com"
    assert_output("#{codigo_otp(osteopaths(:paco))}\n") { Rake::Task["dos_factores:codigo"].invoke }
  end

  test "con un email desconocido no cambia nada" do
    ENV["EMAIL"] = "nadie@example.com"
    assert_raises(SystemExit) do
      assert_output(nil, /No hay ningún osteópata/) { Rake::Task["dos_factores:restablecer"].invoke }
    end
    assert osteopaths(:paco).reload.otp_activado?
  end
end
