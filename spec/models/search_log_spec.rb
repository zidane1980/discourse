require 'rails_helper'

RSpec.describe SearchLog, type: :model do

  describe ".log" do

    context "invalid arguments" do
      it "no search type returns error" do
        status, _ = SearchLog.log(
          term: 'bounty hunter',
          search_type: :missing,
          ip_address: '127.0.0.1'
        )
        expect(status).to eq(:error)
      end

      it "no IP returns error" do
        status, _ = SearchLog.log(
          term: 'bounty hunter',
          search_type: :header,
          ip_address: nil
        )
        expect(status).to eq(:error)
      end
    end

    context "when anonymous" do
      it "logs and updates the search" do
        freeze_time
        action, log_id = SearchLog.log(
          term: 'jabba',
          search_type: :header,
          ip_address: '192.168.0.33'
        )
        expect(action).to eq(:created)
        log = SearchLog.find(log_id)
        expect(log.term).to eq('jabba')
        expect(log.search_type).to eq(SearchLog.search_types[:header])
        expect(log.ip_address).to eq('192.168.0.33')

        action, updated_log_id = SearchLog.log(
          term: 'jabba the hut',
          search_type: :header,
          ip_address: '192.168.0.33'
        )
        expect(action).to eq(:updated)
        expect(updated_log_id).to eq(log_id)
      end

      it "creates a new search with a different prefix" do
        freeze_time
        action, _ = SearchLog.log(
          term: 'darth',
          search_type: :header,
          ip_address: '127.0.0.1'
        )
        expect(action).to eq(:created)

        action, _ = SearchLog.log(
          term: 'anakin',
          search_type: :header,
          ip_address: '127.0.0.1'
        )
        expect(action).to eq(:created)
      end

      it "creates a new search with a different ip" do
        freeze_time
        action, _ = SearchLog.log(
          term: 'darth',
          search_type: :header,
          ip_address: '127.0.0.1'
        )
        expect(action).to eq(:created)

        action, _ = SearchLog.log(
          term: 'darth',
          search_type: :header,
          ip_address: '127.0.0.2'
        )
        expect(action).to eq(:created)
      end
    end

    context "when logged in" do
      let(:user) { Fabricate(:user) }

      it "logs and updates the search" do
        freeze_time
        action, log_id = SearchLog.log(
          term: 'hello',
          search_type: :full_page,
          ip_address: '192.168.0.1',
          user_id: user.id
        )
        expect(action).to eq(:created)
        log = SearchLog.find(log_id)
        expect(log.term).to eq('hello')
        expect(log.search_type).to eq(SearchLog.search_types[:full_page])
        expect(log.ip_address).to eq('192.168.0.1')
        expect(log.user_id).to eq(user.id)

        action, updated_log_id = SearchLog.log(
          term: 'hello dolly',
          search_type: :header,
          ip_address: '192.168.0.33',
          user_id: user.id
        )
        expect(action).to eq(:updated)
        expect(updated_log_id).to eq(log_id)
      end

      it "logs again if time has passed" do
        freeze_time(10.minutes.ago)

        action, _ = SearchLog.log(
          term: 'hello',
          search_type: :full_page,
          ip_address: '192.168.0.1',
          user_id: user.id
        )
        expect(action).to eq(:created)

        freeze_time(10.minutes.from_now)

        action, _ = SearchLog.log(
          term: 'hello',
          search_type: :full_page,
          ip_address: '192.168.0.1',
          user_id: user.id
        )

        expect(action).to eq(:created)
      end

      it "logs again with a different user" do
        freeze_time

        action, _ = SearchLog.log(
          term: 'hello',
          search_type: :full_page,
          ip_address: '192.168.0.1',
          user_id: user.id
        )
        expect(action).to eq(:created)

        action, _ = SearchLog.log(
          term: 'hello dolly',
          search_type: :full_page,
          ip_address: '192.168.0.1',
          user_id: Fabricate(:user).id
        )
        expect(action).to eq(:created)
      end

    end
  end

  context "clean_up" do

    it "will remove old logs" do
      SearchLog.log(term: 'jawa', search_type: :header, ip_address: '127.0.0.1')
      SearchLog.log(term: 'jedi', search_type: :header, ip_address: '127.0.0.1')
      SearchLog.log(term: 'rey', search_type: :header, ip_address: '127.0.0.1')
      SearchLog.log(term: 'finn', search_type: :header, ip_address: '127.0.0.1')

      SiteSetting.search_query_log_max_size = 5
      SearchLog.clean_up
      expect(SearchLog.count).to eq(4)

      SiteSetting.search_query_log_max_size = 2
      SearchLog.clean_up
      expect(SearchLog.count).to eq(2)
      expect(SearchLog.where(term: 'rey').first).to be_present
      expect(SearchLog.where(term: 'finn').first).to be_present
    end

  end

end
