# Por defecto Rails envuelve los campos con errores en <div class="field_with_errors">, lo que rompe la
# maquetación de Bootstrap. Los campos erróneos se marcan con la clase "is-invalid" (ver ApplicationHelper).
Rails.application.config.action_view.field_error_proc = proc { |html_tag, _instance| html_tag }
