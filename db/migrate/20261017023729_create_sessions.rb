class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.date :fecha
      t.integer :escala_dolor_pre_sesion
      t.integer :escala_dolor_post_sesion
      t.references :diagnosis, null: false, foreign_key: true

      t.timestamps
    end
  end
end
