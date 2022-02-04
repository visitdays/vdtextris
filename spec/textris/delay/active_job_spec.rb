describe Textris::Delay::ActiveJob do
  before do
    class ActiveJobTexter < Textris::Base
      def delayed_action(phone)
        text to: phone
      end
    end

    class ActiveJob::Logging::LogSubscriber
      def info(*args, &block)
      end
    end
  end

  context 'ActiveJob not present' do
    let(:message) do
      Textris::Message.new(
        :content => 'X',
        :from    => 'X',
        :to      => '+48 111 222 333')
    end

    before do
      delegate = Class.new.include(Textris::Delay::ActiveJob::Missing)
      delegate = delegate.new

      [:deliver_now, :deliver_later].each do |method|
        allow(message).to receive(method) { delegate.send(method) }
      end
    end

    describe '#deliver_now' do
      it 'raises' do
        expect do
          message.deliver_now
        end.to raise_error(LoadError)
      end
    end

    describe '#deliver_later' do
      it 'raises' do
        expect do
          message.deliver_later
        end.to raise_error(LoadError)
      end
    end
  end

  context 'ActiveJob present' do
    describe '#deliver_now' do
      before do
        class XDelivery < Textris::Delivery::Base
          def deliver(to); end
        end

        class YDelivery < Textris::Delivery::Base
          def deliver(to); end
        end
      end

      it 'works the same as #deliver' do
        expect(Textris::Delivery).to receive(:get).
          and_return([XDelivery, YDelivery])

        message = Textris::Message.new(
          :content => 'X',
          :from    => 'X',
          :to      => '+48 111 222 333')

        expect_any_instance_of(XDelivery).to receive(:deliver_to_all)
        expect_any_instance_of(YDelivery).to receive(:deliver_to_all)

        message.deliver_now
      end
    end

    describe '#deliver_later' do
      before do
        class FakeLogger
          def log(kind = :all)
            @log[kind.to_s] || ""
          end
    
          def method_missing(name, *args)
            if Textris::Delivery::Log::AVAILABLE_LOG_LEVELS.include?(name.to_s)
              @log ||= {}
              @log[name.to_s] ||= ""
              @log[name.to_s] += args[0] + "\n"
              @log["all"] ||= ""
              @log["all"] += args[0] + "\n"
            end
          end
        end

        fake_rails = OpenStruct.new(
          application: OpenStruct.new(
            config: OpenStruct.new(
              textris_delivery_method: [:null]
            )
          ),
          env: OpenStruct.new(test?: true),
          logger: FakeLogger.new
        )

        stub_const("Rails", fake_rails)
      end

      it 'schedules action with proper params' do

        job = ActiveJobTexter.delayed_action('48111222333').deliver_later
        expect(job.queue_name).to eq 'textris'

        job = ActiveJobTexter.delayed_action('48111222333').deliver_later(:queue => :custom)
        expect(job.queue_name).to eq 'custom'
      end

      it 'executes job properly' do
        job = Textris::Delay::ActiveJob::Job.new

        expect_any_instance_of(Textris::Message).to receive(:deliver_now)


        job.perform('ActiveJobTexter', :delayed_action, ['48111222333'])
      end
    end
  end
end
