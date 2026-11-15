import { Controller } from "@hotwired/stimulus"

// Formulario de diagnóstico (diagnoses/_form): el campo «Nombre de la nueva enfermedad» solo se muestra,
// y solo se envía, cuando se elige «Otra…» en el select de enfermedades.
export default class extends Controller {
  static targets = ["eleccion", "grupo", "nombre"]

  connect() {
    this.mostrarNombre(false)
  }

  cambiar() {
    this.mostrarNombre(true)
  }

  mostrarNombre(enfocar) {
    const esOtra = this.eleccionTarget.value === "otra"
    this.grupoTarget.hidden = !esOtra
    this.nombreTarget.disabled = !esOtra
    if (esOtra && enfocar) this.nombreTarget.focus()
  }
}
