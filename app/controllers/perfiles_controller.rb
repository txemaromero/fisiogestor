# Perfil profesional del osteópata conectado (D87): /cuenta/perfil. Cambiar el número de colegiado quita
# la verificación (D88).
class PerfilesController < ApplicationController
  before_action { @osteopata = current_osteopath }

  def edit
  end

  def update
    estaba_verificado = @osteopata.verificado?
    if @osteopata.update(params.expect(osteopath: %i[numero_colegiado especialidad ciudad presentacion]))
      aviso = "Perfil guardado."
      if estaba_verificado && !@osteopata.verificado?
        aviso += " Has cambiado el número de colegiado: un administrador tiene que volver a verificarlo."
      end
      redirect_to cuenta_path, notice: aviso
    else
      render :edit, status: :unprocessable_content
    end
  end
end
