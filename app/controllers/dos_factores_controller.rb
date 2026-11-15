# Alta del segundo factor (D84), obligatoria para usar la aplicación, y cambio de dispositivo:
#   GET  /cuenta/segundo_factor          QR y clave de un secreto nuevo (guardado en la sesión, cifrada)
#   POST /cuenta/segundo_factor          lo activa si el código de la app corresponde a ese secreto; para
#                                        cambiar de dispositivo pide además la clave y un código del móvil
#                                        actual o de recuperación (D92)
#   POST /cuenta/codigos_recuperacion    códigos de recuperación nuevos (pide un código de la app o de recuperación)
# Los códigos de recuperación se enseñan una sola vez, en la respuesta del formulario (sin redirigir, para no
# guardarlos en ningún sitio) y sin que el navegador la guarde en caché. Cada cambio se avisa por correo (D93).
class DosFactoresController < ApplicationController
  skip_before_action :exigir_segundo_factor, only: %i[new create]

  rate_limit to: 10, within: 15.minutes, only: %i[create regenerar_codigos],
             with: -> { redirect_to cuenta_path, status: :see_other, alert: "Demasiados intentos. Espera unos minutos." }

  def new
    session[:otp_secreto_nuevo] ||= Osteopath.nuevo_secreto_otp
    preparar_alta
  end

  def create
    secreto = session[:otp_secreto_nuevo]
    return redirect_to(nuevo_segundo_factor_path) unless secreto

    cambio = current_osteopath.otp_activado?
    if cambio && !current_osteopath.valid_password?(texto_param(:clave).to_s)
      return rechazar("La clave actual no es correcta.")
    end
    # Primero el código de la app nueva, sin gastarlo: si está mal, no se gasta el del móvil actual.
    unless Osteopath.paso_otp(secreto, texto_param(:codigo))
      return rechazar("#{cambio ? 'El código de la app nueva' : 'El código'} no es correcto. Comprueba que la hora " \
                      "del móvil es la correcta.")
    end
    if cambio && (error = error_codigo_actual(current_osteopath.comprobar_codigo_de_acceso(texto_param(:codigo_actual))))
      return rechazar(error)
    end

    @codigos = current_osteopath.activar_otp!(secreto, texto_param(:codigo))
    return rechazar("El código de la app nueva no es correcto. Escribe el siguiente que muestre.") unless @codigos

    session.delete(:otp_secreto_nuevo)
    current_osteopath.avisar(cambio ? :dispositivo_cambiado : :segundo_factor_activado)
    flash.now[:notice] = cambio ? "Dispositivo cambiado." : "Segundo factor activado."
    mostrar_codigos
  end

  def regenerar_codigos
    error = error_codigo_actual(current_osteopath.comprobar_codigo_de_acceso(texto_param(:codigo)))
    return redirect_to(cuenta_path, status: :see_other, alert: error) if error

    @codigos = current_osteopath.regenerar_codigos_recuperacion!
    current_osteopath.avisar(:codigos_regenerados)
    flash.now[:notice] = "Códigos de recuperación nuevos. Los anteriores ya no sirven."
    mostrar_codigos
  end

  private

  def preparar_alta
    @secreto = session[:otp_secreto_nuevo]
    @qr = RQRCode::QRCode.new(Osteopath.uri_otp(@secreto, current_osteopath.email))
                         .as_png(size: 240, border_modules: 2).to_data_url
  end

  # Mensaje de error para el resultado de comprobar un código del dispositivo actual (nil si es correcto).
  # Los incorrectos cuentan para el límite de la cuenta (D92), como en el login.
  def error_codigo_actual(resultado)
    case resultado
    when :app, :recuperacion then nil
    when :recien_bloqueado, :bloqueado
      current_osteopath.avisar(:codigos_bloqueados, detalle: aviso_codigos_bloqueados(current_osteopath)) if resultado == :recien_bloqueado
      aviso_codigos_bloqueados(current_osteopath)
    else "El código no es correcto o ya se ha usado."
    end
  end

  def mostrar_codigos
    no_store
    render :codigos
  end

  def rechazar(mensaje)
    preparar_alta
    flash.now[:alert] = mensaje
    render :new, status: :unprocessable_content
  end
end
