# Avisos al osteópata de los cambios en el acceso a su cuenta (D93): si no ha sido él, se entera y puede
# reaccionar. Todos usan la misma plantilla (avisos_seguridad_mailer/aviso), con un texto por tipo.
class AvisosSeguridadMailer < ApplicationMailer
  AVISOS = {
    segundo_factor_activado: {
      asunto: "Se ha activado el segundo factor en tu cuenta",
      texto: "Se ha activado el segundo factor de tu cuenta: desde ahora, al entrar se pide además el código de " \
             "una app de autenticación."
    },
    dispositivo_cambiado: {
      asunto: "Has cambiado de dispositivo para el segundo factor",
      texto: "Se ha cambiado el dispositivo del segundo factor de tu cuenta: los códigos del móvil anterior y los " \
             "códigos de recuperación anteriores ya no sirven."
    },
    codigos_regenerados: {
      asunto: "Códigos de recuperación nuevos",
      texto: "Se han generado códigos de recuperación nuevos para tu cuenta: los anteriores ya no sirven."
    },
    entrada_con_codigo_de_recuperacion: {
      asunto: "Has entrado con un código de recuperación",
      texto: "Alguien ha entrado en tu cuenta con tu clave y uno de tus códigos de recuperación."
    },
    codigos_bloqueados: {
      asunto: "Códigos incorrectos en tu cuenta",
      texto: "Alguien que conoce tu clave ha escrito varios códigos del segundo factor incorrectos. Para " \
             "protegerte, tu cuenta no acepta códigos durante un tiempo."
    }
  }.freeze

  AVISOS.each_key do |tipo|
    define_method(tipo) { aviso(tipo) }
  end

  private

  def aviso(tipo)
    @osteopata = params[:osteopata]
    @texto = AVISOS.fetch(tipo)[:texto]
    @detalle = params[:detalle]
    @momento = Time.current
    mail(to: @osteopata.email, subject: "#{AVISOS.fetch(tipo)[:asunto]} · RedSocialFisios", template_name: "aviso")
  end
end
