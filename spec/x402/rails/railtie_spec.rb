# frozen_string_literal: true

RSpec.describe X402::Rails::Railtie do
  it "includes ControllerExtensions into ActionController on load" do
    controller_class = Class.new(ActionController::Base)
    hook = nil
    allow(ActiveSupport).to receive(:on_load).and_call_original
    allow(ActiveSupport).to receive(:on_load).with(:action_controller) { |&block| hook = block }

    initializer = described_class.initializers.find { |i| i.name == "x402.controller_extensions" }
    initializer.block.call

    controller_class.class_exec(&hook)

    expect(controller_class.include?(X402::Rails::ControllerExtensions)).to be(true)
  end
end
