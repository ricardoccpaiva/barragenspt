defmodule ExOptimizer do
  def optimize(path) do
    System.cmd("svgo", ["-i", "#{path}", "--config", "resources/svg/svgo-config.mjs"])
  end
end
