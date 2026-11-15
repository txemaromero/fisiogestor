class CreateDiagnoses < ActiveRecord::Migration[8.1]
  def change
    create_table :diagnoses do |t|
      t.integer :sesiones_recomendadas, null: false
      t.text :descripcion
      t.references :visit, null: false, foreign_key: true
      t.references :disease, null: false, foreign_key: true

      t.timestamps
    end
  end
end
