import { Controller } from "@hotwired/stimulus"

// Asistente de /crear_visita: tres paneles (Visita, Diagnóstico y Sesiones) en una sola página.
//
// Nada se guarda hasta pulsar «Guardar» en el último panel. Las sesiones y sus técnicas se guardan
// en this.sesiones y se copian como JSON a un campo oculto del formulario, que se envía en un único
// POST. Si el servidor devuelve errores, la página vuelve con ese mismo JSON y el estado se recupera.
//
// Cada sesión es { fecha, escala_dolor_pre_sesion, escala_dolor_post_sesion, tecnicas: [{ nombre, descripcion }] }.
export default class extends Controller {
  static targets = [
    "pestana", "panel", "sesionesJson",
    "enfermedad", "grupoNuevaEnfermedad", "nuevaEnfermedad",
    "listaSesiones", "filasSesiones", "sinSesiones",
    "detalleSesion", "tituloDetalle", "detalleFecha", "detallePre", "detallePost", "filasTecnicas", "sinTecnicas",
    "modalSesion", "nuevaFecha", "nuevaPre", "nuevaPost",
    "modalTecnica", "tecnicaNombre", "tecnicaDescripcion", "avisoTecnica"
  ]
  static values = { panelInicial: Number }

  connect() {
    this.sesiones = this.leerSesiones()
    this.sesionActual = null
    this.cambiarEnfermedad()
    this.pintarSesiones()
    this.mostrarPanel(this.panelInicialValue)
    this.prepararModales()
  }

  // --- Navegación entre paneles ---------------------------------------------------------------

  siguiente(event) {
    event.preventDefault()
    if (this.validarPanel(this.panelActual)) this.mostrarPanel(this.panelActual + 1)
  }

  anterior(event) {
    event.preventDefault()
    this.mostrarPanel(this.panelActual - 1)
  }

