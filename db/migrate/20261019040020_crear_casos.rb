# Casos clínicos anonimizados (D89): un diagnóstico que su osteópata publica para que lo comenten los demás.
# Un diagnóstico se publica una sola vez; los datos clínicos se leen del diagnóstico, no se copian.
class CrearCasos < ActiveRecord::Migration[8.1]
  def change
    create_table :casos do |t|
      t.references :diagnosis, null: false, foreign_key: true, index: { unique: true }
      t.references :osteopath, null: false, foreign_key: true
      t.string :titulo, null: false
      t.text :resumen, null: false
      t.datetime :oculto_at
      t.timestamps
    end
    add_index :casos, :created_at
  end
end
