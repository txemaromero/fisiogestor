class CreateJoinTableSessionsTreatments < ActiveRecord::Migration[8.1]
  def change
    create_join_table :sessions, :treatments, column_options: { foreign_key: true } do |t|
      t.index [ :session_id, :treatment_id ], unique: true
      t.index :treatment_id
    end
  end
end
