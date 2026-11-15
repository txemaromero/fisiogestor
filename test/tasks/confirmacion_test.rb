require "test_helper"
require "rake"

class ConfirmacionTaskTest < ActiveSupport::TestCase
  TAREAS = %w[confirmacion:listar confirmacion:dar].freeze

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |tarea| tarea.name == "confirmacion:dar" }
    @email_anterior = ENV["EMAIL"]
    @ana = Osteopath.create!(nombre: "Ana", apellidos: "Ruiz", email: "ana@example.com", password: "secreto-largo",
                             created_at: Time.zone.local(2026, 10, 27, 9))
  end

  teardown do
    ENV["EMAIL"] = @email_anterior
    TAREAS.each { |nombre| Rake::Task[nombre].reenable }
  end

  test "lista las cuentas sin confirmar y confirma una por su email" do
    assert_output("Sin confirmar:\n  ana@example.com (Ana Ruiz), registrado el 27/10/2026\n") do
      Rake::Task["confirmacion:listar"].invoke
    end

    ENV["EMAIL"] = " Ana@example.com"
    assert_output(/ana@example.com ya tiene el email confirmado: puede entrar con su clave/) do
      Rake::Task["confirmacion:dar"].invoke
    end
    assert @ana.reload.confirmed?

    Rake::Task["confirmacion:listar"].reenable
    assert_output("Sin confirmar:\n  ninguno\n") { Rake::Task["confirmacion:listar"].invoke }
  end

  test "no confirma una cuenta ya confirmada ni un email desconocido" do
    ENV["EMAIL"] = "paco@example.com"
    assert_raises(SystemExit) do
      assert_output(nil, /ya tenía el email confirmado/) { Rake::Task["confirmacion:dar"].invoke }
    end

    Rake::Task["confirmacion:dar"].reenable
    ENV["EMAIL"] = "nadie@example.com"
    assert_raises(SystemExit) do
      assert_output(nil, /No hay ningún osteópata/) { Rake::Task["confirmacion:dar"].invoke }
    end
  end
end
