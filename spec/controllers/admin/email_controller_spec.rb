require 'rails_helper'

describe Admin::EmailController do

  it "is a subclass of AdminController" do
    expect(Admin::EmailController < Admin::AdminController).to eq(true)
  end

  let!(:user) { log_in(:admin) }

  context '.index' do
    before do
      subject.expects(:action_mailer_settings).returns(username: 'username',
                                                       password: 'secret')

      xhr :get, :index
    end

    it 'does not include the password in the response' do
      mail_settings = JSON.parse(response.body)['settings']

      expect(
        mail_settings.select { |setting| setting['name'] == 'password' }
      ).to be_empty
    end
  end

  context '.sent' do
    before do
      xhr :get, :sent
    end

    subject { response }
    it { is_expected.to be_success }
  end

  context '.skipped' do
    before do
      xhr :get, :skipped
    end

    subject { response }
    it { is_expected.to be_success }
  end

  context '.test' do
    it 'raises an error without the email parameter' do
      expect { xhr :post, :test }.to raise_error(ActionController::ParameterMissing)
    end

    context 'with an email address' do
      it 'enqueues a test email job' do
        job_mock = mock
        Jobs::TestEmail.expects(:new).returns(job_mock)
        job_mock.expects(:execute).with(to_address: 'eviltrout@test.domain')
        xhr :post, :test, email_address: 'eviltrout@test.domain'
      end
    end
  end

  context '.preview_digest' do
    it 'raises an error without the last_seen_at parameter' do
      expect { xhr :get, :preview_digest }.to raise_error(ActionController::ParameterMissing)
    end

    it "previews the digest" do
      xhr :get, :preview_digest, last_seen_at: 1.week.ago, username: user.username
      expect(response).to be_success
    end
  end

  context '#handle_mail' do
    before do
      log_in_user(Fabricate(:admin))
      SiteSetting.queue_jobs = true
    end

    it 'should enqueue the right job' do
      expect { xhr :post, :handle_mail, email: email('cc') }
        .to change { Jobs::ProcessEmail.jobs.count }.by(1)
    end
  end

  context '.rejected' do
    it 'should provide a string for a blank error' do
      Fabricate(:incoming_email, error: "")
      xhr :get, :rejected
      rejected = JSON.parse(response.body)
      expect(rejected.first['error']).to eq(I18n.t("emails.incoming.unrecognized_error"))
    end
  end

  context '.incoming' do
    it 'should provide a string for a blank error' do
      incoming_email = Fabricate(:incoming_email, error: "")
      xhr :get, :incoming, id: incoming_email.id
      incoming = JSON.parse(response.body)
      expect(incoming['error']).to eq(I18n.t("emails.incoming.unrecognized_error"))
    end
  end

end
