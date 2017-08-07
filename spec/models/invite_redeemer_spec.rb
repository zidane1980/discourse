require 'rails_helper'

describe InviteRedeemer do

  describe '#create_user_from_invite' do
    it "should be created correctly" do
      user = InviteRedeemer.create_user_from_invite(Fabricate(:invite, email: 'walter.white@email.com'), 'walter', 'Walter White')
      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user).to be_active
      expect(user.email).to eq('walter.white@email.com')
      expect(user.approved).to eq(true)
    end

    it "can set the password too" do
      password = 's3cure5tpasSw0rD'
      user = InviteRedeemer.create_user_from_invite(Fabricate(:invite, email: 'walter.white@email.com'), 'walter', 'Walter White', password)
      expect(user).to have_password
      expect(user.confirm_password?(password)).to eq(true)
      expect(user.approved).to eq(true)
    end

    it "raises exception with record and errors" do
      error = nil
      begin
        InviteRedeemer.create_user_from_invite(Fabricate(:invite, email: 'walter.white@email.com'), 'walter', 'Walter White', 'aaa')
      rescue ActiveRecord::RecordInvalid => e
        error = e
      end
      expect(error).to be_present
      expect(error.record.errors[:password]).to be_present
    end
  end

  describe "#redeem" do
    let(:invite) { Fabricate(:invite) }
    let(:name) { 'john snow' }
    let(:username) { 'kingofthenorth' }
    let(:password) { 'know5nOthiNG' }
    let(:invite_redeemer) { InviteRedeemer.new(invite, username, name) }

    it "should redeem the invite if invited by staff" do
      SiteSetting.must_approve_users = true
      inviter = invite.invited_by
      inviter.admin = true
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(user.approved).to eq(true)
    end

    it "should redeem the invite if invited by non staff but not approve" do
      SiteSetting.must_approve_users = true
      inviter = invite.invited_by
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(user.approved).to eq(false)
    end

    it "should redeem the invite if invited by non staff and approve if staff not required to approve" do
      inviter = invite.invited_by
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(user.approved).to eq(true)
    end

    it "should not blow up if invited_by user has been removed" do
      invite.invited_by.destroy!
      invite.reload

      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(nil)
    end

    it "can set password" do
      inviter = invite.invited_by
      user = InviteRedeemer.new(invite, username, name, password).redeem
      expect(user).to have_password
      expect(user.confirm_password?(password)).to eq(true)
      expect(user.approved).to eq(true)
    end

    it "can set custom fields" do
      required_field = Fabricate(:user_field)
      optional_field = Fabricate(:user_field, required: false)
      user_fields = {
        required_field.id.to_s => 'value1',
        optional_field.id.to_s => 'value2'
      }
      user = InviteRedeemer.new(invite, username, name, password, user_fields).redeem

      expect(user).to be_present
      expect(user.custom_fields["user_field_#{required_field.id}"]).to eq('value1')
      expect(user.custom_fields["user_field_#{optional_field.id}"]).to eq('value2')
    end
  end
end
