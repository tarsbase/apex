defmodule Ello.Stream.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Ello.Core.{Factory, Factory.Script}
    end
  end

  setup _tags do
    Ecto.Adapters.SQL.Sandbox.checkout(Ello.Core.Repo)
  end
end
