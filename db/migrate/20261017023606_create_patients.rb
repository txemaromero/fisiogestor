class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.string :nombre, null: false
      t.string :apellidos, null: false
      t.integer :anyo_nacimiento, null: false
      t.string :sexo, null: false
      t.references :osteopath, null: false, foreign_key: true

      t.timestamps
    end
  end
end
