# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_27_090010) do
  create_table "accesos_fichas", force: :cascade do |t|
    t.integer "osteopath_id", null: false
    t.integer "patient_id", null: false
    t.string "pagina", null: false
    t.datetime "created_at", null: false
    t.index ["osteopath_id"], name: "index_accesos_fichas_on_osteopath_id"
    t.index ["patient_id", "created_at"], name: "index_accesos_fichas_on_patient_id_and_created_at"
    t.index ["patient_id"], name: "index_accesos_fichas_on_patient_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "casos", force: :cascade do |t|
    t.integer "diagnosis_id", null: false
    t.integer "osteopath_id", null: false
    t.string "titulo", null: false
    t.text "resumen", null: false
    t.datetime "oculto_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "retirado_at"
    t.index ["created_at"], name: "index_casos_on_created_at"
    t.index ["diagnosis_id"], name: "index_casos_on_diagnosis_id", unique: true
    t.index ["osteopath_id"], name: "index_casos_on_osteopath_id"
  end

  create_table "comentarios", force: :cascade do |t|
    t.integer "caso_id", null: false
    t.integer "osteopath_id", null: false
    t.text "texto"
    t.datetime "oculto_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["caso_id"], name: "index_comentarios_on_caso_id"
    t.index ["osteopath_id"], name: "index_comentarios_on_osteopath_id"
  end

  create_table "comentarios_treatments", id: false, force: :cascade do |t|
    t.integer "comentario_id", null: false
    t.integer "treatment_id", null: false
    t.index ["comentario_id", "treatment_id"], name: "index_comentarios_treatments_on_comentario_id_and_treatment_id", unique: true
    t.index ["treatment_id"], name: "index_comentarios_treatments_on_treatment_id"
  end

  create_table "denuncias", force: :cascade do |t|
    t.integer "osteopath_id", null: false
    t.string "denunciable_type", null: false
    t.integer "denunciable_id", null: false
    t.text "motivo", null: false
    t.datetime "resuelta_at"
    t.integer "resuelta_por_id"
    t.string "resultado"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "autor_contenido_id"
    t.index ["autor_contenido_id"], name: "index_denuncias_on_autor_contenido_id"
    t.index ["denunciable_type", "denunciable_id"], name: "index_denuncias_on_denunciable"
    t.index ["osteopath_id", "denunciable_type", "denunciable_id"], name: "index_denuncias_una_por_osteopata", unique: true
    t.index ["osteopath_id"], name: "index_denuncias_on_osteopath_id"
    t.index ["resuelta_por_id"], name: "index_denuncias_on_resuelta_por_id"
  end

  create_table "diagnoses", force: :cascade do |t|
    t.integer "sesiones_recomendadas", null: false
    t.text "descripcion"
    t.integer "visit_id", null: false
    t.integer "disease_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["disease_id"], name: "index_diagnoses_on_disease_id"
    t.index ["visit_id"], name: "index_diagnoses_on_visit_id"
  end

  create_table "diseases", force: :cascade do |t|
    t.string "nombre", null: false
    t.text "descripcion", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(nombre)", name: "index_diseases_on_lower_nombre", unique: true
  end

  create_table "examinations", force: :cascade do |t|
    t.string "inspeccion_estatica"
    t.string "inspeccion_dinamica"
    t.string "disfunciones_somaticas"
    t.string "examen_craneal_forma"
    t.string "examen_craneal_fijaciones"
    t.string "examen_craneal_musculos"
    t.string "examen_visceral_palpacion"
    t.string "examen_visceral_dermalgias"
    t.string "examen_visceral_fijaciones"
    t.string "examen_ortopedico_test"
    t.string "examen_ortopedico_testing_muscular"
    t.string "examen_neurologico_reflejos"
    t.string "examen_neurologico_central"
    t.string "examen_neurologico_periferico"
    t.string "examen_neurologico_pulsos"
    t.string "examen_neurologico_auscultacion"
    t.string "examen_cardiovascular_tension_arterial"
    t.integer "visit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["visit_id"], name: "index_examinations_on_visit_id", unique: true
  end

  create_table "family_medical_backgrounds", force: :cascade do |t|
    t.string "familiar", null: false
    t.string "tipo", null: false
    t.text "descripcion", null: false
    t.integer "patient_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id"], name: "index_family_medical_backgrounds_on_patient_id"
  end

  create_table "fusiones_catalogo", force: :cascade do |t|
    t.string "tipo", null: false
    t.string "origen_nombre", null: false
    t.string "destino_nombre", null: false
    t.integer "destino_id", null: false
    t.integer "usos", default: 0, null: false
    t.integer "osteopath_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["osteopath_id"], name: "index_fusiones_catalogo_on_osteopath_id"
  end

  create_table "osteopaths", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "apellidos", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "admin", default: false, null: false
    t.text "otp_secret"
    t.datetime "otp_activado_at"
    t.bigint "otp_ultimo_paso"
    t.text "codigos_recuperacion"
    t.string "numero_colegiado"
    t.string "especialidad"
    t.string "ciudad"
    t.text "presentacion"
    t.datetime "verificado_at"
    t.integer "otp_fallos", default: 0, null: false
    t.datetime "otp_bloqueado_hasta"
    t.string "clave_colegiado"
    t.integer "verificado_por_id"
    t.string "token_sesion"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.index ["clave_colegiado"], name: "index_osteopaths_on_clave_colegiado", unique: true
    t.index ["confirmation_token"], name: "index_osteopaths_on_confirmation_token", unique: true
    t.index ["email"], name: "index_osteopaths_on_email", unique: true
    t.index ["reset_password_token"], name: "index_osteopaths_on_reset_password_token", unique: true
    t.index ["verificado_por_id"], name: "index_osteopaths_on_verificado_por_id"
  end

  create_table "patients", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "apellidos", null: false
    t.integer "anyo_nacimiento", null: false
    t.string "sexo", null: false
    t.integer "osteopath_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "texto_busqueda"
    t.boolean "consiente_compartir", default: false, null: false
    t.datetime "consentimiento_actualizado_at"
    t.index ["osteopath_id"], name: "index_patients_on_osteopath_id"
  end

  create_table "personal_medical_backgrounds", force: :cascade do |t|
    t.string "tipo", null: false
    t.text "descripcion", null: false
    t.integer "patient_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id"], name: "index_personal_medical_backgrounds_on_patient_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.date "fecha"
    t.integer "escala_dolor_pre_sesion"
    t.integer "escala_dolor_post_sesion"
    t.integer "diagnosis_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_id"], name: "index_sessions_on_diagnosis_id"
  end

  create_table "sessions_treatments", id: false, force: :cascade do |t|
    t.integer "session_id", null: false
    t.integer "treatment_id", null: false
    t.index ["session_id", "treatment_id"], name: "index_sessions_treatments_on_session_id_and_treatment_id", unique: true
    t.index ["treatment_id"], name: "index_sessions_treatments_on_treatment_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", limit: 1024, null: false
    t.binary "value", limit: 536870912, null: false
    t.datetime "created_at", null: false
    t.integer "key_hash", limit: 8, null: false
    t.integer "byte_size", limit: 4, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "supplementary_tests", force: :cascade do |t|
    t.string "tipo_prueba", null: false
    t.text "resumen", null: false
    t.string "escaneado", null: false
    t.integer "visit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["visit_id"], name: "index_supplementary_tests_on_visit_id"
  end

  create_table "treatments", force: :cascade do |t|
    t.string "nombre", null: false
    t.text "descripcion"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(nombre)", name: "index_treatments_on_lower_nombre", unique: true
  end

  create_table "visits", force: :cascade do |t|
    t.date "fecha"
    t.text "anamnesis"
    t.integer "escala_dolor"
    t.string "motivo"
    t.integer "patient_id", null: false
    t.integer "osteopath_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["osteopath_id"], name: "index_visits_on_osteopath_id"
    t.index ["patient_id"], name: "index_visits_on_patient_id"
  end

  add_foreign_key "accesos_fichas", "osteopaths"
  add_foreign_key "accesos_fichas", "patients"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "casos", "diagnoses"
  add_foreign_key "casos", "osteopaths"
  add_foreign_key "comentarios", "casos"
  add_foreign_key "comentarios", "osteopaths"
  add_foreign_key "comentarios_treatments", "comentarios"
  add_foreign_key "comentarios_treatments", "treatments"
  add_foreign_key "denuncias", "osteopaths"
  add_foreign_key "denuncias", "osteopaths", column: "autor_contenido_id", on_delete: :nullify
  add_foreign_key "denuncias", "osteopaths", column: "resuelta_por_id", on_delete: :nullify
  add_foreign_key "diagnoses", "diseases"
  add_foreign_key "diagnoses", "visits"
  add_foreign_key "examinations", "visits"
  add_foreign_key "family_medical_backgrounds", "patients"
  add_foreign_key "fusiones_catalogo", "osteopaths", on_delete: :nullify
  add_foreign_key "osteopaths", "osteopaths", column: "verificado_por_id", on_delete: :nullify
  add_foreign_key "patients", "osteopaths"
  add_foreign_key "personal_medical_backgrounds", "patients"
  add_foreign_key "sessions", "diagnoses"
  add_foreign_key "sessions_treatments", "sessions"
  add_foreign_key "sessions_treatments", "treatments"
  add_foreign_key "supplementary_tests", "visits"
  add_foreign_key "visits", "osteopaths"
  add_foreign_key "visits", "patients"
end
