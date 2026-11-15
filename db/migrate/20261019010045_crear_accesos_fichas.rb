# Registro de quién abre la ficha o los antecedentes de un paciente que no es suyo, y cuándo (D85).
class CrearAccesosFichas < ActiveRecord::Migration[8.1]
  def change
    create_table :accesos_fichas do |t|
      t.references :osteopath, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.string :pagina, null: false
      t.datetime :created_at, null: false
    end
    add_index :accesos_fichas, %i[patient_id created_at]
  end
end
