# Denuncias de casos y comentarios, que resuelven los administradores (D91). Cada osteópata denuncia un
# mismo contenido una sola vez.
class CrearDenuncias < ActiveRecord::Migration[8.1]
  def change
    create_table :denuncias do |t|
      t.references :osteopath, null: false, foreign_key: true
      t.references :denunciable, polymorphic: true, null: false
      t.text :motivo, null: false
      t.datetime :resuelta_at
      t.references :resuelta_por, foreign_key: { to_table: :osteopaths, on_delete: :nullify }
      t.string :resultado
      t.timestamps
    end
    add_index :denuncias, %i[osteopath_id denunciable_type denunciable_id], unique: true, name: "index_denuncias_una_por_osteopata"
  end
end
