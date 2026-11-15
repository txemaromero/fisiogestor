class CreateExaminations < ActiveRecord::Migration[8.1]
  def change
    create_table :examinations do |t|
      t.string :inspeccion_estatica
      t.string :inspeccion_dinamica
      t.string :disfunciones_somaticas
      t.string :examen_craneal_forma
      t.string :examen_craneal_fijaciones
      t.string :examen_craneal_musculos
      t.string :examen_visceral_palpacion
      t.string :examen_visceral_dermalgias
      t.string :examen_visceral_fijaciones
      t.string :examen_ortopedico_test
      t.string :examen_ortopedico_testing_muscular
      t.string :examen_neurologico_reflejos
      t.string :examen_neurologico_central
      t.string :examen_neurologico_periferico
      t.string :examen_neurologico_pulsos
      t.string :examen_neurologico_auscultacion
      t.string :examen_cardiovascular_tension_arterial
      t.references :visit, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
