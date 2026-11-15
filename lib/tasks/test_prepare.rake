# Rails actualiza la base de datos de test lanzando `system("bin/rails db:test:prepare")`, lo que en
# Windows falla (no se puede ejecutar un script sin extensión). Preparándola aquí, antes de cargar los
# tests, el esquema ya está al día y Rails no necesita lanzar ese proceso. En Linux/macOS no cambia nada.
task "test:prepare" => "db:test:prepare"
