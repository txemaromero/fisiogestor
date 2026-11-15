require "test_helper"

class ExaminationTest < ActiveSupport::TestCase
  test "todos los campos son opcionales salvo la visita" do
    assert Examination.new(visit: visits(:visita_juan)).valid?
    assert_not Examination.new.valid?
  end

  test "una visita tiene como máximo una exploración" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Examination.create!(visit: visits(:visita_pepe))
    end
  end
end
