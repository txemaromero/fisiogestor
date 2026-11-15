# Buscador de pacientes (D74): nombre y apellidos sin tildes y en minúsculas, para que «maria» encuentre a
# «María». Se rellena aquí para los pacientes que ya existen y después lo mantiene Patient al guardar.
class TextoDeBusquedaEnPacientes < ActiveRecord::Migration[8.1]
  # Modelo propio de la migración, para no depender de cómo cambie Patient en el futuro.
  class Paciente < ActiveRecord::Base
    self.table_name = "patients"
  end

  def up
    add_column :patients, :texto_busqueda, :string
    Paciente.reset_column_information
    Paciente.find_each do |paciente|
      texto = I18n.transliterate("#{paciente.nombre} #{paciente.apellidos}", locale: :es).downcase.squish
      paciente.update_columns(texto_busqueda: texto)
    end
  end

  def down
    remove_column :patients, :texto_busqueda
  end
end
