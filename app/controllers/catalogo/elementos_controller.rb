# Edición, fusión y borrado de una entrada del catálogo (D82). Las subclases (TecnicasController y
# EnfermedadesController) indican el modelo y sus rutas; las vistas son comunes (catalogo/elementos).
class Catalogo::ElementosController < Catalogo::BaseController
  before_action :set_elemento
  helper_method :tipo_elemento, :ruta_elemento, :ruta_fusionar, :texto_usos

  def edit
  end

  # El nombre y la descripción cambian para todos los osteópatas.
  def update
    if @elemento.update(params.expect(parametro => %i[nombre descripcion]))
      redirect_to catalogo_path(anchor: ancla), notice: "«#{@elemento.nombre}» se ha actualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Solo se borran las entradas que no se usan; las que se usan se fusionan con otra.
  def destroy
    if usos.positive?
      redirect_to catalogo_path(anchor: ancla), status: :see_other,
                                               alert: "«#{@elemento.nombre}» no se puede borrar porque se usa: fusiónala con otra."
    else
      @elemento.destroy!
      redirect_to catalogo_path(anchor: ancla), status: :see_other, notice: "«#{@elemento.nombre}» se ha borrado."
    end
  end

  # Formulario para elegir con qué entrada se fusiona.
  def fusion
    @destinos = modelo.where.not(id: @elemento.id).order(:nombre)
    @usos = usos
  end

  def fusionar
    destino = modelo.where.not(id: @elemento.id).find_by(id: texto_param(:destino_id))
    return redirect_to(ruta_fusion, alert: "Elige con qué entrada fusionarla.") unless destino

    fusion = FusionCatalogo.fusionar!(@elemento, destino, osteopath: current_osteopath)
    redirect_to catalogo_path(anchor: ancla), status: :see_other,
                notice: "«#{fusion.origen_nombre}» se ha fusionado con «#{destino.nombre}»: " \
                        "#{texto_usos(fusion.usos)} #{fusion.usos == 1 ? 'pasa' : 'pasan'} a usar «#{destino.nombre}»."
  end

  private

  def set_elemento
    @elemento = modelo.find(params[:id])
  end

  # "1 sesión", "3 diagnósticos"...
  def texto_usos(numero)
    singular, plural = unidad_usos
    helpers.pluralize(numero, singular, plural: plural)
  end
end
