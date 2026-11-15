module PatientsHelper
  # Rutas de la ficha y de los antecedentes de un paciente: con el id si es del osteópata conectado y con
  # un identificador firmado si es de otro (ver Patient#id_ficha_para).
  def ruta_ficha(patient)
    patient_path(patient.id_ficha_para(current_osteopath))
  end

  def ruta_antecedentes(patient)
    medical_background_patient_path(patient.id_ficha_para(current_osteopath))
  end

  # Al borrar un paciente se borran todos sus datos (D86): conviene exportarlos antes si los ha pedido.
  def confirmacion_borrar_paciente(patient)
    "¿Seguro que quieres borrar a #{patient.nombre_completo}? Se borrarán todos sus datos: antecedentes, visitas, " \
      "pruebas con sus ficheros, diagnósticos, sesiones, casos clínicos publicados y el registro de accesos. " \
      "No se puede deshacer."
  end
end
