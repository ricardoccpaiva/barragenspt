defmodule Barragenspt.Services.S3 do
  alias ExAws.S3

  def upload(local_path, bucket, remote_path) do
    local_path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket, remote_path)
    |> ExAws.request!()
  end
end
