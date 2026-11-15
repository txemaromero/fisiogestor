# Fusión de dos entradas duplicadas del catálogo (D82): todo lo que usaba la de origen pasa a usar la de
# destino, la de origen se borra y queda registrado quién lo hizo y cuándo. Solo la hacen los
# administradores (D81).
class FusionCatalogo < ApplicationRecord
  self.table_name = "fusiones_catalogo"

  TIPOS = { "tecnica" => Treatment, "enfermedad" => Disease }.freeze

  belongs_to :osteopath, optional: true

  validates :tipo, inclusion: { in: TIPOS.keys }
  validates :origen_nombre, :destino_nombre, presence: true

  # Mueve los usos de origen a destino y borra origen, todo en una transacción. Si el destino no tiene
  # descripción, se queda con la del origen.
  def self.fusionar!(origen, destino, osteopath:)
    tipo = TIPOS.key(origen.class)
    unless tipo && destino.instance_of?(origen.class) && origen != destino
      raise ArgumentError, "Solo se fusionan dos entradas distintas del mismo catálogo"
    end

    transaction do
      usos = origen.is_a?(Treatment) ? mover_tecnica(origen, destino) : origen.diagnoses.update_all(disease_id: destino.id)
      destino.update!(descripcion: origen.descripcion) if destino.descripcion.blank? && origen.descripcion.present?
      origen.reload.destroy!
      create!(tipo: tipo, origen_nombre: origen.nombre, destino_nombre: destino.nombre, destino_id: destino.id,
              usos: usos, osteopath: osteopath)
    end
  end

  # Al fusionar técnicas, en cada tabla que las usa (las técnicas aplicadas en las sesiones y las sugeridas
  # en los comentarios de los casos clínicos, D90): primero se quitan las de origen donde ya está la de
  # destino (el par es único) y después se cambia la de origen por la de destino en el resto.
  SQL_MOVER_TECNICA = [
    [ "DELETE FROM sessions_treatments WHERE treatment_id = ? " \
      "AND session_id IN (SELECT session_id FROM sessions_treatments WHERE treatment_id = ?)",
      "UPDATE sessions_treatments SET treatment_id = ? WHERE treatment_id = ?" ],
    [ "DELETE FROM comentarios_treatments WHERE treatment_id = ? " \
      "AND comentario_id IN (SELECT comentario_id FROM comentarios_treatments WHERE treatment_id = ?)",
      "UPDATE comentarios_treatments SET treatment_id = ? WHERE treatment_id = ?" ]
  ].freeze

  # Devuelve en cuántas sesiones estaba la técnica de origen.
  def self.mover_tecnica(origen, destino)
    usos = origen.sessions.count
    SQL_MOVER_TECNICA.each do |quitar_repetidas, cambiar|
      connection.delete(sanitize_sql_array([ quitar_repetidas, origen.id, destino.id ]))
      connection.update(sanitize_sql_array([ cambiar, destino.id, origen.id ]))
    end
    usos
  end
  private_class_method :mover_tecnica

  def tipo_legible
    tipo == "tecnica" ? "Técnica" : "Enfermedad"
  end
end
