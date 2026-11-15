class CreateFamilyMedicalBackgrounds < ActiveRecord::Migration[8.1]
  def change
    create_table :family_medical_backgrounds do |t|
      t.string :familiar, null: false
      t.string :tipo, null: false
      t.text :descripcion, null: false
      t.references :patient, null: false, foreign_key: true

      t.timestamps
    end
  end
end
