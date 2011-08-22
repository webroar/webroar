AdminPanel::Application.routes.draw do
  match '/' => 'admin#index', :as => :root
  match '/home' => 'admin#home', :as => :home
  match '/configuration' => 'admin#configuration', :as => :configuration
  match '/analytics' => 'graph#index', :as => :analytics
  match '/contact_us' => 'admin#contact_us', :as => :contact_us
  match '/settings' => 'admin#change_password_form', :as => :settings
  match '/exceptions' => 'exceptions#index', :as => :exceptions
  match '/logout' => 'admin#logout', :as => :logout
  match '/configuration/add' => 'application_specification#add_application_form'
  match '/configuration/create' => 'application_specification#add_application'
  match '/configuration/edit/:id' => 'application_specification#edit_application_form'
  match '/configuration/update/:id' => 'application_specification#edit_application'
  match '/settings/update' => 'admin#change_password'
  match '/:controller(/:action(/:id))'
end
