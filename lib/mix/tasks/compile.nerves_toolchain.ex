defmodule Mix.Tasks.Compile.NervesToolchain do
  use Mix.Task
  import Mix.NervesToolchain.Utils
  require Logger

  @moduledoc """
  Build Nerves Toolchain
  """

  @recursive true
  @switches [cache: :string]
  @recv_timeout 120_000
  @dir "nerves/toolchain"

  def run(args) do
    Mix.shell.info "[nerves_toolchain][compile]"
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    config = Mix.Project.config
    toolchain = config[:app]
    {:ok, _} = Application.ensure_all_started(:nerves_toolchain)
    {:ok, _} = Application.ensure_all_started(toolchain)

    toolchain_config = Application.get_all_env(toolchain)
    target_tuple = toolchain_config[:target_tuple]
    cache_url = toolchain_config[:cache_url]

    nerves_toolchain_config = Application.get_all_env(:nerves_toolchain)
    |> Enum.into(%{})

    cache       = opts[:cache] || nerves_toolchain_config[:cache] || :github
    cache       = if is_binary(cache), do: String.to_atom(cache), else: cache
    build_path  = Mix.Project.build_path
                  |> Path.join(@dir)
    params      = %{target_tuple: target_tuple, cache_url: cache_url, version: config[:version], build_path: build_path}

    if stale?(build_path) do
      File.rm_rf!(build_path)
      toolchain   = cache(cache, params)
      toolchain
      |> copy_build(params)
    else
      shell_info "Toolchain up to date"
    end

  end

  defp stale?(build_path) do
    manifest = Path.join(build_path, ".nerves.lock")
    if (File.exists?(manifest)) do
      src =  Path.join(File.cwd!, "src")
      sources = src
      |> File.ls!
      |> Enum.map(& Path.join(src, &1))

      Mix.Utils.stale?(sources, [manifest])
    else
      true
    end
  end

  defp cache(:github, params=%{target_tuple: target_tuple}) when target_tuple != nil do
    "https://github.com/nerves-project/nerves-toolchain/releases/download/v#{params.version}/nerves-#{params.target_tuple}-#{host_platform}-#{host_arch}-v#{params.version}.tar.xz"
    |> download_url()
  end

  defp cache(_, params=%{cache_url: cache_url}) when cache_url != nil do
    cache_url
    |> download_url()
  end

  defp cache(:none, params) do
    compile(params)
  end


  defp download_url(url) do
    shell_info "Downloading Toolchain"
    case Mix.Utils.read_path(url) do
      {:ok, body} ->
        shell_info "Toolchain Downloaded"
        body
      {_, error} ->
        raise "Nerves Toolchain Github cache returned error: #{inspect error}"
    end
  end



  defp compile(params) do
    Mix.shell.info "Starting Nerves Toolchain Build"
    Mix.shell.info "  Host Platform: #{host_platform}"
    Mix.shell.info "  Host Arch: #{host_arch}"
    Mix.shell.info "  Target Tuple: #{params[:target_tuple]}"

    nerves_toolchain = Mix.Dep.loaded([])
    |> Enum.find(fn
      %{app: :nerves_toolchain} -> true
      _ -> false
    end)

    toolchain_src = nerves_toolchain
    |> Map.get(:opts)
    |> Keyword.get(:dest)
    toolchain_src = toolchain_src <> "/src"
    ctng_config = File.cwd! <> "/src/#{host_platform}.config"

    result = System.cmd("sh", ["build.sh", ctng_config], stderr_to_stdout: true, cd: toolchain_src, into: IO.stream(:stdio, :line))
    case result do
      {_, 0} -> File.read!(toolchain_src <> "/toolchain.tar.xz")
      {error, _} -> raise "Error compiling toolchain: #{inspect error}"
    end
  end

  defp copy_build(toolchain_tar, params) do
    shell_info "Unpacking Toolchain"
    dest = params.build_path
    tmp_dir = Path.join(dest, ".tmp")
    File.mkdir_p(dest)
    File.mkdir_p(tmp_dir)

    tar_file = tmp_dir <> "/toolchain.tar.xz"
    File.write(tar_file, toolchain_tar)
    extract_archive(tar_file,tmp_dir)

    source =
      File.ls!(tmp_dir)
      |> Enum.map(& Path.join(tmp_dir, &1))
      |> Enum.find(&File.dir?/1)

    File.cp_r(source, dest)
    File.rm_rf!(tmp_dir)
    Path.join(dest, ".nerves.lock")
    |> File.touch
  end

  defp extract_archive(tar_file,tmp_dir) do
    {_,os_type} = :os.type
    extract_archive(os_type,tar_file,tmp_dir)
  end

  defp extract_archive(:nt,tarxz_file,tmp_dir) do
    System.cmd("7z", ["x", tarxz_file], cd: tmp_dir)
    tar_file = String.replace_suffix(tarxz_file,".xz","")
    System.cmd("7z", ["x", tar_file], cd: tmp_dir)
  end

  defp extract_archive(_,tar_file,tmp_dir) do
    System.cmd("tar", ["xf", tar_file], cd: tmp_dir)
  end

  def shell_info(text), do: Mix.shell.info "[nerves_toolchain][http] #{text}"

end
