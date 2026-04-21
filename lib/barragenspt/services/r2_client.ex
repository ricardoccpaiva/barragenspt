defmodule Barragenspt.Services.R2 do
  require Logger

  @r2_assets_bucket "assets-barragens-pt"

  def exists?(remote_path) do
    try do
      @r2_assets_bucket
      |> ExAws.S3.head_object(remote_path)
      |> ExAws.request!()

      true
    rescue
      _e in ExAws.Error ->
        Logger.info("File not found: #{remote_path}")
        false
    end
  end

  def upload(local_path, remote_path) do
    local_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(@r2_assets_bucket, remote_path)
    |> ExAws.request!()

    Logger.info("File uploaded to R2: #{remote_path}")
  end

  def download(path) do
    try do
      [payload] =
        ExAws.S3.download_file(@r2_assets_bucket, path, :memory)
        |> ExAws.stream!()
        |> Enum.to_list()

      Logger.info("Found #{path} in R2")

      {:ok, payload}
    rescue
      _e in ExAws.Error ->
        Logger.warning("File not found: #{path}")
        {:error, :not_found}
    end
  end

  def public_url(remote_path) when is_binary(remote_path) do
    path = normalize_remote_path(remote_path)

    case configured_public_base_url() do
      {:ok, base} ->
        {:ok, base <> path}

      :error ->
        with {:ok, base} <- ex_aws_public_base_url() do
          {:ok, base <> path}
        end
    end
  end

  defp configured_public_base_url do
    case Application.get_env(:barragenspt, :r2_public_base_url) do
      base when is_binary(base) and base != "" ->
        {:ok, String.trim_trailing(base, "/")}

      _ ->
        :error
    end
  end

  defp ex_aws_public_base_url do
    s3_cfg = Application.get_env(:ex_aws, :s3, [])
    raw_host = Keyword.get(s3_cfg, :host, "")

    cond do
      not is_binary(raw_host) or raw_host == "" ->
        {:error, :missing_r2_host}

      true ->
        {:ok, "https://assets.barragens.pt"}
    end
  end

  defp normalize_remote_path(remote_path) do
    if String.starts_with?(remote_path, "/"), do: remote_path, else: "/#{remote_path}"
  end
end
