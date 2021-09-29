defmodule ViaInputEvent.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/copperpunk-elixir/via-input-event"

  def project do
    [
      app: :via_input_event,
      version: @version,
      elixir: "~> 1.12",
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Process input from a joystick or keyboard to a Via autopilot simulation"
  end

  defp package do
    %{
      licenses: ["GPL-3.0"],
      links: %{"Github" => @source_url}
    }
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:input_event, "~> 0.4.3"},
      {:via_utils, git: "https://github.com/copperpunk-elixir/via-utils.git", tag: "v0.1.4-alpha"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
