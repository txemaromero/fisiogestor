class ApplicationMailer < ActionMailer::Base
  # El mismo remitente que los correos de Devise (MAIL_FROM en producción).
  default from: -> { Devise.mailer_sender }
  layout "mailer"
end
