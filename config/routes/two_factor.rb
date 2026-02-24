namespace :users do
  resource :two_factor, only: [], controller: "two_factor" do
    get :setup
    post :enable
    delete :disable
    get :regenerate_backup_codes
  end

  resource :two_factor_verification, only: [:new, :create], controller: "two_factor_verification"
end
