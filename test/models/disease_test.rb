require "test_helper"

class DiseaseTest < ActiveSupport::TestCase
  test "nombre y descripción son obligatorios" do
    enfermedad = Disease.new
    assert_not enfermedad.valid?
    assert enfermedad.errors.added?(:nombre, :blank)
    assert enfermedad.errors.added?(:descripcion, :blank)
  end

  test "el nombre es único sin distinguir mayúsculas" do
    assert Disease.new(nombre: "lumbago", descripcion: "x").invalid?
    assert Disease.new(nombre: "Escoliosis", descripcion: "x").valid?
  end

  test "el nombre se normaliza quitando espacios sobrantes" do
    assert_equal "Hernia discal", Disease.new(nombre: "  Hernia   discal ").nombre
  end

  test "buscar_o_crear! reutiliza la enfermedad o la crea" do
    assert_equal diseases(:lumbago), Disease.buscar_o_crear!("lumbago", "x")
    assert_difference -> { Disease.count } => 1 do
      Disease.buscar_o_crear!("Escoliosis", "Curvatura lateral de la columna")
    end
  end

  test "elegida: la del catálogo por su id o, con «Otra…», la del nombre escrito" do
    assert_equal diseases(:ciatica), Disease.elegida(diseases(:ciatica).id.to_s, "", "")
    assert_nil Disease.elegida("", "Escoliosis", "")
    assert_nil Disease.elegida("999999", nil, nil)
    assert_equal diseases(:lumbago), Disease.elegida(Disease::OTRA, " lumbago ", "")

    nueva = Disease.elegida(Disease::OTRA, "Escoliosis", "")
    assert nueva.persisted?
    assert_equal Disease::DESCRIPCION_NUEVA, nueva.descripcion
    assert_raises(ActiveRecord::RecordInvalid) { Disease.elegida(Disease::OTRA, " ", "") }
  end

  test "tiene diagnósticos" do
    assert_equal diagnoses(:diag_juan, :diag_maria_perez).sort, diseases(:lumbago).diagnoses.sort
  end
end
