class CreateSupplementaryTests < ActiveRecord::Migration[8.1]
  def change
    create_table :supplementary_tests do |t|
      t.string :tipo_prueba, null: false
      t.text :resumen, null: false
      t.string :escaneado, null: false
      t.references :visit, null: false, foreign_key: true

      t.timestamps
    end
  end
end
