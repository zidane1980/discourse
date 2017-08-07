require 'rails_helper'

describe Admin::SiteSettingsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteSettingsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context 'index' do
      it 'returns success' do
        xhr :get, :index
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    context 'update' do

      before do
        SiteSetting.setting(:test_setting, "default")
        SiteSetting.refresh!
      end

      it 'sets the value when the param is present' do
        xhr :put, :update, id: 'test_setting', test_setting: 'hello'

        expect(SiteSetting.test_setting).to eq('hello')
      end

      it 'allows value to be a blank string' do
        xhr :put, :update, id: 'test_setting', test_setting: ''
        expect(SiteSetting.test_setting).to eq('')
      end

      it 'logs the change' do
        SiteSetting.test_setting = 'previous'
        StaffActionLogger.any_instance.expects(:log_site_setting_change).with('test_setting', 'previous', 'hello')
        xhr :put, :update, id: 'test_setting', test_setting: 'hello'
        expect(SiteSetting.test_setting).to eq('hello')
      end

      it 'does not allow changing of hidden settings' do
        SiteSetting.setting(:hidden_setting, "hidden", hidden: true)
        SiteSetting.refresh!
        result = xhr :put, :update, id: 'hidden_setting', hidden_setting: 'not allowed'
        expect(SiteSetting.hidden_setting).to eq("hidden")
        expect(result.status).to eq(422)
      end

      it 'fails when a setting does not exist' do
        expect {
          xhr :put, :update, id: 'provider', provider: 'gotcha'
        }.to raise_error(ArgumentError)
      end
    end

  end

end
