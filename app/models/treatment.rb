# Técnica de fisioterapia/osteopatía. Es un catálogo compartido por todos los osteópatas.
class Treatment < ApplicationRecord
  include EntradaCatalogo

  has_and_belongs_to_many :sessions
  # Comentarios de casos clínicos que la sugieren (D90). Al borrar la técnica se quita de esas sugerencias.
  has_and_belongs_to_many :comentarios

  normalizes :nombre, with: ->(nombre) { nombre.squish }

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :descripcion, length: { maximum: 1000 }

  # Busca por nombre sin distinguir mayúsculas, igual que la validación de unicidad.
  def self.buscar_por_nombre(nombre)
    find_by("LOWER(nombre) = LOWER(?)", nombre.to_s.squish)
  end

  # find_or_create_by(nombre:) del catálogo: reutiliza la técnica si ya existe con ese nombre y,
  # si no, la crea con la descripción indicada. Si otra petición la crea a la vez, el índice único
  # rechaza la segunda inserción y se devuelve la que ya existe (el savepoint permite seguir dentro de
  # la transacción del asistente de visita).
  def self.buscar_o_crear!(nombre, descripcion = nil)
    buscar_por_nombre(nombre) || transaction(requires_new: true) { create!(nombre: nombre, descripcion: descripcion.presence) }
  rescue ActiveRecord::RecordNotUnique
    buscar_por_nombre(nombre) || raise
  end

  # --- Informes (/informes) ---------------------------------------------------------------------
  # Cada técnica de estos rankings trae calculados dos atributos:
  #   num_sesiones     número de sesiones en las que se aplicó.
  #   reduccion_media  media de (dolor presesión − dolor postsesión) en esas sesiones. Las sesiones a las
  #                    que les falta alguna de las dos escalas no cuentan (AVG ignora los NULL); es nil
  #                    si ninguna las tiene.
  # Solo aparecen las técnicas que se han aplicado alguna vez. Con «sesiones» (Session.para_informe) solo
  # cuentan esas: las de unas fechas o las de los pacientes de un osteópata.

  REDUCCION_DOLOR = "sessions.escala_dolor_pre_sesion - sessions.escala_dolor_post_sesion".freeze

  # Por debajo de este número de sesiones, la reducción media de una técnica es poco fiable (D79).
  MIN_SESIONES_FIABLE = 5

  def self.con_estadisticas(sesiones = nil)
    relacion = joins(:sessions)
                 .group(:id)
                 .select("treatments.*", "COUNT(sessions.id) AS num_sesiones", "AVG(#{REDUCCION_DOLOR}) AS reduccion_media")
    sesiones ? relacion.where(sessions: { id: sesiones.select(:id) }) : relacion
  end

  # 1. Técnicas realizadas con mayor frecuencia: por número de sesiones en las que se aplicaron.
  def self.mas_frecuentes(sesiones = nil)
    con_estadisticas(sesiones).order(Arel.sql("num_sesiones").desc, :nombre)
  end

  # 2. Técnicas más efectivas: por reducción media del dolor, contando solo las sesiones que tienen
  #    las dos escalas (así num_sesiones es el número de sesiones en las que se basa la media).
  def self.mas_efectivas(sesiones = nil)
    con_estadisticas(sesiones)
      .where.not(sessions: { escala_dolor_pre_sesion: nil })
      .where.not(sessions: { escala_dolor_post_sesion: nil })
      .order(Arel.sql("reduccion_media").desc, Arel.sql("num_sesiones").desc, :nombre)
  end

  # 3. Técnicas menos efectivas: el mismo ranking en orden inverso.
  def self.menos_efectivas(sesiones = nil)
    mas_efectivas(sesiones).reverse_order
  end

  # 4. Técnicas posibles para un cuadro clínico: las aplicadas en diagnósticos de esa enfermedad
  #    (opcionalmente de pacientes de un sexo y rango de edad, con Diagnosis.filtrar), ordenadas por
  #    reducción media del dolor; las que no tienen ninguna sesión con ambas escalas van al final.
  def self.para_cuadro_clinico(disease_id, sexo: nil, edad_min: nil, edad_max: nil, sesiones: nil)
    diagnosticos = Diagnosis.filtrar(sexo: sexo, edad_min: edad_min, edad_max: edad_max, dolencias: [ disease_id ])
    con_estadisticas(sesiones)
      .where(sessions: { diagnosis_id: diagnosticos.select(:id) })
      .order(Arel.sql("reduccion_media").desc.nulls_last, Arel.sql("num_sesiones").desc, :nombre)
  end

  # En los rankings: si la media se basa en menos sesiones de las necesarias para fiarse de ella.
  def pocas_sesiones?
    num_sesiones.to_i < MIN_SESIONES_FIABLE
  end
end
