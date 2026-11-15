# Registro de accesos (D85): cada vez que un osteópata abre la ficha o los antecedentes de un paciente de
# otro osteópata, queda anotado quién, cuándo y qué página. El osteópata del paciente lo ve en la ficha.
# Sus propios accesos no se anotan.
class AccesoFicha < ApplicationRecord
  self.table_name = "accesos_fichas"

  PAGINAS = { "ficha" => "Ficha", "antecedentes" => "Antecedentes" }.freeze

  # Cuántos accesos se enseñan en la ficha (la exportación de los datos los incluye todos).
  ULTIMOS = 20

  belongs_to :osteopath
  belongs_to :patient

  validates :pagina, inclusion: { in: PAGINAS.keys }

  def nombre_pagina
    PAGINAS.fetch(pagina)
  end
end