  mostrarPanel(indice) {
    this.panelActual = indice
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== indice })
    this.pestanaTargets.forEach((pestana, i) => {
      pestana.classList.toggle("active", i === indice)
      if (i === indice) {
        pestana.setAttribute("aria-current", "step")
      } else {
        pestana.removeAttribute("aria-current")
      }
    })
  }

  // Comprueba los campos obligatorios del panel (required, min...) y marca en rojo los erróneos.
  validarPanel(indice) {
    const campos = [...this.panelTargets[indice].querySelectorAll("input, select, textarea")]
      .filter(campo => !campo.disabled)
    let primerError = null
    campos.forEach(campo => {
      const valido = campo.checkValidity()
      campo.classList.toggle("is-invalid", !valido)
      if (!valido && !primerError) primerError = campo
    })
    if (primerError) {
      this.mostrarPanel(indice)
      primerError.focus()
    }
    return primerError === null
  }

  // Al enviar el formulario. Enter en un campo de los primeros paneles avanza en lugar de guardar.
  guardar(event) {
    if (this.panelActual < this.panelTargets.length - 1) {
      this.siguiente(event)
      return
    }
    for (let i = 0; i < this.panelTargets.length; i++) {
      if (!this.validarPanel(i)) {
        event.preventDefault()
        return
      }
    }
    this.guardarEstado()
  }

  // --- Panel Diagnóstico ----------------------------------------------------------------------

  // Con «Otra…» se muestra (y pasa a ser obligatorio) el campo para escribir la enfermedad nueva.
  cambiarEnfermedad() {
    const esOtra = this.enfermedadTarget.value === "otra"
    this.grupoNuevaEnfermedadTarget.hidden = !esOtra
    this.nuevaEnfermedadTarget.disabled = !esOtra
    this.nuevaEnfermedadTarget.required = esOtra
    if (esOtra) this.nuevaEnfermedadTarget.focus()
  }

  // --- Panel Sesiones -------------------------------------------------------------------------

  crearSesion(event) {
    event.preventDefault()
    this.sesiones.push({
      fecha: this.nuevaFechaTarget.value,
      escala_dolor_pre_sesion: this.nuevaPreTarget.value,
      escala_dolor_post_sesion: this.nuevaPostTarget.value,
      tecnicas: []
    })
    this.nuevaPreTarget.value = ""
    this.nuevaPostTarget.value = ""
    this.cerrarModal(this.modalSesionTarget)
    this.pintarSesiones()
  }

  borrarSesion(event) {
    this.sesiones.splice(Number(event.currentTarget.dataset.indice), 1)
    this.pintarSesiones()
  }

  // «Ver»: abre el subpanel de la sesión en lugar de la lista.
  verSesion(event) {
    this.sesionActual = Number(event.currentTarget.dataset.indice)
    const sesion = this.sesiones[this.sesionActual]
    this.tituloDetalleTarget.textContent = `Sesión ${this.sesionActual + 1}`
    this.detalleFechaTarget.value = sesion.fecha
    this.detallePreTarget.value = sesion.escala_dolor_pre_sesion
    this.detallePostTarget.value = sesion.escala_dolor_post_sesion
    this.pintarTecnicas()
    this.listaSesionesTarget.hidden = true
    this.detalleSesionTarget.hidden = false
  }

  // Los cambios de fecha y escalas del subpanel se reflejan al momento en la tabla de sesiones.
  actualizarSesion() {
    const sesion = this.sesiones[this.sesionActual]
    sesion.fecha = this.detalleFechaTarget.value
    sesion.escala_dolor_pre_sesion = this.detallePreTarget.value
    sesion.escala_dolor_post_sesion = this.detallePostTarget.value
    this.pintarSesiones()
  }

  // «Guardar» del subpanel: vuelve a la lista de sesiones (los cambios ya están aplicados).
  cerrarDetalle(event) {
    event?.preventDefault()
    this.sesionActual = null
    this.detalleSesionTarget.hidden = true
    this.listaSesionesTarget.hidden = false
  }

  crearTecnica(event) {
    event.preventDefault()
    const nombre = this.tecnicaNombreTarget.value.trim().replace(/\s+/g, " ")
    const tecnicas = this.sesiones[this.sesionActual].tecnicas
    const repetida = tecnicas.some(tecnica => tecnica.nombre.toLowerCase() === nombre.toLowerCase())

    this.tecnicaNombreTarget.classList.toggle("is-invalid", repetida)
    if (nombre === "" || repetida) return

    tecnicas.push({ nombre, descripcion: this.tecnicaDescripcionTarget.value.trim() })
    this.tecnicaNombreTarget.value = ""
    this.tecnicaDescripcionTarget.value = ""
    this.cerrarModal(this.modalTecnicaTarget)
    this.pintarTecnicas()
    this.pintarSesiones()
  }

  borrarTecnica(event) {
    this.sesiones[this.sesionActual].tecnicas.splice(Number(event.currentTarget.dataset.indice), 1)
    this.pintarTecnicas()
    this.pintarSesiones()
  }

  // --- Pintado de tablas y estado -------------------------------------------------------------

  pintarSesiones() {
    const filas = this.sesiones.map((sesion, indice) => this.fila([
      this.formatearFecha(sesion.fecha),
      this.valorOGuion(sesion.escala_dolor_pre_sesion),
      this.valorOGuion(sesion.escala_dolor_post_sesion),
      sesion.tecnicas.map(tecnica => tecnica.nombre).join(", ") || "—",
      this.boton("Ver", "btn-success", "verSesion", indice),
      this.boton("Borrar", "btn-outline-danger", "borrarSesion", indice)
    ]))
    this.filasSesionesTarget.replaceChildren(...filas)
    this.sinSesionesTarget.hidden = this.sesiones.length > 0
    this.guardarEstado()
  }

  pintarTecnicas() {
    const tecnicas = this.sesiones[this.sesionActual].tecnicas
    const filas = tecnicas.map((tecnica, indice) => this.fila([
      tecnica.nombre,
      this.valorOGuion(tecnica.descripcion),
      this.boton("Borrar", "btn-outline-danger", "borrarTecnica", indice)
    ]))
    this.filasTecnicasTarget.replaceChildren(...filas)
    this.sinTecnicasTarget.hidden = tecnicas.length > 0
  }

  guardarEstado() {
    this.sesionesJsonTarget.value = JSON.stringify(this.sesiones)
  }

  leerSesiones() {
    try {
      const datos = JSON.parse(this.sesionesJsonTarget.value || "[]")
      return Array.isArray(datos) ? datos.map(sesion => ({ ...sesion, tecnicas: sesion.tecnicas || [] })) : []
    } catch {
      return []
    }
  }

  // --- Utilidades -----------------------------------------------------------------------------

  // Fila de tabla; las celdas son texto (nunca HTML, para no inyectar lo que escribe el usuario) o botones.
  fila(celdas) {
    const tr = document.createElement("tr")
    celdas.forEach(contenido => {
      const td = document.createElement("td")
      if (contenido instanceof HTMLElement) {
        td.classList.add("text-center")
        td.append(contenido)
      } else {
        td.textContent = contenido
      }
      tr.append(td)
    })
    return tr
  }

  boton(texto, clase, accion, indice) {
    const boton = document.createElement("button")
    boton.type = "button"
    boton.className = `btn btn-sm ${clase}`
    boton.textContent = texto
    boton.dataset.action = `asistente-visita#${accion}`
    boton.dataset.indice = indice
    return boton
  }

  // Al abrir un modal se limpia el aviso de error y se pone el foco en su primer campo. Se anota si
  // el modal está aún abriéndose (animación) porque en ese momento Bootstrap ignora hide().
  // Al terminar de abrirse, Bootstrap mueve el foco al propio modal: si el usuario ya estaba escribiendo
  // en un campo, se le devuelve el foco a ese campo para que el texto no acabe en otro.
  prepararModales() {
    [this.modalSesionTarget, this.modalTecnicaTarget].forEach(modal => {
      let campoConFoco = null
      modal.addEventListener("show.bs.modal", () => {
        modal.dataset.abriendo = "true"
        campoConFoco = null
        modal.querySelectorAll(".is-invalid").forEach(campo => campo.classList.remove("is-invalid"))
      })
      modal.addEventListener("focusin", event => {
        if (modal.dataset.abriendo === "true" && event.target !== modal) campoConFoco = event.target
      })
      modal.addEventListener("shown.bs.modal", () => {
        modal.dataset.abriendo = "false"
        const campo = campoConFoco || modal.querySelector("input")
        campo?.focus()
      })
    })
  }

  cerrarModal(modal) {
    const instancia = window.bootstrap.Modal.getOrCreateInstance(modal)
    if (modal.dataset.abriendo === "true") {
      modal.addEventListener("shown.bs.modal", () => instancia.hide(), { once: true })
    } else {
      instancia.hide()
    }
  }

  // "2026-03-04" -> "4/3/2026" (mismo formato que las fechas que pinta Rails)
  formatearFecha(fecha) {
    if (!fecha) return "—"
    const [anyo, mes, dia] = fecha.split("-")
    return `${Number(dia)}/${Number(mes)}/${anyo}`
  }

  valorOGuion(valor) {
    return valor === "" || valor === null || valor === undefined ? "—" : String(valor)
  }
}
