defmodule MohoMine.Router do
  use MohoMine.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MohoMine do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/dashboard", DashboardController, :index
    get "/demo", DemoController, :index
    get "/file/:file_name", FileController, :download
  end

  # Other scopes may use custom stacks.
   scope "/api", MohoMine do
     pipe_through :api

     resources "/tenants", TenantController
     resources "/report_schemas", ReportSchemaController, except: [:show]
     resources "/report_schemas", ReportSchemaController, param: "system_name", only: [:show]
   end
end
