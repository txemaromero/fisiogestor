# bin/ci (D102): lo que tiene que pasar antes de subir cambios. Cada paso se lanza con el Ruby actual y sin
# shell, como bin/setup, para que funcione igual en Windows. Los pasos de seguridad necesitan red (la base de
# avisos de bundler-audit y la auditoría del importmap).
ruby = RbConfig.ruby

CI.run do
  step "Setup", ruby, "bin/setup", "--skip-server"

  step "Security: Gem audit", ruby, "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", ruby, "bin/importmap", "audit"
  step "Security: Brakeman code analysis", ruby, "bin/brakeman", "--quiet", "--no-pager", "--exit-on-warn", "--exit-on-error"

  step "Tests: Rails", ruby, "bin/rails", "test"
  # RAILS_ENV va en el entorno del proceso (no como argumento): replant vacía la base de datos antes de cargar
  # las seeds, y tiene que ser la de test.
  step "Tests: Seeds", { "RAILS_ENV" => "test" }, ruby, "bin/rails", "db:seed:replant"

  # Los system tests (Chrome) tardan más: se lanzan aparte con bin/rails test:system.
  # step "Tests: System", ruby, "bin/rails", "test:system"
end
