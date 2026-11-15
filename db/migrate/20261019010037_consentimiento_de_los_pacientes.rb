# Consentimiento del paciente para compartir sus datos clínicos anonimizados con otros osteópatas (D83).
# Los pacientes nuevos empiezan sin consentimiento; los que ya existían se marcan como que consienten,
# para que el filtro y los informes de la plataforma sigan funcionando como hasta ahora.
class ConsentimientoDeLosPacientes < ActiveRecord::Migration[8.1]
  class Paciente < ActiveRecord::Base
    self.table_name = "patients"
  end

  def up
    add_column :patients, :consiente_compartir, :boolean, default: false, null: false
    add_column :patients, :consentimiento_actualizado_at, :datetime
    Paciente.reset_column_information
    Paciente.update_all(consiente_compartir: true)
  end

  def down
    remove_column :patients, :consentimiento_actualizado_at
    remove_column :patients, :consiente_compartir
  end
end
