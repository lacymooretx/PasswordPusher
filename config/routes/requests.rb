resources :requests

# Public intake form (no authentication)
# Both show (GET) and create (POST) need the request URL token in the path
resources :req, only: [:show], controller: "request_submissions", as: :request_submissions do
  post "", on: :member, action: :create
end
