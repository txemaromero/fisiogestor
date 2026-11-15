ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # En Linux/macOS los tests se ejecutan en paralelo con un proceso (y una base de datos) por núcleo.
    # En Windows no hay fork() y con hilos los tests chocan al compartir la conexión SQLite de los
    # fixtures transaccionales, así que se ejecutan en un solo proceso (la suite tarda unos segundos).
    parallelize(workers: Gem.win_platform? ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Cada test empieza con los contadores del límite de intentos a cero.
    setup { Rails.cache.clear }

    # Código de la app de autenticación de un osteópata en un momento dado (D84).
    def codigo_otp(osteopata, momento = Time.current)
      ROTP::TOTP.new(osteopata.otp_secret).at(momento)
    end

    # Sustituye un método de clase mientras dura el bloque y después lo restaura
    # (Minitest 6 ya no incluye Object#stub).
    def sustituir(objeto, metodo, implementacion)
      original = objeto.method(metodo)
      objeto.define_singleton_method(metodo, &implementacion)
      yield
    ensure
      if original.owner == objeto.singleton_class
        objeto.define_singleton_method(metodo, original)
      else
        objeto.singleton_class.remove_method(metodo)
      end
    end
  end
end

# Los ficheros que suben los tests (Active Storage, servicio :test en tmp/storage) se borran al terminar.
# Dir.glob no incluye los ficheros ocultos: el .keep de la carpeta, que está en Git, se queda.
# La carpeta se averigua ya, antes de repartir los tests entre procesos (Linux y macOS): al terminar, el
# proceso principal ha descartado sus conexiones a la base de datos, y cargar entonces ActiveStorage::Blob
# falla (comprueba si hay conexión) y hace que la suite termine con error aunque todos los tests pasen.
carpeta_ficheros_tests = ActiveStorage::Blob.service.root
Minitest.after_run { FileUtils.rm_rf(Dir.glob(File.join(carpeta_ficheros_tests, "*"))) }

class ActionDispatch::IntegrationTest
  # sign_in / sign_out de Devise para los tests de controladores e integración.
  include Devise::Test::IntegrationHelpers
end
