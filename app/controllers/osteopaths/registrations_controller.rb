# Registro de Devise con límite de altas por IP (evita la creación masiva de cuentas).
class Osteopaths::RegistrationsController < Devise::RegistrationsController
  rate_limit to: 5, within: 1.hour, only: :create,
             with: -> { redirect_to new_osteopath_registration_path, status: :see_other,
                                    alert: "Demasiados registros desde esta conexión. Inténtalo más tarde." }

  protected

  # Tras registrarse no se entra: hay que confirmar el email (D103). Se vuelve al login, con el aviso de que
  # ha llegado un correo con el enlace.
  def after_inactive_sign_up_path_for(_resource)
    new_osteopath_session_path
  end
end
