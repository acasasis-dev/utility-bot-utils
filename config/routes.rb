Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "application#hello"
  get "/utilitybot", to: "utility_bot#index"
  get "/utilitybot/:feature/:subfeature", to: "utility_bot#determine"
end
