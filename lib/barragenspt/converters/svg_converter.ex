defmodule ExOptimizer do
  def optimize(path) do
    System.cmd("svgo", ["-i", "#{path}", "--config", "svgo-config.mjs"])
  end
end
