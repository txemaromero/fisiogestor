# Comentarios de los casos clínicos, con técnicas del catálogo sugeridas (D90).
class CrearComentarios < ActiveRecord::Migration[8.1]
  def change
    create_table :comentarios do |t|
      t.references :caso, null: false, foreign_key: true
      t.references :osteopath, null: false, foreign_key: true
      t.text :texto
      t.datetime :oculto_at
      t.timestamps
    end

    create_join_table :comentarios, :treatments do |t|
      t.index %i[comentario_id treatment_id], unique: true
      t.index :treatment_id
    end
    add_foreign_key :comentarios_treatments, :comentarios
    add_foreign_key :comentarios_treatments, :treatments
  end
end
