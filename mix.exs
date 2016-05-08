defmodule NervesToolchain.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_toolchain,
     version: "0.6.1",
     elixir: "~> 1.2",
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    []
  end

  defp deps do
    [{:httpoison, "~> 0.8"}]
  end

  defp description do
    """
    Elixir compilers and scripts for building Nerves Toolchains. For useable toolchain configurations see nerves_toolchain_*
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves_toolchain"}]
  end
end
