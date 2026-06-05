defmodule BotArmyOutcomesRecorder.NATS.Responders.FeedbackAnalysisResponderTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyOutcomesRecorder.NATS.Responders.FeedbackAnalysisResponder

  describe "module structure" do
    test "FeedbackAnalysisResponder module compiles" do
      assert Code.ensure_loaded(FeedbackAnalysisResponder) == {:module, FeedbackAnalysisResponder}
    end
  end
end
