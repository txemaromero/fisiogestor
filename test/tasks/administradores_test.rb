require "test_helper"
require "rake"

class AdministradoresTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |tarea| tarea.name == "administradores:dar" }
    @email_anterior = ENV["EMAIL"]
  end

  teardown do
    ENV["EMAIL"] = @email_anterior
    %w[administradores:dar administradores:quitar administradores:listar].each { |nombre| Rake::Task[nombre].reenable }
  end

  test "dar y quitar el permiso de administrador por email" do
    ENV["EMAIL"] = "Maria_Campos@example.com "
    assert_output(/maria_campos@example.com ya es administrador del catálogo/) { Rake::Task["administradores:dar"].invoke }
    assert osteopaths(:maria).reload.admin?

    assert_output(/maria_campos@example.com.*paco@example.com/m) { Rake::Task["administradores:listar"].invoke }

    assert_output(/ya no es administrador/) { Rake::Task["administradores:quitar"].invoke }
    assert_not osteopaths(:maria).reload.admin?
  end

  test "con un email desconocido no cambia nada" do
    ENV["EMAIL"] = "nadie@example.com"
    assert_raises(SystemExit) do
      assert_output(nil, /No hay ningún osteópata/) { Rake::Task["administradores:dar"].invoke }
    end
  end
end
