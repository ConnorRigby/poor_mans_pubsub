defmodule PMPS do
  @moduledoc """
  Poor Mans PubSub

  Usage:

  ```elixir
  require PMPS
  {:ok, _} = PMPS.start_link(:name_of_pubsub)
  :ok = PMPS.subscribe(:name_of_pubsub, {:a, :b, _c})
  _ = PMPS.publish(:name_of_pubsub, {:a, :b, :c})
  flush()
  {:a, :b, :c, :d}
  :ok = PMPS.subscribe(:name_of_pubsub, %{some: %{complex: _pattern}}, fn(data) ->
    IO.inspect(data, label: "MATCHED  DATA")
  end)
  PMPS.publish(:name_of_pubsub, %{some: %{complex: {:pattern, :match}}})
  MATCHED DATA: %{some: %{complex: {:pattern, :match}}}
  ```
  """

  @doc false
  def child_spec(name) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [name]}
    }
  end

  @doc "Start a piubsub"
  def start_link(name) do
    Registry.start_link(keys: :duplicate, name: name)
  end

  @doc "Subscribe to events on a pubsub"
  defmacro subscribe(pubsub, pattern) do
    pattern_bin = :erlang.term_to_binary(pattern)
    quote location: :keep do
      PMPS.bare_subscribe(unquote(pubsub), unquote(pattern_bin), nil)
    end
  end

  defmacro subscribe(pubsub, pattern, fun) do
    pattern_bin = :erlang.term_to_binary(pattern)
    quote location: :keep do
      PMPS.bare_subscribe(unquote(pubsub), unquote(pattern_bin), unquote(fun))
    end
  end

  @doc false
  def bare_subscribe(pubsub, pattern_bin, fun) do
    pattern = :erlang.binary_to_term(pattern_bin)
    {:ok, _} = Registry.register(pubsub, __MODULE__, {pattern, fun})
    :ok
  end

  @doc "Publish an event on the pubsub"
  def publish(pubsub, data) do
    Registry.dispatch(pubsub, __MODULE__, fn entries ->
      for {pid, {pattern, fun}} <- entries do
        quoted = quote location: :keep, do:
          match?(unquote(pattern), unquote(Macro.escape(data)))

        case Code.eval_quoted(quoted, []) do
          {true, _} when is_function(fun) ->
            fun.(data)
          {true, _binding} ->
            send pid, data
          _ ->
            :ok
        end
      end
    end)
  end
end
