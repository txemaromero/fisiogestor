# Pruebas complementarias de una visita: /visits/:visit_id/supplementary_tests
class SupplementaryTestsController < ApplicationController
  # CSP de las respuestas con el fichero: los visores de imagen y PDF del navegador necesitan estilos
  # inline (la CSP de las páginas los bloquea), y un fichero no necesita nada más: ni scripts, ni
  # conexiones, ni formularios, ni que otra web lo incruste.
  POLITICA_FICHEROS = ActionDispatch::ContentSecurityPolicy.new do |politica|
    politica.default_src :none
    politica.img_src :self
    politica.style_src :unsafe_inline
    politica.base_uri :none
    politica.form_action :none
    politica.frame_ancestors :none
  end

  before_action :set_visit
  before_action :set_supplementary_test, only: %i[edit update destroy archivo]

  def index
    @supplementary_tests = @visit.supplementary_tests.with_attached_archivo.order(:id)
  end

  def new
    @supplementary_test = @visit.supplementary_tests.build
  end

  def create
    @supplementary_test = @visit.supplementary_tests.build(supplementary_test_params)
    if @supplementary_test.save
      redirect_to visit_supplementary_tests_path(@visit), notice: "Prueba complementaria guardada correctamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  # Si no se sube otro fichero, se conserva el que tenía.
  def update
    if @supplementary_test.update(supplementary_test_params)
      redirect_to visit_supplementary_tests_path(@visit), notice: "Prueba complementaria actualizada correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @supplementary_test.destroy
    redirect_to visit_supplementary_tests_path(@visit), notice: "Prueba complementaria borrada.", status: :see_other
  end

  # El fichero escaneado: solo para el osteópata de la visita (set_visit) y sin guardarse en cachés.
  # Se abre en el navegador, o se descarga con ?descargar=1.
  def archivo
    archivo = @supplementary_test.archivo
    return head :not_found unless archivo.attached?

    blob = archivo.blob
    request.content_security_policy = POLITICA_FICHEROS
    request.content_security_policy_nonce_directives = [] # con un nonce, el navegador ignoraría 'unsafe-inline'
    response.headers["Cache-Control"] = "private, no-store"
    send_data blob.download, filename: blob.filename.sanitized, type: blob.content_type_for_serving,
                             disposition: blob.forced_disposition_for_serving || (params[:descargar] ? :attachment : :inline)
  end

  private

  # Solo se accede a las visitas propias: las ajenas responden 404.
  def set_visit
    @visit = current_osteopath.visits.find(params[:visit_id])
  end

  def set_supplementary_test
    @supplementary_test = @visit.supplementary_tests.find(params[:id])
  end

  def supplementary_test_params
    params.expect(supplementary_test: %i[tipo_prueba resumen archivo])
  end
end
