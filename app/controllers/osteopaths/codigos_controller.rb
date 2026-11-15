# Segundo paso del login (D84): el código de 6 cifras de la app de autenticación o un código de
# recuperación. Solo se llega después de dar una clave correcta (Osteopaths::SessionsController), y hay
# 5 minutos; si no, hay que volver a empezar desde el login. Los códigos incorrectos se cuentan por cuenta
# en la base de datos (D92): tras 5 seguidos, la cuenta no acepta códigos durante un tiempo.
class Osteopaths::CodigosController < ApplicationController
  skip_before_action :authenticate_osteopath!, :exigir_segundo_factor
  before_action :set_pendiente

  rate_limit to: 10, within: 5.minutes, only: :create,
             with: -> { redirect_to new_osteopath_session_path, status: :see_other,
                                    alert: "Demasiados intentos. Espera unos minutos." }

  def new
  end

  def create
    case @osteopata.comprobar_codigo_de_acceso(texto_param(:codigo))
    when :app
      entrar(t("devise.sessions.signed_in"))
    when :recuperacion
      restantes = @osteopata.codigos_recuperacion_restantes
      @osteopata.avisar(:entrada_con_codigo_de_recuperacion, detalle: "Te quedan #{restantes} códigos de recuperación.")
      entrar("Has entrado con un código de recuperación; te quedan #{restantes}. Si has perdido el móvil, " \
             "cambia de dispositivo en «Mi cuenta».")
    when :recien_bloqueado
      # Alguien conoce la clave: se avisa al osteópata por correo.
      @osteopata.avisar(:codigos_bloqueados, detalle: aviso_codigos_bloqueados(@osteopata))
      bloqueada
    when :bloqueado
      bloqueada
    else
      flash.now[:alert] = "El código no es correcto o ya se ha usado."
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_pendiente
    pendiente = session[:segundo_factor]
    @osteopata = Osteopath.find_by(id: pendiente["id"]) if pendiente.is_a?(Hash) && pendiente["hasta"].to_i > Time.current.to_i
    return if @osteopata

    session.delete(:segundo_factor)
    redirect_to new_osteopath_session_path, status: :see_other, alert: "Vuelve a iniciar sesión."
  end

  def entrar(aviso)
    session.delete(:segundo_factor)
    sign_in(:osteopath, @osteopata)
    redirect_to after_sign_in_path_for(@osteopata), notice: aviso, status: :see_other
  end

  # Hay que volver a dar la clave (cuando la cuenta vuelva a aceptar códigos).
  def bloqueada
    session.delete(:segundo_factor)
    redirect_to new_osteopath_session_path, status: :see_other, alert: aviso_codigos_bloqueados(@osteopata)
  end
end
