import { Controller } from "@hotwired/stimulus"

// Formulario de /informes: los controles del cuadro clínico (enfermedad, género y edad) solo se muestran,
// y solo se envían, cuando el tipo de informe elegido es «Técnicas posibles para un cuadro clínico».
export default class extends Controller {
  static targets = ["tipo", "cuadroClinico"]

  connect() {
    this.cambiarTipo()
  }

  cambiarTipo() {
    const visible = this.tipoTarget.value === "cuadro_clinico"
    this.cuadroClinicoTarget.hidden = !visible
    this.cuadroClinicoTarget.querySelectorAll("input, select").forEach(campo => { campo.disabled = !visible })
  }
}
