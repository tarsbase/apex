{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = Application.ensure_all_started(:ello_core)
{:ok, _} = Application.ensure_all_started(:ello_auth)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Ello.Core.Repo, :manual)
