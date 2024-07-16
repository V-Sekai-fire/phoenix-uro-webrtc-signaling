defmodule UroWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import UroWeb.ChannelCase

      @endpoint UroWeb.Endpoint
    end
  end
end
