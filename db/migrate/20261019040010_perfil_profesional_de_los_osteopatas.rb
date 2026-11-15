# Perfil profesional de cada osteópata (D87) y su verificación por un administrador (D88): solo los
# osteópatas verificados ven los casos clínicos.
class PerfilProfesionalDeLosOsteopatas < ActiveRecord::Migration[8.1]
  def change
    add_column :osteopaths, :numero_colegiado, :string
    add_column :osteopaths, :especialidad, :string
    add_column :osteopaths, :ciudad, :string
    add_column :osteopaths, :presentacion, :text
    add_column :osteopaths, :verificado_at, :datetime
  end
end
