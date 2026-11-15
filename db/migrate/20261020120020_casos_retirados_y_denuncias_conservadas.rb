# Casos retirados de la red porque el paciente retiró el consentimiento (D96): aunque vuelva a consentir, no
# reaparecen solos; decide su autor. Y las denuncias se conservan aunque se borre lo denunciado (D97): se
# guarda de quién era, para que borrar no sirva para esquivar la moderación.
class CasosRetiradosYDenunciasConservadas < ActiveRecord::Migration[8.1]
  def change
    add_column :casos, :retirado_at, :datetime
    add_reference :denuncias, :autor_contenido, foreign_key: { to_table: :osteopaths, on_delete: :nullify }
  end
end
