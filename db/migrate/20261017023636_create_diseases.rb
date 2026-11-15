class CreateDiseases < ActiveRecord::Migration[8.1]
  def change
    create_table :diseases do |t|
      t.string :nombre, null: false
      t.text :descripcion, null: false

      t.timestamps
    end
    add_index :diseases, :nombre, unique: true
  end
end
