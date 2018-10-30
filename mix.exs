defmodule LogTamer.MixProject do
  use Mix.Project

  def project do
    [
      app: :log_tamer,
      version: "0.5.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def description do
    "Capture, flush and resume logging in the Elixir mix console."
  end

  def package do
    [
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/facto/log_tamer"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end
end
