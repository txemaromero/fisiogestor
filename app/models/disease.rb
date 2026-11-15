class Disease < ApplicationRecord
  include EntradaCatalogo

  # Valor de la opción «Otra…» en los selects de enfermedad, y descripción de las enfermedades creadas
  # así cuando el diagnóstico no tiene descripción (Disease la exige).
  OTRA = "otra".freeze
  DESCRIPCION_NUEVA = "Enfermedad añadida al registrar una visita.".freeze

  has_many :diagnoses

  normalizes :nombre, with: ->(nombre) { nombre.squish }

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :descripcion, presence: true, length: { maximum: 2000 }

  # Busca por nombre sin distinguir mayúsculas, igual que la validación de unicidad.
  def self.buscar_por_nombre(nombre)
    find_by("LOWER(nombre) = LOWER(?)", nombre.to_s.squish)
  end

  # Reutiliza la enfermedad si ya existe con ese nombre y, si no, la crea (con el mismo tratamiento de las
  # altas simultáneas que Treatment.buscar_o_crear!).
  def self.buscar_o_crear!(nombre, descripcion)
    buscar_por_nombre(nombre) || transaction(requires_new: true) { create!(nombre: nombre, descripcion: descripcion) }
  rescue ActiveRecord::RecordNotUnique
    buscar_por_nombre(nombre) || raise
  end

  # Enfermedad elegida en un formulario de diagnóstico: la del catálogo con ese id o, con «Otra…», la del
  # nombre escrito (se reutiliza si ya existe y, si no, se crea con la descripción del diagnóstico).
  # Devuelve nil si no se ha elegido ninguna; lanza RecordInvalid si el nombre nuevo no es válido.
  def self.elegida(eleccion, nombre_nueva, descripcion)
    return find_by(id: eleccion) unless eleccion == OTRA

    buscar_o_crear!(nombre_nueva, descripcion.presence || DESCRIPCION_NUEVA)
  end
end
