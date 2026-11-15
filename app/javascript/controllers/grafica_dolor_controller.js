import { Controller } from "@hotwired/stimulus"

// Tooltip de la gráfica «Evolución del dolor» (patients/_grafica_dolor): al pasar el ratón o el foco del
// teclado por la columna de una sesión, muestra el dolor antes y después, la fecha y la enfermedad.
// Los datos salen de los data-atributos de la columna y se insertan con textContent. El tooltip se coloca
// al lado de la columna (a la derecha en la mitad izquierda de la gráfica y al revés) para no tapar sus puntos.
export default class extends Controller {
  static targets = ["tooltip", "antes", "despues", "detalle"]

  mostrar(event) {
    const zona = event.currentTarget
    const { antes, despues, fecha, enfermedad } = zona.dataset

    this.antesTarget.textContent = antes
    this.despuesTarget.textContent = despues
    this.detalleTarget.textContent = `${fecha} · ${enfermedad}`

    this.zonaActiva?.classList.remove("activa")
    zona.classList.add("activa")
    this.zonaActiva = zona

    const tooltip = this.tooltipTarget
    tooltip.hidden = false
    const caja = this.element.getBoundingClientRect()
    const columna = zona.getBoundingClientRect()
    const izquierda = columna.left - caja.left
    const derecha = columna.right - caja.left
    const ancho = tooltip.offsetWidth
    const x = (izquierda + derecha) / 2 < caja.width / 2 ? derecha + 8 : izquierda - ancho - 8
    tooltip.style.left = `${Math.max(0, Math.min(x, caja.width - ancho))}px`
    tooltip.style.top = `${columna.top - caja.top}px`
  }

  ocultar(event) {
    event.currentTarget.classList.remove("activa")
    this.tooltipTarget.hidden = true
  }
}
