class Diagnosis < ApplicationRecord
  belongs_to :visit
  belongs_to :disease
  has_many :sessions, -> { order(:fecha, :id) }, dependent: :destroy
  # Publicado como caso clínico (D89): se borra con el diagnóstico.
  has_one :caso, dependent: :destroy

  validates :sesiones_recomendadas, presence: true
  validates :sesiones_recomendadas, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :descripcion, length: { maximum: 2000 }

  # --- Filtro de tratamientos (/filtrar_tratamientos) ---------------------------------------------
  # Cada criterio es un método de clase que devuelve TODOS los diagnósticos cuando recibe el valor
  # "no filtrar" (vacío, o "ambos" en el sexo). Todos son inclusivos. filtrar los encadena (AND):
  # para añadir un criterio nuevo basta con escribir su método y encadenarlo en filtrar.

  def self.por_sexo(sexo)
    return all if sexo.blank? || sexo == "ambos"

    joins(visit: :patient).where(patients: { sexo: sexo })
  end

  # La edad es año actual − año de nacimiento, así que edad >= mínima  <=>  año <= año actual − mínima.
  def self.por_edad_minima(edad)
    edad = Integer(edad, exception: false)
    return all if edad.nil?

    joins(visit: :patient).where(patients: { anyo_nacimiento: ..(Date.current.year - edad) })
  end

  # edad <= máxima  <=>  año de nacimiento >= año actual − máxima.
  def self.por_edad_maxima(edad)
    edad = Integer(edad, exception: false)
    return all if edad.nil?

    joins(visit: :patient).where(patients: { anyo_nacimiento: (Date.current.year - edad).. })
  end

  # Diagnósticos que puede ver un osteópata en el filtro: los de sus pacientes y los de pacientes de otros
  # que consienten compartir sus datos (D83).
  def self.visibles_para(osteopath)
    joins(visit: :patient).merge(Patient.visibles_para(osteopath))
  end

  # Varias dolencias se combinan con OR: diagnósticos de cualquiera de ellas.
  def self.por_dolencias(disease_ids)
    ids = Array(disease_ids).compact_blank
    return all if ids.empty?

    where(disease_id: ids)
  end

  # Se encadenan en lugar de usar merge porque merge sustituye las condiciones sobre una misma columna,
  # y la edad mínima y la máxima filtran las dos por patients.anyo_nacimiento.
  def self.filtrar(sexo: nil, edad_min: nil, edad_max: nil, dolencias: nil)
    por_sexo(sexo)
      .por_edad_minima(edad_min)
      .por_edad_maxima(edad_max)
      .por_dolencias(dolencias)
  end

  # Técnicas aplicadas en las sesiones de este diagnóstico, sin repetir.
  def tecnicas_aplicadas
    sessions.flat_map(&:treatments).uniq
  end

  # --- Progreso del tratamiento --------------------------------------------------------------------
  # Realizadas: las sesiones de hoy o de antes (y las que no tienen fecha). Programadas: las de fecha
  # futura, que salen en la agenda. Se cuentan en Ruby para aprovechar las sesiones ya cargadas.

  def sesiones_realizadas
    sessions.to_a.count { |sesion| sesion.fecha.nil? || sesion.fecha <= Date.current }
  end

  def sesiones_programadas
    sessions.to_a.count { |sesion| sesion.fecha&.after?(Date.current) }
  end

  def completado?
    sesiones_realizadas >= sesiones_recomendadas.to_i
  end
end
