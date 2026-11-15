# Registro de las fusiones del catálogo (D82): qué entrada se fusionó con cuál, cuántos usos se movieron,
# quién lo hizo y cuándo. Se guardan los nombres porque la entrada de origen deja de existir.
class CrearFusionesCatalogo < ActiveRecord::Migration[8.1]
  def change
    create_table :fusiones_catalogo do |t|
      t.string :tipo, null: false
      t.string :origen_nombre, null: false
      t.string :destino_nombre, null: false
      t.integer :destino_id, null: false
      t.integer :usos, null: false, default: 0
      t.references :osteopath, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
  end
end
