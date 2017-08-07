require 'rails_helper'

describe Jobs::ToggleTopicClosed do
  let(:admin) { Fabricate(:admin) }

  let(:topic) do
    Fabricate(:topic_timer, user: admin).topic
  end

  before do
    SiteSetting.queue_jobs = true
  end

  it 'should be able to close a topic' do
    topic

    freeze_time(1.hour.from_now) do
      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: true
      )

      expect(topic.reload.closed).to eq(true)

      expect(Post.last.raw).to eq(I18n.t(
        'topic_statuses.autoclosed_enabled_minutes', count: 60
      ))
    end
  end

  it 'should be able to open a topic' do
    topic.update!(closed: true)

    freeze_time(1.hour.from_now) do
      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: false
      )

      expect(topic.reload.closed).to eq(false)

      expect(Post.last.raw).to eq(I18n.t(
        'topic_statuses.autoclosed_disabled_minutes', count: 60
      ))
    end
  end

  describe 'when trying to close a topic that has been deleted' do
    it 'should not do anything' do
      topic.trash!

      Topic.any_instance.expects(:update_status).never

      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: true
      )
    end
  end

  describe 'when user is not authorized to close topics' do
    let(:topic) do
      Fabricate(:topic_timer, execute_at: 2.hours.from_now).topic
    end

    it 'should not do anything' do
      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: false
      )

      expect(topic.reload.closed).to eq(false)
    end
  end
end
