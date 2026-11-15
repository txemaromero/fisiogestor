# Login de Devise con límite de intentos (protección frente a ataques de fuerza bruta) y segundo factor
# (D84): si el email y la clave son correctos y el osteópata tiene el segundo factor activado, aún no se
# inicia la sesión; se apunta quién es en la sesión y se pide el código (Osteopaths::CodigosController).
# Sin segundo factor activado se entra como siempre, y la aplicación obliga a darlo de alta.
class Osteopaths::SessionsController < Devise::SessionsController
  # Cuánto tiempo hay para escribir el código después de dar la clave.
  TIEMPO_CODIGO = 5.minutes

  # Límite por IP...
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_osteopath_session_path, status: :see_other,
                                    alert: "Demasiados intentos de inicio de sesión. Espera unos minutos." }
  # ...y por cuenta (D92), para los ataques repartidos entre muchas IP. A cambio, quien escriba muchas claves
  # incorrectas de una cuenta impide entrar en ella durante 15 minutos.
  rate_limit to: 20, within: 15.minutes, only: :create, name: "por_cuenta", by: :email_del_formulario,
             with: -> { redirect_to new_osteopath_session_path, status: :see_other,
                                    alert: "Demasiados intentos de inicio de sesión en esta cuenta. Espera unos minutos." }

  def create
    osteopata = osteopata_con_segundo_factor
    return super unless osteopata
    # Con una clave incorrecta, el error de siempre sin volver a comprobarla con Devise. Así cada intento
    # comprueba la clave una sola vez (lo que más tarda), tenga o no la cuenta el segundo factor y exista o no
    # (Devise la calcula igual en modo paranoico), y el tiempo de respuesta no dice qué emails tienen cuenta (D104).
    unless osteopata.valid_password?(params[:osteopath][:password])
      # Sin esto, Devise la comprobaría otra vez al volver a pintar el formulario (current_osteopath).
      request.env["devise.allow_params_authentication"] = false
      throw :warden, auth_options.merge(message: :invalid)
    end
    return redirect_to(new_osteopath_session_path, status: :see_other, alert: aviso_codigos_bloqueados(osteopata)) if osteopata.otp_bloqueado?

    session[:segundo_factor] = { "id" => osteopata.id, "hasta" => TIEMPO_CODIGO.from_now.to_i }
    redirect_to codigo_login_path, status: :see_other
  end

  # Al cerrar sesión cambia el token de sesión (D99): la cookie de esta sesión, y cualquier copia suya, deja
  # de valer. Cierra también las sesiones abiertas en otros dispositivos. (Al caducar una sesión por
  # inactividad no se cambia: las de otros dispositivos siguen abiertas.)
  def destroy
    current_osteopath&.renovar_token_sesion!
    super
  end

  private

  def email_del_formulario
    datos = params[:osteopath]
    datos.respond_to?(:key?) && datos[:email].is_a?(String) ? datos[:email].strip.downcase : ""
  end

  # El osteópata del formulario si tiene el segundo factor activado y puede entrar (la clave se comprueba
  # después). Si no, nil: el login sigue el camino normal de Devise. Sin clave, también: Devise entonces no
  # calcula nada, y aquí tampoco se debe.
  def osteopata_con_segundo_factor
    datos = params[:osteopath]
    return unless datos.respond_to?(:key?) && datos[:email].is_a?(String) && datos[:password].is_a?(String) &&
                  datos[:password].present?

    osteopata = Osteopath.find_for_authentication(email: datos[:email])
    osteopata if osteopata&.otp_activado? && osteopata.active_for_authentication?
  end
end
