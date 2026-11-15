class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Toda la aplicación exige haber iniciado sesión, salvo las páginas de Devise (login y registro).
  before_action :authenticate_osteopath!, unless: :devise_controller?
  # Y tener activado el segundo factor (D84): hasta entonces solo se puede ir a darlo de alta.
  before_action :exigir_segundo_factor, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[nombre apellidos])
  end

  # Tras cerrar sesión se vuelve directamente al login (y no a la raíz, que exige sesión).
  def after_sign_out_path_for(_resource_or_scope)
    new_osteopath_session_path
  end

  private

  def exigir_segundo_factor
    return if current_osteopath.nil? || current_osteopath.otp_activado?

    redirect_to nuevo_segundo_factor_path
  end

  # Mensaje de una cuenta que no acepta códigos del segundo factor por los incorrectos (D92).
  def aviso_codigos_bloqueados(osteopata)
    hasta = osteopata.otp_bloqueado_hasta
    hora = l(hasta, format: hasta.to_date == Date.current ? "%H:%M" : "%H:%M del %-d/%-m")
    "Demasiados códigos incorrectos: esta cuenta no acepta códigos hasta las #{hora}. Si no has sido tú, cambia tu clave."
  end

  # Parámetros de los filtros (GET). Solo se aceptan textos: un valor con otra forma (por ejemplo
  # ?sexo[a]=b, que no puede venir de los formularios) se trata como si no se hubiera enviado.
  def texto_param(clave)
    params[clave] if params[clave].is_a?(String)
  end

  def lista_param(clave)
    params[clave].is_a?(Array) ? params[clave].grep(String) : []
  end

  # Género de los filtros: "hombre", "mujer" o "ambos" (cualquier otro valor equivale a no filtrar).
  def sexo_param
    texto_param(:sexo).presence_in(Patient.sexos.keys) || "ambos"
  end
end
