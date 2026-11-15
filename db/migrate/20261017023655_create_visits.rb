class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.date :fecha
      t.text :anamnesis
      t.integer :escala_dolor
      t.string :motivo
      t.references :patient, null: false, foreign_key: true
      t.references :osteopath, null: false, foreign_key: true

      t.timestamps
    end
  end
end
