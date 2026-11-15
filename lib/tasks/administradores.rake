# Administradores del catálogo de técnicas y enfermedades (D81). El permiso no se puede conseguir desde la
# aplicación: lo da quien administra el servidor.
#   bin/rails administradores:listar
#   bin/rails administradores:dar EMAIL=paco@example.com
#   bin/rails administradores:quitar EMAIL=paco@example.com
namespace :administradores do
  cambiar_administrador = lambda do |admin|
    osteopata = Osteopath.find_by(email: ENV["EMAIL"].to_s.strip.downcase)
    abort "No hay ningún osteópata con el email #{ENV['EMAIL'].inspect}. Uso: EMAIL=correo@ejemplo.com" unless osteopata

    osteopata.update!(admin: admin)
    puts "#{osteopata.email} #{admin ? 'ya es' : 'ya no es'} administrador del catálogo."
  end

  desc "Lista los osteópatas administradores del catálogo"
  task listar: :environment do
    administradores = Osteopath.where(admin: true).order(:email)
    puts administradores.any? ? administradores.map { |osteopata| "#{osteopata.email} (#{osteopata.nombre_completo})" } : "No hay administradores."
  end

  desc "Da permiso de administrador del catálogo a un osteópata (EMAIL=...)"
  task dar: :environment do
    cambiar_administrador.(true)
  end

  desc "Quita el permiso de administrador del catálogo a un osteópata (EMAIL=...)"
  task quitar: :environment do
    cambiar_administrador.(false)
  end
end
