# Sesión de fisioterapia de un diagnóstico, con el dolor antes y después y las técnicas aplicadas.
# Ojo: en vistas y controladores "session" (en minúscula) es la sesión HTTP de Rails;
# para las variables locales de este modelo se usa "sesion".
class Session < ApplicationRecord
  belongs_to :diagnosis
  has_and_belongs_to_many :treatments

  validates :escala_dolor_pre_sesion, :escala_dolor_post_sesion,
            numericality: { only_integer: true, in: 0..10 }, allow_nil: true

  # Sesiones que cuentan en un informe (D78): entre unas fechas (incluidas) y, si se indica, solo las de
  # los pacientes de un osteópata. Con fechas, las sesiones sin fecha no cuentan.
  # «visibles_para» es obligatorio: un osteópata solo cuenta las sesiones de sus pacientes y las de pacientes
  # de otros que consienten compartir sus datos (D83).
  def self.para_informe(visibles_para:, desde: nil, hasta: nil, osteopath: nil)
    sesiones = joins(diagnosis: { visit: :patient }).merge(Patient.visibles_para(visibles_para))
    sesiones = sesiones.where(fecha: desde..) if desde
    sesiones = sesiones.where(fecha: ..hasta) if hasta
    sesiones = sesiones.joins(diagnosis: :visit).where(visits: { osteopath_id: osteopath.id }) if osteopath
    sesiones
  end
end
