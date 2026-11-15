# Be sure to restart your server when you modify this file.

# Política de seguridad de contenidos (CSP): el navegador solo ejecuta scripts y aplica estilos que
# vengan de la propia aplicación (o lleven el nonce de la sesión, como el importmap). Si algún día se
# colara HTML de un usuario en una página, no podría ejecutar JavaScript.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.font_src        :self, :data
    policy.img_src         :self, :data # Bootstrap usa imágenes SVG en data: (flechas de los select, botón cerrar)
    policy.object_src      :none
    policy.script_src      :self
    policy.style_src       :self
    policy.connect_src     :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end

  # Nonces de sesión (no por petición) para el importmap y los estilos que inserta Turbo: con Turbo la
  # página no se recarga entera, así que el nonce tiene que ser el mismo en las navegaciones siguientes.
  # Se guarda un valor aleatorio en la sesión en lugar de usar su id (como propone la plantilla de
  # Rails), porque en la primera visita la sesión aún no tiene id y el nonce quedaba vacío: el
  # navegador bloqueaba entonces el JavaScript de la página de login.
  config.content_security_policy_nonce_generator = ->(request) { request.session[:nonce_csp] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
