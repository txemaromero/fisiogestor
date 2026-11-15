import { Controller } from "@hotwired/stimulus"

// Botón «Imprimir o guardar como PDF» del informe de la visita: abre el diálogo de impresión del
// navegador, donde también se puede elegir «Guardar como PDF».
export default class extends Controller {
  imprimir() {
    window.print()
  }
}
