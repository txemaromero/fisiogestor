require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |opciones|
    # Sin gestor de contraseñas: Chrome muestra un aviso de "contraseña filtrada" al iniciar sesión con
    # claves como 123456 que tapa la página y bloquea los clics.
    opciones.add_preference("credentials_enable_service", false)
    opciones.add_preference("profile.password_manager_enabled", false)
    opciones.add_preference("profile.password_manager_leak_detection", false)
  end

  # Los campos de las tablas editables no tienen <label> visible, solo aria-label.
  Capybara.enable_aria_label = true

  # sign_in de Devise: inicia sesión sin pasar por el formulario de login.
  include Devise::Test::IntegrationHelpers
end
