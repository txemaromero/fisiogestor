# Un número de colegiado solo puede estar en una cuenta (D95), comparado sin espacios, puntos, guiones ni
# barras ni mayúsculas («28-01234» y «28/01234» son el mismo), y se guarda qué administrador verificó a cada
# osteópata.
class IdentidadDeLosColegiados < ActiveRecord::Migration[8.1]
  class Osteopata < ActiveRecord::Base
    self.table_name = "osteopaths"
  end

  def up
    add_column :osteopaths, :clave_colegiado, :string
    add_reference :osteopaths, :verificado_por, foreign_key: { to_table: :osteopaths, on_delete: :nullify }
    Osteopata.reset_column_information
    Osteopata.where.not(numero_colegiado: nil).find_each do |osteopata|
      osteopata.update_columns(clave_colegiado: osteopata.numero_colegiado.upcase.gsub(/[^[:alnum:]]/, ""))
    end
    add_index :osteopaths, :clave_colegiado, unique: true
  end

  def down
    remove_index :osteopaths, :clave_colegiado
    remove_reference :osteopaths, :verificado_por, foreign_key: { to_table: :osteopaths }
    remove_column :osteopaths, :clave_colegiado
  end
end
