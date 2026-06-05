defmodule BotArmyOutcomesRecorder.Feedback.FeedbackLoggerTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyOutcomesRecorder.Feedback.FeedbackLogger

  describe "module structure" do
    test "FeedbackLogger module compiles" do
      # Module compiles and is available
      assert Code.ensure_loaded(FeedbackLogger) == {:module, FeedbackLogger}
    end
  end
end
