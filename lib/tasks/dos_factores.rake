# Segundo factor de autenticación (D84) desde la consola del servidor:
#   bin/rails dos_factores:estado
#   bin/rails dos_factores:restablecer EMAIL=paco@example.com   si ha perdido el móvil y los códigos de recuperación
#                                                               (también quita el bloqueo por códigos incorrectos, D92)
#   bin/rails dos_factores:codigo EMAIL=paco@example.com        código actual (solo en desarrollo y test)
namespace :dos_factores do
  buscar_osteopata = lambda do
    osteopata = Osteopath.find_by(email: ENV["EMAIL"].to_s.strip.downcase)
    abort "No hay ningún osteópata con el email #{ENV['EMAIL'].inspect}. Uso: EMAIL=correo@ejemplo.com" unless osteopata

    osteopata
  end

  desc "Lista qué osteópatas tienen activado el segundo factor y cuántos códigos de recuperación les quedan"
  task estado: :environment do
    Osteopath.order(:email).each do |osteopata|
      estado = if osteopata.otp_activado?
        "activado el #{I18n.l(osteopata.otp_activado_at.to_date, locale: :es)}, " \
          "#{osteopata.codigos_recuperacion_restantes} códigos de recuperación"
      else
        "sin activar (se le pedirá al entrar)"
      end
      if osteopata.otp_bloqueado?
        estado += "; no acepta códigos hasta el #{I18n.l(osteopata.otp_bloqueado_hasta, format: '%d/%m/%Y %H:%M', locale: :es)} " \
                  "(#{osteopata.otp_fallos} incorrectos seguidos)"
      end
      puts "#{osteopata.email}: #{estado}"
    end
  end

  desc "Quita el segundo factor de un osteópata (EMAIL=...): lo dará de alta otra vez al entrar"
  task restablecer: :environment do
    osteopata = buscar_osteopata.()
    osteopata.restablecer_otp!
    puts "#{osteopata.email} ya no tiene segundo factor. Al entrar con su clave tendrá que darlo de alta otra vez."
  end

  # Para probar la aplicación sin móvil. En producción no existe: el código solo debe verlo su dueño.
  if Rails.env.local?
    desc "Muestra el código actual del segundo factor de un osteópata (EMAIL=...; solo en desarrollo y test)"
    task codigo: :environment do
      osteopata = buscar_osteopata.()
      abort "#{osteopata.email} no tiene activado el segundo factor." unless osteopata.otp_activado?

      puts ROTP::TOTP.new(osteopata.otp_secret).now
    end
  end
end
