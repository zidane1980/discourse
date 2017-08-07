require 'rails_helper'

describe Admin::SiteTextsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteTextsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context '.index' do
      it 'returns json' do
        xhr :get, :index, q: 'title'
        expect(response).to be_success
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    context '.show' do
      it 'returns a site text for a key that exists' do
        xhr :get, :show, id: 'title'
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(I18n.t(:title))
      end

      it 'returns not found for missing keys' do
        xhr :get, :show, id: 'made_up_no_key_exists'
        expect(response).not_to be_success
      end
    end

    context '#update and #revert' do
      after do
        TranslationOverride.delete_all
        I18n.reload!
      end

      describe 'failure' do
        before do
          I18n.backend.store_translations(:en, some_key: '%{first} %{second}')
        end

        it 'returns the right error message' do
          xhr :put, :update, id: 'some_key', site_text: { value: 'hello %{key}' }

          expect(response.status).to eq(422)

          body = JSON.parse(response.body)

          expect(body['message']).to eq(I18n.t(
            'activerecord.errors.models.translation_overrides.attributes.value.missing_interpolation_keys',
            keys: 'first, second'
          ))
        end
      end

      it 'updates and reverts the key' do
        orig_title = I18n.t(:title)

        xhr :put, :update, id: 'title', site_text: { value: 'hello' }
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq('hello')

        # Revert
        xhr :put, :revert, id: 'title'
        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json).to be_present

        site_text = json['site_text']
        expect(site_text).to be_present

        expect(site_text['id']).to eq('title')
        expect(site_text['value']).to eq(orig_title)
      end

      it 'returns not found for missing keys' do
        xhr :put, :update, id: 'made_up_no_key_exists', site_text: { value: 'hello' }
        expect(response).not_to be_success
      end

      it 'logs the change' do
        original_title = I18n.t(:title)

        xhr :put, :update, id: 'title', site_text: { value: 'yay' }

        log = UserHistory.last

        expect(log.previous_value).to eq(original_title)
        expect(log.new_value).to eq('yay')
        expect(log.action).to eq(UserHistory.actions[:change_site_text])

        xhr :put, :revert, id: 'title'

        log = UserHistory.last

        expect(log.previous_value).to eq('yay')
        expect(log.new_value).to eq(original_title)
        expect(log.action).to eq(UserHistory.actions[:change_site_text])
      end
    end
  end

end
