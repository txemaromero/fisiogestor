# Los nombres de enfermedades y técnicas son únicos sin distinguir mayúsculas (D17). La validación de
# Rails no basta si dos peticiones crean a la vez el mismo nombre: el índice único sobre LOWER(nombre)
# lo garantiza en la base de datos.
class IndicesUnicosSinMayusculasEnCatalogos < ActiveRecord::Migration[8.1]
  def change
    remove_index :diseases, :nombre, unique: true
    add_index :diseases, "LOWER(nombre)", unique: true, name: "index_diseases_on_lower_nombre"

    remove_index :treatments, :nombre, unique: true
    add_index :treatments, "LOWER(nombre)", unique: true, name: "index_treatments_on_lower_nombre"
  end
end
