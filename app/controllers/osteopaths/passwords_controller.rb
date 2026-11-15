# Recuperación de la clave de Devise con límite de intentos por IP: pedir el enlace (create) no se puede
# usar para enviar correos sin control, ni cambiar la clave (update) para probar enlaces a ciegas. Cada límite
# lleva su nombre: sin él, los de un mismo controlador compartirían el contador (D104).
class Osteopaths::PasswordsController < Devise::PasswordsController
  rate_limit to: 5, within: 15.minutes, only: :create, name: "pedir_enlace",
             with: -> { redirect_to new_osteopath_password_path, status: :see_other,
                                    alert: "Demasiadas peticiones desde esta conexión. Espera unos minutos." }
  rate_limit to: 10, within: 15.minutes, only: :update, name: "cambiar_clave",
             with: -> { redirect_to new_osteopath_session_path, status: :see_other,
                                    alert: "Demasiados intentos de cambiar la clave. Espera unos minutos." }
end
