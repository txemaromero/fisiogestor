# Verificación de los profesionales (D88) desde la consola del servidor, igual que en /verificaciones.
# Sirve, por ejemplo, para verificar al primer administrador.
#   bin/rails verificacion:listar
#   bin/rails verificacion:dar EMAIL=paco@example.com
#   bin/rails verificacion:quitar EMAIL=paco@example.com
namespace :verificacion do
  buscar_osteopata = lambda do
    osteopata = Osteopath.find_by(email: ENV["EMAIL"].to_s.strip.downcase)
    abort "No hay ningún osteópata con el email #{ENV['EMAIL'].inspect}. Uso: EMAIL=correo@ejemplo.com" unless osteopata

    osteopata
  end

  desc "Lista los osteópatas pendientes de verificar y los verificados"
  task listar: :environment do
    { "Pendientes" => Osteopath.pendientes_de_verificar, "Verificados" => Osteopath.verificados }.each do |titulo, osteopatas|
      puts "#{titulo}:"
      lineas = osteopatas.order(:email).map do |osteopata|
        verificador = ", verificado por #{osteopata.verificado_por.email}" if osteopata.verificado_por
        "  #{osteopata.email} (#{osteopata.nombre_completo}), colegiado #{osteopata.numero_colegiado}#{verificador}"
      end
      puts lineas.presence || "  ninguno"
    end
  end

  desc "Verifica a un osteópata (EMAIL=...): tiene que tener su número de colegiado en el perfil"
  task dar: :environment do
    osteopata = buscar_osteopata.()
    abort "#{osteopata.email} no tiene número de colegiado en su perfil." if osteopata.numero_colegiado.blank?

    osteopata.verificar!
    puts "#{osteopata.email} (colegiado #{osteopata.numero_colegiado}) ya está verificado."
  end

  desc "Quita la verificación a un osteópata (EMAIL=...): dejará de ver lo de otros osteópatas"
  task quitar: :environment do
    osteopata = buscar_osteopata.()
    osteopata.quitar_verificacion!
    puts "#{osteopata.email} ya no está verificado."
  end
end
