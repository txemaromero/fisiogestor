# Páginas del catálogo de técnicas y enfermedades (D81): solo para los osteópatas administradores. A los
# demás les responden 404, como si no existieran.
class Catalogo::BaseController < ApplicationController
  include SoloAdministradores
end
