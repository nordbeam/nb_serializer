defmodule NbSerializer.Registry do
  @moduledoc """
  Registry for automatic serializer discovery.

  This registry allows you to automatically find the correct serializer for a given
  struct type, enabling features like `NbSerializer.serialize_inferred/2`.

  ## Usage

  Serializers are automatically registered when they are compiled if they specify
  the `:for` option:

      defmodule UserSerializer do
        use NbSerializer.Serializer, for: User

        schema do
          field :id, :number
          field :name, :string
        end
      end

  Now you can serialize User structs without specifying the serializer:

      user = %User{id: 1, name: "Alice"}
      NbSerializer.serialize_inferred(user)
      # Uses UserSerializer automatically

  ## Manual Registration

  You can also manually register serializers:

      NbSerializer.Registry.register(User, UserSerializer)

  ## Lookup

  To find a serializer for a struct:

      {:ok, serializer} = NbSerializer.Registry.lookup(User)
      # or
      {:ok, serializer} = NbSerializer.Registry.lookup(%User{})

  """

  use GenServer

  @registry_name __MODULE__

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @registry_name)
  end

  @doc """
  Registers a serializer for a given struct module.

  ## Examples

      iex> NbSerializer.Registry.register(User, UserSerializer)
      :ok

  """
  @spec register(module(), module()) :: :ok
  def register(struct_module, serializer_module) do
    GenServer.call(@registry_name, {:register, struct_module, serializer_module})
  end

  @doc """
  Looks up the serializer for a given struct module or struct instance.

  Returns `{:ok, serializer}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> NbSerializer.Registry.lookup(User)
      {:ok, UserSerializer}

      iex> NbSerializer.Registry.lookup(%User{})
      {:ok, UserSerializer}

      iex> NbSerializer.Registry.lookup(UnknownStruct)
      {:error, :not_found}

  """
  @spec lookup(module() | struct()) :: {:ok, module()} | {:error, :not_found}
  def lookup(struct) when is_struct(struct) do
    lookup(struct.__struct__)
  end

  def lookup(struct_module) when is_atom(struct_module) do
    GenServer.call(@registry_name, {:lookup, struct_module})
  end

  @doc """
  Lists all registered struct-serializer pairs.

  ## Examples

      iex> NbSerializer.Registry.list()
      [{User, UserSerializer}, {Post, PostSerializer}]

  """
  @spec list() :: [{module(), module()}]
  def list do
    GenServer.call(@registry_name, :list)
  end

  @doc """
  Unregisters a serializer for a given struct module.

  ## Examples

      iex> NbSerializer.Registry.unregister(User)
      :ok

  """
  @spec unregister(module()) :: :ok
  def unregister(struct_module) do
    GenServer.call(@registry_name, {:unregister, struct_module})
  end

  @doc """
  Clears all registrations (primarily for testing).

  ## Examples

      iex> NbSerializer.Registry.clear()
      :ok

  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(@registry_name, :clear)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, struct_module, serializer_module}, _from, state) do
    new_state = Map.put(state, struct_module, serializer_module)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:lookup, struct_module}, _from, state) do
    case Map.fetch(state, struct_module) do
      {:ok, serializer} -> {:reply, {:ok, serializer}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.to_list(state), state}
  end

  @impl true
  def handle_call({:unregister, struct_module}, _from, state) do
    new_state = Map.delete(state, struct_module)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{}}
  end
end
