Rails.application.routes.draw do
  # Login (/osteopaths/sign_in), logout (DELETE /osteopaths/sign_out), recuperación de la clave
  # (/osteopaths/password/new) y confirmación del email (/osteopaths/confirmation, con el enlace del correo, y
  # /osteopaths/confirmation/new para pedir otro; D103). Los controladores propios añaden el límite de
  # intentos a los de Devise (y el de sesiones, el segundo factor; el de confirmación, la clave: D104).
  devise_for :osteopaths, skip: :registrations,
                          controllers: { sessions: "osteopaths/sessions", passwords: "osteopaths/passwords",
                                         confirmations: "osteopaths/confirmations" }
  # Del registro solo se usa el alta (/osteopaths/sign_up): la especificación no incluye editar ni
  # borrar la cuenta.
  devise_scope :osteopath do
    resource :registration, only: %i[new create], path: "osteopaths", path_names: { new: "sign_up" },
                            controller: "osteopaths/registrations", as: :osteopath_registration
    # El enlace del correo (GET) pide la clave; el email se confirma al enviarla (D104).
    patch "osteopaths/confirmation", to: "osteopaths/confirmations#update", as: nil
  end

  # Segundo paso del login (D84): el código de la app de autenticación o un código de recuperación.
  get "osteopaths/codigo", to: "osteopaths/codigos#new", as: :codigo_login
  post "osteopaths/codigo", to: "osteopaths/codigos#create"

  # Mi cuenta: el segundo factor (obligatorio). Alta o cambio de dispositivo, y códigos de recuperación.
  get "cuenta", to: "cuenta#show", as: :cuenta
  get "cuenta/segundo_factor", to: "dos_factores#new", as: :nuevo_segundo_factor
  post "cuenta/segundo_factor", to: "dos_factores#create", as: :segundo_factor
  post "cuenta/codigos_recuperacion", to: "dos_factores#regenerar_codigos", as: :codigos_recuperacion
  # Perfil profesional (D87): número de colegiado, especialidad, ciudad y presentación.
  get "cuenta/perfil", to: "perfiles#edit", as: :editar_perfil
  patch "cuenta/perfil", to: "perfiles#update", as: :perfil

  resources :patients do
    get :medical_background, on: :member
    # Todos los datos del paciente en JSON (D86), solo para su osteópata.
    get :exportar, on: :member
  end

  # Asistente de creación de visitas: GET muestra los tres paneles, POST lo guarda todo de una vez.
  get "crear_visita", to: "visits#new", as: :crear_visita
  post "crear_visita", to: "visits#create"

  # Tratamientos aplicados por todos los osteópatas, filtrando por perfil de paciente.
  get "filtrar_tratamientos", to: "treatments#filtrar", as: :filtrar_tratamientos
  get "tecnicas_aplicadas", to: "treatments#aplicadas", as: :tecnicas_aplicadas

  get "informes", to: "informes#index", as: :informes

  # Agenda: las sesiones del osteópata a partir de hoy, por días.
  get "agenda", to: "agenda#index", as: :agenda

  # Red de osteópatas verificados (D87-D91): casos clínicos anonimizados, sus comentarios (con técnicas
  # sugeridas), las denuncias y los perfiles profesionales. Un caso se publica desde un diagnóstico
  # propio: /diagnoses/:diagnosis_id/caso/new.
  resources :casos, only: %i[index show edit update destroy] do
    resources :comentarios, only: %i[create destroy], shallow: true
    post :denuncia, on: :member, to: "denuncias#create", defaults: { tipo: "caso" }
    # Su autor lo vuelve a publicar después de retirarse por falta de consentimiento (D96).
    patch :republicar, on: :member
  end
  resources :comentarios, only: [] do
    post :denuncia, on: :member, to: "denuncias#create", defaults: { tipo: "comentario" }
  end
  resources :osteopatas, only: :show

  # Administración (D88, D91): verificar a los profesionales y moderar los casos y comentarios.
  get "verificaciones", to: "verificaciones#index", as: :verificaciones
  post "verificaciones/:id", to: "verificaciones#create", as: :verificacion
  delete "verificaciones/:id", to: "verificaciones#destroy"
  get "moderacion", to: "moderacion#index", as: :moderacion
  scope "moderacion/:tipo/:id", constraints: { tipo: /caso|comentario/, id: /\d+/ } do
    post "ocultar", to: "moderacion#ocultar", as: :ocultar_moderacion
    post "descartar", to: "moderacion#descartar", as: :descartar_moderacion
    post "mostrar", to: "moderacion#mostrar", as: :mostrar_moderacion
  end

  # Catálogo de técnicas y enfermedades: editar, fusionar duplicados y borrar las que no se usan.
  # Solo para administradores (D81): a los demás les responde 404.
  get "catalogo", to: "catalogo/inicio#index", as: :catalogo
  namespace :catalogo do
    resources :tecnicas, only: %i[edit update destroy] do
      member do
        get :fusion
        post :fusionar
      end
    end
    resources :enfermedades, only: %i[edit update destroy] do
      member do
        get :fusion
        post :fusionar
      end
    end
  end

  # Una visita guardada se puede editar y borrar, y completar con diagnósticos y sesiones:
  #   /visits/:visit_id/diagnoses/new       /diagnoses/:id/edit
  #   /diagnoses/:diagnosis_id/sesiones/new /sesiones/:id/edit
  resources :visits, only: %i[show edit update destroy] do
    # Informe de la visita para el paciente (para imprimir o guardar como PDF).
    get :informe, on: :member
    resource :examination, only: %i[show new create edit update destroy]
    # /visits/:visit_id/supplementary_tests/:id/archivo: el fichero escaneado (solo para su osteópata).
    resources :supplementary_tests, only: %i[index new create edit update destroy] do
      get :archivo, on: :member
    end
    resources :diagnoses, only: %i[new create edit update destroy], shallow: true do
      resources :sesiones, only: %i[new create edit update destroy]
      # Publicar el diagnóstico como caso clínico (D89).
      resource :caso, only: %i[new create]
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/patients", status: 302)
end
