# Osteópatas administradores del catálogo de técnicas y enfermedades (D81). Nadie lo es por defecto; se
# asigna con «bin/rails administradores:dar EMAIL=...».
class AdministradoresDelCatalogo < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :admin, :boolean, default: false, null: false
  end
end
