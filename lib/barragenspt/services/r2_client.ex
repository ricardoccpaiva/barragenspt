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
      e in ExAws.Error ->
        Logger.warn("File not found: #{path}")
        {:error, :not_found}
    end
  end
end
