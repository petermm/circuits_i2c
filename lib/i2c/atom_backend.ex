defmodule Circuits.I2C.AtomBackend do
  @moduledoc """
  Circuits.I2C backend for AtomVM
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Bus

  import String

  defstruct [:ref, :retries, :flags]

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options), do: []

  @doc """
  Open an I2C bus

  No supported options. Must be in this format to set pins "sda=26_scl=27"
  """
  @impl Backend
  def open(bus_name, options) do
    retries = Keyword.get(options, :retries, 0)

    ["sda=" <> sda, "scl=" <> scl] =
      :string.split(bus_name, "_")

    conf = %{:sda => String.to_integer(sda), :scl => String.to_integer(scl)}

    bus_name_atom = String.to_atom(bus_name)

    case Process.whereis(bus_name_atom) do
      nil ->
        with {:ok, ref} <- :i2c_bus.start_link(conf) do
          Process.register(ref, bus_name_atom)
          {:ok, %__MODULE__{ref: ref, flags: [], retries: retries}}
          # {:ok, ref}
        end

      pid ->
        {:ok, %__MODULE__{ref: pid, flags: [], retries: retries}}
    end
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{name: __MODULE__}
  end

  defimpl Bus do
    @impl Bus
    def flags(%Circuits.I2C.AtomBackend{flags: flags}) do
      flags
    end

    @impl Bus
    def read(%Circuits.I2C.AtomBackend{ref: ref, retries: retries}, address, count, options) do
      retries = Keyword.get(options, :retries, retries)

      :i2c_bus.read_bytes(ref, address, count)
    end

    @impl Bus
    def write(%Circuits.I2C.AtomBackend{ref: ref, retries: retries}, address, data, options) do
      retries = Keyword.get(options, :retries, retries)

      :i2c_bus.write_bytes(ref, address, data)
    end

    @impl Bus
    def write_read(
          %Circuits.I2C.AtomBackend{ref: ref, retries: retries},
          address,
          [write_data],
          read_count,
          options
        ) do
      retries = Keyword.get(options, :retries, retries)

      :i2c_bus.write_bytes(ref, address, write_data)
      :timer.sleep(1)

      :i2c_bus.read_bytes(ref, address, read_count)
    end

    @impl Bus
    def close(%Circuits.I2C.AtomBackend{ref: ref}) do
      # Nif.close(ref)
      :i2c_bus.stop(ref)
    end
  end
end
