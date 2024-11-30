defmodule RuntimeCheck.FlagActor do
  defstruct [:id]

  defimpl FunWithFlags.Actor do
    def id(%{id: id}) do
      "actor:#{id}"
    end
  end
end
