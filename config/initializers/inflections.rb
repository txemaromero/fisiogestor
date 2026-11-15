# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# Rutas de las sesiones de un diagnóstico (/sesiones/:id): con esta regla los helpers se llaman
# sesion_path, edit_sesion_path... y no session_path, que es un helper de Devise (login).
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "sesion", "sesiones"
  # Rutas del catálogo (/catalogo/enfermedades/:id): sin esta regla, el singular sería «enfermedade».
  inflect.irregular "enfermedad", "enfermedades"
  # Las reglas del inglés toman las palabras acabadas en «ia» como plurales (como «data»): sin esta regla, la
  # tabla de Denuncia sería «denuncia».
  inflect.irregular "denuncia", "denuncias"
end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end
