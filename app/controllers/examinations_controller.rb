# Exploración de una visita (una como máximo): /visits/:visit_id/examination
class ExaminationsController < ApplicationController
  before_action :set_visit
  before_action :set_examination, only: %i[show edit update destroy]

  def show
  end

  def new
    return redirect_to edit_visit_examination_path(@visit) if @visit.examination

    @examination = Examination.new(visit: @visit)
  end

  def create
    return redirect_to edit_visit_examination_path(@visit) if @visit.examination

    @examination = Examination.new(examination_params.merge(visit: @visit))
    if @examination.save
      redirect_to visit_examination_path(@visit), notice: "Exploración guardada correctamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @examination.update(examination_params)
      redirect_to visit_examination_path(@visit), notice: "Exploración actualizada correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @examination.destroy
    redirect_to @visit, notice: "Exploración borrada.", status: :see_other
  end

  private

  # Solo se accede a las visitas propias: las ajenas responden 404.
  def set_visit
    @visit = current_osteopath.visits.find(params[:visit_id])
  end

  def set_examination
    @examination = @visit.examination
    redirect_to new_visit_examination_path(@visit) unless @examination
  end

  def examination_params
    params.require(:examination).permit(*Examination::CAMPOS)
  end
end
