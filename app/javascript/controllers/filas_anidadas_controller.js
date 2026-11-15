import { Controller } from "@hotwired/stimulus"

// Tabla de registros anidados (accepts_nested_attributes_for) a la que se añaden y quitan filas sin
// recargar la página. Las filas viven en la propia tabla del formulario y se envían con él al guardar.
//
// - Las filas nuevas se copian de un <template> cuyo índice NEW_RECORD se sustituye por uno único.
// - Al borrar una fila nueva se elimina sin más; una fila ya guardada se oculta y se marca con
//   _destroy=1 para que Rails la borre al guardar el formulario.
export default class extends Controller {
  static targets = ["filas", "plantilla"]

  agregarFila(event) {
    event.preventDefault()
    const indice = `${Date.now()}${this.filasTarget.children.length}`
    const html = this.plantillaTarget.innerHTML.replaceAll("NEW_RECORD", indice)
    this.filasTarget.insertAdjacentHTML("beforeend", html)
    this.filasTarget.lastElementChild.querySelector("input:not([type=hidden]), select")?.focus()
  }

  borrarFila(event) {
    event.preventDefault()
    const fila = event.target.closest("tr")
    if (fila.dataset.nuevo === "true") {
      fila.remove()
    } else {
      fila.querySelector("input[name$='[_destroy]']").value = "1"
      fila.hidden = true
    }
  }
}
