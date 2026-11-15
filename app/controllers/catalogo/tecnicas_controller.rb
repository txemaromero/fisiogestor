# /catalogo/tecnicas/:id: editar, fusionar o borrar una técnica del catálogo.
class Catalogo::TecnicasController < Catalogo::ElementosController
  private

  def modelo = Treatment
  def parametro = :treatment
  def ancla = "tecnicas"
  def tipo_elemento = "técnica"
  def unidad_usos = %w[sesión sesiones]
  def usos = @elemento.sessions.count
  def ruta_elemento = catalogo_tecnica_path(@elemento)
  def ruta_fusion = fusion_catalogo_tecnica_path(@elemento)
  def ruta_fusionar = fusionar_catalogo_tecnica_path(@elemento)
end
