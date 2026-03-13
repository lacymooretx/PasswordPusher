# frozen_string_literal: true

resources :csp_tenants, except: [:new, :create] do
  post :sync, on: :collection
  post :onboard, on: :member
  post :toggle_sso, on: :member
end
