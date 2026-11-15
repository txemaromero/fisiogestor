# Confirmación del email de Devise (D103) con la clave de la cuenta (D104): el enlace del correo abre un
# formulario (show) y el email se confirma al enviarlo con la clave correcta (update). Abrir el enlace no
# confirma nada.
#
# Con límite de intentos por IP: pedir otro enlace (create) no se puede usar para enviar correos sin control,
# ni abrir enlaces y confirmar (show y update, que comparten el contador) para probar enlaces o claves a
# ciegas. Cada límite lleva su nombre: sin él, los de un mismo controlador compartirían el contador.
class Osteopaths::ConfirmationsController < Devise::ConfirmationsController
  rate_limit to: 5, within: 15.minutes, only: :create, name: "pedir_enlace",
             with: -> { redirect_to new_osteopath_confirmation_path, status: :see_other,
                                    alert: "Demasiadas peticiones desde esta conexión. Espera unos minutos." }
  rate_limit to: 10, within: 15.minutes, only: %i[show update], name: "confirmar",
             with: -> { redirect_to new_osteopath_session_path, status: :see_other,
                                    alert: "Demasiados intentos de confirmar el email. Espera unos minutos." }

  # GET /osteopaths/confirmation?confirmation_token=...: el formulario que pide la clave. Si el enlace no vale,
  # ya se usó o ha caducado, la página para pedir otro con el error.
  def show
    self.resource = resource_class.para_confirmar(params[:confirmation_token])
    render :new, status: :unprocessable_content if resource.errors.any?
  end

  # PATCH /osteopaths/confirmation: confirma el email si la clave es la de la cuenta.
  def update
    self.resource = resource_class.para_confirmar(params[:confirmation_token])
    return render(:new, status: :unprocessable_content) if resource.errors.any?

    if resource.confirmar_con_clave(clave_del_formulario)
      set_flash_message!(:notice, :confirmed)
      redirect_to new_osteopath_session_path, status: :see_other
    else
      # Si mientras tanto ha caducado o se ha confirmado, el error de la página para pedir otro enlace.
      pagina = resource.errors.include?(:email) ? :new : :show
      render pagina, status: :unprocessable_content
    end
  end

  private

  def clave_del_formulario
    datos = params[:osteopath]
    datos[:password] if datos.respond_to?(:key?)
  end
end
