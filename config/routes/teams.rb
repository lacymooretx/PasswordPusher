resources :teams do
  resources :memberships, only: [:update, :destroy]
  resources :invitations, only: [:create, :destroy], controller: "team_invitations"
  resource :policy, only: [:show, :edit, :update], controller: "team_policies"
  resource :branding, only: [:edit, :update], controller: "team_brandings"
  resource :two_factor, only: [:show, :update], controller: "team_two_factor" do
    post :remind
  end
end

# Public invitation acceptance (requires login)
get "invitations/:token/accept", to: "team_invitations#accept", as: :accept_team_invitation
