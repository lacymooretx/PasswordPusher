allowed_reg_routes = if Settings.disable_signups
  %i[edit update destroy]
else
  %i[new create edit update destroy]
end

devise_for :users, skip: :registrations, controllers: {
  sessions: "users/sessions",
  passwords: "users/passwords",
  unlocks: "users/unlocks",
  confirmations: "users/confirmations",
  registrations: "users/registrations",
  omniauth_callbacks: "users/omniauth_callbacks"
}

devise_scope :user do
  resource :registration,
    only: allowed_reg_routes,
    path: "users",
    path_names: {new: "sign_up"},
    controller: "users/registrations",
    as: :user_registration do
      get :cancel
      get :token
      delete :token, action: :regen_token
    end

  # SSO account linking — verify password before linking SSO to existing account
  get "users/sso/link", to: "users/omniauth_callbacks#link_account", as: :sso_link
  post "users/sso/link", to: "users/omniauth_callbacks#confirm_link"
end
