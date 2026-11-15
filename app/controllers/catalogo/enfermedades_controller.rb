# /catalogo/enfermedades/:id: editar, fusionar o borrar una enfermedad del catálogo.
class Catalogo::EnfermedadesController < Catalogo::ElementosController
  private

  def modelo = Disease
  def parametro = :disease
  def ancla = "enfermedades"
  def tipo_elemento = "enfermedad"
  def unidad_usos = %w[diagnóstico diagnósticos]
  def usos = @elemento.diagnoses.count
  def ruta_elemento = catalogo_enfermedad_path(@elemento)
  def ruta_fusion = fusion_catalogo_enfermedad_path(@elemento)
  def ruta_fusionar = fusionar_catalogo_enfermedad_path(@elemento)
end
