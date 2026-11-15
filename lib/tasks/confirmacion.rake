# Confirmación del email (D103) desde la consola del servidor: para quien no recibe el correo después de
# comprobar que el email es suyo, o para el primer administrador si el correo aún no funciona.
#   bin/rails confirmacion:listar
#   bin/rails confirmacion:dar EMAIL=ana@example.com
namespace :confirmacion do
  desc "Lista los osteópatas que aún no han confirmado su email"
  task listar: :environment do
    puts "Sin confirmar:"
    lineas = Osteopath.where(confirmed_at: nil).order(:email).map do |osteopata|
      "  #{osteopata.email} (#{osteopata.nombre_completo}), registrado el #{I18n.l(osteopata.created_at.to_date)}"
    end
    puts lineas.presence || "  ninguno"
  end

  desc "Confirma el email de un osteópata (EMAIL=...) sin el enlace del correo"
  task dar: :environment do
    osteopata = Osteopath.find_by(email: ENV["EMAIL"].to_s.strip.downcase)
    abort "No hay ningún osteópata con el email #{ENV['EMAIL'].inspect}. Uso: EMAIL=correo@ejemplo.com" unless osteopata
    abort "#{osteopata.email} ya tenía el email confirmado." if osteopata.confirmed?

    osteopata.confirm
    puts "#{osteopata.email} ya tiene el email confirmado: puede entrar con su clave."
  end
end
