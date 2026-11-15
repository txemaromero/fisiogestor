class CreateTreatments < ActiveRecord::Migration[8.1]
  def change
    create_table :treatments do |t|
      t.string :nombre, null: false
      t.text :descripcion

      t.timestamps
    end
    add_index :treatments, :nombre, unique: true
  end
end
