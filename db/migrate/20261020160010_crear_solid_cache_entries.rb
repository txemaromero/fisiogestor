# Tabla de Solid Cache (D98), la caché de producción, en la base de datos principal. Es la del esquema que
# trae la gema (solid_cache 1.0.10, db/cache_schema.rb), como migración para no necesitar otra base de datos.
class CrearSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false
      t.index :byte_size
      t.index %i[key_hash byte_size]
      t.index :key_hash, unique: true
    end
  end
end
