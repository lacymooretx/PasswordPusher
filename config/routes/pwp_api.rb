constraints(format: :json) do
  namespace :api do
    namespace :v1 do
      get :version, to: "version#show"

      resource :user_policy, only: [:show, :update], controller: "user_policies"

      resources :teams, only: [:index, :show, :create, :update, :destroy] do
        resources :members, only: [:index, :create, :update, :destroy], controller: "team_members"
        resources :invitations, only: [:index, :create, :destroy], controller: "team_invitations"
        resource :policy, only: [:show, :update], controller: "team_policies"
        resource :two_factor, only: [:show, :update], controller: "team_two_factor" do
          post :remind
        end
      end

      # Team invitation acceptance (token-based, not nested under team)
      post "teams/invitations/:token/accept", to: "team_invitations#accept", as: :accept_team_invitation

      resource :user_branding, only: [:show, :update]
      resources :requests, only: [:index, :show, :create, :update, :destroy]
      resources :webhooks, only: [:index, :show, :create, :update, :destroy]
      resources :audit_logs, only: [:index]

      # Admin settings API
      namespace :admin do
        get "settings", to: "settings#index"
        patch "settings", to: "settings#update"
      end

      # Account management
      resource :account, only: [:show, :update, :destroy], controller: "accounts" do
        post :register, on: :collection
        patch :password, action: :change_password
        post :token, action: :regenerate_token

        resource :two_factor, only: [], controller: "two_factor" do
          post :setup, on: :collection
          post :enable, on: :collection
          delete "", action: :disable, on: :collection
          post :backup_codes, action: :regenerate_backup_codes, on: :collection
        end

        resource :notifications, only: [:show, :update], controller: "notification_preferences"
      end
    end
  end

  resources :p, controller: "api/v1/pushes", as: :passwords, except: %i[new index edit update] do
    get "preview", on: :member
    get "audit", on: :member
    get "active", on: :collection
    get "expired", on: :collection
  end

  resources :p, controller: "api/v1/pushes", as: :json_pushes, except: %i[new index edit update] do
    get "preview", on: :member
    get "audit", on: :member
    get "active", on: :collection
    get "expired", on: :collection
  end

  # File pushes only enabled when logins are enabled.
  if Settings.enable_logins && Settings.enable_file_pushes
    resources :f, controller: "api/v1/pushes", as: :file_pushes, except: %i[new index edit update] do
      get "preview", on: :member
      get "audit", on: :member
      get "active", on: :collection
      get "expired", on: :collection
    end
  end

  # URL based pushes can only enabled when logins are enabled.
  if Settings.enable_logins && Settings.enable_url_pushes
    resources :r, controller: "api/v1/pushes", as: :urls, except: %i[new index edit update] do
      get "preview", on: :member
      get "audit", on: :member
      get "active", on: :collection
      get "expired", on: :collection
    end
  end
end
