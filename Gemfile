source "https://rubygems.org"

# Versiones (D101): las gemas que se han añadido para las mejoras van con versión exacta; el resto, con «~>»
# desde la que está en Gemfile.lock (misma versión mayor; en las 0.x, solo correcciones), para que un
# `bundle update` no salte a una versión mayor sin revisarla. Gemfile.lock lleva la huella (SHA-256) de
# cada gema, y Bundler rechaza una que no coincida.

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft", "~> 1.3"
# Use sqlite3 as the database for Active Record
gem "sqlite3", "~> 2.10"
# PostgreSQL en producción (ver config/database.yml). Versión exacta: pg 1.7.0 (octubre de 2026).
gem "pg", "1.7.0", group: :production
# Caché compartida de producción para los límites de intentos (D98), en la misma base de datos.
# Versión exacta: solid_cache 1.0.10 (noviembre de 2025).
gem "solid_cache", "1.0.10"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 8.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", "~> 2.2"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", "~> 2.0"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", "~> 1.3"
# Bootstrap 5 (SCSS + JS) compilado con Dart Sass, sin Node [https://github.com/twbs/bootstrap-rubygem]
gem "bootstrap", "~> 5.3"
gem "dartsass-rails", "~> 0.5.1"
# Autenticación de osteópatas [https://github.com/heartcombo/devise]
gem "devise", "~> 5.0"
# Traducciones al español de Rails (validaciones, fechas) y de Devise
gem "rails-i18n", "~> 8.0"
gem "devise-i18n", "~> 1.16"
# Segundo factor de autenticación obligatorio (D84): códigos TOTP y el QR para darlo de alta.
# Versiones exactas: rotp 6.3.0 (agosto de 2023) y rqrcode 3.2.0 (enero de 2026).
gem "rotp", "6.3.0"
gem "rqrcode", "3.2.0"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# Sin «~>» a propósito: son los datos de las zonas horarias, que conviene tener siempre al día.
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "~> 1.26", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", "~> 1.11", platforms: %i[ mri windows ], require: "debug/prelude"

  # Comprobaciones de seguridad de bin/ci (D102): análisis estático del código y vulnerabilidades conocidas
  # de las gemas. Versiones exactas: brakeman 8.1.0 (octubre de 2026) y bundler-audit 0.9.3 (noviembre de 2025).
  gem "brakeman", "8.1.0", require: false
  gem "bundler-audit", "0.9.3", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console", "~> 4.3"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara", "~> 3.40"
  gem "selenium-webdriver", "~> 4.51"
end
