defmodule BotArmyOutcomesRecorder.Feedback.FeedbackLoopIntegratorTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyOutcomesRecorder.Feedback.FeedbackLoopIntegrator

  describe "module structure" do
    test "FeedbackLoopIntegrator module compiles" do
      assert Code.ensure_loaded(FeedbackLoopIntegrator) == {:module, FeedbackLoopIntegrator}
    end
  end
end
