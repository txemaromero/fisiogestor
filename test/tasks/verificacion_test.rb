require "test_helper"
require "rake"

class VerificacionTaskTest < ActiveSupport::TestCase
  TAREAS = %w[verificacion:listar verificacion:dar verificacion:quitar].freeze

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |tarea| tarea.name == "verificacion:dar" }
    @email_anterior = ENV["EMAIL"]
  end

  teardown do
    ENV["EMAIL"] = @email_anterior
    TAREAS.each { |nombre| Rake::Task[nombre].reenable }
  end

  test "quitar y dar la verificación por email, y listar" do
    ENV["EMAIL"] = " Maria_Campos@example.com"
    assert_output(/maria_campos@example.com ya no está verificado/) { Rake::Task["verificacion:quitar"].invoke }
    assert_not osteopaths(:maria).reload.verificado?

    assert_output(/Pendientes:\n  maria_campos@example.com \(Maria Campos Gil\), colegiado 46-05678\nVerificados:\n  paco@example.com/) do
      Rake::Task["verificacion:listar"].invoke
    end

    assert_output(/colegiado 46-05678\) ya está verificado/) { Rake::Task["verificacion:dar"].invoke }
    assert osteopaths(:maria).reload.verificado?
  end

  test "no se verifica a quien no tiene número de colegiado ni a un email desconocido" do
    osteopaths(:maria).update!(numero_colegiado: nil)
    ENV["EMAIL"] = "maria_campos@example.com"
    assert_raises(SystemExit) do
      assert_output(nil, /no tiene número de colegiado/) { Rake::Task["verificacion:dar"].invoke }
    end

    Rake::Task["verificacion:dar"].reenable
    ENV["EMAIL"] = "nadie@example.com"
    assert_raises(SystemExit) do
      assert_output(nil, /No hay ningún osteópata/) { Rake::Task["verificacion:dar"].invoke }
    end
  end
end
